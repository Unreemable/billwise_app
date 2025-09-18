import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final WarrantyService instance = WarrantyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء ضمان (مرتبط بفاتورة)
  Future<String> createWarranty({
    required String billId,
    required DateTime startDate,
    required DateTime endDate,
    required String userId,            // اجباري
    String provider = 'Unknown',
    String status = 'active',
  }) async {
    final ref = _db.collection('Warranties').doc();
    await ref.set({
      'bill_id': billId,
      'provider': provider,
      'start_date': _ts(startDate),
      'end_date': _ts(endDate),
      'status': status,
      'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateWarranty({
    required String id,
    String? provider,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final patch = <String, dynamic>{
      if (provider != null) 'provider': provider,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': _ts(startDate),
      if (endDate != null)   'end_date': _ts(endDate),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (patch.isNotEmpty) {
      await _db.collection('Warranties').doc(id).update(patch);
    }
  }

  Future<void> deleteWarranty(String id) async {
    await _db.collection('Warranties').doc(id).delete();
  }

  /// ستريم ضمانات المستخدم الحالي مرتّبة حسب تاريخ الانتهاء (الأحدث/الأقرب أولاً)
  /// ملاحظة: where(user_id) + orderBy(end_date) يحتاج Composite Index:
  /// Warranties: user_id ASC + end_date DESC (أو ASC حسب ترتيبك)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamWarrantiesSnapshot({
    required String userId,
    bool descending = true,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('Warranties')
        .where('user_id', isEqualTo: userId)
        .orderBy('end_date', descending: descending);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  Stream<List<Map<String, dynamic>>> streamWarranties({
    required String userId,
    bool descending = true,
    int? limit,
  }) {
    return streamWarrantiesSnapshot(
      userId: userId,
      descending: descending,
      limit: limit,
    ).map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
