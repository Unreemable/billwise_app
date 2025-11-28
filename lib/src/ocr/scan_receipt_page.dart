// lib/src/ocr/scan_receipt_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../gemini_service.dart';           // خدمة Gemini OCR (ما عدلنا عليها هنا)
import '../bills/ui/add_bill_page.dart';
import 'receipt_parser.dart';              // مفسّر احتياطي للنص إذا ما رجع JSON جاهز

// NEW: telemetry (تتبع الأداء/الوقت للأو سي آر)
import '../common/metrics.dart';

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});
  static const route = '/scan-receipt';

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  // ===== ألوان وتصميم الواجهة فقط =====
  static const _bg = Color(0xFF0B0B2E);
  static const _card = Color(0xFF171636);
  static const _cardStroke = Color(0x1FFFFFFF);
  static const _textDim = Color(0xFFBFC3D9);
  static const _accent = Color(0xFF5D6BFF);
  static const _secondaryBtn = Color(0xFF2C2B52);
  static const _headerGrad = LinearGradient(
    colors: [Color(0xFF0B0B2E), Color(0xFF21124C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ملف الصورة اللي اختارها المستخدم
  File? _image;

  // هل نشتغل الآن على الأو سي آر؟
  bool _processing = false;

  // رسالة خطأ نظهرها تحت لو صار شيء
  String? _error;

  /// اختيار صورة من الكاميرا أو الاستديو وحفظها في مجلد التطبيق
  Future<void> _pick(bool camera) async {
    // كل ما نختار صورة جديدة، نمسح رسالة الخطأ القديمة
    setState(() => _error = null);

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 92, // نقلل الجودة قليلاً عشان حجم الملف
    );
    if (x == null) return; // المستخدم رجع بدون ما يختار صورة

    // نحفظ نسخة من الصورة داخل مجلد التطبيق (Documents) باسم ثابت
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}';
    final saved = await File(x.path).copy(p.join(dir.path, filename));

    setState(() => _image = saved);
  }

  /// تجهيز الصورة قبل إرسالها لـ Gemini:
  /// - تصغير العرض إلى 1280 بكسل لو كانت كبيرة
  /// - ضغطها بصيغة JPG بجودة 85
  /// الهدف: نقلل الضجيج وحجم البيانات (tokens) بدون ما نخسر التفاصيل المهمة
  Future<Uint8List> _prepareBytes(File f) async {
    try {
      // نقرأ بايتات الصورة الأصلية
      final bytes = await f.readAsBytes();

      // نحاول نفك ترميز الصورة (decode)
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        // لو ما قدرنا نفك الترميز، نرجع البايتات كما هي
        return Uint8List.fromList(bytes);
      }

      // لو عرض الصورة أكبر من 1280، نصغرها، غير كذا نخليها كما هي
      final resized =
      decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;

      // نضغط الصورة إلى JPG بجودة 85 (توازن بين الجودة والحجم)
      final jpeg = img.encodeJpg(resized, quality: 85);
      return Uint8List.fromList(jpeg);
    } catch (_) {
      // لو صار خطأ في التصغير/الضغط نرجع الصورة الأصلية
      return Uint8List.fromList(await f.readAsBytes());
    }
  }

  /// خط أنابيب الأو سي آر الكامل:
  /// 1) تجهيز الصورة (_prepareBytes)
  /// 2) نحاول أولاً نطلب من Gemini JSON مُهيكل (extractReceipt)
  /// 3) لو فشل يرجع لنص عادي (ocrToText) ثم نحلله بـ ReceiptParser
  /// 4) نبني خريطة prefill ونرسلها لصفحة AddBillPage لتعبئة الحقول مسبقًا
  /// 5) نسجل المدة والطريقة المستخدمة في Metrics.logOcrPipeline
  Future<void> _runOcrAndGo() async {
    if (_image == null) return;

    setState(() {
      _processing = true; // نوقف الأزرار ونشغّل الـ Loader
      _error = null;
    });

    // ساعة توقيت للخط بالكامل
    final totalSw = Stopwatch()..start();

    int prepareMs = 0;        // كم أخذ تجهيز الصورة (تصغير + ضغط)
    bool overallOk = false;   // هل نجح الأو سي آر بالكامل؟
    String methodUsed = 'unknown'; // أي فرع استخدمنا: json أو text+parser
    String? errorMsg;         // رسالة الخطأ لو صار

    try {
      // 1) تحضير الصورة
      final prepSw = Stopwatch()..start();
      final processedBytes = await _prepareBytes(_image!);
      prepSw.stop();
      prepareMs = prepSw.elapsedMilliseconds;

      const mime = 'image/jpeg'; // بعد التحضير نرسلها دائمًا كـ JPEG

      // 2) محاولة الحصول على JSON جاهز من Gemini (أفضل سيناريو)
      final receipt = await GeminiOcrService.I.extractReceipt(
        processedBytes,
        mimeType: mime,
      );

      Map<String, dynamic>? prefill;

      if (receipt != null) {
        // ✅ نجحنا بالحصول على JSON منظّم من Gemini
        methodUsed = 'json';

        // نحول التواريخ إلى ISO string إذا احتجناها كسلسلة
        final purchaseIso = receipt.purchaseDate?.toIso8601String();
        final returnIso = receipt.returnDeadline?.toIso8601String();
        final exchangeIso = receipt.exchangeDeadline?.toIso8601String();

        // نبني خريطة القيم المسبقة (prefill) لصفحة إضافة الفاتورة
        prefill = {
          // العنوان: إذا عندنا title من Gemini نستخدمه، وإلا نركب عنوان من اسم المتجر
          'title': (receipt.title != null && receipt.title!.trim().isNotEmpty)
              ? receipt.title
              : (receipt.shopName == null || receipt.shopName!.trim().isEmpty)
              ? 'Receipt'
              : '${receipt.shopName} Purchase',

          // بيانات المتجر والمبلغ والعملة
          'shop_name': receipt.shopName,
          'store': receipt.shopName,
          'total_amount': receipt.totalAmount,
          'amount': receipt.totalAmount,
          'currency': receipt.currency,

          // التواريخ
          'purchase_date': receipt.purchaseDate,
          'purchaseDate': purchaseIso,
          'return_deadline': receipt.returnDeadline,
          'exchange_deadline': receipt.exchangeDeadline,

          // تواريخ الضمان (هنا نفترض بداية الضمان = تاريخ الشراء)
          'warrantyStart': purchaseIso,
          'warrantyEnd': exchangeIso ?? returnIso,

          // مسار الصورة عشان نخزنها مع الفاتورة
          'image_path': _image!.path,
          'imagePath': _image!.path,

          // ما نحتاج نص خام هنا لأن عندنا JSON منظم
          'rawText': null,
          'raw_source': 'gemini-ocr-json',
        };
      } else {
        // 3) لو JSON فشل: نرجع إلى وضع النص + المفسّر ReceiptParser
        final plain = await GeminiOcrService.I.ocrToText(
          processedBytes,
          mimeType: mime,
        );

        // لو حتى النص فاضي، نطلع برسالة للمستخدم ونوقف
        if (plain == null || plain.trim().isEmpty) {
          errorMsg =
          'لم يتم استخراج بيانات مُهيكلة من الصورة.\n'
              'نصيحة: قرّبي على منطقة اسم المتجر والإجمالي، وإضاءة أعلى، وصورة مستقيمة.';
          setState(() => _error = errorMsg);
          return;
        }

        methodUsed = 'text+parser';

        // نمرر النص الخام لـ ReceiptParser عشان يحاول يستخرج (اسم المتجر، المبلغ، التاريخ، الضمان...)
        final parsed = ReceiptParser.parse(plain);

        // نبني prefill من النتائج اللي طلعنا بها
        prefill = {
          'title':
          (parsed.storeName == null || parsed.storeName!.trim().isEmpty)
              ? 'Receipt'
              : '${parsed.storeName} Purchase',
          'shop_name': parsed.storeName,
          'store': parsed.storeName,
          'total_amount': parsed.totalAmount,
          'amount': parsed.totalAmount,
          'purchase_date': parsed.purchaseDate,
          'purchaseDate': parsed.purchaseDate?.toIso8601String(),
          'warrantyStart': parsed.warrantyStartDate?.toIso8601String(),
          'warrantyEnd': parsed.warrantyExpiryDate?.toIso8601String(),
          'image_path': _image!.path,
          'imagePath': _image!.path,

          // هنا نخزن النص الخام عشان لو حبّينا نراجعه لاحقًا
          'rawText': plain,
          'raw_source': 'gemini-ocr-text+parser',
        };
      }

      // منطق بسيط عشان نقرر هل نقترح إضافة ضمان في صفحة AddBill:
      // إذا عندنا تاريخ نهاية ضمان أو النص فيه كلمة warranty
      final args = {
        'suggestWarranty': (prefill['warrantyEnd'] != null) ||
            ((prefill['rawText'] ?? '')
                .toString()
                .toLowerCase()
                .contains('warranty')),
        'prefill': prefill,
      };

      overallOk = true; // وصلنا للنهاية بدون استثناءات

      if (!mounted) return;

      // نروح لصفحة إضافة الفاتورة مع إرسال القيم المسبقة
      await Navigator.pushNamed(context, AddBillPage.route, arguments: args);
    } catch (e) {
      // لو صار أي استثناء، نخزّن الرسالة ونظهرها للمستخدم
      errorMsg = e.toString();
      setState(() => _error = errorMsg);
    } finally {
      // نوقف ساعة التوقيت ونرسل كل شيء للتليمتري
      totalSw.stop();

      // NEW: تسجيل الأداء/الوقت وطريقة الأو سي آر في Firestore أو أي مكان داخل Metrics
      await Metrics.logOcrPipeline(
        prepareMs: prepareMs,
        totalMs: totalSw.elapsedMilliseconds,
        ok: overallOk,
        path: _image?.path,
        method: methodUsed,
        error: errorMsg,
        extra: {'page': 'scan_receipt'},
      );

      // نرجّع حالة الزرّ العاديّة
      if (mounted) setState(() => _processing = false);
    }
  }

  // ===== دالة مساعدة للشكل الخارجي للكروت في الواجهة =====
  BoxDecoration _cardBox() => BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _cardStroke),
  );

  @override
  Widget build(BuildContext context) {
    // نقدر نشغّل الأو سي آر فقط إذا فيه صورة وما فيه معالجة شغالة الآن
    final canRun = _image != null && !_processing;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon:
            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Quick Add '),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _headerGrad),
          ),
        ),
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // ===== بطاقة معاينة الصورة =====
              Container(
                width: double.infinity,
                decoration: _cardBox(),
                padding: const EdgeInsets.all(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      color: const Color(0xFF202048),
                    ),
                    child: Stack(
                      children: [
                        if (_image == null)
                        // نص إرشادي قبل اختيار الصورة
                          Center(
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Take a photo of the bill or select from gallery',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textDim),
                              ),
                            ),
                          )
                        else
                        // عرض الصورة اللي اختارها المستخدم
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _image!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),

                        // لو الأو سي آر شغّال، نظهر طبقة شفافة مع دائرة تحميل
                        if (_processing)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ===== رسالة الخطأ (لو موجودة) =====
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ],

              const SizedBox(height: 16),

              // ===== أزرار اختيار الصورة: من الاستديو أو من الكاميرا =====
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _accent),
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _processing ? null : () => _pick(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _processing ? null : () => _pick(true),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('From Camera'),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ===== زر تشغيل الأو سي آر والانتقال لصفحة إضافة الفاتورة =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canRun ? _accent : _secondaryBtn,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: canRun ? _runOcrAndGo : null,
                  icon: _processing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                    _processing
                        ? 'Recognizing…'
                        : 'Recognize & Fill Fields',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}