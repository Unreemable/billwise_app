// lib/src/ocr/scan_receipt_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../gemini_service.dart';
import '../bills/ui/add_bill_page.dart';
import 'receipt_parser.dart';
import '../common/metrics.dart';

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});
  static const route = '/scan-receipt';

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  static const _bg = Color(0xFF0B0B2E);
  static const _card = Color(0xFF171636);
  static const _cardStroke = Color(0x1FFFFFFF);
  static const _textDim = Color(0xFFBFC3D9);
  static const _accent = Color(0xFF9B5CFF);
  static const _secondaryBtn = Color(0xFF2C2B52);
  static const _headerGrad = LinearGradient(
    colors: [Color(0xFF0B0B2E), Color(0xFF21124C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  File? _image;
  bool _processing = false;
  String? _error;

  Future<void> _pick(bool camera) async {
    setState(() => _error = null);

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 92,
    );
    if (x == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}';
    final saved = await File(x.path).copy(p.join(dir.path, filename));

    setState(() => _image = saved);
  }

  Future<Uint8List> _prepareBytes(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) return Uint8List.fromList(bytes);

      final resized = decoded.width > 1280
          ? img.copyResize(decoded, width: 1280)
          : decoded;

      final jpeg = img.encodeJpg(resized, quality: 85);
      return Uint8List.fromList(jpeg);
    } catch (_) {
      return Uint8List.fromList(await f.readAsBytes());
    }
  }

  Future<void> _runOcrAndGo() async {
    if (_image == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    final totalSw = Stopwatch()..start();
    int prepareMs = 0;
    bool overallOk = false;
    String methodUsed = 'unknown';
    String? errorMsg;

    try {
      final prepSw = Stopwatch()..start();
      final processedBytes = await _prepareBytes(_image!);
      prepSw.stop();
      prepareMs = prepSw.elapsedMilliseconds;

      const mime = 'image/jpeg';
      final receipt = await GeminiOcrService.I.extractReceipt(
        processedBytes,
        mimeType: mime,
      );

      Map<String, dynamic>? prefill;

      // ===============================
      //      JSON SUCCESS BRANCH
      // ===============================
      if (receipt != null) {
        methodUsed = 'json';

        prefill = {
          'title': (receipt.title != null && receipt.title!.trim().isNotEmpty)
              ? receipt.title
              : (receipt.shopName == null ||
              receipt.shopName!.trim().isEmpty)
              ? 'Receipt'
              : '${receipt.shopName} Purchase',

          'shop_name': receipt.shopName,
          'store': receipt.shopName,
          'total_amount': receipt.totalAmount,
          'amount': receipt.totalAmount,
          'currency': receipt.currency,

          'purchase_date': receipt.purchaseDate?.toIso8601String(),
          'return_deadline': receipt.returnDeadline?.toIso8601String(),
          'exchange_deadline': receipt.exchangeDeadline?.toIso8601String(),

          // warranty
          'warrantyStart': receipt.purchaseDate?.toIso8601String(),
          'warrantyEnd': receipt.exchangeDeadline?.toIso8601String() ??
              receipt.returnDeadline?.toIso8601String(),

          // 🟣 مسار الصورة عشان يروح مع الفاتورة والضمان
          'receiptPath': _image!.path,

          'rawText': null,
          'raw_source': 'gemini-ocr-json',
        };
      }

      // ===============================
      //      TEXT FALLBACK BRANCH
      // ===============================
      else {
        final plain = await GeminiOcrService.I.ocrToText(
          processedBytes,
          mimeType: mime,
        );

        if (plain == null || plain.trim().isEmpty) {
          errorMsg =
          'لم يتم استخراج نص يمكن تحليله.\nجربي الإضاءة أو الاقتراب من الفاتورة.';
          setState(() => _error = errorMsg);
          return;
        }

        methodUsed = 'text+parser';
        final parsed = ReceiptParser.parse(plain);

        prefill = {
          'title': (parsed.storeName == null ||
              parsed.storeName!.trim().isEmpty)
              ? 'Receipt'
              : '${parsed.storeName} Purchase',

          'shop_name': parsed.storeName,
          'store': parsed.storeName,
          'total_amount': parsed.totalAmount,
          'amount': parsed.totalAmount,

          'purchase_date': parsed.purchaseDate?.toIso8601String(),
          'warrantyStart': parsed.warrantyStartDate?.toIso8601String(),
          'warrantyEnd': parsed.warrantyExpiryDate?.toIso8601String(),

          'receiptPath': _image!.path,

          'rawText': plain,
          'raw_source': 'gemini-ocr-text+parser',
        };
      }

      // ===============================
      //   ✅ التحقق إنها فعلاً فاتورة
      // ===============================
      bool isProbablyBill = false;
      if (prefill != null) {
        final shop = (prefill['shop_name'] ?? prefill['store'] ?? '')
            .toString()
            .trim();
        final amount = prefill['total_amount'] ?? prefill['amount'];
        final purchaseDate = prefill['purchase_date'];

        if (shop.isNotEmpty || amount != null || purchaseDate != null) {
          isProbablyBill = true;
        }
      }

      if (!isProbablyBill) {
        // 🔴 مو فاتورة → لا تروحين لصفحة AddBill وخلي المستخدم يعيد التصوير
        errorMsg =
        'This image does not look like a bill.\nPlease capture a real bill .';
        setState(() => _error = errorMsg);
        return;
      }

      final args = {
        'suggestWarranty': prefill?['warrantyEnd'] != null,
        'prefill': prefill,
        'receiptPath': _image!.path,
      };

      overallOk = true;

      if (!mounted) return;

      await Navigator.pushNamed(context, AddBillPage.route, arguments: args);
    } catch (e) {
      errorMsg = e.toString();
      setState(() => _error = errorMsg);
    } finally {
      totalSw.stop();

      await Metrics.logOcrPipeline(
        prepareMs: prepareMs,
        totalMs: totalSw.elapsedMilliseconds,
        ok: overallOk,
        path: _image?.path,
        method: methodUsed,
        error: errorMsg,
        extra: {'page': 'scan_receipt'},
      );

      if (mounted) setState(() => _processing = false);
    }
  }

  BoxDecoration _cardBox() => BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _cardStroke),
  );

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Quick Add'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _headerGrad),
          ),
        ),
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: _cardBox(),
                padding: const EdgeInsets.all(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.12)),
                      color: const Color(0xFF202048),
                    ),
                    child: Stack(
                      children: [
                        if (_image == null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Text(
                                'Take a photo of the bill or select from gallery',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textDim),
                              ),
                            ),
                          )
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _image!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
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

              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _accent),
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
