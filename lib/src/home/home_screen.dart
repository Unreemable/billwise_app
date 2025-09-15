import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_screen.dart';
import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
import '../warranties/ui/warranty_list_page.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/data/bill_service.dart';
import '../warranties/data/warranty_service.dart';

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
          onPressed: () async {
            // Add Bill manually
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBillPage()),
            );
            if (mounted) setState(() {});
          },
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

  // Recent items according to filter + search
  Widget _buildRecentList({String? userId}) {
    if (_filter == HomeFilter.bills) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: BillService.instance.streamBills(userId: userId),
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var docs = s.data!.docs;

          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final title = (data['title'] ?? '').toString().toLowerCase();
              final shop = (data['shop_name'] ?? '').toString().toLowerCase();
              return title.contains(q) || shop.contains(q);
            }).toList();
          }
          if (docs.isEmpty) return const _EmptyHint(text: 'No bills found.');

          final toShow = docs.take(8).toList();
          return Column(
            children: toShow.map((doc) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop = (d['shop_name'] ?? '—').toString();
              final amount = d['total_amount'];
              return _ItemTile(
                title: title,
                subtitle: '$shop • ${amount ?? '-'}',
                meta: 'Tap to view or edit',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillListPage())),
              );
            }).toList(),
          );
        },
      );
    } else {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: WarrantyService.instance.streamWarranties(userId: userId),
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var docs = s.data!.docs;

          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final provider = (data['provider'] ?? '').toString().toLowerCase();
              return provider.contains(q);
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyListPage())),
              );
            }).toList(),
          );
        },
      );
    }
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
                    onChanged: (_) => (context as Element).markNeedsBuild(),
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
