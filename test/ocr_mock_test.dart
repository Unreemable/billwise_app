import "package:flutter_test/flutter_test.dart";

/// بديل مبسّط لـ Gemini داخل الاختبار فقط.
class FakeOcrClient {
  Future<Map<String, dynamic>> extract(String imagePath) async {
    // ترجيع JSON كما لو جا من Gemini
    return {
      "total": "99,00",        // فاصلة أوروبية
      "date": "2025-10-01",
      "warrantyMonths": "12",
      "raw_text": "Total: 99.00 SAR ...",
    };
  }
}

Map<String, dynamic> mapFromOcr(Map<String, dynamic> ocr) {
  final result = <String, dynamic>{};

  final totalStr = (ocr["total"] ?? "").toString().replaceAll(",", ".");
  final total = double.tryParse(totalStr);
  if (total != null) result["total"] = total;

  try {
    result["date"] = DateTime.parse((ocr["date"] ?? "").toString());
  } catch (_) {}

  final months = int.tryParse((ocr["warrantyMonths"] ?? "").toString());
  if (months != null) result["warrantyMonths"] = months;

  return result;
}

void main() {
  test("maps mocked Gemini OCR JSON to normalized fields", () async {
    final fake = FakeOcrClient();
    final ocrJson = await fake.extract("dummy_path.jpg");

    final mapped = mapFromOcr(ocrJson);

    expect(mapped["total"], 99.00);
    expect((mapped["date"] as DateTime).toIso8601String().startsWith("2025-10-01"), true);
    expect(mapped["warrantyMonths"], 12);
  });
}