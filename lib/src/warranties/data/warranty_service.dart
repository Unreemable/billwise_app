import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyService {
  WarrantyService._();
  static final WarrantyService instance = WarrantyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  /// إنشاء ضمان (يرتبط بفاتورة إن توفّر billId)
  Future<String> createWarranty({
    String? billId,                 // اختياري
    required DateTime startDate,
    required DateTime endDate,
    required String userId,         // إلزامي
    String provider = 'Unknown',
    String? status,                 // اختياري
    String? serialNumber,           // NEW
    String? attachmentLocalPath,    // NEW (محلي فقط)
    String? attachmentName,         // NEW (اسم للعرض)
  }) async {
    final ref = _db.collection('Warranties').doc();
    final data = <String, dynamic>{
      if (billId != null) 'bill_id': billId,
      'provider': provider,
      'start_date': _ts(startDate),
      'end_date': _ts(endDate),
      if (status != null) 'status': status,
      'user_id': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      if (serialNumber != null && serialNumber.trim().isNotEmpty)
        'serial_number': serialNumber.trim(),
      if (attachmentLocalPath != null && attachmentLocalPath.trim().isNotEmpty)
        'attachment_local_path': attachmentLocalPath.trim(),
      if (attachmentName != null && attachmentName.trim().isNotEmpty)
        'attachment_name': attachmentName.trim(),
    };
    await ref.set(data);
    return ref.id;
  }

  /// تحديث ضمان (Patch)
  ///
  /// ملاحظات:
  /// - لو تبي تمسح السيريال/المرفق حط clearSerial/clearAttachment = true
  /// - السلاسل الفارغة يتم تجاهلها، استخدم clear* للحذف الصريح
  Future<void> updateWarranty({
    required String id,
    String? provider,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? billId,                 // ممكن تغييره
    String? serialNumber,           // NEW
    bool clearSerial = false,       // NEW
    String? attachmentLocalPath,    // NEW
    String? attachmentName,         // NEW
    bool clearAttachment = false,   // NEW
  }) async {
    final patch = <String, dynamic>{
      if (provider != null)  'provider': provider,
      if (status != null)    'status': status,
      if (startDate != null) 'start_date': _ts(startDate),
      if (endDate != null)   'end_date': _ts(endDate),
      if (billId != null)    'bill_id': billId,
      // serial_number
      if (clearSerial) 'serial_number': FieldValue.delete()
      else if (serialNumber != null && serialNumber.trim().isNotEmpty)
        'serial_number': serialNumber.trim(),
      // attachment fields
      if (clearAttachment) ...{
        'attachment_local_path': FieldValue.delete(),
        'attachment_name': FieldValue.delete(),
      } else ...{
        if (attachmentLocalPath != null && attachmentLocalPath.trim().isNotEmpty)
          'attachment_local_path': attachmentLocalPath.trim(),
        if (attachmentName != null && attachmentName.trim().isNotEmpty)
          'attachment_name': attachmentName.trim(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    };

    // لو ما فيه أي تغيير، لا تنادي Firestore
    final hasRealChange = patch.keys.any((k) => k != 'updated_at');
    if (!hasRealChange) return;

    await _db.collection('Warranties').doc(id).update(patch);
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

  /// هل يوجد ضمان مرتبط بهذه الفاتورة؟
  Future<bool> hasWarrantyForBill(String billId) async {
    final q = await _db
        .collection('Warranties')
        .where('bill_id', isEqualTo: billId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// أول ضمان مرتبط بفاتورة (أو null)
  Future<Map<String, dynamic>?> getFirstWarrantyForBill(String billId) async {
    final q = await _db
        .collection('Warranties')
        .where('bill_id', isEqualTo: billId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return {'id': d.id, ...d.data()};
  }

  /// ستريم ضمانات المستخدم
  /// ملاحظة: قد تحتاج Composite Index: user_id ASC + end_date DESC
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

  /// ستريم ضمانات فاتورة محددة (اختياري)
  Stream<List<Map<String, dynamic>>> streamWarrantiesForBill(String billId) {
    return _db
        .collection('Warranties')
        .where('bill_id', isEqualTo: billId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
