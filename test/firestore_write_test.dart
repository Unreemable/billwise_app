import "package:flutter_test/flutter_test.dart";
import "package:fake_cloud_firestore/fake_cloud_firestore.dart";

void main() {
  test("writes and reads a bill document (FakeFirestore)", () async {
    final db = FakeFirebaseFirestore();

    // هنا نمثل نتيجة OCR/Gemini بشكل مبسط بدون Parser
    final ocrJson = {
      "total": "123.45",
      "date": "2025-10-01",
      "warrantyMonths": 24,
      "title": "Grocery Store"
    };

    // تحويل بسيط داخل الاختبار نفسه (بدون أي ملف في lib/)
    double? total = double.tryParse((ocrJson["total"] ?? "").toString());
    DateTime? date;
    try { date = DateTime.parse((ocrJson["date"] ?? "").toString()); } catch (_) {}
    final months = int.tryParse((ocrJson["warrantyMonths"] ?? "").toString());

    await db.collection("Bills").add({
      "title": ocrJson["title"] ?? "Untitled",
      if (total != null) "total": total,
      if (date != null) "purchase_date": date.toIso8601String(),
      if (months != null) "warranty_months": months,
      "user_id": "test-uid",
    });

    final snap = await db.collection("Bills").get();
    expect(snap.docs.length, 1);
    expect(snap.docs.first.data()["title"], "Grocery Store");
    expect(snap.docs.first.data()["user_id"], "test-uid");
  });
}