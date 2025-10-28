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

  final Set<String> _dismissed = {};

  // ألوان وهوية الصفحة (مطابقة لبقية الصفحات)
  static const _kPrimary = Color(0xFF5B6BFF); // أزرار/هايلايت
  static const _kHeaderGrad = LinearGradient(
    colors: [Color(0xFF1B0B66), Color(0xFF0B0425)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

      final now = DateTime.now(); // ← تعريف واحد
      final startWindow = now.subtract(const Duration(days: 14));
      final endWindow = now.add(const Duration(days: 30));

      final items = <_NotifFeedItem>[];

      DateTime atMidnight(DateTime x) => DateTime(x.year, x.month, x.day, 0, 0);

      // ===== Bills =====
      final billsSnap = await FirebaseFirestore.instance
          .collection('Bills')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in billsSnap.docs) {
        final data = doc.data();
        final titleRaw = data['title'];
        final billTitle = (titleRaw == null || ('$titleRaw').trim().isEmpty)
            ? 'Untitled bill'
            : '$titleRaw';

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
              title: billTitle,
              deadlineText: 'Deadline: ${_fmtDate.format(rd0)}',
              kind: _NotifKind.returnReminder,
            ));
          }
          if (rd0.isAfter(startWindow) && rd0.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: rd0,
              title: billTitle,
              deadlineText: 'Deadline: ${_fmtDate.format(rd0)}',
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
              title: billTitle,
              deadlineText: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeReminder,
            ));
          }
          if (edM1.isAfter(startWindow) && edM1.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: edM1,
              title: billTitle,
              deadlineText: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeReminder,
            ));
          }
          if (ed0.isAfter(startWindow) && ed0.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: ed0,
              title: billTitle,
              deadlineText: 'Deadline: ${_fmtDate.format(ed0)}',
              kind: _NotifKind.exchangeDeadline,
            ));
          }
        }
      }

      // ===== Warranties =====
      final warrSnap = await FirebaseFirestore.instance
          .collection('Warranties')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in warrSnap.docs) {
        final data = doc.data();
        final providerRaw = data['provider'];
        final warrTitle = (providerRaw == null || ('$providerRaw').trim().isEmpty)
            ? 'Warranty'
            : '$providerRaw';

        DateTime? wd = (data['end_date'] is Timestamp)
            ? (data['end_date'] as Timestamp).toDate()
            : null;

        if (wd != null) {
          final w0 = atMidnight(wd);
          final wM7 = w0.subtract(const Duration(days: 7));
          final wM3 = w0.subtract(const Duration(days: 3));

          if (wM7.isAfter(startWindow) && wM7.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: wM7,
              title: warrTitle,
              deadlineText: 'Warranty ends: ${_fmtDate.format(w0)}',
              kind: _NotifKind.warrantyReminder,
            ));
          }
          if (wM3.isAfter(startWindow) && wM3.isBefore(endWindow)) {
            items.add(_NotifFeedItem(
              when: wM3,
              title: warrTitle,
              deadlineText: 'Warranty ends: ${_fmtDate.format(w0)}',
              kind: _NotifKind.warrantyReminder,
            ));
          }
          if (w0.isAfter(startWindow) && w0.isBefore(endWindow)) {
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
            _section('Due today', _today, isToday: true),
            _section('Upcoming', _upcoming),
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
      backgroundColor: cs.surface, // ينسّق مع الثيم الداكن
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
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...visible.map((e) {
          final s = _styleFor(e.kind);
          final tile = _NotifTile(
            isToday: isToday,
            dim: dim,
            baseColor: s.baseColor,
            todayBackground: isToday ? _kPrimary : null, // بطاقات اليوم موف
            icon: s.icon,
            kindLabel: s.kindLabel,
            title: e.title,
            deadlineText: e.deadlineText,
            whenText: _fmtChip.format(e.when),
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

  _KindStyle _styleFor(_NotifKind k) {
    switch (k) {
      case _NotifKind.returnReminder:
        return _KindStyle(
          baseColor: Colors.green.shade600,
          icon: Icons.swap_horiz,
          kindLabel: 'Return • Reminder',
        );
      case _NotifKind.exchangeReminder:
        return _KindStyle(
          baseColor: Colors.green.shade600,
          icon: Icons.change_circle_outlined,
          kindLabel: 'Exchange • Reminder',
        );
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
      case _NotifKind.warrantyReminder:
        return _KindStyle(
          baseColor: Colors.blue.shade600,
          icon: Icons.verified,
          kindLabel: 'Warranty • Reminder',
        );
      case _NotifKind.warrantyDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.verified,
          kindLabel: 'Warranty • Deadline',
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
  final Color baseColor;        // لون النوع
  final Color? todayBackground; // موف لبطاقات اليوم
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
    final faded = onSurface.withValues(alpha: 0.60);
    final dimmed = dim ? onSurface.withValues(alpha: 0.55) : onSurface;

    final bgColor = isToday
        ? (todayBackground ?? Colors.purple).withValues(alpha: 0.10)
        : Theme.of(context).cardColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isToday
              ? (todayBackground ?? Colors.purple).withValues(alpha: 0.25)
              : const Color(0x1F000000),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أيقونة
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: baseColor, size: 20),
            ),
            const SizedBox(width: 12),

            // محتوى
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // صف علوي: البادج يتمدد، والوقت يمين
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: dimmed,
                    ),
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
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _timeChip(String text, Color onSurface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onSurface.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
