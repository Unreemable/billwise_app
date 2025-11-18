import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة الإشعارات المحلية (داخل الجهاز) مع:
/// - تهيئة الـ plugin مرّة واحدة
/// - ضبط المنطقة الزمنية على Asia/Riyadh
/// - إنشاء قناة إشعارات خاصة بالتطبيق
/// - جدولة تنبيهات الفواتير/الضمانات بدقّة
/// - توابع تشخيص (diagnostics) عشان تفهمين حالة الإشعارات على جهازك
class NotificationsService {
  NotificationsService._();
  static final NotificationsService I = NotificationsService._();

  // الكائن الأساسي من flutter_local_notifications
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _inited = false;       // هل سوّينا initialize للـ plugin؟
  bool _channelReady = false; // هل أنشأنا قناة الإشعارات على أندرويد؟
  bool _tzReady = false;      // هل جهّزنا مكتبة timezone واخترنا الرياض؟

  // ================== Init & Permissions ==================

  /// نداء عام من أي مكان في التطبيق:
  /// يتأكد إن كل شيء مهيأ (plugin + tz + القناة)
  Future<void> init() async => _ensureInitialized();

  /// تهيئة flutter_local_notifications وربطه بالكولباك عند الضغط على الإشعار
  Future<void> _ensureInitialized() async {
    if (_inited) return;

    // إعدادات init للأندرويد (الأيقونة الافتراضية @mipmap/ic_launcher)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        // هنا تقدري تقرئين resp.payload
        // وتسوين navigation معيّن حسب نوع الإشعار لو حبيتي (مستقبلاً).
      },
    );

    // تهيئة المناطق الزمنية وضبطها على Asia/Riyadh
    await _ensureTZ();
    _inited = true;
  }

  /// طلب إذن الإشعارات (مهم لأندرويد 13+)
  Future<void> requestPermissions([BuildContext? _]) async {
    await _ensureInitialized();
    if (!Platform.isAndroid) return;

    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // بعض الأجهزة تستخدم requestPermission وبعضها requestNotificationsPermission
    try {
      await (android as dynamic).requestPermission();
    } catch (_) {
      try {
        await (android as dynamic).requestNotificationsPermission();
      } catch (_) {/* نتجاهل أي خطأ */}
    }
  }

  /// هل الإشعارات مفعّلة من إعدادات النظام لهذا التطبيق؟
  Future<bool> areNotificationsEnabled() async {
    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // منصات ثانية: نفترض OK
    try {
      final enabled = await (android as dynamic).areNotificationsEnabled();
      return (enabled is bool) ? enabled : true;
    } catch (_) {
      return true;
    }
  }

  /// هل النظام يسمح لنا نستخدم exact alarms (دقّة عالية)؟
  Future<bool> canScheduleExactAlarms() async {
    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final ok = await (android as dynamic).canScheduleExactNotifications();
      if (ok is bool) return ok;
    } catch (_) {
      try {
        final ok2 = await (android as dynamic).areAlarmsAndRemindersEnabled();
        if (ok2 is bool) return ok2;
      } catch (_) {}
    }
    // لو ما قدر يشيّك، ما نمنع الجدولة
    return true;
  }

  /// يفتح شاشة إعدادات exact alarms في أندرويد (لو النظام حاظرها على التطبيق)
  Future<void> openExactAlarmsSettings() async {
    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await (android as dynamic).openAlarmsAndRemindersSettings();
    } catch (_) {/* نتجاهل */}
  }

  /// تهيئة مكتبة timezone واختيار Asia/Riyadh كمنطقة محليّة
  Future<void> _ensureTZ() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
    _tzReady = true;
  }

  /// إنشاء قناة الإشعارات على أندرويد (مطلوبة من Android 8+)
  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    if (!Platform.isAndroid) {
      _channelReady = true;
      return;
    }

    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const ch = AndroidNotificationChannel(
        'billwise_reminders', // لازم يطابق نفس الـ ID المستخدم في الـ details
        'BillWise Reminders',
        description:
        'Reminders for return/exchange deadlines and warranty expiry',
        importance: Importance.max,
      );
      await android.createNotificationChannel(ch);
      _channelReady = true;
    }
  }

  /// إعدادات الـ NotificationDetails الافتراضية (صوت، اهتزاز... إلخ)
  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'billwise_reminders',
      'BillWise Reminders',
      channelDescription:
      'Reminders for return/exchange deadlines and warranty expiry',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'BillWise',
    );
    return const NotificationDetails(android: android);
  }

  // ================== Helpers عامة ==================

  /// hash بسيط بس نعمله mask عشان نضمن إنه موجب وصغير
  int _safeHash(String s) => s.hashCode & 0x7fffffff;

  /// توليد ID لإشعارات الفاتورة بناءً على billId + tag (ret / ex ...)
  int _billReminderId(String billId, String tag) =>
      (_safeHash('$billId::$tag') % 500000) + 1000000;

  /// ID أساسي للضمان (نستخدمه لتذكير “ينتهي اليوم”)
  int _warrantyId(String warrantyId) =>
      (_safeHash(warrantyId) % 500000) + 2000000;

  /// ID لباقي إشعارات الضمان بحسب tag (early/mid/final/month_before ...)
  int _warrantyTagId(String warrantyId, String tag) =>
      (_safeHash('$warrantyId::$tag') % 500000) + 2500000;

  /// نحول أي DateTime إلى tz.TZDateTime على المنطقة المحلية (الرياض)
  tz.TZDateTime _toTZ(DateTime local) => tz.TZDateTime.from(local, tz.local);

  /// نضمن إن التاريخ يكون على 00:00 (بداية اليوم)
  DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// دالة داخلية لجدولة إشعار:
  /// - تحاول أولاً exactAllowWhileIdle
  /// - لو النظام رفض، ترجع لـ inexactAllowWhileIdle
  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
    bool exact = true,
  }) async {
    // نحول التاريخ إلى TZDateTime حسب tz.local (الرياض)
    final when = _toTZ(whenLocal);

    // أحياناً الآن + الموعد قريب جداً، فنزود 2 ثانية احتياط
    final now = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2));
    if (!when.isAfter(now)) {
      // لو الموعد في الماضي أو قريب مرّة، ما نرسل إشعار
      return;
    }

    await _ensureInitialized();
    await _ensureChannel();

    // المحاولة الأولى: exactAllowWhileIdle
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
        );
        return; // نجح، ما نكمل
      } catch (e) {
        final msg = e.toString();
        // لو الخطأ فيه كلمة exact أو EXAC نعتبره رفض صلاحية exact alarms
        if (!msg.contains('exact') && !msg.contains('EXACT')) {
          // لو نوع الخطأ شيء ثاني، برضو راح ننزل للـ inexact تحت
        }
      }
    }

    // المحاولة الثانية: inexactAllowWhileIdle (أقل دقة لكن يعمل غالباً)
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

    // ID يعتمد على تاريخ/وقت الجدولة + العنوان
    final id =
        _safeHash('${whenLocal.toIso8601String()}::$title') % 900000 + 3000000;

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

  // ================== Bills Logic ==================

  /// إعادة جدولة كل إشعارات "فاتورة" معيّنة:
  /// - يلغي القديم
  /// - يجهّز:
  ///   • تذكير واحد للاسترجاع قبل الـ deadline بيوم → الساعة 12:00 منتصف الليل (بداية اليوم)
  ///   • تذكير واحد للاستبدال قبل الـ deadline بيوم → الساعة 12:00 منتصف الليل
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

    // أول شيء: نكنسل أي إشعارات قديمة لنفس الفاتورة
    await cancelBillReminders(billId);

    const bool exact = true;

    // ===== تذكير الاسترجاع =====
    if (returnDeadline != null) {
      // ناخذ يوم الديدلاين على 00:00 وبعدين ننقص يوم واحد
      final deadlineDay = _atMidnight(returnDeadline);
      final notifyDay = deadlineDay.subtract(const Duration(days: 1));

      await _zonedSchedule(
        id: _billReminderId(billId, 'ret_minus1'),
        title: 'Return reminder',
        body:
        '“$title” from $shop — return period ends tomorrow.',
        whenLocal: notifyDay,
        payload: 'bill:$billId:return:minus1',
        exact: exact,
      );
    }

    // ===== تذكير الاستبدال =====
    if (exchangeDeadline != null) {
      // نفس المنطق: إشعار واحد قبل يوم، الساعة 00:00
      final deadlineDay = _atMidnight(exchangeDeadline);
      final notifyDay = deadlineDay.subtract(const Duration(days: 1));

      await _zonedSchedule(
        id: _billReminderId(billId, 'ex_minus1'),
        title: 'Exchange reminder',
        body:
        '“$title” from $shop — exchange period ends tomorrow.',
        whenLocal: notifyDay,
        payload: 'bill:$billId:exchange:minus1',
        exact: exact,
      );
    }
  }

  /// إلغاء كل إشعارات فاتورة معيّنة باستخدام billId
  Future<void> cancelBillReminders(String billId) async {
    await _ensureInitialized();
    // حتى لو بعض الـ tags ما نستخدمها حالياً، ما يضر نكنسلها كلها
    for (final tag in const [
      'ret_minus1',
      'ret_last',
      'ex_minus2',
      'ex_minus1',
      'ex_last',
    ]) {
      await _plugin.cancel(_billReminderId(billId, tag));
    }
  }

  // ================== Warranties Logic ==================

  /// إعادة جدولة إشعارات "ضمان" معيّن.
  ///
  /// المنطق الجديد:
  /// - نقسم فترة الضمان إلى 3 أجزاء (ثلث أول / ثاني / أخير) ونرسل إشعار في بداية كل جزء.
  /// - نرسل إشعار ثابت قبل انتهاء الضمان بشهر (قدر الإمكان).
  /// - نرسل إشعار في يوم انتهاء الضمان نفسه.
  /// - كل المواعيد تكون على 12:00 منتصف الليل (بداية اليوم) حسب Asia/Riyadh.
  Future<void> rescheduleWarrantyReminder({
    required String warrantyId,
    required String provider,
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureInitialized();
    await _ensureChannel();

    // أولاً نكنسل أي إشعارات قديمة لهذا الضمان
    await cancelWarrantyReminder(warrantyId);

    // نتأكد إن التاريخين على بداية اليوم
    final startDay = _atMidnight(start);
    final endDay = _atMidnight(end);

    // لو التواريخ ملخبطة أو مافي مجال أيام، نكتفي بإشعار "ينتهي اليوم"
    final totalDays = endDay.difference(startDay).inDays;
    if (totalDays <= 0) {
      await _zonedSchedule(
        id: _warrantyId(warrantyId),
        title: 'Warranty ends today',
        body: 'Warranty by $provider ends today.',
        whenLocal: endDay,
        payload: 'warranty:$warrantyId:end',
        exact: true,
      );
      return;
    }

    // ===== 1) تقسيم الفترة إلى 3 أجزاء =====
    // مثال: 90 يوم → كل ثلث 30 يوم تقريباً.
    final firstThirdOffset = (totalDays / 3).floor();
    final secondThirdOffset = (2 * totalDays / 3).floor();

    final firstThirdDay = startDay; // بداية الضمان
    final secondThirdDay = startDay.add(Duration(days: firstThirdOffset));
    final finalThirdDay = startDay.add(Duration(days: secondThirdOffset));

    // نتأكد إن كل نقطة داخل [startDay, endDay]
    DateTime clamp(DateTime d) {
      if (d.isBefore(startDay)) return startDay;
      if (d.isAfter(endDay)) return endDay;
      return d;
    }

    final earlyDay = clamp(firstThirdDay);
    final midDay = clamp(secondThirdDay);
    final lastPeriodDay = clamp(finalThirdDay);

    // إشعار بداية الثلث الأول (غالباً = بداية الضمان)
    await _zonedSchedule(
      id: _warrantyTagId(warrantyId, 'early'),
      title: 'Warranty active',
      body: 'Warranty by $provider is now active.',
      whenLocal: earlyDay,
      payload: 'warranty:$warrantyId:early',
      exact: true,
    );

    // إشعار بداية الثلث الثاني
    if (midDay.isAfter(earlyDay)) {
      await _zonedSchedule(
        id: _warrantyTagId(warrantyId, 'mid'),
        title: 'Warranty mid-term',
        body: 'Warranty by $provider is in its middle period.',
        whenLocal: midDay,
        payload: 'warranty:$warrantyId:mid',
        exact: true,
      );
    }

    // إشعار بداية الثلث الأخير
    if (lastPeriodDay.isAfter(midDay)) {
      await _zonedSchedule(
        id: _warrantyTagId(warrantyId, 'final_third'),
        title: 'Warranty in final period',
        body: 'Warranty by $provider is now in its final period.',
        whenLocal: lastPeriodDay,
        payload: 'warranty:$warrantyId:final_third',
        exact: true,
      );
    }

    // ===== 2) إشعار ثابت قبل الانتهاء بشهر =====
    // نحسب end - 30 يوم، ونضمن إنه ما يطلع قبل startDay.
    var monthBefore = endDay.subtract(const Duration(days: 30));
    if (monthBefore.isBefore(startDay)) {
      monthBefore = startDay;
    }

    await _zonedSchedule(
      id: _warrantyTagId(warrantyId, 'month_before'),
      title: 'Warranty ends in 1 month',
      body: 'Warranty by $provider will end in about 1 month.',
      whenLocal: monthBefore,
      payload: 'warranty:$warrantyId:month_before',
      exact: true,
    );

    // ===== 3) إشعار يوم انتهاء الضمان =====
    await _zonedSchedule(
      id: _warrantyId(warrantyId),
      title: 'Warranty ends today',
      body: 'Warranty by $provider ends today.',
      whenLocal: endDay,
      payload: 'warranty:$warrantyId:end',
      exact: true,
    );
  }

  /// إلغاء *كل* إشعارات الضمان لهذا الـ warrantyId
  Future<void> cancelWarrantyReminder(String warrantyId) async {
    await _ensureInitialized();

    // نكنسل الـ ID الأساسي (يوم الانتهاء)
    await _plugin.cancel(_warrantyId(warrantyId));

    // نكنسل باقي الـ tags المحتملة
    for (final tag in const [
      'early',
      'mid',
      'final_third',
      'month_before',
    ]) {
      await _plugin.cancel(_warrantyTagId(warrantyId, tag));
    }
  }

  // ================== Utilities / Testing ==================

  /// إظهار إشعار فوري (مفيد للاختبار من داخل التطبيق)
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

  /// إلغاء كل الإشعارات (المجدولة + المعروضة) لهذا التطبيق
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// Dialog تشخيصي:
  /// - يطبع حالة الإذن
  /// - هل exact alarms متاحة
  /// - عدد الإشعارات المعلقة
  /// - أول 10 إشعارات معلقة بالتفصيل
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
