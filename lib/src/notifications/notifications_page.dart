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

  List<_NotifFeedItem> _today = [];
  List<_NotifFeedItem> _upcoming = [];
  List<_NotifFeedItem> _missed = [];

  // مفاتيح الإشعارات المحذوفة نهائياً
  final Set<String> _dismissed = {};

  // ألوان وهوية الصفحة
  static const _kPrimary = Color(0xFF5B6BFF);
  static const _kHeaderGrad = LinearGradient(
    colors: [Color(0xFF1B0B66), Color(0xFF0B0425)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ===== Helpers =====
  DateTime _atMidnight(DateTime x) => DateTime(x.year, x.month, x.day, 0, 0);
  bool _inInclusive(DateTime t, DateTime start, DateTime end) =>
      (t.isAfter(start) || t.isAtSameMomentAs(start)) &&
          (t.isBefore(end)   || t.isAtSameMomentAs(end));

  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime)  return v;
    if (v is int) {
      try { return DateTime.fromMillisecondsSinceEpoch(v); } catch (_) {}
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try { return DateTime.parse(s); } catch (_) {}
      try {
        final p = DateFormat('yyyy-MM-dd').parseStrict(s);
        return DateTime(p.year, p.month, p.day);
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      // حمل المحذوف نهائياً
      await _loadDismissedFromCloud(uid);

      final now = DateTime.now();
      // نافذة واسعة: -90 يوم إلى +365 يوم
      final startWindow = now.subtract(const Duration(days: 90));
      final endWindow   = now.add(const Duration(days: 365));

      final items = <_NotifFeedItem>[];

      // ===== Bills (deadlines فقط) =====
      final billsSnap = await FirebaseFirestore.instance
          .collection('Bills')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final title = (d['title'] ?? 'Bill').toString().trim().isEmpty
            ? 'Bill' : (d['title'] as String).trim();
        final shop  = (d['shop_name'] ?? '').toString().trim();
        final label = shop.isEmpty ? title : title;

        // return_deadline
        final ret = _parseAnyDate(d['return_deadline']);
        if (ret != null) {
          final r0 = _atMidnight(ret);
          if (_inInclusive(r0, startWindow, endWindow)) {
            items.add(_NotifFeedItem(
              when: r0,
              title: label,
              deadlineText: 'Return deadline: ${_fmtDate.format(r0)}',
              kind: _NotifKind.returnDeadline,
            ));
          }
        }

        // exchange_deadline
        final ex = _parseAnyDate(d['exchange_deadline']);
        if (ex != null) {
          final e0 = _atMidnight(ex);
          if (_inInclusive(e0, startWindow, endWindow)) {
            items.add(_NotifFeedItem(
              when: e0,
              title: label,
              deadlineText: 'Exchange deadline: ${_fmtDate.format(e0)}',
              kind: _NotifKind.exchangeDeadline,
            ));
          }
        }
      }

      // ===== Warranties (end_date فقط) =====
      final warrSnap = await FirebaseFirestore.instance
          .collection('Warranties')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in warrSnap.docs) {
        final d = doc.data();
        final provider = ((d['provider'] ?? d['brand'] ?? d['vendor'] ?? '') as String).trim();
        final warrTitle = provider.isEmpty ? 'Warranty' : provider;

        final end = _parseAnyDate(
            d['end_date'] ?? d['warranty_end_date'] ?? d['expiry'] ?? d['expires_at']
        );
        if (end != null) {
          final w0 = _atMidnight(end);
          if (_inInclusive(w0, startWindow, endWindow)) {
            items.add(_NotifFeedItem(
              when: w0,
              title: warrTitle,
              deadlineText: 'Warranty ends: ${_fmtDate.format(w0)}',
              kind: _NotifKind.warrantyDeadline,
            ));
          }
        }
      }

      // تقسيم حسب اليوم
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday   = startToday.add(const Duration(days: 1));

      final today = <_NotifFeedItem>[];
      final upcoming = <_NotifFeedItem>[];
      final missed = <_NotifFeedItem>[];

      for (final it in items) {
        if (_dismissed.contains(it.key)) continue;
        if (it.when.isBefore(startToday)) {
          missed.add(it);
        } else if (it.when.isBefore(endToday)) {
          today.add(it);
        } else {
          upcoming.add(it);
        }
      }

      today.sort((a, b) => a.when.compareTo(b.when));
      upcoming.sort((a, b) => a.when.compareTo(b.when));
      missed.sort((a, b) => b.when.compareTo(a.when));

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

  Future<void> _loadDismissedFromCloud(String uid) async {
    _dismissed.clear();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dismissedNotifs')
        .get();
    for (final d in snap.docs) {
      _dismissed.add(d.id);
    }
  }

  Future<void> _persistDismissed(String key, _NotifFeedItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dismissedNotifs')
        .doc(key)
        .set({
      'key': key,
      'kind': item.kind.name,
      'title': item.title,
      'when': Timestamp.fromDate(item.when),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeDismissed(String key) async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dismissedNotifs')
        .doc(key)
        .delete();
  }

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            _section('Due today', _today, isToday: true, deletable: true),
            _section('Upcoming', _upcoming, deletable: true),
            _section('Already ended', _missed, deletable: true, dim: true),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendNow,
        tooltip: 'Send test notification',
        backgroundColor: _kPrimary,
        child: const Icon(Icons.bolt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: cs.surface,
    );
  }

  Widget _section(
      String title,
      List<_NotifFeedItem> list, {
        bool isToday = false,
        bool deletable = false,
        bool dim = false,
      }) {
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
          final s = _styleFor(e.kind);
          final tile = _NotifTile(
            isToday: isToday,
            dim: dim,
            baseColor: s.baseColor,
            todayBackground: isToday ? _kPrimary : null,
            icon: s.icon,
            kindLabel: s.kindLabel,
            title: e.title,
            deadlineText: e.deadlineText,
            whenText: _fmtChip.format(e.when),
          );

          if (!deletable) return tile;

          return Dismissible(
            key: ValueKey(e.key),
            direction: DismissDirection.horizontal,
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) async {
              setState(() => _dismissed.add(e.key));
              await _persistDismissed(e.key, e);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Notification removed'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await _removeDismissed(e.key);
                      if (!mounted) return;
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

  _KindStyle _styleFor(_NotifKind k) {
    switch (k) {
      case _NotifKind.returnDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.swap_horiz,
          kindLabel: 'Return • Deadline',
        );
      case _NotifKind.exchangeDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.change_circle_outlined,
          kindLabel: 'Exchange • Deadline',
        );
      case _NotifKind.warrantyDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.verified,
          kindLabel: 'Warranty • Deadline',
        );
      default:
        return _KindStyle(
          baseColor: Colors.blue.shade600,
          icon: Icons.notifications,
          kindLabel: 'Deadline',
        );
    }
  }
}

/* ========= Models ========= */

enum _NotifKind {
  returnReminder,
  returnDeadline,
  exchangeReminder,
  exchangeDeadline,
  warrantyReminder,
  warrantyDeadline,
}

class _NotifFeedItem {
  _NotifFeedItem({
    required this.when,
    required this.title,
    required this.deadlineText,
    required this.kind,
  });

  final DateTime when;
  final String title;
  final String deadlineText;
  final _NotifKind kind;

  String get key => '${kind.name}|$title|${when.millisecondsSinceEpoch}';
}

/* ========= UI ========= */

class _KindStyle {
  final Color baseColor;
  final IconData icon;
  final String kindLabel;
  _KindStyle({required this.baseColor, required this.icon, required this.kindLabel});
}

class _NotifTile extends StatelessWidget {
  final bool isToday;
  final bool dim;
  final Color baseColor;
  final Color? todayBackground;
  final IconData icon;
  final String kindLabel;
  final String title;
  final String deadlineText;
  final String whenText;

  const _NotifTile({
    super.key,
    required this.isToday,
    required this.dim,
    required this.baseColor,
    required this.todayBackground,
    required this.icon,
    required this.kindLabel,
    required this.title,
    required this.deadlineText,
    required this.whenText,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final faded = onSurface.withOpacity(0.60);
    final dimmed = dim ? onSurface.withOpacity(0.55) : onSurface;

    final bgColor = isToday
        ? (todayBackground ?? Colors.purple).withOpacity(0.10)
        : Theme.of(context).cardColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isToday
              ? (todayBackground ?? Colors.purple).withOpacity(0.25)
              : const Color(0x1F000000),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: baseColor, size: 20),
            ),
            const SizedBox(width: 12),
            // content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _badge(kindLabel, baseColor)),
                      const SizedBox(width: 8),
                      _timeChip(whenText, onSurface),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(fontWeight: FontWeight.w600, color: dimmed),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deadlineText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: faded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c, height: 1.0),
      ),
    );
  }

  Widget _timeChip(String text, Color onSurface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onSurface.withOpacity(0.26)),
      ),
      child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
