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

// Models (لصفحات التفاصيل)
import 'src/common/models.dart';

// صفحة الـ Scan
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

      // يوجّه حسب حالة الدخول
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
        ScanReceiptPage.route: (_) => const ScanReceiptPage(),
        // AddBillPage لا تحتاج arguments حالياً
        AddBillPage.route: (_) => const AddBillPage(),
      },

      // صفحات تحتاج arguments
      onGenerateRoute: (settings) {
        // تفاصيل فاتورة: نتوقع BillDetails
        if (settings.name == BillDetailPage.route &&
            settings.arguments is BillDetails) {
          return MaterialPageRoute(
            builder: (_) =>
                BillDetailPage(details: settings.arguments as BillDetails),
            settings: settings,
          );
        }

        // تفاصيل ضمان: نتوقع WarrantyDetails
        if (settings.name == WarrantyDetailPage.route &&
            settings.arguments is WarrantyDetails) {
          return MaterialPageRoute(
            builder: (_) => WarrantyDetailPage(
                details: settings.arguments as WarrantyDetails),
            settings: settings,
          );
        }

        // إضافة ضمان: تحتاج billId (وممكن start/end اختياري)
        if (settings.name == AddWarrantyPage.route) {
          final args = settings.arguments;
          if (args is Map<String, dynamic> && args['billId'] is String) {
            return MaterialPageRoute(
              builder: (_) => AddWarrantyPage(
                billId: args['billId'] as String,
                defaultStartDate: args['start'] as DateTime?,
                defaultEndDate: args['end'] as DateTime?,
              ),
              settings: settings,
            );
          }
          // في حال نُسيت الـ arguments
          return MaterialPageRoute(
            builder: (_) => const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(
                  child: Text('⚠️ يلزم تمرير billId لصفحة إضافة الضمان'),
                ),
              ),
            ),
          );
        }

        return null;
      },
    );
  }
}
