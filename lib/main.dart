import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'src/auth/login_screen.dart';
import 'src/auth/register_screen.dart';
import 'src/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'hhhh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // يوجّه تلقائيًا حسب حالة الدخول
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return snap.hasData ? const HomeScreen() : const LoginScreen();
        },
      ),
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
      },
    );
  }
}
