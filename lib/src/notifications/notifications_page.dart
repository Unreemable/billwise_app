import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
        .orderBy('created_at', descending: true);

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
              final d = docs[i].data() as Map<String, dynamic>;
              final title = (d['title'] ?? '').toString();
              final body  = (d['body'] ?? '').toString();
              final ts    = d['created_at'];
              final dt    = ts is Timestamp ? ts.toDate() : DateTime.now();
              final when  = DateFormat('y-MM-dd HH:mm').format(dt);

              return Material(
                elevation: 1,
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(title.isEmpty ? 'Notification' : title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (body.isNotEmpty) Text(body),
                      const SizedBox(height: 6),
                      Text(when, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
