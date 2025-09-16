import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class BillService {
  BillService._();
  static final instance = BillService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  Future<String?> _uploadIfAny({
    required String? receiptImagePath,
    required String billId,
    required String? userId,
  }) async {
    if (receiptImagePath == null) return null;
    final file = File(receiptImagePath);
    if (!await file.exists()) return null;

    final fileName = p.basename(file.path);
    final ref = _storage
        .ref()
        .child('receipts/${userId ?? "anon"}/$billId/$fileName');

    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<String> createBill({
    required String title,
    required String shopName,
    required DateTime purchaseDate,
    required num totalAmount,
    required DateTime returnDeadline,
    required DateTime exchangeDeadline,
    required bool warrantyCoverage,
    DateTime? warrantyEndDate,
    String? userId,               // لتصفية حسب المستخدم
    String? receiptImagePath,     // مسار الصورة من ImagePicker (اختياري)
  }) async {
    final ref = _db.collection('Bills').doc();

    // ارفع الصورة أولاً (لو فيه)
    final receiptUrl = await _uploadIfAny(
      receiptImagePath: receiptImagePath,
      billId: ref.id,
      userId: userId,
    );

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

      // احتفظي بالمصدر + رابط التحميل
      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath,
      if (receiptUrl != null) 'receipt_url': receiptUrl,

      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBills({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Bills');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q.orderBy('created_at', descending: true).snapshots();
  }

  Future<void> updateBill(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Bills').doc(id).update(patch);
  }

  Future<void> deleteBill(String id) async {
    await _db.collection('Bills').doc(id).delete();
  }
}
