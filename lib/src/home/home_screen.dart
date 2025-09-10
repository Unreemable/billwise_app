import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  static const route = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'مستخدم';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرئيسية'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () async => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(child: Text('أهلًا، $email')),
      ),
    );
  }
}
