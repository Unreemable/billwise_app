import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final instance = WarrantyService._();
  final _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  List<Timestamp> _remindersForWarranty(DateTime endDate) {
    DateTime at(int daysBefore) =>
        DateTime(endDate.year, endDate.month, endDate.day, 9).subtract(Duration(days: daysBefore));
    final items = <DateTime>{
      at(30), at(7), at(1),
      DateTime(endDate.year, endDate.month, endDate.day, 9),
    }.where((d) => d.isAfter(DateTime.now())).toList()
      ..sort();
    return items.map(_ts).toList();
  }

  // ===== Create =====
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
      'reminder_dates': _remindersForWarranty(endDate), // تذكيرات الضمان
      if (userId != null) 'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ===== Read =====
  Stream<QuerySnapshot<Map<String, dynamic>>> streamWarranties({String? userId}) {
    Query<Map<String, dynamic>> q = _db.collection('Warranties');
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    return q.orderBy('end_date').snapshots();
  }

  // ===== Update =====
  Future<void> updateWarranty(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('Warranties').doc(id).update(patch);
  }

  Future<void> regenerateReminders(String id, DateTime endDate) async {
    await updateWarranty(id, {
      'reminder_dates': _remindersForWarranty(endDate),
    });
  }

  // ===== Delete =====
  Future<void> deleteWarranty(String id) async {
    await _db.collection('Warranties').doc(id).delete();
  }
}
