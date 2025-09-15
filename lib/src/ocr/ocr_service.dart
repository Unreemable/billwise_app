import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(File imageFile) async {
    try {
      final input = InputImage.fromFile(imageFile);
      final result = await _recognizer.processImage(input);
      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      throw Exception('OCR failed: $e');
    }
  }

  Future<void> dispose() async => _recognizer.close();
}
