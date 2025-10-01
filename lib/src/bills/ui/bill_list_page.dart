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

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Color? _threeDayReturnColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return Colors.blueGrey;
    if (diff == 0) return Colors.green;
    if (diff == 1) return Colors.orange;
    if (diff == 2) return Colors.red;
    return Colors.grey;
  }

  String? _threeDayReturnLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return 'Starts soon';
    if (diff == 0) return 'Day 1 of 3';
    if (diff == 1) return 'Day 2 of 3';
    if (diff == 2) return 'Final day (3 of 3)';
    return 'Expired';
  }

  Color? _sevenDayExchangeColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1;
    if (diff <= 0) return Colors.blueGrey;
    if (diff >= 1 && diff <= 3) return Colors.green;
    if (diff >= 4 && diff <= 6) return Colors.orange;
    if (diff == 7) return Colors.red;
    return Colors.grey;
  }

  String? _sevenDayExchangeLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1;
    if (diff <= 0) return 'Starts soon';
    if (diff >= 1 && diff <= 3) return 'Days 1–3 of 7';
    if (diff >= 4 && diff <= 6) return 'Days 4–6 of 7';
    if (diff == 7) return 'Final day (7 of 7)';
    return 'Expired';
  }

  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  Color? _warrantyColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());
    if (today.isBefore(s)) return Colors.blueGrey;
    if (!today.isBefore(e)) return Colors.grey;
    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;
      if (elapsedMonths < 18) return Colors.orange;
      return Colors.red;
    }
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return Colors.grey;
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return Colors.green;
    if (elapsedDays < t2) return Colors.orange;
    return Colors.red;
  }

  String? _warrantyLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());
    if (today.isBefore(s)) return 'Starts soon';
    if (!today.isBefore(e)) return 'Expired';
    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return 'Year 1 of 2';
      if (elapsedMonths < 18) return 'Year 2 (first 6 months)';
      return 'Year 2 (final 6 months)';
    }
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return 'Expired';
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

  Chip _statusChip(DateTime? startUtc, DateTime? endUtc, {Color? overrideColor}) {
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
      color = overrideColor ?? Colors.green;
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

    final kind = title.toLowerCase();
    final isReturn   = kind == 'return';
    final isExchange = kind == 'exchange';
    final isWarranty = kind == 'warranty';

    final threeDayColor = isReturn   ? _threeDayReturnColor(start, end)   : null;
    final threeDayLabel = isReturn   ? _threeDayReturnLabel(start, end)   : null;

    final sevenDayColor = isExchange ? _sevenDayExchangeColor(start, end) : null;
    final sevenDayLabel = isExchange ? _sevenDayExchangeLabel(start, end) : null;

    final warrantyColor = isWarranty ? _warrantyColor(start, end)         : null;
    final warrantyLabel = isWarranty ? _warrantyLabel(start, end)         : null;

    final barColor = threeDayColor ?? sevenDayColor ?? warrantyColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (threeDayColor != null) ...[
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: threeDayColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(threeDayLabel ?? 'Return (3-day window)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (sevenDayColor != null) ...[
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: sevenDayColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(sevenDayLabel ?? 'Exchange (7-day window)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (warrantyColor != null) ...[
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: warrantyColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(warrantyLabel ?? 'Warranty (3 segments)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ExpiryProgress(
          title: title,
          startDate: start,
          endDate: end,
          dense: true,
          showInMonths: isWarranty,
          barColor: barColor,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: _statusChip(start, end, overrideColor: barColor),
        ),
      ],
    );
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

                      final title = (d['title'] ?? '—').toString();
                      final shop = (d['shop_name'] ?? '—').toString();
                      final amount = (d['total_amount'] as num?)?.toDouble();

                      final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
                      final ret = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
                      final ex  = (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

                      final hasWarranty = (d['warranty_coverage'] as bool?) ?? false;
                      final wEnd = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

                      final hasReceipt = (d['receipt_image_path'] as String?)
                          ?.trim()
                          .isNotEmpty == true;

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            shop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${title == shop ? '' : '$title • '}${amount == null ? '-' : _money.format(amount)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),

                              _policyBlock(title: 'Return',   start: purchase, end: ret),
                              const SizedBox(height: 10),
                              _policyBlock(title: 'Exchange', start: purchase, end: ex),
                              const SizedBox(height: 10),

                              if (hasWarranty && wEnd != null)
                                _policyBlock(title: 'Warranty', start: purchase, end: wEnd),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasReceipt) const Icon(Icons.attachment, size: 18),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            final details = BillDetails(
                              id: doc.id,
                              title: title,
                              product: shop,
                              amount: amount ?? 0,
                              purchaseDate: purchase ?? DateTime.now(),
                              returnDeadline: ret,
                              exchangeDeadline: ex,
                              hasWarranty: hasWarranty,
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
