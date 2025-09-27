import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
import '../warranties/ui/warranty_list_page.dart';
import '../warranties/ui/add_warranty_page.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/data/bill_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeFilter { bills, warranties }

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.bills;
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

        // زر الإضافة → نافذة اختيار
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
                    Text(
                      _filter == HomeFilter.bills ? 'Recent bills' : 'Recent warranties',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildRecentList(userId: user?.uid),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ستريم الفواتير
  Stream<QuerySnapshot<Map<String, dynamic>>> _billsStream({String? userId}) {
    final col = FirebaseFirestore.instance.collection('Bills');
    final baseQuery = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    return baseQuery.orderBy('created_at', descending: true).limit(25).snapshots();
  }

  // ستريم الضمانات
  Stream<QuerySnapshot<Map<String, dynamic>>> _warrantiesStream({String? userId}) {
    final col = FirebaseFirestore.instance.collection('Warranties');
    final baseQuery = userId != null ? col.where('user_id', isEqualTo: userId) : col;
    return baseQuery.orderBy('start_date', descending: true).limit(25).snapshots();
  }

  // القائمة على الرئيسية
  Widget _buildRecentList({String? userId}) {
    if (_filter == HomeFilter.bills) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _billsStream(userId: userId),
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = s.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final title = (data['title'] ?? '').toString().toLowerCase();
              final shop  = (data['shop_name'] ?? '').toString().toLowerCase();
              return title.contains(q) || shop.contains(q);
            }).toList();
          }

          if (docs.isEmpty) return const _EmptyHint(text: 'No bills found.');

          final toShow = docs.take(8).toList();
          return Column(
            children: toShow.map((doc) {
              final d = doc.data();
              final title  = (d['title'] ?? '—').toString();
              final shop   = (d['shop_name'] ?? '—').toString();
              final amount = d['total_amount'];
              return _ItemTile(
                title: title,
                subtitle: '$shop • ${amount ?? '-'}',
                meta: 'Tap to view or edit',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillListPage()),
                ),
              );
            }).toList(),
          );
        },
      );
    } else {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _warrantiesStream(userId: userId),
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = s.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final provider = (data['provider'] ?? '').toString().toLowerCase();
              final title = (data['title'] ?? '').toString().toLowerCase();
              return provider.contains(q) || title.contains(q);
            }).toList();
          }

          if (docs.isEmpty) return const _EmptyHint(text: 'No warranties found.');

          final toShow = docs.take(8).toList();
          return Column(
            children: toShow.map((doc) {
              final d = doc.data();
              final provider = (d['provider'] ?? 'Warranty').toString();
              return _ItemTile(
                title: provider,
                subtitle: 'Tap to view',
                meta: '—',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WarrantyListPage()),
                ),
              );
            }).toList(),
          );
        },
      );
    }
  }

  // نافذة اختيار: Bill / Warranty (+ OCR)
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
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
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

  // خيارات الضمان: ربط/إضافة ضمان فقط
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

  void _showFilterSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<HomeFilter>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
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

// ===== Widgets مساعدة =====

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
                Chip(
                  label: Text(filter == HomeFilter.bills ? 'Bills' : 'Warranties'),
                  avatar: const Icon(Icons.filter_list),
                ),
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

// زر كبير لخيارات الإضافة
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

// Bottom sheet لاختيار فاتورة موجودة
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
                      final shop  = (d['shop_name'] ?? '—').toString();
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
