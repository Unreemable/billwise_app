
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Local storage نخزن بيانات بسيطة مثل الflags
import 'package:shared_preferences/shared_preferences.dart';

// .env نخزن api kays
import 'package:flutter_dotenv/flutter_dotenv.dart';

// استيراد الصفحات يبدأ من هنا
// Firebase options
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

// Notifications
import 'src/notifications/notifications_service.dart';
import 'src/notifications/notifications_page.dart';
import 'src/notifications/notifications_bootstrap.dart';

// Profile
import 'src/profile/profile_page.dart';
import 'src/profile/edit_profile_page.dart';

// الخلفية العامة
import 'src/common/soft_pastel_background.dart';

// App Shell
import 'src/shell/app_shell.dart';

// Welcome
import 'welcome/welcome_screen.dart';

/// يدالة تسجيل تأخير الإشعار
/// تقيس كم تأخرت رسالة Firebase من وقت إرسالها (sent_at_iso) إلى وصولها وتحفظ الرقم في ماتركس الفايربيس

Future<void> _logFcmDeliveryDelay(RemoteMessage message) async {
  try {
    final sentIso = message.data['sent_at_iso'];
    if (sentIso is String && sentIso.isNotEmpty) {
      final sentAt = DateTime.tryParse(sentIso)?.toUtc();
      final arriveAt = DateTime.now().toUtc();
      if (sentAt != null) {
        final delayMs = arriveAt.difference(sentAt).inMilliseconds;
        await FirebaseFirestore.instance.collection('perf_metrics').add({
          'kind': 'notification_receive',
          'delay_ms': delayMs,
          'at_iso': arriveAt.toIso8601String(),
          'message_id': message.messageId,
          'title': message.notification?.title,
          'body': message.notification?.body,
        });
      }
    }
  } catch (_) {}
}

/// معالج FCM في الخلفية (top-level)
/// يشتغل حتى لو التطبيق مغلق

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _logFcmDeliveryDelay(message);
  final n = message.notification;
  if (n != null) {
    await NotificationsService.I.init();
    await NotificationsService.I.showNow(
      title: n.title ?? 'BillWise',
      body: n.body ?? 'Background message',
    );
  }
}
//دالة main
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // واجهة حافة-لحافة + صبغ أشرطة النظام
  //إعداد الشكل العام للجهاز
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0E0722), // داكن
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // .env
  await dotenv.load(fileName: ".env");

  // Firebase تشغيل
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics ^5.x
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // نسوي تهيئة للاشعارات المحلية
  await setupLocalNotifications();

  //  تهيئة معالج الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // نشغل التطبيق داخلها عشان اي خطأ مانلقطه يروح للcrashlytics
  runZonedGuarded(() {
    runApp(const App());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
///كلاس App (MaterialApp) هنا نضبط الثيم والخلفية العامة وصفحة البداية والrouts
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E0722);

    return MaterialApp(
      debugShowCheckedModeBanner: false, //يشيل علامة الديبق الحمراء
      title: 'BillWise',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,//الخلفية شفافة
        canvasColor: Colors.transparent,
        cardColor: const Color(0x1AFFFFFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F33E1),
          brightness: Brightness.dark,
          surface: bg,
          onSurface: Colors.white,
          primary: const Color(0xFF6C3EFF),
          onPrimary: Colors.white,
        ),
      ),

      // الخلفية العامة الناعمة
      builder: (context, child) => const SoftPastelBackground(
        child: SizedBox.expand(child: ColoredBox(color: Colors.transparent)),
      ).copyWithChild(child ?? const SizedBox.shrink()),


      //اذا المستخدم مسجل AppShell
      // غير مسجل؟ → WelcomeScreen
      home: const _RootGate(),

      routes: {
        // Welcome + Auth
        WelcomeScreen.route: (_) => const WelcomeScreen(),
        LoginScreen.route:   (_) => const LoginScreen(),
        RegisterScreen.route:(_) => const RegisterScreen(),


        HomeScreen.route: (_) => const HomeScreen(),

        // Bills and Warranties
        BillListPage.route: (_) => const BillListPage(),
        WarrantyListPage.route: (_) => const WarrantyListPage(),
        ScanReceiptPage.route: (_) => const ScanReceiptPage(),
        AddBillPage.route: (_) => const AddBillPage(),

        // Profile / Notifs
        EditProfilePage.route: (_) => const EditProfilePage(),
        NotificationsPage.route: (_) => const NotificationsPage(),
        ProfilePage.route: (_) => const ProfilePage(),
      },

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
      await _initFCM(); //تفعيل الإشعارات
    });
  }

  DateTime? tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  Future<void> _autoBackfillRemindersDaily() async { // يعيد حساب الريمايندر بشكل يومي بحيث يضمن عدم تكرار الاشعار
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
    debugPrint('🔑 FCM Device Token: fgN8ZhvUTT2GTuqWsptvGV:APA91bG0OPeDF8zHRryaiVN8kNX1oF-tj2O6kSIlzfs4qgIRSkOynk28rzPY-8OCXEi4ugzGnRlJMGwwE1EcHE8vljCcX7xj2Y_l8iT8E15TVf520EvS3_A');

    await _saveFcmTokenForUser(token);

    // فورغراوند: نحسب تأخير التسليم + نعرض إشعار محلي يعني التطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _logFcmDeliveryDelay(message);
      final n = message.notification;
      if (n != null) {
        await NotificationsService.I.showNow(
          title: n.title ?? 'BillWise',
          body: n.body ?? 'New message',
        );
      }
    });

    // دخل من الاشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamed(NotificationsPage.route);
      }
    });

    // فتح والتطبيق مقفل
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && mounted) {
      await _logFcmDeliveryDelay(initial);
      Navigator.of(context, rootNavigator: true)
          .pushNamed(NotificationsPage.route);
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

  /// يتابع حالة تسجيل الدخول
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(//إن كان المستخدم Logged in
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoBackfillRemindersDaily();
          });
          // ملاحظة: AppShell لازم يستخدم Scaffold(extendBody: true, backgroundColor: Colors.transparent)
          return const AppShell();
        }
        // الشاشة الافتراضية لغير المسجلين إلى شاشة الترحيب
        return const WelcomeScreen();
      },
    );
  }
}

// ====== تمديد Widget بسيط يسمح بتمرير child ديناميكي لـ SoftPastelBackground=
extension on SoftPastelBackground {
  Widget copyWithChild(Widget newChild) {
    return SoftPastelBackground(child: newChild);
  }
}
