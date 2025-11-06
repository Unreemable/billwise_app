// ================== Home Screen (Tight Header + Row Tiles + Wide QuickAdd + Live Results) ==================
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../bills/ui/bill_list_page.dart';
import '../common/models.dart';

import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import '../warranties/ui/warranty_list_page.dart';

import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';

import '../common/widgets/expiry_progress.dart';

import 'dart:math' as math;


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
const double _kHeaderHeight = 240;
const double _kTilesGap     = 12;
const double _kColGap       = 12;
const double _kTilesYOffset = -6;

// تحكم سريع بالمقاسات:
const double kRowTileAspect   = 0.66; // ارتفاع مربعات Bill/Warranty = itemW * هذا الرقم
const double kQuickTileAspect = 0.68; // ارتفاع Quick Add            = itemW * هذا الرقم

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  int _selectedTab = 0; // 0 = Warranties, 1 = Bills

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _greetName(User? u) {
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'there';
  }

  bool get _showResults => _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // === حسابات المقاسات مرة واحدة عشان ما يصير اختلاف ===
    final screenW   = MediaQuery.of(context).size.width;
    final usableW   = screenW - 32; // padding 16 يمين + 16 يسار
    final itemW     = (usableW - _kColGap) / 2;
    final itemH     = itemW * kRowTileAspect;
    final quickH    = itemW * kQuickTileAspect;
    final tilesTop  = _kHeaderHeight - 70 + _kTilesYOffset;
    final tilesH    = itemH + _kTilesGap + quickH;
    final contentTop= tilesTop + tilesH + 12;

    return WillPopScope(
      onWillPop: () async {
        if (_showResults) {
          _searchCtrl.clear();
          _searchFocus.unfocus();
          setState(() {});
          return false;
        }
        return true;
      },
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Scaffold(
          backgroundColor: _kBgDark,
          resizeToAvoidBottomInset: true,

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
                  searchFocus: _searchFocus,
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

              // 2) البلاطات (Bill/Warranty) فوق + Quick Add تحتهم
              Positioned(
                top: tilesTop,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: tilesH,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: itemW, height: itemH,
                            child: _ActionMiniTile(
                              title: 'Bill',
                              subtitle: 'Add Bill',
                              icon: Icons.receipt_long_rounded,
                              gradient: const [_kGrad3, _kGrad1],
                              onTap: () => Navigator.of(context, rootNavigator: true)
                                  .push(MaterialPageRoute(builder: (_) => const AddBillPage())),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          SizedBox(
                            width: itemW, height: itemH,
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
                      const SizedBox(height: _kTilesGap),
                      SizedBox(
                        width: usableW,
                        height: quickH,
                        child: _ActionRectWide(
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
                ),
              ),

              // 3) المحتوى — يبدأ دائماً بعد البلاطات المحسوبة (لا تداخل)
              Positioned.fill(
                top: contentTop,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExpiringMixed3(
                          userId: FirebaseAuth.instance.currentUser?.uid,
                          query: _searchCtrl.text,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // 4) نتائج البحث — تبدأ من تحت الهيدر مباشرة لتغطي البلاطات
              if (_showResults)
                Positioned.fill(
                  top: _kHeaderHeight + 8,
                  child: _SearchResultsPanel(
                    query: _searchCtrl.text,
                    userId: FirebaseAuth.instance.currentUser?.uid,
                    onClose: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final FocusNode searchFocus;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  const _Header({
    required this.name,
    required this.searchCtrl,
    required this.searchFocus,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
              const SizedBox(height: 14),
              _SearchBar(
                controller: searchCtrl,
                focusNode: searchFocus,
                hint: 'Search bills or warranties...',
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
              ),
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
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SearchBar({
    required this.controller,
    this.focusNode,
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
          BoxShadow(color: _kGrad2.withOpacity(0.45), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTapOutside: (_) => focusNode?.unfocus(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.search,
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
                onChanged?.call('');
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

// مستطيل عريض لــ Quick Add
class _ActionRectWide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionRectWide({
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======= أفاتارات =======
const Map<String, List<dynamic>> _kAvatarPresets = {
  'fox_purple':     ['🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]],
  'panda_blue':     ['🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]],
  'cat_pink':       ['🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]],
  'deer_gold':      ['🦌', [Color(0xFFFBBF24), Color(0xFFFFF7ED)]],
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
    Timestamp? _ts(Map<String, dynamic> d, List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
      }
      return null;
    }

    String _str(Map<String, dynamic> d, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return fallback;
    }

    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.limit(300).snapshots();

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
              final provider = _str(d, ['provider','brand','vendor'], fallback: 'Warranty');
              final wTitle   = _str(d, ['title','product','item_name'], fallback: provider);

              final startTs  = _ts(d, ['start_date','warranty_start','start']);
              final endTs    = _ts(d, ['end_date','warranty_end_date','expiry','expires_at']);

              final end = endTs?.toDate().toLocal();
              if (end == null) continue;

              final start = (startTs?.toDate().toLocal()) ?? end.subtract(const Duration(days: 365));

              items.add({
                'type': 'warranty','id': doc.id,
                'title': provider,'subtitle': wTitle,
                'start': start,'end': end,'expiry': _only(end),
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

            final upcoming = items.where((e) => !(e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));
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
                  final type    = e['type'] as String;
                  final expiry  = e['expiry'] as DateTime;
                  final subtype = (e['subtype'] as String?);

                  IconData leadingIcon;
                  String kindLabel = '';
                  if (type == 'bill') {
                    if (subtype == 'return') { leadingIcon = Icons.keyboard_return; kindLabel = 'Return'; }
                    else if (subtype == 'exchange') { leadingIcon = Icons.swap_horiz; kindLabel = 'Exchange'; }
                    else { leadingIcon = Icons.receipt_long; }
                  } else {
                    leadingIcon = Icons.verified_user; kindLabel = 'Warranty';
                  }

                  final startForBar = (e['start'] as DateTime?) ??
                      (e['purchase'] as DateTime?) ??
                      DateTime.now();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: _kCardDark, borderRadius: BorderRadius.circular(12)),
                    child: MediaQuery( // حد أقصى للتكبير داخل البلاطة كاملة
                      data: MediaQuery.of(context).copyWith(
                        textScaleFactor: MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.25),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isThreeLine: true,
                        minVerticalPadding: 6,
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
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(kindLabel, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          (e['subtitle'] as String?)?.isEmpty == true ? '—' : (e['subtitle'] as String? ?? '—'),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70),
                        ),
                        // ===== يمين: التاريخ + شريط التقدّم (مرن بدون Overflow) =====
                        trailing: ConstrainedBox(
                          constraints: BoxConstraints(
                            // مهم: صفر عشان ما يصير min > max على الشاشات الصغيرة
                            minWidth: 0,
                            // ناخذ أكبر قيمة بين 120 و النسبة من عرض الشاشة
                            maxWidth: math.max(
                              120.0,
                              (MediaQuery.of(context).size.width - 32) * 0.36, // 32 = padding أفقي
                            ),
                          ),
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaleFactor: MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _fmt(expiry),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                ExpiryProgress(
                                  startDate: startForBar,
                                  endDate:   expiry,
                                  title:     '',
                                  dense:     true,
                                  showInMonths: (type == 'warranty'),
                                ),
                              ],
                            ),
                          ),
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

// =================== لوحة نتائج البحث الفورية ===================
class _SearchResultsPanel extends StatelessWidget {
  final String query;
  final String? userId;
  final VoidCallback onClose;

  const _SearchResultsPanel({
    required this.query,
    required this.userId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // ارتفاع الكيبورد
    return Material(
      color: _kBgDark.withOpacity(0.94),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Results', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  )
                ],
              ),
              const SizedBox(height: 4),
              Expanded(child: _LiveSearchList(query: query, userId: userId)),
              SizedBox(height: bottomInset), // يحترم الكيبورد
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSearchList extends StatelessWidget {
  final String query;
  final String? userId;
  const _LiveSearchList({required this.query, required this.userId});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final uid = userId;

    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: billsStream,
      builder: (context, bSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: warrStream,
          builder: (context, wSnap) {
            if (!bSnap.hasData || !wSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<_SearchItem> out = [];

            for (final d in bSnap.data!.docs) {
              final m = d.data();
              final title = (m['title'] ?? '').toString();
              final shop  = (m['shop_name'] ?? '').toString();
              if (q.isEmpty || title.toLowerCase().contains(q) || shop.toLowerCase().contains(q)) {
                out.add(_SearchItem.bill(
                  id: d.id,
                  title: title.isEmpty ? 'Bill' : title,
                  subtitle: shop.isEmpty ? '—' : shop,
                  purchase: (m['purchase_date'] as Timestamp?)?.toDate(),
                  amount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
                ));
              }
            }

            for (final d in wSnap.data!.docs) {
              final m = d.data();
              final provider = (m['provider'] ?? m['brand'] ?? '').toString();
              final prod     = (m['title'] ?? m['product'] ?? '').toString();
              final title    = provider.isEmpty ? 'Warranty' : provider;
              final subtitle = prod.isEmpty ? '—' : prod;
              if (q.isEmpty || title.toLowerCase().contains(q) || subtitle.toLowerCase().contains(q)) {
                out.add(_SearchItem.warranty(
                  id: d.id,
                  title: title,
                  subtitle: subtitle,
                  start: (m['start_date'] as Timestamp?)?.toDate(),
                  end:   (m['end_date']   as Timestamp?)?.toDate(),
                ));
              }
            }

            if (out.isEmpty) {
              return const Center(
                child: Text('No results', style: TextStyle(color: Colors.white70)),
              );
            }

            out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

            return ListView.separated(
              itemCount: out.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = out[i];
                return Container(
                  decoration: BoxDecoration(color: _kCardDark, borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      it.isBill ? Icons.receipt_long_rounded : Icons.verified_user_rounded,
                      color: Colors.white70,
                    ),
                    title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      if (it.isBill) {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => BillDetailPage(details: BillDetails(
                            id: it.id,
                            title: it.title,
                            product: it.subtitle,
                            amount: it.amount ?? 0.0,
                            purchaseDate: it.purchase ?? DateTime.now(),
                            returnDeadline: null,
                            warrantyExpiry: null,
                          ))),
                        );
                      } else {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: WarrantyDetails(
                            id: it.id,
                            product: it.title,
                            title: it.subtitle,
                            warrantyStart: it.start ?? DateTime.now(),
                            warrantyExpiry: it.end ?? DateTime.now(),
                            returnDeadline: null,
                          ))),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SearchItem {
  final bool isBill;
  final String id;
  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? purchase;
  final DateTime? start;
  final DateTime? end;

  _SearchItem.bill({
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    this.purchase,
  })  : isBill = true, start = null, end = null;

  _SearchItem.warranty({
    required this.id,
    required this.title,
    required this.subtitle,
    this.start,
    this.end,
  })  : isBill = false, amount = null, purchase = null;
}

// =================== Bottom Gradient Bar ===================
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
      width: 54, height: 54,
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
