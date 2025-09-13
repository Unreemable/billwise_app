import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'ocr_service.dart';
import 'receipt_parser.dart';
import '../bills/ui/add_bill_page.dart';

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
    setState(() { _error = null; });
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    // احفظ نسخة محليًا
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}';
    final saved = await File(x.path).copy(p.join(dir.path, filename));
    setState(() { _image = saved; });
  }

  Future<void> _runOcrAndGo() async {
    if (_image == null) return;
    setState(() { _processing = true; _error = null; });

    try {
      final text = await OcrService.instance.extractText(_image!);
      final parsed = ReceiptParser.parse(text);

      // بناء باراميترات لصفحة AddBill
      final args = {
        'suggestWarranty': parsed.hasWarrantyKeyword,
        'prefill': {
          'store': parsed.storeName,
          'amount': parsed.totalAmount,
          'date': parsed.purchaseDate?.toIso8601String(),
          'warrantyMonths': parsed.warrantyMonths,
          'warrantyStart': parsed.warrantyStartDate?.toIso8601String(),
          'warrantyExpiry': parsed.warrantyExpiryDate?.toIso8601String(),
          'imagePath': _image!.path,
          'rawText': parsed.rawText,
        }
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Quick Add (OCR)')),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: _image == null
                    ? const Text('التقط صورة للفاتورة أو اختر من المعرض')
                    : Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing ? null : () => _pick(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('من المعرض'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _processing ? null : () => _pick(true),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('من الكاميرا'),
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.text_snippet),
                label: const Text('التعرّف وملء الحقول'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
