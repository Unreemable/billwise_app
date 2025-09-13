import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _billsCol(String uid) =>
      _db.collection('users').doc(uid).collection('bills');

  CollectionReference<Map<String, dynamic>> _warrantiesCol(String uid) =>
      _db.collection('users').doc(uid).collection('warranties');

  Future<String?> _uploadReceiptImage(String uid, File? image) async {
    if (image == null) return null;
    final ref = _storage
        .ref()
        .child('users/$uid/receipts/${DateTime.now().millisecondsSinceEpoch}${image.path.split('.').last.isNotEmpty ? '.${image.path.split('.').last}' : ''}');
    await ref.putFile(image);
    return ref.getDownloadURL();
  }

  Future<String> createBill({
    required String uid,
    required DateTime purchaseDate,
    required double totalAmount,
    required bool warrantyCoverage,
    File? receiptImage,
  }) async {
    final imageUrl = await _uploadReceiptImage(uid, receiptImage);

    final doc = _billsCol(uid).doc();
    await doc.set({
      'bill_id': doc.id,
      'user_id': uid,
      'purchase_date': Timestamp.fromDate(purchaseDate),
      'total_amount': totalAmount,
      'warranty_coverage': warrantyCoverage,
      'image_url': imageUrl,
      'created_at': Timestamp.now(),
    });
    return doc.id;
  }

  Future<String> createWarrantyForBill({
    required String uid,
    required String billId,
    required DateTime startDate,
    required DateTime endDate,
    int? months,
    String status = 'active',
  }) async {
    final doc = _warrantiesCol(uid).doc();
    await doc.set({
      'warranty_id': doc.id,
      'bill_id': billId,
      'warranty_status': status,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'months': months,
      'created_at': Timestamp.now(),
    });
    return doc.id;
  }

  Future<String> createBillAndMaybeWarrantyFromOCR({
    required String uid,
    required DateTime purchaseDate,
    required double totalAmount,
    required bool hasWarranty,
    File? receiptImage,
    int? warrantyMonths,
    DateTime? warrantyStart,
    DateTime? warrantyEnd,
  }) async {
    final billId = await createBill(
      uid: uid,
      purchaseDate: purchaseDate,
      totalAmount: totalAmount,
      warrantyCoverage: hasWarranty,
      receiptImage: receiptImage,
    );

    if (hasWarranty && warrantyStart != null && warrantyEnd != null) {
      await createWarrantyForBill(
        uid: uid,
        billId: billId,
        startDate: warrantyStart,
        endDate: warrantyEnd,
        months: warrantyMonths,
      );
    }
    return billId;
  }

  Future<Map<String, dynamic>?> getBill(String uid, String billId) async {
    final doc = await _billsCol(uid).doc(billId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getWarrantyByBillId(String uid, String billId) async {
    final snap = await _warrantiesCol(uid)
        .where('bill_id', isEqualTo: billId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }
}
