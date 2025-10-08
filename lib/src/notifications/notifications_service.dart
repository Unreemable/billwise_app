import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة الإشعارات (محلية) — تعمل بلا تغيير في main/AddBill/AddWarranty.
/// فيها تهيئة كسولة (lazy): أي دالة تستدعيها تضمن التهيئة تلقائياً.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService I = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _inited = false;
  bool _channelReady = false;
  bool _tzReady = false;

  // ================== Init & Permissions ==================
  Future<void> init() async {
    // تهيئة صريحة (اختياري). الدوال أدناه تنفذها تلقائيًا لو نسيتها.
    await _ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);

    await _plugin.initialize(init);

    // توقيت (للجدولة بالتاريخ/الساعة)
    await _ensureTZ();

    _inited = true;
  }

  Future<void> requestPermissions([BuildContext? _]) async {
    await _ensureInitialized();
    if (!Platform.isAndroid) return;

    final android =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // أجهزة 13+ تحتاج Runtime permission
    try {
      // بعض إصدارات المكتبة تستخدم هذا الاسم
      await (android as dynamic).requestPermission();
    } catch (_) {
      try {
        // وبعضها هذا
        await (android as dynamic).requestNotificationsPermission();
      } catch (_) {/* تجاهل */}
    }
  }

  Future<void> _ensureTZ() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      // بدون إضافة حزم خارجية لقراءة IANA timezone:
      // نفترض الرياض كافتراضي منطقي للمنطقة، وإن فشل نرجع UTC.
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

    final android =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const ch = AndroidNotificationChannel(
        'billwise_reminders',
        'BillWise Reminders',
        description:
        'Reminders for return/exchange deadlines and warranty expiry',
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
      channelDescription:
      'Reminders for return/exchange deadlines and warranty expiry',
      importance: Importance.max,
      priority: Priority.high,
    );
    return const NotificationDetails(android: android);
  }

  // ================== Helpers ==================
  int _safeHash(String s) => s.hashCode & 0x7fffffff;
  int _billReturnId(String billId) => (_safeHash(billId) % 500000) + 1000000;
  int _billExchangeId(String billId) => (_safeHash(billId) % 500000) + 1500000;
  int _warrantyId(String warrantyId) => (_safeHash(warrantyId) % 500000) + 2000000;

  DateTime _at10am(DateTime d) => DateTime(d.year, d.month, d.day, 10, 0);
  tz.TZDateTime _toTZ(DateTime local) => tz.TZDateTime.from(local, tz.local);

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

    // ألغِ أي إشعارات قديمة لهذي الفاتورة
    await cancelBillReminders(billId);

    final now = DateTime.now();

    if (returnDeadline != null) {
      final when = _at10am(returnDeadline);
      if (when.isAfter(now)) {
        await _plugin.zonedSchedule(
          _billReturnId(billId),
          'Return deadline',
          '“$title” from $shop — last day for return.',
          _toTZ(when),
          _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'bill:$billId:return',
        );
      }
    }

    if (exchangeDeadline != null) {
      final when = _at10am(exchangeDeadline);
      if (when.isAfter(now)) {
        await _plugin.zonedSchedule(
          _billExchangeId(billId),
          'Exchange deadline',
          '“$title” from $shop — last day for exchange.',
          _toTZ(when),
          _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'bill:$billId:exchange',
        );
      }
    }
  }

  Future<void> cancelBillReminders(String billId) async {
    await _ensureInitialized();
    await _plugin.cancel(_billReturnId(billId));
    await _plugin.cancel(_billExchangeId(billId));
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

    final now = DateTime.now();
    final when = _at10am(end);
    if (when.isAfter(now)) {
      await _plugin.zonedSchedule(
        _warrantyId(warrantyId),
        'Warranty ends today',
        'Warranty by $provider ends today.',
        _toTZ(when),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'warranty:$warrantyId:end',
      );
    }
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
      // id عشوائي آمن
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
}
