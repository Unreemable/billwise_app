// lib/common/metrics.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// مجموعة واحدة نجمع فيها كل قياسات الأداء.
/// تروح على مجموعة Firestore: perf_metrics
class Metrics {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// سجّل زمن نداء Gemini (لكل موديل)
  static Future<void> logOcrLatency({
    required int latencyMs,
    required String model,
    required bool ok,
    String? error,
    Map<String, Object?> extra = const {},
  }) async {
    try {
      await _db.collection('perf_metrics').add({
        'kind': 'ocr_call',
        'model': model,
        'ok': ok,
        'latency_ms': latencyMs,
        if (error != null) 'error': error,
        'at_iso': DateTime.now().toUtc().toIso8601String(),
        ...extra,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('logOcrLatency failed: $e');
      }
    }
  }

  /// سجّل زمن خط الأنابيب الكامل في الشاشة (تجهيز صورة + OCR)
  static Future<void> logOcrPipeline({
    required int prepareMs,
    required int totalMs,
    required bool ok,
    String? path,
    String? method, // 'json' أو 'text+parser'
    String? error,
    Map<String, Object?> extra = const {},
  }) async {
    try {
      await _db.collection('perf_metrics').add({
        'kind': 'ocr_pipeline',
        'ok': ok,
        'prepare_ms': prepareMs,
        'total_ms': totalMs,
        if (path != null) 'image_path_tail': path.length >= 10 ? path.substring(path.length - 10) : path,
        if (method != null) 'method': method,
        if (error != null) 'error': error,
        'at_iso': DateTime.now().toUtc().toIso8601String(),
        ...extra,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('logOcrPipeline failed: $e');
      }
    }
  }
}
