// ================== Home Screen (Content Only) ==================
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../common/models.dart';

import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';

// صفحة الإشعارات
import '../notifications/notifications_page.dart';

// صفحة البروفايل
import '../profile/profile_page.dart';

/// تدرّج الهيدر: #5F33E1 → #000000
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF5F33E1), Color(0xFF000000)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// === إعدادات الهيدر والتداخل مع الدوائر ===
const double _kHeaderHeight = 300;          // هيدر أطول
const double _kActionSize   = 100;          // حجم دائرة الإجراء
const double _kActionsOverlap = _kActionSize / 2; // نصف الدائرة يطلع تحت
const double _kActionsLabelsHeight = 44;    // تعويض لعناوين الأزرار تحت الدوائر

/// واجهة المحتوى فقط — تُستخدم داخل AppShell
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _greetName(User? u) {
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Stack(
        clipBehavior: Clip.none, // يسمح بتداخل الدوائر
        children: [
          // 1) الهيدر
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Header(
              name: _greetName(user),
              searchCtrl: _searchCtrl,
              onLogout: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  LoginScreen.route,
                      (_) => false,
                );
              },
              onNotifications: () => Navigator.of(context, rootNavigator: true)
                  .pushNamed(NotificationsPage.route),
              onProfile: () => Navigator.of(context, rootNavigator: true)
                  .pushNamed(ProfilePage.route),
            ),
          ),

          // 2) المحتوى — يتّرسَم قبل الأزرار عشان ما يغطيها
          Positioned.fill(
            top: _kHeaderHeight,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // تعويض الجزء المتداخل من الدوائر + عنوان الأزرار
                    const SizedBox(height: _kActionsOverlap + _kActionsLabelsHeight),

                    // باقي المحتوى
                    _ExpiringMixed3(userId: user?.uid, query: _searchCtrl.text),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // 3) صف الدوائر — آخر عنصر = فوق الكل = يضغط
          Positioned(
            top: _kHeaderHeight - _kActionsOverlap,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _RoundAction(
                  icon: Icons.center_focus_strong, // OCR
                  label: 'Quick Add\n(OCR)',
                ),
                _RoundAction(
                  icon: Icons.receipt_long, // Bill
                  label: 'Add Bill',
                ),
                _RoundAction(
                  icon: Icons.verified_user, // Warranty
                  label: 'Add Warranty',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// للتوافق مع Route قديمة إن وُجدت
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: HomeContent(),
    );
  }
}

// ================= Header (مستطيل + بحث داخله) =================

class _Header extends StatelessWidget {
  final String name;
  final TextEditingController searchCtrl;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _Header({
    required this.name,
    required this.searchCtrl,
    required this.onLogout,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderHeight,
      decoration: const BoxDecoration(
        gradient: kHeaderGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الصف العلوي: أفاتار + اسم + أيقونات
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _ProfileAvatar(name: name, onTap: onProfile),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello,',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: onNotifications,
                        icon: const Icon(Icons.notifications, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // خانة البحث داخل الهيدر (فوق الدوائر)
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by title / store / provider',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
                  ),
                ),
              ),

              // مسافة سفلية داخل الهيدر للتنفس
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ======= أفاتارات جاهزة (emoji + gradient) تُستخدم في الهيدر =======
const Map<String, List<dynamic>> _kAvatarPresets = {
  'fox_purple':     ['🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]],
  'panda_blue':     ['🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]],
  'cat_pink':       ['🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]],
  'dog_orange':     ['🐶', [Color(0xFFFB923C), Color(0xFFFFEDD5)]],
  'koala_green':    ['🐨', [Color(0xFF34D399), Color(0xFFD1FAE5)]],
  'penguin_sky':    ['🐧', [Color(0xFF60A5FA), Color(0xFFE0E7FF)]],
  'bear_violet':    ['🐻', [Color(0xFFA78BFA), Color(0xFFEDE9FE)]],
  'bunny_mint':     ['🐰', [Color(0xFF4ADE80), Color(0xFFD1FAE5)]],
  'tiger_sunset':   ['🐯', [Color(0xFFF59E0B), Color(0xFFFFF7ED)]],
  'owl_night':      ['🦉', [Color(0xFF64748B), Color(0xFFE2E8F0)]],
  'alien_candy':    ['👽', [Color(0xFF22D3EE), Color(0xFFCCFBF1)]],
  'robot_lavender': ['🤖', [Color(0xFF93C5FD), Color(0xFFE0E7FF)]],
};

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const _ProfileAvatar({required this.name, this.onTap});

  String _initialOf(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'U';
    return t.substring(0, 1).toUpperCase();
  }

  Widget _fallbackCircle(BuildContext context, String initials) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initialOf(name);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      final base = _fallbackCircle(context, initials);
      return onTap == null ? base : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: base);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        Widget child;
        if (!snap.hasData || !snap.data!.exists) {
          child = _fallbackCircle(context, initials);
        } else {
          final data = snap.data!.data();
          final avatarId = (data?['avatar_id'] ?? '') as String;
          if (avatarId.isEmpty || !_kAvatarPresets.containsKey(avatarId)) {
            child = _fallbackCircle(context, initials);
          } else {
            final item = _kAvatarPresets[avatarId]!;
            final emoji  = item[0] as String;
            final colors = (item[1] as List<Color>);
            child = Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            );
          }
        }

        return onTap == null
            ? child
            : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: child);
      },
    );
  }
}

// =================== Gradient Icon ===================

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;
  const GradientIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, size, size)),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

// =================== Round Actions ===================

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoundAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    Future<void> _go(Widget page) async {
      final s = ScaffoldMessenger.of(context);
      s.clearSnackBars();
      await Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute(builder: (_) => page));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (label.contains('OCR')) {
            _go(const ScanReceiptPage());
          } else if (label.contains('Bill')) {
            _go(const AddBillPage());
          } else {
            _go(const AddWarrantyPage(
              billId: null,
              defaultStartDate: null,
              defaultEndDate: null,
            ));
          }
        },
        borderRadius: BorderRadius.circular(56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دائرة الأيقونة
            Container(
              width: _kActionSize,
              height: _kActionSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black.withOpacity(0.06),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: GradientIcon(
                icon: icon,
                size: _kActionSize * 0.4, // ≈40 عند 100
                gradient: const LinearGradient(
                  colors: [Color(0xFF5F33E1), Color(0xFF000000)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // العنوان أسفل الأيقونة (حتى لسطرين)
            SizedBox(
              width: _kActionSize,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black87, height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Expiring Mixed (3 عناصر) ===================

class _ExpiringMixed3 extends StatelessWidget {
  final String? userId;
  final String query;
  const _ExpiringMixed3({required this.userId, required this.query});

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol = FirebaseFirestore.instance.collection('Warranties');

    final billsBase =
    uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase =
    uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots();
    final warrStream = warrBase
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots();

    Color sColor(DateTime todayOnly, DateTime e) {
      final diff = e.difference(todayOnly).inDays;
      if (diff < 0) return Colors.red;
      if (diff == 0 || diff <= 7) return Colors.orange;
      return Colors.green;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: billsStream,
      builder: (context, bSnap) {
        if (bSnap.hasError) return const SizedBox.shrink();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: warrStream,
          builder: (context, wSnap) {
            if (wSnap.hasError) return const SizedBox.shrink();
            if (!bSnap.hasData || !wSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final todayOnly = DateTime(now.year, now.month, now.day);

            final items = <Map<String, dynamic>>[];

            // Bills
            for (final doc in bSnap.data!.docs) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop = (d['shop_name'] ?? '').toString();

              final purchase =
              (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret =
              (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final ex =
              (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

              final amountN = (d['total_amount'] as num?);
              final amount = amountN?.toDouble() ?? 0.0;

              if (ret != null) {
                items.add({
                  'type': 'bill',
                  'subtype': 'return',
                  'id': doc.id,
                  'title': title,
                  'subtitle': shop,
                  'purchase': purchase,
                  'amount': amount,
                  'expiry': _only(ret),
                });
              }
              if (ex != null) {
                items.add({
                  'type': 'bill',
                  'subtype': 'exchange',
                  'id': doc.id,
                  'title': title,
                  'subtitle': shop,
                  'purchase': purchase,
                  'amount': amount,
                  'expiry': _only(ex),
                });
              }
            }

            // Warranties
            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider =
              (d['provider']?.toString().trim().isNotEmpty == true)
                  ? d['provider'].toString().trim()
                  : 'Warranty';
              final wTitle = (d['title']?.toString().trim().isNotEmpty == true)
                  ? d['title'].toString().trim()
                  : provider;

              final start =
              (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();
              if (end == null) continue;

              items.add({
                'type': 'warranty',
                'id': doc.id,
                'title': provider,
                'subtitle': wTitle,
                'start': start,
                'end': _only(end),
                'expiry': _only(end),
              });
            }

            final q = query.trim().toLowerCase();
            if (q.isNotEmpty) {
              items.retainWhere((e) {
                final t = (e['title'] as String).toLowerCase();
                final s = (e['subtitle'] as String).toLowerCase();
                return t.contains(q) || s.contains(q);
              });
            }

            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Expiring soon',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(q.isEmpty
                          ? 'No items with deadlines.'
                          : 'No results for "$q".'),
                    ),
                  ),
                ],
              );
            }

            final upcoming = items
              ..retainWhere((e) => !(e['expiry'] as DateTime).isBefore(todayOnly));
            upcoming.sort((a, b) =>
                (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));

            final past = items
                .where((e) => (e['expiry'] as DateTime).isBefore(todayOnly))
                .toList()
              ..sort((a, b) =>
                  (b['expiry'] as DateTime).compareTo(a['expiry'] as DateTime));

            final selected = <Map<String, dynamic>>[]..addAll(upcoming.take(3));
            if (selected.length < 3) {
              selected.addAll(past.take(3 - selected.length));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Expiring soon',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...selected.map((e) {
                  final type = e['type'] as String;
                  final expiry = e['expiry'] as DateTime;
                  final subtype = (e['subtype'] as String?);

                  final diff = expiry.difference(todayOnly).inDays;
                  final stx = diff == 0
                      ? 'Due today'
                      : (diff > 0
                      ? 'In $diff day${diff == 1 ? '' : 's'}'
                      : '${diff.abs()} day${diff.abs() == 1 ? '' : 's'} ago');
                  final scolor = sColor(todayOnly, expiry);

                  IconData leadingIcon;
                  String kindLabel = '';
                  if (type == 'bill') {
                    if (subtype == 'return') {
                      leadingIcon = Icons.keyboard_return;
                      kindLabel = 'Return';
                    } else if (subtype == 'exchange') {
                      leadingIcon = Icons.swap_horiz;
                      kindLabel = 'Exchange';
                    } else {
                      leadingIcon = Icons.receipt_long;
                    }
                  } else {
                    leadingIcon = Icons.verified_user;
                    kindLabel = 'Warranty';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(leadingIcon),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (kindLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(kindLabel,
                                  style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        (e['subtitle'] as String?)?.isEmpty == true
                            ? '—'
                            : (e['subtitle'] as String? ?? '—'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_fmt(expiry),
                              style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(
                            stx,
                            style: TextStyle(fontSize: 11, color: scolor),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (type == 'bill') {
                          final details = BillDetails(
                            id: e['id'] as String,
                            title: e['title'] as String,
                            product: (e['subtitle'] as String? ?? ''),
                            amount: (e['amount'] as double?) ?? 0.0,
                            purchaseDate:
                            (e['purchase'] as DateTime?) ?? DateTime.now(),
                            returnDeadline:
                            subtype == 'return' ? expiry : null,
                            warrantyExpiry: null,
                          );
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => BillDetailPage(details: details),
                            ),
                          );
                        } else {
                          final details = WarrantyDetails(
                            id: e['id'] as String,
                            product: e['title'] as String,
                            title: e['subtitle'] as String? ?? '',
                            warrantyStart:
                            (e['start'] as DateTime?) ?? DateTime.now(),
                            warrantyExpiry: expiry,
                            returnDeadline: null,
                          );
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WarrantyDetailPage(details: details),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
