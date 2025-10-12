import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// إشعارات محلية مع دعم الجدولة الدقيقة على أندرويد + تشخيص
class NotificationsService {
  NotificationsService._();
  static final NotificationsService I = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _inited = false;
  bool _channelReady = false;
  bool _tzReady = false;

  // ================== Init & Permissions ==================
  Future<void> init() async => _ensureInitialized();

  Future<void> _ensureInitialized() async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        // بإمكانك هنا التعامل مع payload لو حبيت.
      },
    );

    await _ensureTZ();
    _inited = true;
  }

  Future<void> requestPermissions([BuildContext? _]) async {
    await _ensureInitialized();
    if (!Platform.isAndroid) return;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Android 13+
    try {
      await (android as dynamic).requestPermission();
    } catch (_) {
      try {
        await (android as dynamic).requestNotificationsPermission();
      } catch (_) {/* تجاهل */}
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // اعتبرها مسموحة على منصات أخرى
    try {
      final enabled = await (android as dynamic).areNotificationsEnabled();
      return (enabled is bool) ? enabled : true;
    } catch (_) {
      return true;
    }
  }

  /// هل مسموح للبرنامج بجدولة exact alarms؟
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final ok = await (android as dynamic).canScheduleExactNotifications();
      // بعض الإصدارات تستخدم اسم مختلف:
      if (ok is bool) return ok;
    } catch (_) {
      // جرّب اسم API آخر شائع
      try {
        final ok2 = await (android as dynamic).areAlarmsAndRemindersEnabled();
        if (ok2 is bool) return ok2;
      } catch (_) {}
    }
    return true; // إن ما قدرنا نستعلم، لا نوقف الجدولة
  }

  Future<void> openExactAlarmsSettings() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await (android as dynamic).openAlarmsAndRemindersSettings();
    } catch (_) {/* تجاهل */}
  }

  Future<void> _ensureTZ() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    // ثبّت الرياض، ولو فشل خذ UTC
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
    _tzReady = true;
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    if (!Platform.isAndroid) {
      _channelReady = true;
      return;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const ch = AndroidNotificationChannel(
        'billwise_reminders',
        'BillWise Reminders',
        description: 'Reminders for return/exchange deadlines and warranty expiry',
        importance: Importance.max,
      );
      await android.createNotificationChannel(ch);
      _channelReady = true;
    }
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'billwise_reminders',
      'BillWise Reminders',
      channelDescription: 'Reminders for return/exchange deadlines and warranty expiry',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'BillWise',
    );
    return const NotificationDetails(android: android);
  }

  // ================== Helpers ==================
  int _safeHash(String s) => s.hashCode & 0x7fffffff;

  int _billReminderId(String billId, String tag) => (_safeHash('$billId::$tag') % 500000) + 1000000;
  int _warrantyId(String warrantyId) => (_safeHash(warrantyId) % 500000) + 2000000;

  tz.TZDateTime _toTZ(DateTime local) => tz.TZDateTime.from(local, tz.local);

  /// جدولة مع fallback تلقائي: نحاول exact، وإذا رفض النظام نسقط إلى inexact
  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
    bool exact = true,
  }) async {
    final when = _toTZ(whenLocal);
    // أحيانًا يكون الفرق أجزاء من الثانية → نزود 2 ثواني أمان
    final now = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2));
    if (!when.isAfter(now)) return;

    await _ensureInitialized();
    await _ensureChannel();

    // أولًا: حاول exact
    if (exact) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
          // منذ 18.x أزيل uiLocalNotificationDateInterpretation والمطابقة: لا نمررها
          // matchDateTimeComponents: null,  ← الافتراضي null
        );
        return;
      } catch (e) {
        final msg = e.toString();
        // لو رفض النظام exact alarms، نسقط إلى inexact
        if (!msg.contains('exact') && !msg.contains('EXACT')) {
          // أخطاء أخرى: سنعيد المحاولة بأسلوب inexact عمومًا
        }
        // Fallthrough إلى inexact
      }
    }

    // ثانيًا: inexact
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  // للاستخدام اليدوي من صفحة NotificationsPage
  Future<int> scheduleAt({
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
    bool exact = true,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();
    final id = _safeHash('${whenLocal.toIso8601String()}::$title') % 900000 + 3000000;
    await _zonedSchedule(
      id: id,
      title: title,
      body: body,
      whenLocal: whenLocal,
      payload: payload,
      exact: exact,
    );
    return id;
  }

  // ================== Bills ==================
  Future<void> rescheduleBillReminders({
    required String billId,
    required String title,
    required String shop,
    required DateTime purchaseDate,
    DateTime? returnDeadline,
    DateTime? exchangeDeadline,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();

    await cancelBillReminders(billId);

    const bool exact = true;

    if (returnDeadline != null) {
      final d = DateTime(returnDeadline.year, returnDeadline.month, returnDeadline.day, 10);
      await _zonedSchedule(
        id: _billReminderId(billId, 'ret_minus1'),
        title: 'Return reminder',
        body: '“$title” from $shop — return period ends tomorrow.',
        whenLocal: d.subtract(const Duration(days: 1)),
        payload: 'bill:$billId:return:minus1',
        exact: exact,
      );
      await _zonedSchedule(
        id: _billReminderId(billId, 'ret_last'),
        title: 'Return deadline',
        body: '“$title” from $shop — return period ends today.',
        whenLocal: d,
        payload: 'bill:$billId:return:last',
        exact: exact,
      );
    }

    if (exchangeDeadline != null) {
      final d = DateTime(exchangeDeadline.year, exchangeDeadline.month, exchangeDeadline.day, 10);
      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_minus2'),
        title: 'Exchange reminder',
        body: '“$title” from $shop — 2 days left to exchange.',
        whenLocal: d.subtract(const Duration(days: 2)),
        payload: 'bill:$billId:exchange:minus2',
        exact: exact,
      );
      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_minus1'),
        title: 'Exchange reminder',
        body: '“$title” from $shop — 1 day left to exchange.',
        whenLocal: d.subtract(const Duration(days: 1)),
        payload: 'bill:$billId:exchange:minus1',
        exact: exact,
      );
      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_last'),
        title: 'Exchange deadline',
        body: '“$title” from $shop — exchange period ends today.',
        whenLocal: d,
        payload: 'bill:$billId:exchange:last',
        exact: exact,
      );
    }
  }

  Future<void> cancelBillReminders(String billId) async {
    await _ensureInitialized();
    for (final tag in const ['ret_minus1', 'ret_last', 'ex_minus2', 'ex_minus1', 'ex_last']) {
      await _plugin.cancel(_billReminderId(billId, tag));
    }
  }

  // ================== Warranties ==================
  Future<void> rescheduleWarrantyReminder({
    required String warrantyId,
    required String provider,
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();

    await cancelWarrantyReminder(warrantyId);

    final d = DateTime(end.year, end.month, end.day, 10);
    await _zonedSchedule(
      id: _warrantyId(warrantyId),
      title: 'Warranty ends today',
      body: 'Warranty by $provider ends today.',
      whenLocal: d,
      payload: 'warranty:$warrantyId:end',
      exact: true,
    );
  }

  Future<void> cancelWarrantyReminder(String warrantyId) async {
    await _ensureInitialized();
    await _plugin.cancel(_warrantyId(warrantyId));
  }

  // ================== Utilities ==================
  Future<void> showNow({
    String title = 'Test notification',
    String body = 'Hello from BillWise',
  }) async {
    await _ensureInitialized();
    await _ensureChannel();
    await _plugin.show(
      _safeHash(DateTime.now().toIso8601String()) % 900000 + 3000000,
      title,
      body,
      _details(),
    );
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// تشخيص سريع: يُظهر حالة الإذن/القناة/exact/pending
  Future<void> showDiagnosticsDialog(BuildContext context) async {
    await _ensureInitialized();
    await _ensureChannel();

    final enabled = await areNotificationsEnabled();
    final exactOk = await canScheduleExactAlarms();
    final pending = await _plugin.pendingNotificationRequests();
    final buf = StringBuffer()
      ..writeln('🔧 Notifications diagnostics')
      ..writeln('• areNotificationsEnabled: $enabled')
      ..writeln('• canScheduleExactAlarms:  $exactOk')
      ..writeln('• pending count:          ${pending.length}')
      ..writeln('• tz.local:               ${tz.local.name}');

    // أعرض IDs مختصرة
    for (final p in pending.take(10)) {
      buf.writeln('   - [${p.id}] ${p.title ?? ''} (${p.payload ?? ''})');
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('BillWise • Diagnostics'),
        content: SingleChildScrollView(child: Text(buf.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openExactAlarmsSettings();
            },
            child: const Text('Open exact-alarms settings'),
          ),
        ],
      ),
    );
  }
}
