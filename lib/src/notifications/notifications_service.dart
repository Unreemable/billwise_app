import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة الإشعارات المحلية (داخل الجهاز) مع:
/// - ضبط المنطقة الزمنية على الرياض
/// - إنشاء قناة خاصة للتطبيق
/// - جدولة إشعارات الفواتير والضمانات بدقة
/// - دوال تشخيص (diagnostics) لمعرفة حالة الإشعارات
class NotificationsService {
  NotificationsService._();
  static final NotificationsService I = NotificationsService._();

  // الكائن الرئيسي لمكتبة flutter_local_notifications
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _inited = false;       // هل تم عمل initialize للمكتبة؟
  bool _channelReady = false; // هل تم إنشاء قناة الإشعارات على أندرويد؟
  bool _tzReady = false;      // هل تم تهيئة المنطقة الزمنية tz ؟

  // ================== Init & Permissions ==================

  /// نداء عام من أي مكان: يضمن أن الخدمة مهيّأة
  Future<void> init() async => _ensureInitialized();

  /// تهيئة مكتبة الإشعارات + إعداد المنطقة الزمنية
  Future<void> _ensureInitialized() async {
    if (_inited) return;

    // إعدادات التهيئة للأندرويد (الأيقونة الافتراضية)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);

    // initialize للمكتبة مع كولباك عند الضغط على الإشعار
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        // تقدر هنا تقرأ resp.payload وتوجّه المستخدم لصفحة معيّنة لو حبيتي
      },
    );

    // تهيئة مكتبة timezone وضبطها على الرياض
    await _ensureTZ();
    _inited = true;
  }

  /// طلب أذونات الإشعارات (مهم لأندرويد 13+)
  Future<void> requestPermissions([BuildContext? _]) async {
    await _ensureInitialized();
    if (!Platform.isAndroid) return;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // أندرويد 13 وما فوق تحتاج طلب إذن notifications
    try {
      await (android as dynamic).requestPermission();
    } catch (_) {
      try {
        await (android as dynamic).requestNotificationsPermission();
      } catch (_) {/* تجاهل أي خطأ */}
    }
  }

  /// التحقق: هل الإشعارات مفعّلة للتطبيق أم لا؟
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // على منصات غير أندرويد نفترض أنها شغالة
    try {
      final enabled = await (android as dynamic).areNotificationsEnabled();
      return (enabled is bool) ? enabled : true;
    } catch (_) {
      return true;
    }
  }

  /// التحقق: هل النظام يسمح لنا بجدولة exact alarms (دقة عالية جدًا)؟
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final ok = await (android as dynamic).canScheduleExactNotifications();
      // بعض الأجهزة/الإصدارات ترجع نوع ثاني، لذلك نتحقق أنه bool
      if (ok is bool) return ok;
    } catch (_) {
      // في حال فشل الاسم الأول، نجرب اسم API آخر
      try {
        final ok2 = await (android as dynamic).areAlarmsAndRemindersEnabled();
        if (ok2 is bool) return ok2;
      } catch (_) {}
    }
    return true; // لو فشل الاستعلام، ما نوقف الجدولة
  }

  /// فتح إعدادات exact alarms من النظام (لو المستخدم محتاج يفعّلها)
  Future<void> openExactAlarmsSettings() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await (android as dynamic).openAlarmsAndRemindersSettings();
    } catch (_) {/* تجاهل */}
  }

  /// تهيئة مكتبة المناطق الزمنية واختيار Asia/Riyadh كمنطقة محلية
  Future<void> _ensureTZ() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    // نحاول نضبط الرياض، لو صار خطأ نرجع لـ UTC
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
    _tzReady = true;
  }

  /// إنشاء قناة الإشعارات للأندرويد (مطلوبة من Android 8+)
  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    if (!Platform.isAndroid) {
      _channelReady = true;
      return;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const ch = AndroidNotificationChannel(
        'billwise_reminders',                      // id القناة
        'BillWise Reminders',                      // اسم القناة في إعدادات النظام
        description: 'Reminders for return/exchange deadlines and warranty expiry',
        importance: Importance.max,                // أعلى أولوية
      );
      await android.createNotificationChannel(ch);
      _channelReady = true;
    }
  }

  /// إعدادات التفاصيل الافتراضية للإشعار (صوت/اهتزاز... إلخ)
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

  /// hash آمن (نستخدمه لتوليد IDs) مع تقليل احتمال التضارب
  int _safeHash(String s) => s.hashCode & 0x7fffffff;

  /// توليد ID فريد لإشعارات الفاتورة بناءً على billId + tag
  int _billReminderId(String billId, String tag) =>
      (_safeHash('$billId::$tag') % 500000) + 1000000;

  /// توليد ID فريد لإشعار الضمان بناءً على warrantyId
  int _warrantyId(String warrantyId) =>
      (_safeHash(warrantyId) % 500000) + 2000000;

  /// تحويل DateTime عادي إلى TZDateTime باستخدام tz.local
  tz.TZDateTime _toTZ(DateTime local) => tz.TZDateTime.from(local, tz.local);

  /// دالة داخلية لجدولة إشعار:
  /// - تحاول أولاً exactAllowWhileIdle
  /// - لو رفض النظام، ترجع لـ inexactAllowWhileIdle
  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
    bool exact = true,
  }) async {
    final when = _toTZ(whenLocal);

    // أحيانًا يكون الفرق أجزاء من الثانية، فنزود ثانيتين احتياط
    final now = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2));
    if (!when.isAfter(now)) return; // لو الموعد في الماضي/قريب جدًا، نتجاهل

    await _ensureInitialized();
    await _ensureChannel();

    // المحاولة الأولى: exact
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
          // في الإصدارات الجديدة ما نحتاج نمرر uiLocalNotificationDateInterpretation
        );
        return; // نجحت، نرجع
      } catch (e) {
        final msg = e.toString();
        // لو الرسالة ما تتعلق بكلمة exact، ممكن يكون نوع خطأ آخر،
        // عموماً بعدها نسقط إلى inexact.
        if (!msg.contains('exact') && !msg.contains('EXACT')) {
          // أخطاء أخرى: بنسوي inexact برضو
        }
        // نكمل تحت لـ inexact
      }
    }

    // المحاولة الثانية: inexact (أقل دقة لكن أمان أكثر)
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

  /// جدولة إشعار عام في وقت معيّن (للاستخدام اليدوي من أي صفحة)
  Future<int> scheduleAt({
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
    bool exact = true,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();

    // توليد ID فريد بناءً على الوقت + العنوان
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

  /// إعادة جدولة كل إشعارات "فاتورة" معيّنة:
  /// - يلغي أي إشعارات قديمة لهذه الفاتورة
  /// - يعيد إنشاء تذكيرات الاسترجاع والاستبدال بناءً على التواريخ
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

    // أولاً: نلغي أي إشعارات قديمة مرتبطة بنفس الفاتورة
    await cancelBillReminders(billId);

    const bool exact = true;

    // ===== إشعارات الاسترجاع =====
    if (returnDeadline != null) {
      // نثبت الساعة 10 صباحًا في يوم الاسترجاع
      final d = DateTime(returnDeadline.year, returnDeadline.month, returnDeadline.day, 10);

      // إشعار قبل يوم من نهاية فترة الاسترجاع
      await _zonedSchedule(
        id: _billReminderId(billId, 'ret_minus1'),
        title: 'Return reminder',
        body: '“$title” from $shop — return period ends tomorrow.',
        whenLocal: d.subtract(const Duration(days: 1)),
        payload: 'bill:$billId:return:minus1',
        exact: exact,
      );

      // إشعار في نفس يوم الاسترجاع
      await _zonedSchedule(
        id: _billReminderId(billId, 'ret_last'),
        title: 'Return deadline',
        body: '“$title” from $shop — return period ends today.',
        whenLocal: d,
        payload: 'bill:$billId:return:last',
        exact: exact,
      );
    }

    // ===== إشعارات الاستبدال =====
    if (exchangeDeadline != null) {
      // نثبت الساعة 10 صباحًا في يوم الاستبدال
      final d = DateTime(exchangeDeadline.year, exchangeDeadline.month, exchangeDeadline.day, 10);

      // إشعار قبل يومين من نهاية فترة الاستبدال
      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_minus2'),
        title: 'Exchange reminder',
        body: '“$title” from $shop — 2 days left to exchange.',
        whenLocal: d.subtract(const Duration(days: 2)),
        payload: 'bill:$billId:exchange:minus2',
        exact: exact,
      );

      // إشعار قبل يوم واحد من نهاية فترة الاستبدال
      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_minus1'),
        title: 'Exchange reminder',
        body: '“$title” from $shop — 1 day left to exchange.',
        whenLocal: d.subtract(const Duration(days: 1)),
        payload: 'bill:$billId:exchange:minus1',
        exact: exact,
      );

      // إشعار في نفس يوم انتهاء الاستبدال
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

  /// إلغاء كل إشعارات فاتورة معيّنة باستخدام billId
  Future<void> cancelBillReminders(String billId) async {
    await _ensureInitialized();
    for (final tag in const ['ret_minus1', 'ret_last', 'ex_minus2', 'ex_minus1', 'ex_last']) {
      await _plugin.cancel(_billReminderId(billId, tag));
    }
  }

  // ================== Warranties ==================

  /// إعادة جدولة إشعار "ضمان" معيّن:
  /// - حاليًا: إشعار واحد في يوم انتهاء الضمان الساعة 10 صباحًا
  Future<void> rescheduleWarrantyReminder({
    required String warrantyId,
    required String provider,
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();

    // إلغاء أي إشعار سابق لنفس الضمان
    await cancelWarrantyReminder(warrantyId);

    // ساعة إرسال الإشعار في يوم انتهاء الضمان
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

  /// إلغاء إشعار الضمان الوحيد لهذا الضمان
  Future<void> cancelWarrantyReminder(String warrantyId) async {
    await _ensureInitialized();
    await _plugin.cancel(_warrantyId(warrantyId));
  }

  // ================== Utilities ==================

  /// إظهار إشعار فوري الآن (مفيد للاختبار السريع من داخل التطبيق)
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

  /// إلغاء كل الإشعارات المجدولة/المعروضة لهذا التطبيق
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// نافذة حوار (Dialog) تشخيصية:
  /// - تعرض حالة الإذن
  /// - قدرة exact alarms
  /// - عدد الإشعارات المعلّقة
  /// - أول 10 إشعارات معلّقة (IDs + عناوين + payload)
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

    // نطبع أول 10 إشعارات معلّقة بالتفاصيل
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
              // يفتح إعدادات exact alarms في النظام
              openExactAlarmsSettings();
            },
            child: const Text('Open exact-alarms settings'),
          ),
        ],
      ),
    );
  }
}
