import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final WarrantyService instance = WarrantyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء ضمان في مجموعة Warranties
  Future<String> createWarranty({
    required String billId,
    required DateTime startDate,
    required DateTime endDate,
    String provider = 'Unknown',
    String status = 'active',
    String? userId,
  }) async {
    final ref = _db.collection('Warranties').doc();
    await ref.set({
      'bill_id': billId,
      'provider': provider,
      'start_date': _ts(startDate),
      'end_date': _ts(endDate),
      'status': status,
      if (userId != null) 'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateWarranty(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Warranties').doc(id).update(patch);
  }

  Future<void> deleteWarranty(String id) async {
    await _db.collection('Warranties').doc(id).delete();
  }

  /// عرض الضمانات مرتبة حسب تاريخ الانتهاء (أقرب انتهاء أولاً).
  /// هذا الاستعلام يحتاج الإندكس: user_id ASC + end_date ASC (أو DESC حسب رغبتك).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamWarranties({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Warranties');
    if (userId != null) {
      q = q.where('user_id', isEqualTo: userId);
    }
    return q.orderBy('end_date', descending: true).snapshots();

  }
}
