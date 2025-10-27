import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../gemini_service.dart';           // Gemini OCR
import '../bills/ui/add_bill_page.dart';
import 'receipt_parser.dart';              // Fallback parser

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});
  static const route = '/scan-receipt';

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
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
        // نجح JSON
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
        // 3) فشل JSON → OCR نصّي + ReceiptParser (حسب الحقول المتوفرة في ParsedReceipt)
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
          // مافيه currency/returnDeadline/exchangeDeadline في ParsedReceipt الافتراضي
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

      // 4) الذهاب لصفحة الإضافة
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Add (Gemini OCR)')),
      body: Column( // ✅ كان child: — عدّلناها إلى body:
        children: [
          Expanded(
            child: Center(
              child: _image == null
                  ? const Text('Take a photo of the receipt or select from gallery')
                  : Image.file(_image!, fit: BoxFit.contain),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : () => _pick(false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing ? null : () => _pick(true),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('From Camera'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: FilledButton.icon(
              onPressed: (_image == null || _processing) ? null : _runOcrAndGo,
              icon: _processing
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.text_snippet),
              label: const Text('Recognize & Fill Fields'),
            ),
          ),
        ],
      ),
    );
  }
}
