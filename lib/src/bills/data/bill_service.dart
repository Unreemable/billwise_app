import 'package:cloud_firestore/cloud_firestore.dart';

class BillService {
  BillService._();
  static final instance = BillService._();

  final _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء فاتورة جديدة
  Future<String> createBill({
    required String title,
    required String shopName,
    required DateTime purchaseDate,
    required num totalAmount,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
    required bool warrantyCoverage,
    DateTime? warrantyStartDate,          // اختياري
    DateTime? warrantyEndDate,            // اختياري
    required String userId,               // اجباري
    String? receiptImagePath,             // اختياري
  }) async {
    final ref = _db.collection('Bills').doc();

    final data = <String, dynamic>{
      'title': title,
      'shop_name': shopName,
      'purchase_date': _ts(purchaseDate),
      'total_amount': totalAmount,
      'return_deadline': _ts(returnDeadline),
      'exchange_deadline': _ts(exchangeDeadline),
      'warranty_coverage': warrantyCoverage,
      if (warrantyStartDate != null) 'warranty_start_date': _ts(warrantyStartDate),
      if (warrantyEndDate != null)   'warranty_end_date': _ts(warrantyEndDate),
      'receipt_image_path': receiptImagePath,
      'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await ref.set(data);
    return ref.id;
  }

  /// تحديث فاتورة
  Future<void> updateBill({
    required String billId,
    String? title,
    String? shopName,
    DateTime? purchaseDate,
    num? totalAmount,
    DateTime? returnDeadline,
    DateTime? exchangeDeadline,
    bool? warrantyCoverage,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    String? receiptImagePath,
  }) async {
    final ref = _db.collection('Bills').doc(billId);

    final patch = <String, dynamic>{
      if (title != null)            'title': title,
      if (shopName != null)         'shop_name': shopName,
      if (purchaseDate != null)     'purchase_date': _ts(purchaseDate),
      if (totalAmount != null)      'total_amount': totalAmount,
      if (returnDeadline != null)   'return_deadline': _ts(returnDeadline),
      if (exchangeDeadline != null) 'exchange_deadline': _ts(exchangeDeadline),
      if (warrantyCoverage != null) 'warranty_coverage': warrantyCoverage,
      if (warrantyStartDate != null) 'warranty_start_date': _ts(warrantyStartDate),
      if (warrantyEndDate != null)   'warranty_end_date': _ts(warrantyEndDate),
      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (patch.isNotEmpty) {
      await ref.update(patch);
    }
  }

  /// حذف فاتورة
  Future<void> deleteBill(String billId) async {
    await _db.collection('Bills').doc(billId).delete();
  }

  /// قراءة فاتورة واحدة
  Future<Map<String, dynamic>?> getBill(String billId) async {
    final snap = await _db.collection('Bills').doc(billId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  /// ستريم QuerySnapshot (مناسب لـ StreamBuilder<QuerySnapshot<...>>)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamBillsSnapshot({
    required String userId,
    String orderBy = 'created_at',
    bool descending = true,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('Bills')
        .where('user_id', isEqualTo: userId)
        .orderBy(orderBy, descending: descending);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  /// ستريم كقائمة Maps جاهزة (مناسب لـ StreamBuilder<List<Map>>)
  Stream<List<Map<String, dynamic>>> streamBills({
    required String userId,
    String orderBy = 'created_at',
    bool descending = true,
    int? limit,
  }) {
    return streamBillsSnapshot(
      userId: userId,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    ).map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }




}
