import 'dart:ui' as ui; // لتفادي مشكلة TextDirection.rtl
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../bills/data/bill_service.dart';
import '../../common/models.dart';
import 'add_bill_page.dart';
import 'bill_detail_page.dart';

class BillListPage extends StatefulWidget {
  const BillListPage({super.key});
  static const route = '/bills';

  @override
  State<BillListPage> createState() => _BillListPageState();
}

class _BillListPageState extends State<BillListPage> {
  final _searchCtrl = TextEditingController();
  final _money =
  NumberFormat.currency(locale: 'ar', symbol: 'SAR ', decimalDigits: 2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _daysLeft(DateTime? d) {
    if (d == null) return '—';
    final dd = DateTime(d.year, d.month, d.day);
    final diff = dd.difference(DateTime.now()).inDays;
    if (diff < 0) return 'منتهٍ';
    if (diff == 0) return 'اليوم';
    return 'بعد $diff يوم';
  }

  // نحول وثيقة Firestore إلى BillDetails ونفتح صفحة التفاصيل عبر route
  void _openDetailsFromDoc(Map<String, dynamic> d) {
    final title = (d['title'] ?? '—').toString();
    final product = (d['product'] ?? title).toString();
    final amount = (d['total_amount'] as num?)?.toDouble() ?? 0.0;
    final purchaseDate =
        (d['purchase_date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final returnDeadline = (d['return_deadline'] as Timestamp?)?.toDate();
    final warrantyExpiry = (d['warranty_end_date'] as Timestamp?)?.toDate();

    // ملاحظة: BillDetails عندك لا يحتوي id، لذا لا نمرره هنا
    final details = BillDetails(
      title: title,
      product: product,
      amount: amount,
      purchaseDate: purchaseDate,
      returnDeadline: returnDeadline, // ← الاسم الصحيح
      warrantyExpiry: warrantyExpiry,
    );

    Navigator.pushNamed(context, BillDetailPage.route, arguments: details);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الفواتير')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddBillPage()),
          ),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالعنوان أو المتجر',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BillService.instance.streamBills(),
                builder: (context, s) {
                  if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = s.data!.docs;

                  // فلترة حسب البحث
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final title =
                      (d['title'] ?? '').toString().toLowerCase();
                      final shop =
                      (d['shop_name'] ?? '').toString().toLowerCase();
                      return title.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('لا توجد فواتير مطابقة'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final title = (d['title'] ?? '—').toString();
                      final shop = (d['shop_name'] ?? '—').toString();
                      final amount = (d['total_amount'] as num?)?.toDouble();
                      final ret =
                      (d['return_deadline'] as Timestamp?)?.toDate();
                      final ex =
                      (d['exchange_deadline'] as Timestamp?)?.toDate();
                      final hasWarranty =
                          (d['warranty_coverage'] as bool?) ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          onTap: () => _openDetailsFromDoc(d),
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$shop • '
                                  '${amount == null ? '-' : _money.format(amount)}'),
                              const SizedBox(height: 4),
                              Text(
                                'إرجاع: ${_daysLeft(ret)} · استبدال: ${_daysLeft(ex)}',
                                style:
                                Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasWarranty)
                                const Icon(Icons.verified,
                                    color: Colors.green),
                              const Icon(Icons.chevron_left),
                            ],
                          ),
                        ),
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
