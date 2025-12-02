import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// خدمة بسيطة لعمل OCR (استخراج نص) من صورة باستخدام جيميناي
class OcrService {
  // ====== نمط الـ Singleton ======
  OcrService._();                        // كونستركتور خاص (ما نقدر نسوي OcrService() من برّا)
  static final OcrService instance =     // كائن وحيد ثابت نستخدمه في كل مكان
  OcrService._();

  // ====== إعداد المعرّف (TextRecognizer) ======
  ///    للتعرّف على النصوص بالحروف اللاتينية (مثل فواتير مكتوبة إنجليزي)
  final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  /// تستقبل ملف صورة (File) وترجع النص المستخرج منها كسلسلة (String)
  Future<String> extractText(File imageFile) async {
    try {
      // 1) نحول ملف الصورة إلى InputImage عشان تقدر مكتبة ML Kit تقرأه
      final input = InputImage.fromFile(imageFile);

      // 2) نمرر الصورة للمكتبة عشان تعالجها وتتعرف على النص
      final result = await _recognizer.processImage(input);

      // 3) نستخدم StringBuffer عشان نبني نص طويل بدون ما نكرر العمليات على String
      final buffer = StringBuffer();

      // 4) الـ result يكون مقسوم إلى بلوكات (blocks) وكل بلوك داخله أسطر (lines)
      for (final block in result.blocks) {
        for (final line in block.lines) {
          // نضيف كل سطر من النص مع سطر جديد في النهاية
          buffer.writeln(line.text);
        }
      }

      // 5) نرجع النص النهائي بعد ما نشيل المسافات الفاضية في البداية/النهاية
      return buffer.toString().trim();
    } catch (e) {
      // لو صار أي خطأ في الـ OCR نرمي استثناء برسالة واضحة
      throw Exception('OCR failed: $e');
    }
  }

  /// استدعِ هذه الدالة لما تخلص من استخدام الخدمة عشان تقفل الـ recognizer وتحرّر الموارد
  Future<void> dispose() async => _recognizer.close();
}
