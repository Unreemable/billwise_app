import 'package:cloud_firestore/cloud_firestore.dart';

class BillService {
  BillService._();
  static final instance = BillService._();

  final _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء فاتورة
  Future<String> createBill({
    required String title,
    required String shopName,
    required DateTime purchaseDate,
    required num totalAmount,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
    required bool warrantyCoverage,

    // تمت إضافته:
    DateTime? warrantyStartDate,

    // كان موجود مسبقًا:
    DateTime? warrantyEndDate,

    String? userId,
    String? receiptImagePath,
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

      // الجديد:
      if (warrantyStartDate != null)
        'warranty_start_date': _ts(warrantyStartDate),

      // القديم:
      if (warrantyEndDate != null) 'warranty_end_date': _ts(warrantyEndDate),

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

    // تمت إضافته:
    DateTime? warrantyStartDate,

    // كان موجود مسبقًا:
    DateTime? warrantyEndDate,

    String? receiptImagePath,
  }) async {
    final ref = _db.collection('Bills').doc(billId);

    final data = <String, dynamic>{
      if (title != null) 'title': title,
      if (shopName != null) 'shop_name': shopName,
      if (purchaseDate != null) 'purchase_date': _ts(purchaseDate),
      if (totalAmount != null) 'total_amount': totalAmount,
      if (returnDeadline != null) 'return_deadline': _ts(returnDeadline),
      if (exchangeDeadline != null) 'exchange_deadline': _ts(exchangeDeadline),
      if (warrantyCoverage != null) 'warranty_coverage': warrantyCoverage,

      // الجديد:
      if (warrantyStartDate != null)
        'warranty_start_date': _ts(warrantyStartDate),

      // القديم:
      if (warrantyEndDate != null) 'warranty_end_date': _ts(warrantyEndDate),

      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (data.isNotEmpty) {
      await ref.update(data);
    }
  }

  /// بثّ الفواتير لحظيًا كـ QuerySnapshot (مناسب لـ StreamBuilder<QuerySnapshot<...>>)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamBillsSnapshot({
    String? userId,
    String orderBy = 'created_at',
    bool descending = true,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('Bills');
    if (userId != null) {
      q = q.where('user_id', isEqualTo: userId);
    }
    q = q.orderBy(orderBy, descending: descending);
    return q.snapshots();
  }

  /// بثّ الفواتير كقائمة Maps جاهزة (مناسب لـ StreamBuilder<List<Map>>)
  Stream<List<Map<String, dynamic>>> streamBills({
    String? userId,
    String orderBy = 'created_at',
    bool descending = true,
  }) {
    return streamBillsSnapshot(
      userId: userId,
      orderBy: orderBy,
      descending: descending,
    ).map((snap) =>
        snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
