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
import 'src/home/home_screen.dart';

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

// Notifications (محلي + صفحة الإشعارات)
import 'src/notifications/notifications_service.dart';
import 'src/notifications/notifications_page.dart';

/// لرسائل FCM في الخلفية/إغلاق التطبيق (لازم تكون top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // اختياري: أظهر إشعار محلي عند وصول رسالة خلف الكواليس (لو فيها عنوان/نص)
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

  // FCM: معالج الخلفية لازم يُسجَّل قبل runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // إشعارات محلية (قناة + TZ)
  await NotificationsService.I.init();

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
      home: const _RootGate(),
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        BillListPage.route: (_) => const BillListPage(),
        WarrantyListPage.route: (_) => const WarrantyListPage(),
        ScanReceiptPage.route: (_) => const ScanReceiptPage(),
        AddBillPage.route: (_) => const AddBillPage(),

        // Notifications route
        NotificationsPage.route: (_) => const NotificationsPage(),
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
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('⚠️ billId is required for AddWarrantyPage'),
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}

/// جذر التطبيق: يختار الشاشة المناسبة + يفعّل FCM ويطلب أذونات الإشعار مرة واحدة
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  @override
  void initState() {
    super.initState();

    // نطلب إذن الإشعارات (Android 13+) بعد أول إطار
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationsService.I.requestPermissions(context);
      await _initFCM();              // تهيئة FCM (اختياري لكن مفعّل)
    });
  }

  // ===== Backfill يومي تلقائي (مجاني تمامًا) =====
  Future<void> _autoBackfillRemindersDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'reminders_backfill_yyyyMMdd';
    final today = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString(todayKey) == today) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    DateTime? _tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

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
        purchaseDate: _tsToDate(m['purchase_date']) ?? DateTime.now(),
        returnDeadline: _tsToDate(m['return_deadline']),
        exchangeDeadline: _tsToDate(m['exchange_deadline']),
      );
    }

    await prefs.setString(todayKey, today);
  }

  // ===== FCM =====
  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // تفعيل التهيئة التلقائية (عادة تكون مفعّلة افتراضيًا)
    await messaging.setAutoInitEnabled(true);

    // اطلب الإذن من FCM (iOS/Android 13+)
    final settings = await messaging.requestPermission();
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // اطبع/احفظ الـ token (للاختبار من الـ Console، أو خزّنه للمستخدم)
    final token = await messaging.getToken();
    debugPrint('🔑 FCM Device Token: $token');

    // (اختياري) حفظ التوكن للمستخدم عشان إرسال لاحق من السيرفر (إن رغبتِ)
    await _saveFcmTokenForUser(token);

    // رسائل أثناء فتح التطبيق (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n != null) {
        await NotificationsService.I.showNow(
          title: n.title ?? 'BillWise',
          body: n.body ?? 'New message',
        );
      }
    });

    // الضغط على الإشعار وفتح التطبيق من الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // مثال: افتح صفحة الإشعارات
      if (mounted) {
        Navigator.of(context).pushNamed(NotificationsPage.route);
      }
    });

    // لو فتح التطبيق من إشعار وهو مغلق تمامًا (terminated)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && mounted) {
      Navigator.of(context).pushNamed(NotificationsPage.route);
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
    } catch (_) {
      // تجاهل أي خطأ صامتًا
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          // بعد أول إطار من الدخول: شغّل Backfill اليومي
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoBackfillRemindersDaily();
          });
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
