import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notifications_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  static const route = '/notifications';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('No notifications')),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('Notifications')
        .where('user_id', isEqualTo: uid)
        .orderBy('fire_at', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final title = (d['title'] ?? 'Reminder').toString();
              final body = (d['body'] ?? '').toString();
              final ts = d['fire_at'];
              final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
              final when = DateFormat('y-MM-dd HH:mm').format(dt);
              final status = (d['status'] ?? '').toString();

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await doc.reference.delete();
                },
                child: Material(
                  elevation: 1,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (body.isNotEmpty) Text(body),
                        const SizedBox(height: 6),
                        Text(
                          '$when  •  $status',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await _createManual(context);
          if (created && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder scheduled')),
            );
          }
        },
        label: const Text('New'),
        icon: const Icon(Icons.add_alert),
      ),
    );
  }

  Future<bool> _createManual(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (date == null) return false;
    if (!context.mounted) return false;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: (now.minute + 2) % 60),
    );
    if (time == null) return false;
    if (!context.mounted) return false;

    final fireAt =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // تهيئة الإشعارات وطلب الأذونات
    await NotificationsService.I.init();
    await NotificationsService.I.requestPermissions();

    // جدولة محليًا — (بدون exact param)
    final localId = await NotificationsService.I.scheduleAt(
      whenLocal: fireAt,
      title: 'Reminder',
      body: 'This is your reminder.',
      payload: 'manual',
      exact: true, // ← يحتاج الصلاحية أعلاه
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;

    // خزّن في Firestore
    await FirebaseFirestore.instance.collection('Notifications').add({
      'user_id': uid,
      'title': 'Reminder',
      'body': 'This is your reminder.',
      'type': 'manual',
      'status': 'scheduled',
      'local_id': localId,
      'created_at': DateTime.now(),
      'fire_at': fireAt,
    });

    return true;
  }
}
