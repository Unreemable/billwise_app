import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  static const route = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtChip = DateFormat('MMM d, HH:mm');

  bool _loading = true;

  // القوائم الثلاث
  List<_NotifFeedItem> _today = [];
  List<_NotifFeedItem> _upcoming = [];
  List<_NotifFeedItem> _missed = [];

  // عناصر تم حذفها (للجلسة الحالية فقط مع خيار Undo)
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      final now = DateTime.now();
      final startWindow = now.subtract(const Duration(days: 7));
      final endWindow = now.add(const Duration(days: 14));

      final billsSnap = await FirebaseFirestore.instance
          .collection('Bills')
          .where('user_id', isEqualTo: uid)
          .get();

      final items = <_NotifFeedItem>[];

      // كل التذكيرات تُعرض وكأنها على 00:00 من يومها
      DateTime atMidnight(DateTime x) => DateTime(x.year, x.month, x.day, 0, 0);

      for (final doc in billsSnap.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString();

        DateTime? rd = (data['return_deadline'] is Timestamp)
            ? (data['return_deadline'] as Timestamp).toDate()
            : null;
        DateTime? ed = (data['exchange_deadline'] is Timestamp)
            ? (data['exchange_deadline'] as Timestamp).toDate()
            : null;

        if (rd != null) {
          final rd0 = atMidnight(rd);
          final rdM1 = rd0.subtract(const Duration(days: 1));
          if (rdM1.isAfter(startWindow) && rdM1.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: rdM1,
              title: 'Return • Reminder — $title',
              body: 'Deadline: ${_fmtDate.format(rd0)}',
              kind: _NotifKind.returnReminder,
            ));
          }
          if (rd0.isAfter(startWindow) && rd0.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: rd0,
              title: 'Return • Deadline — $title',
              body: 'Deadline: ${_fmtDate.format(rd0)}',
              kind: _NotifKind.returnDeadline,
            ));
          }
        }

        if (ed != null) {
          final ed0 = atMidnight(ed);
          final edM2 = ed0.subtract(const Duration(days: 2));
          final edM1 = ed0.subtract(const Duration(days: 1));

          if (edM2.isAfter(startWindow) && edM2.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: edM2,
              title: 'Exchange • Reminder — $title',
              body: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeReminder,
            ));
          }
          if (edM1.isAfter(startWindow) && edM1.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: edM1,
              title: 'Exchange • Reminder — $title',
              body: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeReminder,
            ));
          }
          if (ed0.isAfter(startWindow) && ed0.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: ed0,
              title: 'Exchange • Deadline — $title',
              body: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeDeadline,
            ));
          }
        }
      }

      // تقسيم حسب اليوم
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday = startToday.add(const Duration(days: 1));

      final today = <_NotifFeedItem>[];
      final upcoming = <_NotifFeedItem>[];
      final missed = <_NotifFeedItem>[];

      for (final it in items) {
        if (it.when.isBefore(startToday)) {
          missed.add(it);
        } else if (it.when.isBefore(endToday)) {
          today.add(it);
        } else {
          upcoming.add(it);
        }
      }

      // ترتيب العناصر داخل كل قسم
      today.sort((a, b) => a.when.compareTo(b.when));      // تصاعدي (اليوم)
      upcoming.sort((a, b) => a.when.compareTo(b.when));   // تصاعدي (القادم)
      missed.sort((a, b) => b.when.compareTo(a.when));     // تنازلي (الأحدث أولاً)

      if (!mounted) return;
      setState(() {
        _today = today;
        _upcoming = upcoming;
        _missed = missed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notifications: $e')),
      );
    }
  }

  // زر البرق: إشعار فوري بسيط (بدون حوارات/جدولة)
  Future<void> _sendNow() async {
    await NotificationsService.I.requestPermissions();
    await NotificationsService.I.showNow(
      title: 'BillWise',
      body: 'إشعار تجريبي ⚡',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent a test notification')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _section('Due today', _today, deletable: false),
            _section('Upcoming', _upcoming, deletable: false),
            _section('Already ended', _missed, deletable: true),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendNow,
        tooltip: 'Send test notification',
        child: const Icon(Icons.bolt),
      ),
    );
  }

  Widget _section(String title, List<_NotifFeedItem> list, {required bool deletable}) {
    final visible = list.where((e) => !_dismissed.contains(e.key)).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('No items'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, bottom: 6),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...visible.map((e) {
          final tile = Card(
            child: ListTile(
              leading: Icon(e.icon),
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.body),
              trailing: Text(_fmtChip.format(e.when)),
            ),
          );

          if (!deletable) return tile;

          return Dismissible(
            key: ValueKey(e.key),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) {
              setState(() => _dismissed.add(e.key));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Notification removed'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      setState(() => _dismissed.remove(e.key));
                    },
                  ),
                ),
              );
            },
            child: tile,
          );
        }),
      ],
    );
  }
}

enum _NotifKind { returnReminder, returnDeadline, exchangeReminder, exchangeDeadline }

class _NotifFeedItem {
  _NotifFeedItem({
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
  });

  final DateTime when;
  final String title; // مثال: "Return • Reminder — iPhone"
  final String body;  // مثال: "Deadline: 2025-10-14"
  final _NotifKind kind;

  // مفتاح فريد (للإخفاء/الحذف في الجلسة)
  String get key => '${kind.name}|$title|${when.millisecondsSinceEpoch}';

  IconData get icon {
    switch (kind) {
      case _NotifKind.returnReminder:
        return Icons.keyboard_return;
      case _NotifKind.returnDeadline:
        return Icons.assignment_turned_in;
      case _NotifKind.exchangeReminder:
        return Icons.swap_horiz;
      case _NotifKind.exchangeDeadline:
        return Icons.change_circle_outlined;
    }
  }
}
