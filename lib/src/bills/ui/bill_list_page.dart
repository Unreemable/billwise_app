import 'dart:ui' as ui; // for TextDirection.ltr
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../data/bill_service.dart';
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
  NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bills')),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddBillPage()));
            if (mounted) setState(() {}); // refresh after adding
          },
          child: const Icon(Icons.add),
        ),
        body: uid == null
            ? const Center(child: Text('Please sign in to view your bills.'))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by title or store',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: BillService.instance.streamBillsSnapshot(
                  userId: uid,
                  orderBy: 'created_at',
                  descending: true,
                ),
                builder: (context, s) {
                  if (s.hasError) {
                    return Center(child: Text('Error: ${s.error}'));
                  }
                  if (!s.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  var docs = s.data!.docs;

                  // Filter by search (title/shop)
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final title = (d['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final shop = (d['shop_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      return title.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('No bills found.'));
                  }

                  return ListView.builder(
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data();

                      final title =
                      (d['title'] ?? '—').toString();
                      final shop =
                      (d['shop_name'] ?? '—').toString();
                      final amount =
                      (d['total_amount'] as num?)?.toDouble();
                      final purchase =
                      (d['purchase_date'] as Timestamp?)
                          ?.toDate();
                      final ret =
                      (d['return_deadline'] as Timestamp?)
                          ?.toDate();
                      final ex =
                      (d['exchange_deadline'] as Timestamp?)
                          ?.toDate();
                      final hasWarranty =
                          (d['warranty_coverage'] as bool?) ?? false;
                      final wEnd =
                      (d['warranty_end_date'] as Timestamp?)
                          ?.toDate();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          onTap: () {
                            final details = BillDetails(
                              title: title,
                              product: shop,
                              amount: amount ?? 0,
                              purchaseDate:
                              purchase ?? DateTime.now(),
                              returnDeadline: ret,
                              warrantyExpiry: wEnd,
                            );
                            Navigator.pushNamed(
                              context,
                              BillDetailPage.route,
                              arguments: details,
                            );
                          },
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$shop • ${amount == null ? '-' : _money.format(amount)}',
                              ),
                              const SizedBox(height: 6),
                              if (purchase != null && ret != null)
                                ExpiryProgress(
                                  title: 'Return',
                                  startDate: purchase,
                                  endDate: ret,
                                  dense: true, // thin bar
                                  showInMonths:
                                  false, // days for bills
                                ),
                              if (purchase != null && ex != null) ...[
                                const SizedBox(height: 6),
                                ExpiryProgress(
                                  title: 'Exchange',
                                  startDate: purchase,
                                  endDate: ex,
                                  dense: true,
                                  showInMonths: false,
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasWarranty)
                                const Icon(Icons.verified,
                                    color: Colors.green),
                              const Icon(Icons.chevron_right),
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
