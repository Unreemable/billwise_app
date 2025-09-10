import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../warranties/ui/warranty_list_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import '../common/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeFilter { bills, warranties }

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.bills;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تسجيل خروج',
              onPressed: () async {
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, LoginScreen.route, (_) => false);
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.pushNamed(context, AddBillPage.route);
          },
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long), label: 'فواتيري'),
            NavigationDestination(
                icon: Icon(Icons.verified), label: 'الضمانات'),
          ],
          onDestinationSelected: (i) async {
            if (i == 1) {
              await Navigator.pushNamed(context, BillListPage.route);
            } else if (i == 2) {
              await Navigator.pushNamed(context, WarrantyListPage.route);
            }
          },
        ),
        body: Stack(
          children: [
            _HeaderGradient(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      userEmail: user?.email ?? 'غير مسجّل',
                      filter: _filter,
                      onChangeFilter: () => _showFilterSheet(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recent ${_filter == HomeFilter.bills ? "Bills" : "Warranties"}',
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(4, (i) {
                      return _ItemTile(
                        title: _filter == HomeFilter.bills
                            ? 'فاتورة #${i + 1}'
                            : 'ضمان #${i + 1}',
                        subtitle: _filter == HomeFilter.bills
                            ? 'متجر إلكترونيات • 299 SAR'
                            : 'ينتهي بعد 7 أشهر',
                        progress: (i + 1) * 0.18,
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () async {
                          if (_filter == HomeFilter.bills) {
                            final d = BillDetails(
                              title: 'Carrefour',
                              product: 'Air Fryer',
                              amount: 299,
                              purchaseDate: DateTime(2024, 8, 1),
                              returnDeadline: DateTime(2024, 8, 15),
                              warrantyExpiry: DateTime(2025, 8, 1),
                            );
                            Navigator.pushNamed(
                                context, BillDetailPage.route,
                                arguments: d);
                          } else {
                            final d = WarrantyDetails(
                              title: 'Extra',
                              product: 'Dell Laptop',
                              warrantyStart: DateTime(2024, 8, 5),
                              warrantyExpiry: DateTime(2025, 8, 15),
                              returnDeadline: DateTime(2024, 8, 4),
                              reminderDate: DateTime(2025, 8, 5),
                            );
                            Navigator.pushNamed(
                                context, WarrantyDetailPage.route,
                                arguments: d);
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<HomeFilter>(
      context: context,
      showDragHandle: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
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
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }
}

class _HeaderGradient extends StatelessWidget {
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

  const _HeaderCard({
    required this.userEmail,
    required this.filter,
    required this.onChangeFilter,
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
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'فلترة',
                  onPressed: onChangeFilter,
                  icon: const Icon(Icons.tune),
                ),
              ],
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
  final double progress;
  final Widget trailing;
  final VoidCallback onTap;

  const _ItemTile({
    required this.title,
    required this.subtitle,
    required this.progress,
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
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}
