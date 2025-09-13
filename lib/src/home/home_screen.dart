import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

import '../bills/ui/bill_list_page.dart';
import '../bills/ui/add_bill_page.dart';
// لو ما تحتاجين صفحة التفاصيل الآن تقدرين تحذفين هذا الاستيراد
// import '../bills/ui/bill_detail_page.dart';

import '../warranties/ui/warranty_list_page.dart';
// import '../warranties/ui/warranty_detail_page.dart';

import '../ocr/scan_receipt_page.dart';

// خدمات Firestore
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
            // نفتح صفحة إضافة فاتورة مباشرة (بدون الاعتماد على route name)
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBillPage()),
            );
            setState(() {}); // ينعش القائمة عند الرجوع
          },
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long),
              label: 'فواتيري',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified),
              label: 'الضمانات',
            ),
          ],
          onDestinationSelected: (i) async {
            if (i == 1) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillListPage()),
              );
            } else if (i == 2) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WarrantyListPage()),
              );
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
                      userEmail: user?.email ?? 'غير مسجّل',
                      filter: _filter,
                      onChangeFilter: () => _showFilterSheet(context),
                      searchCtrl: _searchCtrl,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter == HomeFilter.bills
                          ? 'أحدث الفواتير'
                          : 'أحدث الضمانات',
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildRecentList(), // القائمة الحقيقية من Firestore
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // قائمة حديثة حسب الفلتر + البحث
  Widget _buildRecentList() {
    if (_filter == HomeFilter.bills) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: BillService.instance.streamBills(),
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text('خطأ: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = s.data!.docs;

          // فلترة بالبحث (عنوان/اسم متجر)
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final title = (data['title'] ?? '').toString().toLowerCase();
              final shop = (data['shop_name'] ?? '').toString().toLowerCase();
              return title.contains(q) || shop.contains(q);
            }).toList();
          }

          if (docs.isEmpty) {
            return const _EmptyHint(text: 'لا توجد فواتير مطابقة');
          }

          // نعرض فقط 8 عناصر (حديثة)
          final toShow = docs.take(8).toList();
          return Column(
            children: toShow.map((doc) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop = (d['shop_name'] ?? '—').toString();
              final amount = d['total_amount'];
              final ret = (d['return_deadline'] as Timestamp?)?.toDate();
              final ex = (d['exchange_deadline'] as Timestamp?)?.toDate();
              final hasWarranty = (d['warranty_coverage'] as bool?) ?? false;

              return _ItemTile(
                title: title,
                subtitle: '$shop • ${amount ?? '-'}',
                meta: 'إرجاع: ${_daysLeft(ret)} · استبدال: ${_daysLeft(ex)}',
                trailing: hasWarranty
                    ? const Icon(Icons.verified, color: Colors.green)
                    : const SizedBox(),
                onTap: () {
                  // لو عندك صفحة تفاصيل جاهزة مرّري id/arguments حسب تطبيقك
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BillListPage()),
                  );
                },
              );
            }).toList(),
          );
        },
      );
    } else {
      // وارنـتيز
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: WarrantyService.instance.streamWarranties(),
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text('خطأ: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = s.data!.docs;

          // فلترة بالبحث (المزوّد/الفاتورة غير متاحة هنا، نكتفي بالمزوّد)
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data();
              final provider = (data['provider'] ?? '').toString().toLowerCase();
              return provider.contains(q);
            }).toList();
          }

          if (docs.isEmpty) {
            return const _EmptyHint(text: 'لا توجد ضمانات مطابقة');
          }

          final toShow = docs.take(8).toList();
          return Column(
            children: toShow.map((doc) {
              final d = doc.data();
              final provider = (d['provider'] ?? '—').toString();
              final end = (d['end_date'] as Timestamp?)?.toDate();

              return _ItemTile(
                title: provider,
                subtitle: 'ينتهي: ${_date(end)}',
                meta: _badge(expiry: end),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WarrantyListPage()),
                  );
                },
              );
            }).toList(),
          );
        },
      );
    }
  }

  String _daysLeft(DateTime? d) {
    if (d == null) return '—';
    final dd = DateTime(d.year, d.month, d.day);
    final diff = dd.difference(DateTime.now()).inDays;
    if (diff < 0) return 'منتهٍ';
    if (diff == 0) return 'اليوم';
    return 'بعد $diff يوم';
  }

  static String _date(DateTime? d) {
    if (d == null) return '—';
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static String _badge({required DateTime? expiry}) {
    if (expiry == null) return '—';
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff < 0) return 'منتهي';
    if (diff <= 7) return 'قريب جدًا';
    if (diff <= 30) return 'قريب';
    return 'ساري';
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
                      hintText: 'ابحث بالعنوان أو المتجر/المزوّد',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      // نعيد بناء الواجهة لتطبيق الفلترة
                      (context as Element).markNeedsBuild();
                    },
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
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanReceiptPage()),
              ),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Quick Add'),
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