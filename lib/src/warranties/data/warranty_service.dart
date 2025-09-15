import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final WarrantyService instance = WarrantyService._();

  final _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// Create warranty document in top-level "Warranties".
  /// Fields:
  /// - bill_id (String)
  /// - provider (String)
  /// - start_date (Timestamp)
  /// - end_date (Timestamp)
  /// - status (String) default 'active'
  /// - user_id (String?)   // pass current uid so list can filter
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

  /// Update warranty by id (partial).
  Future<void> updateWarranty(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Warranties').doc(id).update(patch);
  }

  /// Delete warranty by id.
  Future<void> deleteWarranty(String id) async {
    await _db.collection('Warranties').doc(id).delete();
  }

  /// Stream warranties, optionally filtered by userId.
  /// Ordered by end_date ascending (so nearest-expiring first).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamWarranties({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Warranties');
    if (userId != null) {
      q = q.where('user_id', isEqualTo: userId);
    }
    return q.orderBy('end_date').snapshots();
  }
}
