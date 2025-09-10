import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  Future<UserCredential> register(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح.';
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'البريد مستخدم مسبقًا.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (8 أحرف على الأقل).';
      case 'operation-not-allowed':
        return 'Email/Password غير مفعّل في Firebase.';
      default:
        return e.message ?? e.code;
    }
  }
}
