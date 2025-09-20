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
  final _money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================= Helpers =================
  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Chip _statusChip(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return const Chip(label: Text('—'));

    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());

    late String text;
    late Color color;
    late IconData icon;

    if (today.isBefore(s)) {
      text = 'upcoming';
      color = Colors.blueGrey;
      icon = Icons.schedule;
    } else if (today.isAfter(e) || today.isAtSameMomentAs(e)) {
      text = 'expired';
      color = Colors.red;
      icon = Icons.close_rounded;
    } else {
      text = 'active';
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _policyBlock({
    required String title,
    required DateTime? start,
    required DateTime? end,
  }) {
    if (start == null || end == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // شريط التقدّم
        ExpiryProgress(
          title: title,
          startDate: start,
          endDate: end,
          dense: true,
          showInMonths: false,
        ),
        const SizedBox(height: 6),
        // حالة الشريط (active / expired / upcoming)
        Align(
          alignment: Alignment.centerLeft,
          child: _statusChip(start, end),
        ),
      ],
    );
  }

  // تأكيد حذف الفاتورة + تنفيذ الحذف
  Future<void> _confirmDeleteBill(BuildContext context, String billId, String titleForMsg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text('Are you sure you want to delete “$titleForMsg”? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BillService.instance.deleteBill(billId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBillPage()));
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = s.data!.docs;

                  // Filter by search (title/shop)
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final title = (d['title'] ?? '').toString().toLowerCase();
                      final shop = (d['shop_name'] ?? '').toString().toLowerCase();
                      return title.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('No bills found.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final billId = doc.id;

                      final title = (d['title'] ?? '—').toString();
                      final shop = (d['shop_name'] ?? '—').toString();
                      final amount = (d['total_amount'] as num?)?.toDouble();

                      final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
                      final ret = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
                      final ex = (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

                      final hasWarranty = (d['warranty_coverage'] as bool?) ?? false;
                      final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          // العنوان = اسم المحل
                          title: Text(
                            shop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          // سطر صغير: عنوان الفاتورة + المبلغ
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${title == shop ? '' : '$title • '}${amount == null ? '-' : _money.format(amount)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),

                              // Return
                              _policyBlock(title: 'Return', start: purchase, end: ret),
                              const SizedBox(height: 10),

                              // Exchange
                              _policyBlock(title: 'Exchange', start: purchase, end: ex),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                // لو عندك صفحة تعديل فعلها هنا
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddBillPage()),
                                );
                                if (context.mounted) setState(() {});
                              } else if (v == 'delete') {
                                await _confirmDeleteBill(context, billId, title.isEmpty ? shop : title);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, size: 18),
                                  title: Text('Edit'),
                                  dense: true,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline, size: 18),
                                  title: Text('Delete'),
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            final details = BillDetails(
                              title: title,
                              product: shop,
                              amount: amount ?? 0,
                              purchaseDate: purchase ?? DateTime.now(),
                              returnDeadline: ret,
                              warrantyExpiry: wEnd,
                            );
                            Navigator.pushNamed(
                              context,
                              BillDetailPage.route,
                              arguments: details,
                            );
                          },
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
