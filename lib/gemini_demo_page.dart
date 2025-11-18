import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'src/gemini_service.dart';

/// صفحة تجريبية (Demo) لإظهار طريقة استخدام خدمة Gemini
/// - توليد نص من برومبت
/// - وصف صورة (Image → Text)
class GeminiDemoPage extends StatefulWidget {
  const GeminiDemoPage({super.key});

  @override
  State<GeminiDemoPage> createState() => _GeminiDemoPageState();
}

class _GeminiDemoPageState extends State<GeminiDemoPage> {
  /// كونترولر حقل النص اللي نكتب فيه البرومبت
  final _ctrl = TextEditingController(text: 'Say hello in Arabic.');

  /// النص الناتج من Gemini (يظهر في أسفل الصفحة)
  String _output = '';

  /// فلاق بسيط لمعرفة إذا فيه طلب شغال حاليًا (نص أو صورة)
  bool _busy = false;

  /// استدعاء نموذج Gemini للنص فقط (Text-only)
  Future<void> _runText() async {
    setState(() => _busy = true);
    try {
      // نرسل البرومبت بعد إزالة الفراغات الزائدة
      final text = await GeminiService.i.generateText(_ctrl.text.trim());

      // نحدّث نص المخرجات المعروض للمستخدم
      setState(() => _output = text);
    } finally {
      // نرجّع حالة الفلاق حتى يرجع الزر يشتغل
      setState(() => _busy = false);
    }
  }

  /// استدعاء نموذج Gemini للرؤية (Image + Text)
  Future<void> _runVision() async {
    // نفتح ألبوم الصور باستخدام image_picker
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // تقليل الجودة شوي عشان حجم الصورة ما يكون كبير
    );

    // لو المستخدم رجع بدون اختيار صورة
    if (file == null) return;

    setState(() => _busy = true);
    try {
      // نقرأ الصورة كبايتس
      final bytes = await file.readAsBytes();

      // نحدّد نوع الملف (PNG أو JPEG) من الامتداد
      final mime = file.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // نرسل الصورة + برومبت بسيط لوصف محتوى الصورة
      final text = await GeminiService.i.describeImage(
        prompt: 'Describe the main information in this image.',
        imageBytes: Uint8List.fromList(bytes),
        mimeType: mime,
      );

      // نعرض الوصف النصي اللي رجع من Gemini
      setState(() => _output = text);
    } finally {
      // إلغاء حالة الانشغال
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // شريط علوي بسيط لعنوان الصفحة
      appBar: AppBar(title: const Text('Gemini (Demo)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // حقل البرومبت اللي يكتبه المستخدم
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(labelText: 'Prompt'),
            ),
            const SizedBox(height: 12),

            // الأزرار: واحد للنص وواحد للصورة
            Row(
              children: [
                // زر استدعاء نموذج النص
                ElevatedButton(
                  onPressed: _busy ? null : _runText,
                  child: const Text('Generate Text'),
                ),
                const SizedBox(width: 8),

                // زر استدعاء نموذج الرؤية (صورة → نص)
                OutlinedButton(
                  onPressed: _busy ? null : _runVision,
                  child: const Text('Image → Text'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // لو فيه طلب شغال نعرض شريط تقدّم بسيط
            if (_busy) const LinearProgressIndicator(),

            // منطقة عرض المخرجات النصية من Gemini
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_output),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
