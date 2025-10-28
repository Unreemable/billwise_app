import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../gemini_service.dart';           // Gemini OCR (لا تغييرات)
import '../bills/ui/add_bill_page.dart';
import 'receipt_parser.dart';              // Fallback parser

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});
  static const route = '/scan-receipt';

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  // ===== ألوان وتصميم فقط =====
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

  /// يصغّر الصورة لعرض 1280px ويضغطها JPG 85 لتقليل الضجيج والتوكنات
  Future<Uint8List> _prepareBytes(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return Uint8List.fromList(bytes);
      final resized =
      decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
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

    try {
      // 1) تحضير الصورة
      final processedBytes = await _prepareBytes(_image!);
      const mime = 'image/jpeg'; // بعد الضغط نرسل دائمًا jpeg

      // 2) محاولة JSON منظّم من Gemini
      final receipt = await GeminiOcrService.I.extractReceipt(
        processedBytes,
        mimeType: mime,
      );

      Map<String, dynamic>? prefill;

      if (receipt != null) {
        final purchaseIso = receipt.purchaseDate?.toIso8601String();
        final returnIso   = receipt.returnDeadline?.toIso8601String();
        final exchangeIso = receipt.exchangeDeadline?.toIso8601String();

        prefill = {
          'title': (receipt.title != null && receipt.title!.trim().isNotEmpty)
              ? receipt.title
              : (receipt.shopName == null || receipt.shopName!.trim().isEmpty)
              ? 'Receipt'
              : '${receipt.shopName} Purchase',
          'shop_name': receipt.shopName,
          'store':     receipt.shopName,
          'total_amount': receipt.totalAmount,
          'amount':       receipt.totalAmount,
          'currency':     receipt.currency,
          'purchase_date': receipt.purchaseDate,
          'purchaseDate':  purchaseIso,
          'return_deadline':   receipt.returnDeadline,
          'exchange_deadline': receipt.exchangeDeadline,
          'warrantyStart': purchaseIso,
          'warrantyEnd':   exchangeIso ?? returnIso,
          'image_path': _image!.path,
          'imagePath':  _image!.path,
          'rawText':    null,
          'raw_source': 'gemini-ocr-json',
        };
      } else {
        // 3) OCR نصّي + ReceiptParser
        final plain = await GeminiOcrService.I.ocrToText(
          processedBytes,
          mimeType: mime,
        );

        if (plain == null || plain.trim().isEmpty) {
          setState(() => _error =
          'لم يتم استخراج بيانات مُهيكلة من الصورة.\nنصيحة: قرّبي على منطقة اسم المتجر والإجمالي، وإضاءة أعلى، وصورة مستقيمة.');
          return;
        }

        final parsed = ReceiptParser.parse(plain);

        prefill = {
          'title': (parsed.storeName == null || parsed.storeName!.trim().isEmpty)
              ? 'Receipt'
              : '${parsed.storeName} Purchase',
          'shop_name': parsed.storeName,
          'store':     parsed.storeName,
          'total_amount': parsed.totalAmount,
          'amount':       parsed.totalAmount,
          'purchase_date': parsed.purchaseDate,
          'purchaseDate':  parsed.purchaseDate?.toIso8601String(),
          'warrantyStart': parsed.warrantyStartDate?.toIso8601String(),
          'warrantyEnd':   parsed.warrantyExpiryDate?.toIso8601String(),
          'image_path': _image!.path,
          'imagePath':  _image!.path,
          'rawText':    plain,
          'raw_source': 'gemini-ocr-text+parser',
        };
      }

      final args = {
        'suggestWarranty': (prefill['warrantyEnd'] != null) ||
            ((prefill['rawText'] ?? '').toString().toLowerCase().contains('warranty')),
        'prefill': prefill,
      };

      if (!mounted) return;
      await Navigator.pushNamed(context, AddBillPage.route, arguments: args);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ===== التصميم فقط في build =====
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Quick Add (Gemini OCR)'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _headerGrad),
          ),
        ),
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // بطاقة المعاينة
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
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Take a photo of the receipt or select from gallery',
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
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ],

              const SizedBox(height: 16),

              // أزرار الالتقاط
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

              // زر التعرف
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_processing ? 'Recognizing…' : 'Recognize & Fill Fields'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
