import 'package:cloud_firestore/cloud_firestore.dart';

class BillService {
  BillService._();
  static final instance = BillService._();
  final _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  Future<String> createBill({
    required String title,
    required String shopName,
    required DateTime purchaseDate,
    required num totalAmount,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
    required bool warrantyCoverage,
    DateTime? warrantyEndDate,
    String? userId, // if you use auth-level filtering
    String? receiptImagePath, // <-- new
  }) async {
    final ref = _db.collection('Bills').doc();
    await ref.set({
      'title': title,
      'shop_name': shopName,
      'purchase_date': _ts(purchaseDate),
      'total_amount': totalAmount,
      'return_deadline': _ts(returnDeadline),
      'exchange_deadline': _ts(exchangeDeadline),
      'warranty_coverage': warrantyCoverage,
      if (warrantyEndDate != null) 'warranty_end_date': _ts(warrantyEndDate),
      if (userId != null) 'user_id': userId,
      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath, // <-- saved
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBills({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Bills');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q.orderBy('purchase_date', descending: true).snapshots();
  }

  Future<void> updateBill(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Bills').doc(id).update(patch);
  }

  Future<void> deleteBill(String id) async {
    await _db.collection('Bills').doc(id).delete();
  }
}
