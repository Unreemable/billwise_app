import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Local storage
import 'package:shared_preferences/shared_preferences.dart';

// .env
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // واجهة حافة-لحافة
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0E0722),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // .env
  await dotenv.load(fileName: ".env");

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Local notifications
  await setupLocalNotifications();

  // FCM background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runZonedGuarded(() {
    runApp(const App());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
class App extends StatefulWidget {
  const App({super.key});

  // عشان نقدر نوصل لحالة الثيم من أي صفحة (مثل ProfilePage)
  static _AppState of(BuildContext context) {
    return context.findAncestorStateOfType<_AppState>()!;
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // الوضع الحالي للثيم
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  // نقرأ آخر اختيار من SharedPreferences (اختياري لكن لطيف)
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('theme_mode');
    setState(() {
      _themeMode = _stringToThemeMode(value) ?? ThemeMode.system;
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeModeToString(mode));
    setState(() {
      _themeMode = mode;
    });
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode? _stringToThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF0E0722);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BillWise',

      // 🌞 LIGHT MODE
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F3FF), // Lavender Light
        canvasColor: Colors.transparent,
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3EFF),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: Colors.black87,
          primary: const Color(0xFF6C3EFF),
          onPrimary: Colors.white,
        ),
      ),

      // 🌙 DARK MODE (تصميمك الحالي)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        // *** تم إصلاح هذا: يجب أن تكون الخلفية هي اللون الداكن، وليس شفافاً ***
        scaffoldBackgroundColor: darkBg,
        canvasColor: Colors.transparent,
        cardColor: const Color(0x1AFFFFFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F33E1),
          brightness: Brightness.dark,
          surface: darkBg,
          onSurface: Colors.white,
          primary: const Color(0xFF6C3EFF),
          onPrimary: Colors.white,
        ),
      ),

      // 🎛 هنا نستخدم الثيم المختار
      themeMode: _themeMode,

      // الخلفية العامة الناعمة
      // بما أن الـ Scaffold أصبح الآن معتماً في الوضع الداكن، فإنه سيغطي هذه الخلفية
      builder: (context, child) => const SoftPastelBackground(
        child: SizedBox.expand(child: ColoredBox(color: Colors.transparent)),
      ).copyWithChild(child ?? const SizedBox.shrink()),

      home: const _RootGate(),

      routes: {
        WelcomeScreen.route: (_) => const WelcomeScreen(),
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
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
            builder: (_) => WarrantyDetailPage(
                details: settings.arguments as WarrantyDetails),
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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamed(NotificationsPage.route);
      }
    });

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
          return const AppShell();
        }
        return const WelcomeScreen();
      },
    );
  }
}

extension on SoftPastelBackground {
  Widget copyWithChild(Widget newChild) {
    return SoftPastelBackground(child: newChild);
  }
}