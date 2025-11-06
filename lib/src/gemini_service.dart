// lib/src/gemini_service.dart
// REST v1beta + retry + generationConfig + safetySettings + OCR-friendly models (no *-image)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Text-only models
const List<String> _TEXT_MODELS = <String>[
  'gemini-2.5-flash',
  'gemini-pro-latest',
];

/// Vision (multimodal) models — no "-image"
const List<String> _VISION_MODELS = <String>[
  'gemini-2.5-flash',
  'gemini-2.0-flash',
];

/// Generation config
const Map<String, dynamic> _GEN_CFG = <String, dynamic>{
  'maxOutputTokens': 1024,
  'temperature': 0.2,
};

/// Safety settings
const List<Map<String, dynamic>> _SAFETY = <Map<String, dynamic>>[
  {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
  {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
  {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
  {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
];

Uri _endpoint(String model) => Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
);

String _apiKeyOrThrow() {
  final key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  if (key.isEmpty) {
    throw StateError(
      'GEMINI_API_KEY missing. Add it to .env and call dotenv.load() in main() before runApp.',
    );
  }
  return key;
}

bool _isRetriableStatus(int code) =>
    code == 429 || code == 500 || code == 502 || code == 503;

/// POST with retries + Retry-After handling
Future<Map<String, dynamic>> _postJsonWithRetry(
    String model,
    Map<String, dynamic> body, {
      int maxRetries = 3,
      Duration baseDelay = const Duration(milliseconds: 800),
    }) async {
  final key = _apiKeyOrThrow();
  final url = _endpoint(model).replace(queryParameters: {'key': key});

  final mergedBody = <String, dynamic>{
    ...body,
    'generationConfig': _GEN_CFG,
    'safetySettings': _SAFETY,
  };

  Duration delay = baseDelay;
  Object? lastErr;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final resp = await http
          .post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(mergedBody),
      )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      if (_isRetriableStatus(resp.statusCode) && attempt < maxRetries) {
        final ra = resp.headers['retry-after'];
        if (ra != null) {
          final secs = int.tryParse(ra);
          if (secs != null && secs >= 0) {
            if (kDebugMode) {
              debugPrint('$model → ${resp.statusCode} Retry-After: ${secs}s');
            }
            await Future.delayed(Duration(seconds: secs));
            continue;
          }
        }
        if (kDebugMode) {
          debugPrint('$model → ${resp.statusCode} backoff ${delay.inMilliseconds}ms');
        }
        await Future.delayed(delay);
        delay *= 2;
        continue;
      }

      throw StateError('HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      lastErr = e;
      if (attempt == maxRetries) break;
      if (kDebugMode) {
        debugPrint('POST failed (attempt ${attempt + 1}/$maxRetries, model=$model): $e');
      }
      await Future.delayed(delay);
      delay *= 2;
    }
  }
  throw StateError('Failed after multiple attempts: $lastErr');
}

String _extractText(Map<String, dynamic> json) {
  final candidates = json['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final content = candidates.first['content'];
    final parts = content?['parts'];
    if (parts is List && parts.isNotEmpty) {
      final buffer = StringBuffer();
      for (final p in parts) {
        final t = (p['text'] ?? '').toString();
        if (t.isNotEmpty) buffer.writeln(t);
      }
      final out = buffer.toString().trim();
      if (out.isNotEmpty) return out;
    }
  }
  final blockReason = json['promptFeedback']?['blockReason'];
  if (blockReason != null) return 'Blocked: $blockReason';
  return '';
}

Future<String> _callWithModelList({
  required List<String> models,
  required Map<String, dynamic> body,
}) async {
  Object? lastErr;
  for (final m in models) {
    try {
      final json = await _postJsonWithRetry(m, body);
      if (kDebugMode) debugPrint('Gemini model used: $m (v1beta)');
      final text = _extractText(json);
      if (text.isNotEmpty) return text;
      throw StateError('Empty text from $m');
    } catch (e) {
      lastErr = e;
      if (kDebugMode) debugPrint('Model $m failed: $e');
    }
  }
  throw StateError('All models failed. Last error: $lastErr');
}

class GeminiService {
  GeminiService._();
  static final GeminiService i = GeminiService._();

  Future<String> generateText(String prompt) async {
    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    };
    return _callWithModelList(models: _TEXT_MODELS, body: body);
  }

  Future<String> describeImage({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
    };
    return _callWithModelList(models: _VISION_MODELS, body: body);
  }

  Future<ReceiptData?> extractReceipt(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) async {
    const prompt = '''
You are a strict receipt data extractor. Return ONLY a pure JSON object, no markdown or explanations.
Schema:
{
  "title": string|null,
  "shop_name": string|null,
  "purchase_date": string|null,    // ISO YYYY-MM-DD
  "total_amount": number|null,
  "currency": string|null,         // e.g., SAR or USD
  "return_deadline": string|null,  // ISO or null
  "exchange_deadline": string|null,// ISO or null
  "notes": string|null
}
Rules:
- Normalize dates to ISO when possible.
- If only "X days for return/exchange" is found, convert from purchase_date if possible; else leave null and mention in notes.
IMPORTANT: Return ONLY the JSON object.
''';

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
    };

    final raw = (await _callWithModelList(models: _VISION_MODELS, body: body)).trim();
    if (raw.isEmpty) return null;

    final stripped = raw.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();
    String candidate = stripped;
    if (!candidate.trimLeft().startsWith('{')) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(stripped);
      if (m != null) candidate = m.group(0)!;
    }

    Map<String, dynamic>? obj;
    try {
      obj = jsonDecode(candidate) as Map<String, dynamic>?;
    } catch (_) {
      obj = null;
    }
    if (obj == null) return null;
    return ReceiptData.fromJson(obj);
  }

  Future<String?> transcribeImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''
You are an OCR engine. Extract PLAIN TEXT from this receipt image.
- Primary language may be Arabic; preserve Arabic digits if present.
- Keep line breaks and table rows.
- Do NOT add explanations or JSON. TEXT ONLY.
''';

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
    };

    final txt = (await _callWithModelList(models: _VISION_MODELS, body: body)).trim();
    if (txt.isEmpty) return null;
    final plain = txt.replaceAll(RegExp(r'^```(?:\\w+)?|```$', multiLine: true), '').trim();
    return plain.isEmpty ? null : plain;
  }
}

/// Receipt data model
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

  Map<String, dynamic> toPrefill() => <String, dynamic>{
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
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return null;
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.replaceAll(RegExp(r'[^\d\.,\-]'), '').replaceAll(',', '.');
      try {
        return double.parse(t);
      } catch (_) {}
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

/// Simple UI-facing wrapper
class GeminiOcrService {
  GeminiOcrService._();
  static final GeminiOcrService I = GeminiOcrService._();

  Future<ReceiptData?> extractReceipt(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) {
    return GeminiService.i.extractReceipt(imageBytes, mimeType: mimeType);
  }

  Future<String?> ocrToText(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) {
    return GeminiService.i.transcribeImage(imageBytes: imageBytes, mimeType: mimeType);
  }
}
