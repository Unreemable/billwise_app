// lib/src/gemini_service.dart
// REST v1beta + retry + generationConfig + safetySettings + OCR-friendly models

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// OPTIONAL (لو تبين تشيلينه عادي)
import 'common/metrics.dart';

/// Text-only models
const List<String> _TEXT_MODELS = <String>[
  'gemini-2.5-flash',
  'gemini-pro-latest',
];

/// Vision models
const List<String> _VISION_MODELS = <String>[
  'gemini-2.5-flash',
  'gemini-2.0-flash',
];

/// Generation config
const Map<String, dynamic> _GEN_CFG = <String, dynamic>{
  'maxOutputTokens': 1200,
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
    throw StateError('Missing GEMINI_API_KEY');
  }
  return key;
}

bool _isRetriableStatus(int code) =>
    code == 429 || code == 500 || code == 502 || code == 503;

Future<Map<String, dynamic>> _postJsonWithRetry(
    String model,
    Map<String, dynamic> body, {
      int maxRetries = 3,
    }) async {
  final key = _apiKeyOrThrow();
  final url = _endpoint(model).replace(queryParameters: {'key': key});

  Duration wait = const Duration(milliseconds: 800);
  Object? lastError;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final resp = await http
          .post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          ...body,
          'generationConfig': _GEN_CFG,
          'safetySettings': _SAFETY,
        }),
      )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }

      if (_isRetriableStatus(resp.statusCode) && attempt < maxRetries) {
        await Future.delayed(wait);
        wait *= 2;
        continue;
      }

      throw StateError('HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      lastError = e;
      if (attempt == maxRetries) break;
      await Future.delayed(wait);
      wait *= 2;
    }
  }

  throw StateError('Retry failed: $lastError');
}

String _extractText(Map<String, dynamic> json) {
  final candidates = json['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final content = candidates.first['content'];
    final parts = content?['parts'];
    if (parts is List && parts.isNotEmpty) {
      final buffer = StringBuffer();
      for (final p in parts) {
        final text = (p['text'] ?? '').toString();
        if (text.isNotEmpty) buffer.writeln(text);
      }
      return buffer.toString().trim();
    }
  }
  return '';
}

Future<String> _callWithModels({
  required List<String> models,
  required Map<String, dynamic> body,
}) async {
  Object? lastErr;
  for (final m in models) {
    try {
      final json = await _postJsonWithRetry(m, body);
      final text = _extractText(json);
      if (text.isNotEmpty) return text;
    } catch (e) {
      lastErr = e;
    }
  }
  throw StateError('All models failed: $lastErr');
}

/// ===============================================================
///                RECEIPT EXTRACTION (WITH ITEMS)
/// ===============================================================
class GeminiService {
  GeminiService._();
  static final GeminiService i = GeminiService._();

  Future<ReceiptData?> extractReceipt(
      Uint8List imageBytes, {
        String mimeType = 'image/jpeg',
      }) async {
    const prompt = '''
You are a structured receipt data extractor.
Return ONLY valid JSON. No explanations.

Schema:
{
  "title": string|null,
  "shop_name": string|null,
  "purchase_date": string|null,
  "total_amount": number|null,
  "currency": string|null,

  "items": [
    {
      "name": string|null,
      "price": number|null
    }
  ] | null,

  "return_deadline": string|null,
  "exchange_deadline": string|null,
  "notes": string|null
}

Rules:
- Extract purchased items when possible.
- If items exist & first item has name → set title = that name.
- Dates must be ISO.
- Return ONLY JSON.
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

    final raw = (await _callWithModels(
      models: _VISION_MODELS,
      body: body,
    ))
        .trim();

    if (raw.isEmpty) return null;

    final stripped = raw.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '');
    String jsonText = stripped.trim();

    if (!jsonText.startsWith('{')) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(stripped);
      if (m != null) jsonText = m.group(0)!;
    }

    Map<String, dynamic>? obj;
    try {
      obj = jsonDecode(jsonText);
    } catch (_) {
      obj = null;
    }

    return obj == null ? null : ReceiptData.fromJson(obj);
  }

  Future<String> generateText(String prompt) async {
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ]
    };
    return _callWithModels(models: _TEXT_MODELS, body: body);
  }

  Future<String?> transcribeImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''
You are an OCR engine.
Extract PLAIN TEXT only.
Keep line breaks.
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

    final txt = await _callWithModels(models: _VISION_MODELS, body: body);
    return txt.trim().isEmpty ? null : txt.trim();
  }
}

/// ===============================================================
///                      MODELS (DATA CLASSES)
/// ===============================================================
class ReceiptData {
  final String? title;
  final String? shopName;
  final DateTime? purchaseDate;
  final double? totalAmount;
  final String? currency;

  final List<ReceiptItem>? items;

  final DateTime? returnDeadline;
  final DateTime? exchangeDeadline;
  final String? notes;

  ReceiptData({
    this.title,
    this.shopName,
    this.purchaseDate,
    this.totalAmount,
    this.currency,
    this.items,
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
    if (items != null) 'items': items!.map((e) => e.toJson()).toList(),
    if (returnDeadline != null) 'return_deadline': returnDeadline,
    if (exchangeDeadline != null) 'exchange_deadline': exchangeDeadline,
    if (notes != null) 'notes': notes,
  };

  static DateTime? _parseDate(dynamic v) {
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return null;
  }

  static double? _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final clean = v.replaceAll(RegExp(r'[^\d\.\-]'), '');
      return double.tryParse(clean);
    }
    return null;
  }

  factory ReceiptData.fromJson(Map<String, dynamic> j) {
    List<ReceiptItem>? itemsList;

    if (j['items'] is List) {
      itemsList = (j['items'] as List)
          .map((e) => ReceiptItem.fromJson(e))
          .toList();
    }

    return ReceiptData(
      title: j['title']?.toString(),
      shopName: j['shop_name']?.toString(),
      purchaseDate: _parseDate(j['purchase_date']),
      totalAmount: _parseDouble(j['total_amount']),
      currency: j['currency']?.toString(),
      items: itemsList,
      returnDeadline: _parseDate(j['return_deadline']),
      exchangeDeadline: _parseDate(j['exchange_deadline']),
      notes: j['notes']?.toString(),
    );
  }
}

class ReceiptItem {
  final String? name;
  final double? price;

  ReceiptItem({this.name, this.price});

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
    name: j['name']?.toString(),
    price: ReceiptData._parseDouble(j['price']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

/// Simple wrapper
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
    return GeminiService.i.transcribeImage(
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
  }
}
