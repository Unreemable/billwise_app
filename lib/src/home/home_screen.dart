// ================== Home Screen (fixed filter/sort + no overflow) ==================
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

import '../warranties/ui/warranty_list_page.dart';
import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';

import '../common/models.dart';

// نوع العنصر في تبويب "الكل"
enum _ItemType { bill, warranty }

// عنصر داخلي موحّد لقائمة "All"
class _HomeItem {
  final _ItemType type;
  final DateTime? created; // created_at
  final DateTime? expiry;  // أقرب انتهاء
  final Widget tile;
  const _HomeItem({
    required this.type,
    required this.created,
    required this.expiry,
    required this.tile,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeFilter { all, bills, warranties }
enum SortOption { newest, oldest, billsNear, warrantiesNear }

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;
  SortOption _sort = SortOption.newest;

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
                      sort: _sort,
                      onPickFilter: _pickFilter,
                      onPickSort: _pickSort,
                      searchCtrl: _searchCtrl,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      _sectionTitle(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    if (_filter == HomeFilter.all)
                      _AllMixedList(
                        userId: user?.uid,
                        query: _searchCtrl.text,
                        sort: _sort,
                      )
                    else if (_filter == HomeFilter.bills)
                      _RecentBillsList(
                        userId: user?.uid,
                        query: _searchCtrl.text,
                        sort: _sort,
                      )
                    else
                      _RecentWarrantiesList(
                        userId: user?.uid,
                        query: _searchCtrl.text,
                        sort: _sort,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers =====
  String _labelForFilter(HomeFilter f) => switch (f) {
    HomeFilter.all => 'All',
    HomeFilter.bills => 'Bills',
    HomeFilter.warranties => 'Warranties',
  };

  String _labelForSort(SortOption s) => switch (s) {
    SortOption.newest => 'Newest',
    SortOption.oldest => 'Oldest',
    SortOption.billsNear => 'Bills near expiry',
    SortOption.warrantiesNear => 'Warranties near expiry',
  };

  String _sectionTitle() => '${_labelForFilter(_filter)} • ${_labelForSort(_sort).toLowerCase()}';

  void _pickFilter() async {
    final picked = await showModalBottomSheet<HomeFilter>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final f in HomeFilter.values)
            RadioListTile<HomeFilter>(
              value: f,
              groupValue: _filter,
              title: Text(_labelForFilter(f)),
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() => _filter = picked);
    }
  }

  void _pickSort() async {
    final picked = await showModalBottomSheet<SortOption>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in SortOption.values)
            RadioListTile<SortOption>(
              value: s,
              groupValue: _sort,
              title: Text(_labelForSort(s)),
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _sort = picked;
        if (_sort == SortOption.billsNear) _filter = HomeFilter.bills;
        if (_sort == SortOption.warrantiesNear) _filter = HomeFilter.warranties;
      });
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
                      billId: null, // بدون فاتورة
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
  final SortOption sort;
  final VoidCallback onPickFilter;
  final VoidCallback onPickSort;
  final TextEditingController searchCtrl;

  const _HeaderCard({
    required this.userEmail,
    required this.filter,
    required this.sort,
    required this.onPickFilter,
    required this.onPickSort,
    required this.searchCtrl,
  });

  String _labelForFilter(HomeFilter f) => switch (f) {
    HomeFilter.all => 'All',
    HomeFilter.bills => 'Bills',
    HomeFilter.warranties => 'Warranties',
  };

  String _labelForSort(SortOption s) => switch (s) {
    SortOption.newest => 'Newest',
    SortOption.oldest => 'Oldest',
    SortOption.billsNear => 'Bills near expiry',
    SortOption.warrantiesNear => 'Warranties near expiry',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search
            TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by title / store / provider',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),

            // Quick add
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanReceiptPage()),
                ),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Quick Add (OCR)'),
              ),
            ),

            const SizedBox(height: 10),

            // Filter + Sort chips (simple, clear) + email under Wrap to avoid overflow
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: Text(_labelForFilter(filter)),
                  onPressed: onPickFilter,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.sort),
                  label: Text(_labelForSort(sort)),
                  onPressed: onPickSort,
                ),
                Text(
                  userEmail,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
  final SortOption sort;
  const _RecentBillsList({required this.userId, required this.query, required this.sort});

  DateTime? _minDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('Bills');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;

    final stream = base.orderBy('created_at', descending: true).limit(50).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return const _EmptyHint(text: 'Error loading bills.');
        if (!s.hasData) return const Center(child: CircularProgressIndicator());

        var docs = s.data!.docs.toList();

        // بحث
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

        // فرز محلي
        docs.sort((a, b) {
          final da = a.data(); final db = b.data();
          final ca = (da['created_at'] as Timestamp?)?.toDate();
          final cb = (db['created_at'] as Timestamp?)?.toDate();
          final ra = (da['return_deadline'] as Timestamp?)?.toDate();
          final rb = (db['return_deadline'] as Timestamp?)?.toDate();
          final wa = (da['warranty_end_date'] as Timestamp?)?.toDate();
          final wb = (db['warranty_end_date'] as Timestamp?)?.toDate();

          switch (sort) {
            case SortOption.newest:
              return (cb ?? DateTime(0)).compareTo(ca ?? DateTime(0));
            case SortOption.oldest:
              return (ca ?? DateTime(0)).compareTo(cb ?? DateTime(0));
            case SortOption.billsNear:
              final ea = _minDate(ra, wa);
              final eb = _minDate(rb, wb);
              if (ea == null && eb == null) return 0;
              if (ea == null) return 1;
              if (eb == null) return -1;
              return ea.compareTo(eb);
            case SortOption.warrantiesNear:
            // لا معنى داخل Bills؛ اعتبرها newest
              return (cb ?? DateTime(0)).compareTo(ca ?? DateTime(0));
          }
        });

        docs = docs.take(12).toList();

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
              id: doc.id,
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
              onTap: () => Navigator.pushNamed(context, BillDetailPage.route, arguments: details),
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
  final SortOption sort;
  const _RecentWarrantiesList({required this.userId, required this.query, required this.sort});

  String _fmt(DateTime? dt) =>
      dt == null ? '—' : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('Warranties');
    final base = userId != null ? col.where('user_id', isEqualTo: userId) : col;

    final stream = base.orderBy('created_at', descending: true).limit(50).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return const _EmptyHint(text: 'Error loading warranties.');
        if (!s.hasData) return const Center(child: CircularProgressIndicator());

        var docs = s.data!.docs.toList();

        // بحث
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

        // فرز
        docs.sort((a, b) {
          final da = a.data(); final db = b.data();
          final ca = (da['created_at'] as Timestamp?)?.toDate();
          final cb = (db['created_at'] as Timestamp?)?.toDate();
          final ea = (da['end_date'] as Timestamp?)?.toDate();
          final eb = (db['end_date'] as Timestamp?)?.toDate();

          switch (sort) {
            case SortOption.newest:
              return (cb ?? DateTime(0)).compareTo(ca ?? DateTime(0));
            case SortOption.oldest:
              return (ca ?? DateTime(0)).compareTo(cb ?? DateTime(0));
            case SortOption.warrantiesNear:
              if (ea == null && eb == null) return 0;
              if (ea == null) return 1;
              if (eb == null) return -1;
              return ea.compareTo(eb);
            case SortOption.billsNear:
            // لا معنى داخل Warranties؛ اعتبرها newest
              return (cb ?? DateTime(0)).compareTo(ca ?? DateTime(0));
          }
        });

        docs = docs.take(12).toList();

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

/// قائمة مدموجة (Bills + Warranties) مع فرز بحسب الخيار
class _AllMixedList extends StatelessWidget {
  final String? userId;
  final String query;
  final SortOption sort;
  const _AllMixedList({required this.userId, required this.query, required this.sort});

  DateTime? _dateOnly(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);

  DateTime? _minDate(DateTime? a, DateTime? b) {
    if (a == null) return _dateOnly(b);
    if (b == null) return _dateOnly(a);
    final aa = _dateOnly(a)!;
    final bb = _dateOnly(b)!;
    return aa.isBefore(bb) ? aa : bb;
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(50).snapshots();
    final warrStream  = warrBase.orderBy('created_at', descending: true).limit(50).snapshots();

    String _fmt(DateTime? dt) =>
        dt == null ? '—' : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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

            // Bills
            for (final doc in bSnap.data!.docs) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop  = (d['shop_name'] ?? '—').toString();

              if (q.isNotEmpty) {
                final t = title.toLowerCase();
                final s = shop.toLowerCase();
                if (!(t.contains(q) || s.contains(q))) continue;
              }

              final amountN = (d['total_amount'] as num?);
              final amount  = amountN?.toDouble();

              final created = (d['created_at'] as Timestamp?)?.toDate().toLocal();
              final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret  = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

              final details = BillDetails(
                id: doc.id,
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

              items.add(_HomeItem(
                type: _ItemType.bill,
                created: created,
                expiry: _minDate(ret, wEnd),
                tile: tile,
              ));
            }

            // Warranties
            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider =
              (d['provider']?.toString().trim().isNotEmpty == true) ? d['provider'].toString().trim() : 'Warranty';
              final wTitle =
              (d['title']?.toString().trim().isNotEmpty == true) ? d['title'].toString().trim() : provider;

              if (q.isNotEmpty) {
                final p = provider.toLowerCase();
                final t = wTitle.toLowerCase();
                if (!(p.contains(q) || t.contains(q))) continue;
              }

              final created = (d['created_at'] as Timestamp?)?.toDate().toLocal();
              final start   = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end     = (d['end_date'] as Timestamp?)?.toDate().toLocal();

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

              items.add(_HomeItem(
                type: _ItemType.warranty,
                created: created,
                expiry: end,
                tile: tile,
              ));
            }

            if (items.isEmpty) return const _EmptyHint(text: 'No items found.');

            // فرز بحسب الخيار
            int _cmpDateDesc(DateTime? a, DateTime? b) =>
                (b ?? DateTime(0)).compareTo(a ?? DateTime(0));
            int _cmpDateAsc(DateTime? a, DateTime? b) =>
                (a ?? DateTime(9999, 12, 31)).compareTo(b ?? DateTime(9999, 12, 31));

            List<_HomeItem> list = items;

            switch (sort) {
              case SortOption.newest:
                list.sort((a, b) => _cmpDateDesc(a.created, b.created));
                break;
              case SortOption.oldest:
                list.sort((a, b) => _cmpDateAsc(a.created, b.created));
                break;
              case SortOption.billsNear:
                list = items.where((e) => e.type == _ItemType.bill).toList()
                  ..sort((a, b) => _cmpDateAsc(a.expiry, b.expiry));
                break;
              case SortOption.warrantiesNear:
                list = items.where((e) => e.type == _ItemType.warranty).toList()
                  ..sort((a, b) => _cmpDateAsc(a.expiry, b.expiry));
                break;
            }

            final toShow = list.take(12).map((e) => e.tile).toList();
            return Column(children: toShow);
          },
        );
      },
    );
  }
}
