// lib/notifications/notifications_bootstrap.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel kRemindersChannel = AndroidNotificationChannel(
  'billwise_reminders',                 // يجب أن يطابق channel_id القادم من السيرفر
  'BillWise Reminders',                 // اسم القناة في إعدادات النظام
  description: 'Return / Exchange / Warranty reminders',
  importance: Importance.high,
);

Future<void> setupLocalNotifications() async {
  // تهيئة البلجن
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const init = InitializationSettings(android: androidInit);
  await flnp.initialize(init);

  // إنشاء القناة (Android 8+). النداء متكرر لا يضر.
  final android = flnp.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(kRemindersChannel);
}

// (اختياري) دالة اختبار للتأكد إن القناة تعمل
Future<void> testLocalOnChannel() async {
  await flnp.show(
    9999,
    'Test on billwise_reminders',
    'إذا ظهر هذا التنبيه فالقناة مضبوطة',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'billwise_reminders',            // نفس الـID
        'BillWise Reminders',
        channelDescription: 'Return / Exchange / Warranty reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
