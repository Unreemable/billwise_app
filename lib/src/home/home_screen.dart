// ================== Home Screen (Wave header, search+actions = Add Bill / Add Warranty, MIXED expiring list w/ search, fixed FAB) ==================
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../bills/data/bill_service.dart';
import '../common/models.dart';

import '../warranties/ui/warranty_list_page.dart';
import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';

const LinearGradient _kAppGradient = LinearGradient(
  colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

const double _kHeaderHeight = 200;

class _NoShiftFabAnimator extends FloatingActionButtonAnimator {
  const _NoShiftFabAnimator();
  @override
  Offset getOffset({required Offset begin, required Offset end, required double progress}) => begin;
  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(1.0);
  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(0.0);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  int _selectedTab = 0; // 0=Home, 1=Warranties, 2=Bills

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

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

  void _addWarrantyDirect() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddWarrantyPage(
          billId: null,
          defaultStartDate: DateTime.now(),
          defaultEndDate: DateTime.now().add(const Duration(days: 365)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        floatingActionButtonAnimator: const _NoShiftFabAnimator(),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, toolbarHeight: 0),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _CenterHomeButton(
          selected: _selectedTab == 0,
          onTap: () => setState(() => _selectedTab = 0),
        ),

        bottomNavigationBar: _CurvedBottomBar(
          selectedTab: _selectedTab,
          onTapLeft: () async {
            setState(() => _selectedTab = 1);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyListPage()));
            if (!context.mounted) return;
            setState(() => _selectedTab = 0);
          },
          onTapRight: () async {
            setState(() => _selectedTab = 2);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const BillListPage()));
            if (!context.mounted) return;
            setState(() => _selectedTab = 0);
          },
        ),

        body: Stack(
          children: [
            _WaveHeader(
              name: _greetName(user),
              onLogout: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, LoginScreen.route, (_) => false);
              },
              onNotifications: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications coming soon')),
                );
              },
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, _kHeaderHeight - 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchAndActions(
                      searchCtrl: _searchCtrl,
                      onQuickOCR: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanReceiptPage())),
                      onAddBill:  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBillPage())),
                      onAddWarranty: _addWarrantyDirect,                           // tap = Add Warranty مباشرة
                      onWarrantyOptions: () => _openWarrantyOptions(context, user?.uid), // long-press = خيارات الربط
                    ),

                    const SizedBox(height: 16),

                    _ExpiringMixed3(userId: user?.uid, query: _searchCtrl.text),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWarrantyOptions(BuildContext context, String? uid) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Link to existing bill'),
              subtitle: const Text('Choose one of your bills'),
              onTap: () async {
                Navigator.pop(ctx);
                final String? billId = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _BillPickerSheet(userId: uid),
                );
                if (billId == null) return;
                if (!context.mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddWarrantyPage(
                      billId: billId,
                      defaultStartDate: DateTime.now(),
                      defaultEndDate: DateTime.now().add(const Duration(days: 365)),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Add warranty only'),
              subtitle: const Text('Save a warranty without linking a bill'),
              onTap: () {
                Navigator.pop(ctx);
                _addWarrantyDirect();
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ================= Wave Header =================

class _WaveHeader extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;

  const _WaveHeader({
    required this.name,
    required this.onLogout,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: _kHeaderHeight,
        decoration: BoxDecoration(gradient: _kAppGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _ProfileAvatar(name: name),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello,', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                        _BellButton(onTap: onNotifications),
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
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, size.height - 50);

    final firstControlPoint = Offset(size.width * 0.25, size.height - 15);
    final firstEndPoint     = Offset(size.width * 0.5,  size.height - 28);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    final secondControlPoint = Offset(size.width * 0.75, size.height - 42);
    final secondEndPoint     = Offset(size.width,       size.height - 18);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  const _ProfileAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    String initials = 'U';
    final parts = name.trim().split(' ');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      initials = parts.first.characters.first.toUpperCase();
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BellButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(tooltip: 'Notifications', onPressed: onTap, icon: const Icon(Icons.notifications, color: Colors.white)),
        Positioned(
          right: 8,
          top: 8,
          child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
        ),
      ],
    );
  }
}

// =================== Search + Round Actions ===================

class _SearchAndActions extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback onQuickOCR;
  final VoidCallback onAddBill;
  final VoidCallback onAddWarranty;      // tap = add directly
  final VoidCallback? onWarrantyOptions; // long-press = options (optional)

  const _SearchAndActions({
    required this.searchCtrl,
    required this.onQuickOCR,
    required this.onAddBill,
    required this.onAddWarranty,
    this.onWarrantyOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundAction(icon: Icons.center_focus_strong, label: 'Quick Add\n(OCR)', onTap: onQuickOCR),
            _RoundAction(icon: Icons.receipt_long, label: 'Add Bill', onTap: onAddBill),
            _RoundAction(
              icon: Icons.verified_user,
              label: 'Add Warranty',
              onTap: onAddWarranty,
              onLongPress: onWarrantyOptions,
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(56),
      child: Column(
        children: [
          Ink(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 34, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87)),
        ],
      ),
    );
  }
}

// ================= القائمة المشتركة (فواتير + ضمانات) — 3 فقط + بحث =================

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
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.orderBy('created_at', descending: true).limit(200).snapshots();

    String status(DateTime todayOnly, DateTime e) {
      final diff = e.difference(todayOnly).inDays;
      if (diff == 0) return 'Due today';
      if (diff > 0) return 'In $diff day${diff == 1 ? '' : 's'}';
      final a = diff.abs();
      return '$a day${a == 1 ? '' : 's'} ago';
    }

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
              final shop  = (d['shop_name'] ?? '').toString();

              final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret  = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

              DateTime? expiry;
              if (ret != null && wEnd != null) {
                expiry = ret.isBefore(wEnd) ? ret : wEnd;
              } else {
                expiry = ret ?? wEnd;
              }
              if (expiry == null) continue;

              final amountN = (d['total_amount'] as num?);
              final amount  = amountN?.toDouble() ?? 0.0;

              items.add({
                'type': 'bill',
                'id': doc.id,
                'title': title,
                'subtitle': shop,
                'purchase': purchase,
                'ret': ret,
                'wEnd': wEnd,
                'amount': amount,
                'expiry': _only(expiry),
              });
            }

            // Warranties
            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider = (d['provider']?.toString().trim().isNotEmpty == true)
                  ? d['provider'].toString().trim()
                  : 'Warranty';
              final wTitle = (d['title']?.toString().trim().isNotEmpty == true)
                  ? d['title'].toString().trim()
                  : provider;

              final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end   = (d['end_date']   as Timestamp?)?.toDate().toLocal();
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

            // البحث
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
                  Text('Expiring soon', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        q.isEmpty ? 'No items with deadlines.' : 'No results for "$q".',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              );
            }

            final upcoming = items.where((e) => !(e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));
            final past = items.where((e) => (e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (b['expiry'] as DateTime).compareTo(a['expiry'] as DateTime));

            final selected = <Map<String, dynamic>>[]
              ..addAll(upcoming.take(3));
            if (selected.length < 3) selected.addAll(past.take(3 - selected.length));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Expiring soon', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...selected.map((e) {
                  final type = e['type'] as String;
                  final expiry = e['expiry'] as DateTime;
                  final diff = expiry.difference(todayOnly).inDays;
                  String stx =
                  diff == 0 ? 'Due today' : (diff > 0 ? 'In $diff day${diff == 1 ? '' : 's'}' : '${diff.abs()} day${diff.abs() == 1 ? '' : 's'} ago');
                  final scolor = diff < 0 ? Colors.red : (diff == 0 || diff <= 7 ? Colors.orange : Colors.green);

                  final leadingIcon = type == 'bill' ? Icons.receipt_long : Icons.verified_user;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(leadingIcon),
                      title: Text(e['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text((e['subtitle'] as String).isEmpty ? '—' : (e['subtitle'] as String),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(stx, style: TextStyle(fontSize: 11, color: scolor)),
                        ],
                      ),
                      onTap: () {
                        if (type == 'bill') {
                          final details = BillDetails(
                            id: e['id'] as String,
                            title: e['title'] as String,
                            product: e['subtitle'] as String,
                            amount: (e['amount'] as double?) ?? 0.0,
                            purchaseDate: (e['purchase'] as DateTime?) ?? DateTime.now(),
                            returnDeadline: e['ret'] as DateTime?,
                            warrantyExpiry: e['wEnd'] as DateTime?,
                          );
                          Navigator.pushNamed(context, BillDetailPage.route, arguments: details);
                        } else {
                          final details = WarrantyDetails(
                            id: e['id'] as String,
                            product: e['title'] as String,
                            title: e['subtitle'] as String,
                            warrantyStart: (e['start'] as DateTime?) ?? DateTime.now(),
                            warrantyExpiry: expiry,
                            returnDeadline: null,
                          );
                          Navigator.push(
                            context,
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

// ================= Bottom curved bar + center Home button =================

class _CurvedBottomBar extends StatelessWidget {
  final int selectedTab; // 0 home, 1 warr, 2 bills
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  const _CurvedBottomBar({
    required this.selectedTab,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
        ),
        CircleBorder(),
      ),
      clipBehavior: Clip.antiAlias,
      notchMargin: 8,
      elevation: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: _kAppGradient),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _BottomItem(
                        icon: Icons.verified,
                        label: 'Warranties',
                        selected: selectedTab == 1,
                        onTap: onTapLeft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _BottomItem(
                        icon: Icons.receipt_long,
                        label: 'Bills',
                        selected: selectedTab == 2,
                        onTap: onTapRight,
                      ),
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

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: selected ? 26 : 24),
            const SizedBox(height: 2),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _CenterHomeButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CenterHomeButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _kAppGradient,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.home_filled, color: Colors.white, size: 28),
      ),
    );
  }
}

// ===== Bottom sheet: pick an existing bill to link warranty =====
class _BillPickerSheet extends StatefulWidget {
  final String? userId;
  const _BillPickerSheet({required this.userId});

  @override
  State<_BillPickerSheet> createState() => _BillPickerSheetState();
}

class _BillPickerSheetState extends State<_BillPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Search bills...', prefixIcon: Icon(Icons.search)),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Please sign in to pick a bill.'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BillService.instance.streamBillsSnapshot(userId: uid),
                builder: (context, s) {
                  if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                  if (!s.hasData) return const Center(child: CircularProgressIndicator());

                  var docs = s.data!.docs;
                  final q = _search.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final t = (d['title'] ?? '').toString().toLowerCase();
                      final shop = (d['shop_name'] ?? '').toString().toLowerCase();
                      return t.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) return const Center(child: Text('No bills found.'));

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final title = (d['title'] ?? '—').toString();
                      final shop = (d['shop_name'] ?? '—').toString();
                      final amount = d['total_amount'];
                      return ListTile(
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('$shop • ${amount ?? '-'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, doc.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
