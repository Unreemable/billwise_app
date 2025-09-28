import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../warranties/ui/warranty_list_page.dart';
import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/data/bill_service.dart';
import '../common/models.dart';

/// عنصر داخلي موحّد لقائمة "All"
class _HomeItem {
  final DateTime? expiry;
  final Widget tile;
  const _HomeItem({required this.expiry, required this.tile});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeFilter { all, bills, warranties }

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;
  final _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginScreen.route,
                        (_) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddChooser(context),
          child: const Icon(Icons.add),
        ),

        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Bills'),
            NavigationDestination(icon: Icon(Icons.verified), label: 'Warranties'),
          ],
          onDestinationSelected: (i) async {
            if (i == 1) {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const BillListPage()));
            } else if (i == 2) {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyListPage()));
            }
          },
        ),

        body: Stack(
          children: [
            const _HeaderGradient(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      userEmail: user?.email ?? 'Guest',
                      filter: _filter,
                      onChangeFilter: () => _showFilterSheet(context),
                      searchCtrl: _searchCtrl,
                    ),
                    const SizedBox(height: 16),

                    if (_filter == HomeFilter.all) ...[
                      Text('All (nearest expiry first)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _AllMixedList(userId: user?.uid, query: _searchCtrl.text),
                    ] else ...[
                      Text(
                        _filter == HomeFilter.bills ? 'Recent bills' : 'Recent warranties',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildRecentList(userId: user?.uid),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Streams (عامة) =====
  Stream<QuerySnapshot<Map<String, dynamic>>> _billsStream({String? userId}) {
    final col = FirebaseFirestore.instance.collection('Bills');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    return base.orderBy('created_at', descending: true).limit(25).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _warrantiesStream({String? userId}) {
    final col = FirebaseFirestore.instance.collection('Warranties');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    // مطابق للفهرس الحالي: user_id ASC + end_date DESC
    return base.orderBy('end_date', descending: true).limit(25).snapshots();
  }

  // ===== Recent list (قسم واحد حسب الفلتر) =====
  Widget _buildRecentList({String? userId}) {
    if (_filter == HomeFilter.bills) {
      return _RecentBillsList(userId: userId, query: _searchCtrl.text);
    } else {
      return _RecentWarrantiesList(userId: userId, query: _searchCtrl.text);
    }
  }

  // ===== Add chooser =====
  Future<void> _openAddChooser(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Bill Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.receipt_long,
                      title: 'Bill',
                      subtitle: 'Return & exchange',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddBillPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.verified_user,
                      title: 'Warranty',
                      subtitle: 'Any warranty',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openWarrantyOptions(context, uid);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanReceiptPage()),
                  );
                },
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Quick Add (OCR)'),
              ),
            ],
          ),
        );
      },
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
                if (!mounted) return;

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
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<HomeFilter>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          RadioListTile<HomeFilter>(
            value: HomeFilter.all,
            groupValue: _filter,
            title: const Text('All'),
            onChanged: (v) => Navigator.pop(context, v),
          ),
          RadioListTile<HomeFilter>(
            value: HomeFilter.warranties,
            groupValue: _filter,
            title: const Text('Warranties'),
            onChanged: (v) => Navigator.pop(context, v),
          ),
          RadioListTile<HomeFilter>(
            value: HomeFilter.bills,
            groupValue: _filter,
            title: const Text('Bills'),
            onChanged: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }
}

// ===== UI helpers =====

class _HeaderGradient extends StatelessWidget {
  const _HeaderGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String userEmail;
  final HomeFilter filter;
  final VoidCallback onChangeFilter;
  final TextEditingController searchCtrl;

  const _HeaderCard({
    required this.userEmail,
    required this.filter,
    required this.onChangeFilter,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    String label = switch (filter) {
      HomeFilter.all => 'All',
      HomeFilter.bills => 'Bills',
      HomeFilter.warranties => 'Warranties',
    };

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by title / store / provider',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Filter',
                  onPressed: onChangeFilter,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanReceiptPage()),
              ),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Quick Add (OCR)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(label: Text(label), avatar: const Icon(Icons.filter_list)),
                const Spacer(),
                Text(userEmail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final Widget trailing;
  final VoidCallback onTap;

  const _ItemTile({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 6),
            Text(meta, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
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
                decoration: const InputDecoration(
                  hintText: 'Search bills...',
                  prefixIcon: Icon(Icons.search),
                ),
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

                  if (docs.isEmpty) {
                    return const Center(child: Text('No bills found.'));
                  }

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

// ===== Small lists used on Home =====

class _RecentBillsList extends StatelessWidget {
  final String? userId;
  final String query;
  const _RecentBillsList({required this.userId, required this.query});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('Bills');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    final stream = base.orderBy('created_at', descending: true).limit(8).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return const _EmptyHint(text: 'Error loading bills.');
        if (!s.hasData) return const Center(child: CircularProgressIndicator());

        var docs = s.data!.docs;
        final q = query.trim().toLowerCase();
        if (q.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final title = (data['title'] ?? '').toString().toLowerCase();
            final shop = (data['shop_name'] ?? '').toString().toLowerCase();
            return title.contains(q) || shop.contains(q);
          }).toList();
        }
        if (docs.isEmpty) return const _EmptyHint(text: 'No bills found.');

        return Column(
          children: docs.map((doc) {
            final d = doc.data();
            final title = (d['title'] ?? '—').toString();
            final shop = (d['shop_name'] ?? '—').toString();
            final amountN = (d['total_amount'] as num?);
            final amount = amountN?.toDouble();

            final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
            final ret = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
            final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

            final details = BillDetails(
              id: doc.id, // ✅ إضافة المعرّف
              title: title,
              product: shop,
              amount: amount ?? 0,
              purchaseDate: purchase ?? DateTime.now(),
              returnDeadline: ret,
              warrantyExpiry: wEnd,
            );

            return _ItemTile(
              title: title,
              subtitle: '$shop • ${amount ?? '-'}',
              meta: 'Tap to view or edit',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                context,
                BillDetailPage.route,
                arguments: details,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RecentWarrantiesList extends StatelessWidget {
  final String? userId;
  final String query;
  const _RecentWarrantiesList({required this.userId, required this.query});

  String _fmt(DateTime? dt) =>
      dt == null ? '—' : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('Warranties');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    final stream = base.orderBy('end_date', descending: true).limit(8).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return const _EmptyHint(text: 'Error loading warranties.');
        if (!s.hasData) return const Center(child: CircularProgressIndicator());

        var docs = s.data!.docs;
        final q = query.trim().toLowerCase();
        if (q.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final provider = (data['provider'] ?? '').toString().toLowerCase();
            final title = (data['title'] ?? '').toString().toLowerCase();
            return provider.contains(q) || title.contains(q);
          }).toList();
        }
        if (docs.isEmpty) return const _EmptyHint(text: 'No warranties found.');

        return Column(
          children: docs.map((doc) {
            final d = doc.data();

            final provider =
            (d['provider']?.toString().trim().isNotEmpty == true) ? d['provider'].toString().trim() : 'Warranty';
            final wTitle =
            (d['title']?.toString().trim().isNotEmpty == true) ? d['title'].toString().trim() : provider;

            final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
            final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();

            return _ItemTile(
              title: provider,
              subtitle: wTitle,
              meta: '${_fmt(start)} → ${_fmt(end)}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final details = WarrantyDetails(
                  id: doc.id,
                  product: provider,
                  title: wTitle,
                  warrantyStart: start ?? DateTime.now(),
                  warrantyExpiry: end ?? DateTime.now(),
                  returnDeadline: null,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: details)),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

/// قائمة مدموجة (Bills + Warranties) مرتبة حسب أقرب انتهاء
class _AllMixedList extends StatelessWidget {
  final String? userId;
  final String query;
  const _AllMixedList({required this.userId, required this.query});

  DateTime? _asDateOnly(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);

  DateTime? _minDate(DateTime? a, DateTime? b) {
    if (a == null) return _asDateOnly(b);
    if (b == null) return _asDateOnly(a);
    final aa = _asDateOnly(a)!;
    final bb = _asDateOnly(b)!;
    return aa.isBefore(bb) ? aa : bb;
  }

  // أقرب انتهاء للفاتورة (الأقرب بين الإرجاع والضمان)
  DateTime? _expiryForBill(Map<String, dynamic> d) {
    final ret = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
    final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();
    return _minDate(ret, wEnd);
  }

  // انتهاء الضمان
  DateTime? _expiryForWarranty(Map<String, dynamic> d) {
    final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();
    return _asDateOnly(end);
  }

  String _fmt(DateTime? dt) =>
      dt == null ? '—' : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    // نجلب كمية مناسبة ثم ندمج ونرتّب محلياً
    final billsStream = billsBase.orderBy('created_at', descending: true).limit(25).snapshots();
    final warrStream = warrBase.orderBy('end_date', descending: true).limit(25).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: billsStream,
      builder: (context, bSnap) {
        if (bSnap.hasError) return const _EmptyHint(text: 'Error loading bills.');
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: warrStream,
          builder: (context, wSnap) {
            if (wSnap.hasError) return const _EmptyHint(text: 'Error loading warranties.');
            if (!bSnap.hasData || !wSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final q = query.trim().toLowerCase();
            final items = <_HomeItem>[];

            // Bills -> _HomeItem
            for (final doc in bSnap.data!.docs) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop = (d['shop_name'] ?? '—').toString();
              if (q.isNotEmpty) {
                final t = title.toLowerCase();
                final s = shop.toLowerCase();
                if (!(t.contains(q) || s.contains(q))) continue;
              }

              final amountN = (d['total_amount'] as num?);
              final amount = amountN?.toDouble();
              final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

              final details = BillDetails(
                id: doc.id, // ✅ بدل docId بـ id
                title: title,
                product: shop,
                amount: amount ?? 0,
                purchaseDate: purchase ?? DateTime.now(),
                returnDeadline: ret,
                warrantyExpiry: wEnd,
              );

              final tile = _ItemTile(
                title: title,
                subtitle: '$shop • ${amount ?? '-'}',
                meta: 'Bill • Return: ${_fmt(ret)}  •  Warranty: ${_fmt(wEnd)}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, BillDetailPage.route, arguments: details),
              );

              items.add(_HomeItem(expiry: _expiryForBill(d), tile: tile));
            }

            // Warranties -> _HomeItem
            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider = (d['provider']?.toString().trim().isNotEmpty == true)
                  ? d['provider'].toString().trim()
                  : 'Warranty';
              final wTitle = (d['title']?.toString().trim().isNotEmpty == true)
                  ? d['title'].toString().trim()
                  : provider;

              if (q.isNotEmpty) {
                final p = provider.toLowerCase();
                final t = wTitle.toLowerCase();
                if (!(p.contains(q) || t.contains(q))) continue;
              }

              final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();

              final details = WarrantyDetails(
                id: doc.id,
                product: provider,
                title: wTitle,
                warrantyStart: start ?? DateTime.now(),
                warrantyExpiry: end ?? DateTime.now(),
                returnDeadline: null,
              );

              final tile = _ItemTile(
                title: provider,
                subtitle: wTitle,
                meta: 'Warranty • ${_fmt(start)} → ${_fmt(end)}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: details)),
                ),
              );

              items.add(_HomeItem(expiry: _expiryForWarranty(d), tile: tile));
            }

            if (items.isEmpty) return const _EmptyHint(text: 'No items found.');

            // الترتيب: أقرب انتهاء أولاً (nulls في النهاية)
            items.sort((a, b) {
              final ax = a.expiry;
              final bx = b.expiry;
              if (ax == null && bx == null) return 0;
              if (ax == null) return 1;
              if (bx == null) return -1;
              return ax.compareTo(bx); // تصاعدي = الأقرب أول
            });

            // نعرض أول 12 عنصر
            final toShow = items.take(12).map((e) => e.tile).toList();
            return Column(children: toShow);
          },
        );
      },
    );
  }
}
