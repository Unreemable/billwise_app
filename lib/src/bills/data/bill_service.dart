import 'package:cloud_firestore/cloud_firestore.dart';

class BillService {
  BillService._();
  static final instance = BillService._();
  final _db = FirebaseFirestore.instance;

  // ===== Helpers =====
  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  List<Timestamp> _buildReminders(
      DateTime deadline,
      List<int> daysBefore, {
        int hour = 9,
        int minute = 0,
      }) {
    final base = DateTime(deadline.year, deadline.month, deadline.day, hour, minute);
    final out = <Timestamp>{};
    for (final d in daysBefore) {
      final at = base.subtract(Duration(days: d));
      if (at.isAfter(DateTime.now())) out.add(_ts(at));
    }
    out.add(_ts(base)); // يوم الموعد نفسه
    final list = out.toList()..sort((a, b) => a.toDate().compareTo(b.toDate()));
    return list;
  }

  // ===== Create =====
  Future<String> createBill({
    required String title,
    required String shopName,
    required DateTime purchaseDate,
    required num totalAmount,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
    bool warrantyCoverage = false,
    DateTime? warrantyEndDate,
    String? imageUrl,
    String? notes,
    String? userId, // مرّر UID لو فعّلت Firebase Auth
  }) async {
    final ref = _db.collection('Bills').doc();

    final reminders = [
      ..._buildReminders(returnDeadline, [3, 1]),
      ..._buildReminders(exchangeDeadline, [3, 1]),
    ]..sort((a, b) => a.toDate().compareTo(b.toDate()));

    await ref.set({
      'title': title,
      'shop_name': shopName,
      'purchase_date': _ts(purchaseDate),
      'total_amount': totalAmount,
      'return_deadline': _ts(returnDeadline),
      'exchange_deadline': _ts(exchangeDeadline),
      'warranty_coverage': warrantyCoverage,
      if (warrantyEndDate != null) 'warranty_end_date': _ts(warrantyEndDate),
      if (imageUrl != null) 'image_url': imageUrl,
      if (notes != null) 'notes': notes,
      'reminder_dates': reminders, // تذكيرات الإرجاع/الاستبدال
      if (userId != null) 'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // ===== Read =====
  Stream<QuerySnapshot<Map<String, dynamic>>> streamBills({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Bills');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q.orderBy('purchase_date', descending: true).snapshots();
  }

  Future<Map<String, dynamic>?> getBill(String billId) async {
    final doc = await _db.collection('Bills').doc(billId).get();
    return doc.data();
  }

  // ===== Update =====
  Future<void> updateBill(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Bills').doc(id).update(patch);
  }

  // إعادة توليد التذكيرات عند تعديل المواعيد
  Future<void> regenerateReminders({
    required String billId,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
  }) async {
    final reminders = [
      ..._buildReminders(returnDeadline, [3, 1]),
      ..._buildReminders(exchangeDeadline, [3, 1]),
    ]..sort((a, b) => a.toDate().compareTo(b.toDate()));
    await updateBill(billId, {'reminder_dates': reminders});
  }

  // ===== Delete =====
  Future<void> deleteBill(String id) async {
    await _db.collection('Bills').doc(id).delete();
  }

  // ===== Queries مفيدة =====
  Stream<QuerySnapshot<Map<String, dynamic>>> upcomingReturns(int days, {String? userId}) {
    final now = DateTime.now();
    final until = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    Query<Map<String, dynamic>> q = _db.collection('Bills');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q
        .where('return_deadline', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('return_deadline', isLessThanOrEqualTo: Timestamp.fromDate(until))
        .orderBy('return_deadline')
        .snapshots();
  }
}
