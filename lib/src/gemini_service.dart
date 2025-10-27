// lib/src/gemini_service.dart
// REST v1beta + retry + generationConfig + safetySettings + OCR text fallback
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// موديلات متوافقة مع مفتاحك (v1beta)
const List<String> _TEXT_MODELS = [
  'gemini-2.5-flash',
  'gemini-pro-latest',
];

const List<String> _VISION_MODELS = [
  'gemini-2.5-flash-image', // رؤية
  'gemini-2.5-flash',       // متعدد الوسائط (fallback)
];

/// إعدادات توليد (رفّعنا المخرجات لأن الفواتير طويلة)
const Map<String, dynamic> _GEN_CFG = {
  'maxOutputTokens': 1024,
  'temperature': 0.2,
};

/// إعدادات السلامة (أكثر تساهلاً لتقليل "Blocked")
const List<Map<String, dynamic>> _SAFETY = [
  {"category": "HARM_CATEGORY_HARASSMENT",        "threshold": "BLOCK_NONE"},
  {"category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_NONE"},
  {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
  {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
];

Uri _endpoint(String model) => Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
);

String _apiKeyOrThrow() {
  final key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  if (key.isEmpty) {
    throw StateError('GEMINI_API_KEY مفقود. أضيفيه في .env وحمّليه في main.dart قبل runApp.');
  }
  return key;
}

/// POST مع إعادة محاولات عند 429 (Rate limit) + احترام Retry-After
Future<Map<String, dynamic>> _postJsonWithRetry(
    String model,
    Map<String, dynamic> body, {
      int maxRetries = 3,
    }) async {
  final key = _apiKeyOrThrow();
  final url = _endpoint(model).replace(queryParameters: {'key': key});

  // دمج generationConfig + safetySettings
  final mergedBody = {
    ...body,
    'generationConfig': _GEN_CFG,
    'safetySettings': _SAFETY,
  };

  Duration delay = const Duration(milliseconds: 800);
  Object? lastErr;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mergedBody),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      // 429: احترم Retry-After أو اعمل backoff
      if (resp.statusCode == 429) {
        final ra = resp.headers['retry-after'];
        if (ra != null) {
          final secs = int.tryParse(ra);
          if (secs != null && secs >= 0) {
            if (kDebugMode) debugPrint('429 Retry-After: ${secs}s ($model)');
            await Future.delayed(Duration(seconds: secs));
            continue;
          }
        }
        if (kDebugMode) debugPrint('429 backoff ${delay.inMilliseconds}ms ($model)');
        await Future.delayed(delay);
        delay *= 2;
        continue;
      }

      // أخطاء أخرى
      throw StateError('HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      lastErr = e;
      if (attempt == maxRetries) break;
      if (kDebugMode) debugPrint('POST failed (attempt ${attempt + 1}/$maxRetries): $e');
      await Future.delayed(delay);
      delay *= 2;
    }
  }
  throw StateError('فشل بعد محاولات متعددة: $lastErr');
}

String _extractText(Map<String, dynamic> json) {
  final candidates = json['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final content = candidates.first['content'];
    final parts = content?['parts'];
    if (parts is List) {
      final sb = StringBuffer();
      for (final p in parts) {
        final t = (p['text'] ?? '').toString();
        if (t.isNotEmpty) sb.writeln(t);
      }
      return sb.toString().trim();
    }
  }
  if (json['promptFeedback']?['blockReason'] != null) {
    return 'Blocked: ${json['promptFeedback']['blockReason']}';
  }
  return '';
}

/// يستدعي قائمة موديلات بالترتيب إلى أن ينجح
Future<String> _callWithModelList({
  required List<String> models,
  required Map<String, dynamic> body,
}) async {
  Object? lastErr;
  for (final m in models) {
    try {
      final json = await _postJsonWithRetry(m, body);
      if (kDebugMode) debugPrint('Gemini model used: $m (v1beta)');
      return _extractText(json);
    } catch (e) {
      lastErr = e;
      if (kDebugMode) debugPrint('Model $m failed: $e');
      // جرّب التالي
    }
  }
  throw StateError('فشلت جميع الموديلات. آخر خطأ: $lastErr');
}

class GeminiService {
  GeminiService._();
  static final GeminiService i = GeminiService._();

  /// نص → نص
  Future<String> generateText(String prompt) async {
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    };
    return _callWithModelList(models: _TEXT_MODELS, body: body);
  }

  /// صورة(+نص) → نص
  Future<String> describeImage({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              }
            }
          ]
        }
      ]
    };
    return _callWithModelList(models: _VISION_MODELS, body: body);
  }

  /// OCR منظَّم: صورة → JSON (ReceiptData)
  Future<ReceiptData?> extractReceipt(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) async {
    const prompt = '''
أنت مستخرج بيانات فواتير صارم. أعد فقط JSON خالص بدون أي نص آخر أو Markdown.
المخرجات (JSON فقط):
{
  "title": string|null,
  "shop_name": string|null,
  "purchase_date": string|null,   // ISO YYYY-MM-DD
  "total_amount": number|null,    // الإجمالي النهائي شامل الضرائب
  "currency": string|null,        // مثل SAR أو USD
  "return_deadline": string|null, // ISO أو null
  "exchange_deadline": string|null, // ISO أو null
  "notes": string|null
}
قواعد:
- طبّع التواريخ إلى ISO إن أمكن.
- إذا ذُكر "X أيام للإرجاع/الاستبدال" حوّله إلى تاريخ مطلق انطلاقًا من purchase_date إن أمكن، وإلا اترك null واذكر ذلك في notes.
IMPORTANT: Return ONLY the JSON object, nothing else.
''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              }
            }
          ]
        }
      ]
    };

    final txt = (await _callWithModelList(models: _VISION_MODELS, body: body)).trim();
    if (txt.isEmpty) return null;

    // إزالة ```json ... ``` لو وُجدت + التقاط أول {...} إذا عاد نص إضافي
    final stripped = txt.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();
    String candidate = stripped;
    if (!candidate.trimLeft().startsWith('{')) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(stripped);
      if (m != null) candidate = m.group(0)!;
    }

    Map<String, dynamic>? obj;
    try {
      obj = jsonDecode(candidate);
    } catch (_) {
      obj = null;
    }
    if (obj == null) return null;
    return ReceiptData.fromJson(obj);
  }

  /// صورة → نص خام (OCR fallback)
  Future<String?> transcribeImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''
You are an OCR engine. Extract PLAIN TEXT from this receipt image.
- Language is primarily Arabic; keep Arabic digits if present.
- Keep line breaks and table rows as you see them.
- Do NOT add explanations or JSON. TEXT ONLY.
''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              }
            }
          ]
        }
      ]
    };

    final txt = (await _callWithModelList(models: _VISION_MODELS, body: body)).trim();
    if (txt.isEmpty) return null;

    final plain = txt.replaceAll(RegExp(r'^```(?:\\w+)?|```$', multiLine: true), '').trim();
    return plain.isEmpty ? null : plain;
  }
}

/// نموذج بيانات الفاتورة
class ReceiptData {
  final String? title;
  final String? shopName;
  final DateTime? purchaseDate;
  final double? totalAmount;
  final String? currency;
  final DateTime? returnDeadline;
  final DateTime? exchangeDeadline;
  final String? notes;

  ReceiptData({
    this.title,
    this.shopName,
    this.purchaseDate,
    this.totalAmount,
    this.currency,
    this.returnDeadline,
    this.exchangeDeadline,
    this.notes,
  });

  Map<String, dynamic> toPrefill() => {
    if (title != null) 'title': title,
    if (shopName != null) 'shop_name': shopName,
    if (purchaseDate != null) 'purchase_date': purchaseDate,
    if (totalAmount != null) 'total_amount': totalAmount,
    if (currency != null) 'currency': currency,
    if (returnDeadline != null) 'return_deadline': returnDeadline,
    if (exchangeDeadline != null) 'exchange_deadline': exchangeDeadline,
    if (notes != null) 'notes': notes,
  };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) {
      try { return DateTime.fromMillisecondsSinceEpoch(v); } catch (_) {}
    }
    if (v is String) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.replaceAll(RegExp(r'[^\d\.,\-]'), '').replaceAll(',', '.');
      try { return double.parse(t); } catch (_) {}
    }
    return null;
  }

  factory ReceiptData.fromJson(Map<String, dynamic> j) => ReceiptData(
    title: j['title']?.toString(),
    shopName: j['shop_name']?.toString() ?? j['store_name']?.toString(),
    purchaseDate: _parseDate(j['purchase_date']),
    totalAmount: _parseDouble(j['total_amount']),
    currency: j['currency']?.toString(),
    returnDeadline: _parseDate(j['return_deadline']),
    exchangeDeadline: _parseDate(j['exchange_deadline']),
    notes: j['notes']?.toString(),
  );
}

/// واجهة بسيطة للاستخدام من الـ UI
class GeminiOcrService {
  GeminiOcrService._();
  static final GeminiOcrService I = GeminiOcrService._();

  Future<ReceiptData?> extractReceipt(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) {
    return GeminiService.i.extractReceipt(imageBytes, mimeType: mimeType);
  }

  /// واجهة OCR نص خام (Fallback) — مطلوبة لو حبيتي تمرري النص لـ ReceiptParser
  Future<String?> ocrToText(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) {
    return GeminiService.i.transcribeImage(imageBytes: imageBytes, mimeType: mimeType);
  }
}

