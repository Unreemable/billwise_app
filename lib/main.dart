import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// Auth + Home
import 'src/auth/login_screen.dart';
import 'src/auth/register_screen.dart';
import 'src/home/home_screen.dart';

// Bills & Warranties
import 'src/bills/ui/bill_list_page.dart';
import 'src/bills/ui/add_bill_page.dart';
import 'src/bills/ui/bill_detail_page.dart';
import 'src/warranties/ui/warranty_list_page.dart';
import 'src/warranties/ui/add_warranty_page.dart';
import 'src/warranties/ui/warranty_detail_page.dart';

// Models للتفاصيل
import 'src/common/models.dart';
// صفحة الscan
import 'src/ocr/scan_receipt_page.dart';

Future<void> main() async {
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
      title: 'BillWise',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C7EFF)),
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

      // صفحات لا تحتاج arguments
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        BillListPage.route: (_) => const BillListPage(),
        WarrantyListPage.route: (_) => const WarrantyListPage(),
        AddWarrantyPage.route: (_) => const AddWarrantyPage(),
        ScanReceiptPage.route: (_) => const ScanReceiptPage(),
      },

      // صفحات تحتاج arguments + تمرير suggestWarranty/prefill لـ AddBillPage
      onGenerateRoute: (settings) {
        if (settings.name == BillDetailPage.route && settings.arguments is BillDetails) {
          return MaterialPageRoute(
            builder: (_) => BillDetailPage(details: settings.arguments as BillDetails),
            settings: settings,
          );
        }

        if (settings.name == WarrantyDetailPage.route && settings.arguments is WarrantyDetails) {
          return MaterialPageRoute(
            builder: (_) => WarrantyDetailPage(details: settings.arguments as WarrantyDetails),
            settings: settings,
          );
        }

        if (settings.name == AddBillPage.route) {
          // نتوقع arguments = { suggestWarranty: bool, prefill: Map<String,dynamic>? }
          bool suggest = false;
          Map<String, dynamic>? prefill;

          final args = settings.arguments;
          if (args is Map) {
            suggest = (args['suggestWarranty'] as bool?) ?? false;
            final rawPrefill = args['prefill'];
            if (rawPrefill is Map) {
              prefill = rawPrefill.cast<String, dynamic>();
            }
          }

          return MaterialPageRoute(
            builder: (_) => AddBillPage(
              suggestWarranty: suggest,
              prefill: prefill,
            ),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}
