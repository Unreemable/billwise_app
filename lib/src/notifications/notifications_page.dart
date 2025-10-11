import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// صفحة إشعارات مبنية من بيانات Firestore (بدون الاعتماد على سجل النظام)
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
  List<_NotifFeedItem> _missed = [];
  List<_NotifFeedItem> _today = [];
  List<_NotifFeedItem> _upcoming = [];

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

      DateTime at10(DateTime x) => DateTime(x.year, x.month, x.day, 10);

      for (final doc in billsSnap.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString();
        final shop = (data['shop_name'] ?? '').toString();

        DateTime? rd =
        (data['return_deadline'] is Timestamp) ? (data['return_deadline'] as Timestamp).toDate() : null;
        DateTime? ed =
        (data['exchange_deadline'] is Timestamp) ? (data['exchange_deadline'] as Timestamp).toDate() : null;

        if (rd != null) {
          final rd10 = at10(rd);
          final rdM1 = rd10.subtract(const Duration(days: 1));

          if (rdM1.isAfter(startWindow) && rdM1.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: rdM1,
              title: 'Return reminder',
              body: '“$title” from $shop — ends ${_fmtDate.format(rd10)}',
              kind: _NotifKind.returnReminder,
            ));
          }
          if (rd10.isAfter(startWindow) && rd10.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: rd10,
              title: 'Return deadline',
              body: '“$title” from $shop — ends today',
              kind: _NotifKind.returnDeadline,
            ));
          }
        }

        if (ed != null) {
          final ed10 = at10(ed);
          final edM2 = ed10.subtract(const Duration(days: 2));
          final edM1 = ed10.subtract(const Duration(days: 1));

          for (final t in [edM2, edM1]) {
            if (t.isAfter(startWindow) && t.isBefore(endWindow)) {
              items.add(_NotifFeedItem(
                when: t,
                title: 'Exchange reminder',
                body:
                '“$title” from $shop — ${t == edM2 ? '2' : '1'} days left (ends ${_fmtDate.format(ed10)})',
                kind: _NotifKind.exchangeReminder,
              ));
            }
          }
          if (ed10.isAfter(startWindow) && ed10.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: ed10,
              title: 'Exchange deadline',
              body: '“$title” from $shop — ends today',
              kind: _NotifKind.exchangeDeadline,
            ));
          }
        }
      }

      // تقسيم حسب اليوم
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday = startToday.add(const Duration(days: 1));

      final missed = <_NotifFeedItem>[];
      final today = <_NotifFeedItem>[];
      final upcoming = <_NotifFeedItem>[];

      for (final it in items) {
        if (it.when.isBefore(startToday)) {
          missed.add(it);
        } else if (it.when.isBefore(endToday)) {
          today.add(it);
        } else {
          upcoming.add(it);
        }
      }

      missed.sort((a, b) => a.when.compareTo(b.when));
      today.sort((a, b) => a.when.compareTo(b.when));
      upcoming.sort((a, b) => a.when.compareTo(b.when));

      if (!mounted) return;
      setState(() {
        _missed = missed;
        _today = today;
        _upcoming = upcoming;
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
            _section('Missed (last 7 days)', _missed),
            _section('Due today', _today),
            _section('Upcoming', _upcoming),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<_NotifFeedItem> list) {
    if (list.isEmpty) {
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
        ...list.map((e) => Card(
          child: ListTile(
            leading: Icon(e.icon),
            title: Text(e.title),
            subtitle: Text(e.body),
            trailing: Text(_fmtChip.format(e.when)),
          ),
        )),
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
  final String title;
  final String body;
  final _NotifKind kind;

  IconData get icon {
    switch (kind) {
      case _NotifKind.returnReminder:   return Icons.reply;
      case _NotifKind.returnDeadline:   return Icons.assignment_turned_in;
      case _NotifKind.exchangeReminder: return Icons.cached;
      case _NotifKind.exchangeDeadline: return Icons.swap_horiz;
    }
  }
}
