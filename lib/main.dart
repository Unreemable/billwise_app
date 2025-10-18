import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

// Auth + Home
import 'src/auth/login_screen.dart';
import 'src/auth/register_screen.dart';
import 'src/home/home_screen.dart'; // للتوافق فقط

// Bills & Warranties
import 'src/bills/ui/bill_list_page.dart';
import 'src/bills/ui/add_bill_page.dart';
import 'src/bills/ui/bill_detail_page.dart';
import 'src/warranties/ui/warranty_list_page.dart';
import 'src/warranties/ui/add_warranty_page.dart';
import 'src/warranties/ui/warranty_detail_page.dart';

// Models
import 'src/common/models.dart';

// OCR
import 'src/ocr/scan_receipt_page.dart';

// Notifications
import 'src/notifications/notifications_service.dart';
import 'src/notifications/notifications_page.dart';
// 👇 جديد: إنشاء قناة billwise_reminders
import 'src/notifications/notifications_bootstrap.dart';

// Profile
import 'src/profile/profile_page.dart';
import 'src/profile/edit_profile_page.dart';

// خلفية الباستيل
import 'src/common/soft_pastel_background.dart';

// App Shell (النافقيشن السفلي الدائم)
import 'src/shell/app_shell.dart';

/// لرسائل FCM في الخلفية/إغلاق التطبيق
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final n = message.notification;
  if (n != null) {
    await NotificationsService.I.init();
    await NotificationsService.I.showNow(
      title: n.title ?? 'BillWise',
      body: n.body ?? 'Background message',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // إنشاء قناة الإشعارات محليًا (Android 8+) — يجب قبل أي عرض محلي
  await setupLocalNotifications();

  // FCM: معالج الخلفية لازم يُسجَّل قبل runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        scaffoldBackgroundColor: Colors.transparent, // للخلفية
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C7EFF)),
      ),
      // الخلفية العامة
      builder: (context, child) => SoftPastelBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _RootGate(),
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(), // للتوافق
        BillListPage.route: (_) => const BillListPage(),
        WarrantyListPage.route: (_) => const WarrantyListPage(),
        ScanReceiptPage.route: (_) => const ScanReceiptPage(),
        AddBillPage.route: (_) => const AddBillPage(),
        EditProfilePage.route: (_) => const EditProfilePage(),
        NotificationsPage.route: (_) => const NotificationsPage(),
        ProfilePage.route: (_) => const ProfilePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == BillDetailPage.route &&
            settings.arguments is BillDetails) {
          return MaterialPageRoute(
            builder: (_) =>
                BillDetailPage(details: settings.arguments as BillDetails),
            settings: settings,
          );
        }
        if (settings.name == WarrantyDetailPage.route &&
            settings.arguments is WarrantyDetails) {
          return MaterialPageRoute(
            builder: (_) =>
                WarrantyDetailPage(details: settings.arguments as WarrantyDetails),
            settings: settings,
          );
        }
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
          // 🔧 شلنا const من MaterialPageRoute لأنه ليس const constructor
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: Text('⚠️ billId is required for AddWarrantyPage')),
            ),
          );
        }
        return null;
      },
    );
  }
}

/// Root: يختار الشاشة + يفعّل FCM + Backfill يومي
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationsService.I.requestPermissions(context);
      await _initFCM();
    });
  }

  // ✅ غيّرنا اسم الدالة (بدون underscore) لتفادي تحذير الـ Lint
  DateTime? tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  Future<void> _autoBackfillRemindersDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'reminders_backfill_yyyyMMdd';
    final today =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString(todayKey) == today) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('Bills')
        .where('user_id', isEqualTo: uid)
        .get();

    for (final d in snap.docs) {
      final m = d.data();
      await NotificationsService.I.rescheduleBillReminders(
        billId: d.id,
        title: (m['title'] ?? '').toString(),
        shop: (m['shop_name'] ?? '').toString(),
        purchaseDate: tsToDate(m['purchase_date']) ?? DateTime.now(),
        returnDeadline: tsToDate(m['return_deadline']),
        exchangeDeadline: tsToDate(m['exchange_deadline']),
      );
    }

    await prefs.setString(todayKey, today);
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.setAutoInitEnabled(true);

    final settings = await messaging.requestPermission();
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    debugPrint('🔑 FCM Device Token: $token');

    await _saveFcmTokenForUser(token);

    // فورغراوند: أظهر تنبيه محلي على قناة billwise_reminders
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n != null) {
        await NotificationsService.I.showNow(
          title: n.title ?? 'BillWise',
          body: n.body ?? 'New message',
        );
      }
    });

    // فتح من التنبيه
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushNamed(NotificationsPage.route);
      }
    });

    // فتح من terminated
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && mounted) {
      Navigator.of(context, rootNavigator: true).pushNamed(NotificationsPage.route);
    }
  }

  Future<void> _saveFcmTokenForUser(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoBackfillRemindersDaily();
          });
          // البار السفلي ثابت في كل الصفحات
          return const AppShell();
        }
        return const LoginScreen();
      },
    );
  }
}
