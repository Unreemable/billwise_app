import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> billsCol(String userId) =>
      _db.collection('users').doc(userId).collection('bills');

  CollectionReference<Map<String, dynamic>> warrantiesCol(String userId) =>
      _db.collection('users').doc(userId).collection('warranties');

  Future<DocumentReference<Map<String, dynamic>>> add(
      CollectionReference<Map<String, dynamic>> col, Map<String, dynamic> data) {
    return col.add(data);
  }

  Future<void> setDoc(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data, {
        bool merge = false,
      }) {
    return ref.set(data, SetOptions(merge: merge));
  }

  Future<void> update(
      DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) {
    return ref.update(data);
  }

  Future<void> delete(DocumentReference<Map<String, dynamic>> ref) => ref.delete();
}
