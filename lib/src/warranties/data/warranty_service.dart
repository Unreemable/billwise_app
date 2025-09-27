import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final WarrantyService instance = WarrantyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء ضمان (ممكن مرتبط بفاتورة، وممكن بدون فاتورة)
  Future<String> createWarranty({
    String? billId,                 // ← صارت اختيارية
    required DateTime startDate,
    required DateTime endDate,
    required String userId,         // لا يزال إلزامي
    String provider = 'Unknown',
    String? status,                 // اختياري
  }) async {
    final ref = _db.collection('Warranties').doc();
    await ref.set({
      if (billId != null) 'bill_id': billId, // يُحفظ فقط إذا كان موجود
      'provider': provider,
      'start_date': _ts(startDate),
      'end_date': _ts(endDate),
      if (status != null) 'status': status,
      'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// تحديث ضمان (Patch)
  Future<void> updateWarranty({
    required String id,
    String? provider,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? billId, // ممكن تغييره (اختياري)
  }) async {
    final patch = <String, dynamic>{
      if (provider != null)  'provider': provider,
      if (status != null)    'status': status,
      if (startDate != null) 'start_date': _ts(startDate),
      if (endDate != null)   'end_date': _ts(endDate),
      if (billId != null)    'bill_id': billId,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (patch.isNotEmpty) {
      await _db.collection('Warranties').doc(id).update(patch);
    }
  }

  /// حذف ضمان
  Future<void> deleteWarranty(String id) async {
    await _db.collection('Warranties').doc(id).delete();
  }

  /// قراءة ضمان واحدة كـ Map (مع id)
  Future<Map<String, dynamic>?> getWarranty(String id) async {
    final snap = await _db.collection('Warranties').doc(id).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  /// قراءة DocumentSnapshot مباشرة
  Future<DocumentSnapshot<Map<String, dynamic>>> getWarrantyDoc(String id) {
    return _db.collection('Warranties').doc(id).get();
  }

  /// ستريم ضمانات المستخدم
  /// where(user_id) + orderBy(end_date) قد يحتاج Composite Index:
  /// user_id ASC + end_date DESC (أو ASC حسب ترتيبك)
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

  /// ستريم كـ List<Map>
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
