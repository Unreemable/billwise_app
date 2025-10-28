// ================== Home Screen (Search + Column Tiles + Tall OCR + GradientBottomBar) ==================
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../bills/ui/bill_list_page.dart';           // ✅
import '../common/models.dart';

import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import '../warranties/ui/warranty_list_page.dart';  // ✅

import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';

// ===== ألوان عامة =====
const Color _kBgDark   = Color(0xFF0E0722);
const Color _kGrad1    = Color(0xFF6C3EFF);
const Color _kGrad2    = Color(0xFF934DFE);
const Color _kGrad3    = Color(0xFF3E8EFD);
const Color _kCardDark = Color(0x1AFFFFFF);
const Color _kTextDim  = Colors.white70;

// تدرّج الهيدر
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// === إعدادات ===
const double _kHeaderHeight = 360;

// أحجام البلاطات
const double _kMiniSide         = 128;
const double _kTilesGap         = 12;
const double _kColGap           = 12;
const double _kTilesYOffset     = -8;
const double _kTilesBlockHeight = _kMiniSide * 2 + _kTilesGap;

/// واجهة المحتوى
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _searchCtrl = TextEditingController();
  int _selectedTab = 0; // 0 = Warranties, 1 = Bills

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
      child: Scaffold(
        backgroundColor: _kBgDark,

        // === شريط سفلي متدرّج (بدون overflow) ===
        bottomNavigationBar: GradientBottomBar(
          selectedIndex: _selectedTab,
          onTap: (i) {
            setState(() => _selectedTab = i);
            if (i == 0) {
              Navigator.of(context, rootNavigator: true).pushNamed(WarrantyListPage.route);
            } else if (i == 1) {
              Navigator.of(context, rootNavigator: true).pushNamed(BillListPage.route);
            }
          },
          startColor: _kGrad1,
          endColor: _kGrad3,
        ),

        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1) الهيدر
            Positioned.fill(
              top: 0,
              bottom: null,
              child: _Header(
                name: _greetName(user),
                searchCtrl: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                onSearchSubmitted: (_) => setState(() {}),
                onLogout: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context, LoginScreen.route, (_) => false,
                  );
                },
                onNotifications: () => Navigator.of(context, rootNavigator: true)
                    .pushNamed(NotificationsPage.route),
                onProfile: () => Navigator.of(context, rootNavigator: true)
                    .pushNamed(ProfilePage.route),
              ),
            ),

            // 2) البلاطات: عمود يسار + مستطيل OCR يمين
            Positioned(
              top: _kHeaderHeight - (_kTilesBlockHeight / 2) + _kTilesYOffset,
              left: 16,
              right: 16,
              child: LayoutBuilder(
                builder: (context, c) {
                  final double leftColWidth = _kMiniSide;
                  final double rightWidth   = c.maxWidth - leftColWidth - _kColGap;

                  return SizedBox(
                    height: _kTilesBlockHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // يسار: بلاطتان
                        SizedBox(
                          width: leftColWidth,
                          child: Column(
                            children: [
                              SizedBox(
                                width: _kMiniSide, height: _kMiniSide,
                                child: _ActionMiniTile(
                                  title: 'Bill',
                                  subtitle: 'Add Bill',
                                  icon: Icons.receipt_long_rounded,
                                  gradient: const [_kGrad3, _kGrad1],
                                  onTap: () => Navigator.of(context, rootNavigator: true)
                                      .push(MaterialPageRoute(builder: (_) => const AddBillPage())),
                                ),
                              ),
                              const SizedBox(height: _kTilesGap),
                              SizedBox(
                                width: _kMiniSide, height: _kMiniSide,
                                child: _ActionMiniTile(
                                  title: 'Warranty',
                                  subtitle: 'Add Warranty',
                                  icon: Icons.verified_user_rounded,
                                  gradient: const [Color(0xFFFD6C8E), _kGrad2],
                                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(builder: (_) => const AddWarrantyPage(
                                      billId: null, defaultStartDate: null, defaultEndDate: null,
                                    )),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: _kColGap),

                        // يمين: بطاقة OCR طويلة
                        SizedBox(
                          width: rightWidth,
                          height: _kTilesBlockHeight,
                          child: _ActionRectTall(
                            title: 'Quick Add',
                            subtitle: 'OCR',
                            icon: Icons.document_scanner_outlined,
                            gradient: const [_kGrad1, _kGrad2],
                            onTap: () => Navigator.of(context, rootNavigator: true)
                                .push(MaterialPageRoute(builder: (_) => const ScanReceiptPage())),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3) المحتوى تحت
            Positioned.fill(
              top: _kHeaderHeight + (_kTilesBlockHeight / 2) + _kTilesYOffset + 12,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ExpiringMixed3(userId: user?.uid, query: _searchCtrl.text),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// للتوافق مع Route قديمة
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';
  @override
  Widget build(BuildContext context) => const HomeContent();
}

// ================= Header =================
class _Header extends StatelessWidget {
  final String name;
  final TextEditingController searchCtrl;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  const _Header({
    required this.name,
    required this.searchCtrl,
    required this.onLogout,
    required this.onNotifications,
    required this.onProfile,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderHeight,
      decoration: const BoxDecoration(gradient: kHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                              const Text('Hello,', style: TextStyle(color: _kTextDim, fontSize: 14)),
                              Text(
                                name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SearchBar(
                controller: searchCtrl,
                hint: 'Search bills or warranties...',
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============== Search Bar (TextField) ===============
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_kGrad1, _kGrad3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _kGrad2.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Search bills or warranties...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                if (onChanged != null) onChanged!('');
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// =============== بطاقات الإجراءات ===============
class _ActionMiniTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionMiniTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: gradient.last.withOpacity(.40), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRectTall extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionRectTall({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(.40),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, c) {
                final shortest = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
                final double iconBg  = (shortest * 0.32).clamp(64, 96);
                final double iconSz  = (iconBg * 0.60).clamp(36, 56);
                const double pad = 16;

                return Stack(
                  children: [
                    Positioned(
                      top: pad,
                      left: pad,
                      child: Container(
                        width: iconBg,
                        height: iconBg,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.20),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, size: iconSz, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      left: pad,
                      right: pad,
                      bottom: pad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Quick Add',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('OCR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ======= أفاتارات =======
// استبدلنا الكلب بغزالة 🦌 مع تدرّج صحراوي لطيف، مع الإبقاء على نفس المفتاح dog_orange
const Map<String, List<dynamic>> _kAvatarPresets = {
  'fox_purple':     ['🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]],
  'panda_blue':     ['🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]],
  'cat_pink':       ['🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]],
  'deer_gold':      ['🦌', [Color(0xFFFBBF24), Color(0xFFFFF7ED)]], // ← كان 🐶
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

  String _initialOf(String text) => (text.trim().isEmpty ? 'U' : text.trim()[0].toUpperCase());

  Widget _fallbackCircle(BuildContext context, String initials) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.08), offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text(initials, style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.black87, fontWeight: FontWeight.w700,
      )),
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
                gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            );
          }
        }
        return onTap == null ? child : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: child);
      },
    );
  }
}

// =================== Expiring Mixed ===================
class _ExpiringMixed3 extends StatelessWidget {
  final String? userId;
  final String query;
  const _ExpiringMixed3({required this.userId, required this.query});

  String _fmt(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.orderBy('created_at', descending: true).limit(200).snapshots();

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

            for (final doc in bSnap.data!.docs) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop  = (d['shop_name'] ?? '').toString();

              final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret      = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final ex       = (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

              final amountN = (d['total_amount'] as num?);
              final amount  = amountN?.toDouble() ?? 0.0;

              if (ret != null) {
                items.add({
                  'type': 'bill','subtype': 'return','id': doc.id,
                  'title': title,'subtitle': shop,'purchase': purchase,
                  'amount': amount,'expiry': _only(ret),
                });
              }
              if (ex != null) {
                items.add({
                  'type': 'bill','subtype': 'exchange','id': doc.id,
                  'title': title,'subtitle': shop,'purchase': purchase,
                  'amount': amount,'expiry': _only(ex),
                });
              }
            }

            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider = (d['provider']?.toString().trim().isNotEmpty == true)
                  ? d['provider'].toString().trim() : 'Warranty';
              final wTitle = (d['title']?.toString().trim().isNotEmpty == true)
                  ? d['title'].toString().trim() : provider;

              final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end   = (d['end_date'] as Timestamp?)?.toDate().toLocal();
              if (end == null) continue;

              items.add({
                'type': 'warranty','id': doc.id,
                'title': provider,'subtitle': wTitle,
                'start': start,'end': _only(end),'expiry': _only(end),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: _kCardDark, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16),
                    child: Text(q.isEmpty ? 'No items with deadlines.' : 'No results for "$q".',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              );
            }

            final upcoming = items..retainWhere((e) => !(e['expiry'] as DateTime).isBefore(todayOnly));
            upcoming.sort((a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));

            final past = items.where((e) => (e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (b['expiry'] as DateTime).compareTo(a['expiry'] as DateTime));

            final selected = <Map<String, dynamic>>[]..addAll(upcoming.take(3));
            if (selected.length < 3) selected.addAll(past.take(3 - selected.length));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Expiring soon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                ...selected.map((e) {
                  final type   = e['type'] as String;
                  final expiry = e['expiry'] as DateTime;
                  final subtype = (e['subtype'] as String?);

                  final diff = expiry.difference(todayOnly).inDays;
                  final stx = diff == 0
                      ? 'Due today'
                      : (diff > 0 ? 'In $diff day${diff == 1 ? '' : 's'}'
                      : '${diff.abs()} day${diff.abs() == 1 ? '' : 's'} ago');
                  final scolor = sColor(todayOnly, expiry);

                  IconData leadingIcon;
                  String kindLabel = '';
                  if (type == 'bill') {
                    if (subtype == 'return') { leadingIcon = Icons.keyboard_return; kindLabel = 'Exchange/Return'; }
                    else if (subtype == 'exchange') { leadingIcon = Icons.swap_horiz; kindLabel = 'Exchange'; }
                    else { leadingIcon = Icons.receipt_long; }
                  } else {
                    leadingIcon = Icons.verified_user; kindLabel = 'Warranty';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: _kCardDark, borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(leadingIcon, color: Colors.white70),
                      title: Row(
                        children: [
                          Expanded(child: Text(e['title'] as String,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white))),
                          if (kindLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(kindLabel, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        (e['subtitle'] as String?)?.isEmpty == true ? '—' : (e['subtitle'] as String? ?? '—'),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_fmt(expiry), style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 2),
                          Text(stx, style: TextStyle(fontSize: 11, color: scolor)),
                        ],
                      ),
                      onTap: () {
                        if (type == 'bill') {
                          final details = BillDetails(
                            id: e['id'] as String,
                            title: e['title'] as String,
                            product: (e['subtitle'] as String? ?? ''),
                            amount: (e['amount'] as double?) ?? 0.0,
                            purchaseDate: (e['purchase'] as DateTime?) ?? DateTime.now(),
                            returnDeadline: subtype == 'return' ? expiry : null,
                            warrantyExpiry: null,
                          );
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => BillDetailPage(details: details)),
                          );
                        } else {
                          final details = WarrantyDetails(
                            id: e['id'] as String,
                            product: e['title'] as String,
                            title: e['subtitle'] as String? ?? '',
                            warrantyStart: (e['start'] as DateTime?) ?? DateTime.now(),
                            warrantyExpiry: expiry,
                            returnDeadline: null,
                          );
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: details)),
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

// =================== Bottom Gradient Bar (مرن بلا Overflow) ===================
class GradientBottomBar extends StatelessWidget {
  final int selectedIndex;               // 0 = Warranties, 1 = Bills
  final ValueChanged<int> onTap;
  final Color startColor;
  final Color endColor;

  const GradientBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.startColor = const Color(0xFF6C3EFF),
    this.endColor   = const Color(0xFF3E8EFD),
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [startColor, endColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 76 + bottomInset),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomItem(
                        icon: Icons.verified_user_rounded,
                        label: 'Warranties',
                        selected: selectedIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const _FabDot(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Bills',
                        selected: selectedIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _BottomItem({required this.icon, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white70;
    final selectedBg = Colors.white.withOpacity(.14);

    // نحد من تكبير الخط داخل البار حتى ما يكسر السطر
    final tsf = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.2);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: tsf),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FabDot extends StatelessWidget {
  const _FabDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54, height: 54, // صغّرناها قليلاً كـ buffer
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C3EFF), Color(0xFF3E8EFD)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF934DFE).withOpacity(.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.home_filled, color: Colors.white),
    );
  }
}
