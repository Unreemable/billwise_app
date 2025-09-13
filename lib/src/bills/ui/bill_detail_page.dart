import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/models.dart';

class BillDetailPage extends StatelessWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  @override
  Widget build(BuildContext context) {
    final money =
    NumberFormat.currency(locale: 'ar', symbol: 'SAR ', decimalDigits: 2);
    final two = (int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime? d) =>
        d == null ? '—' : '${d.year}-${two(d.month)}-${two(d.day)}';

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(details.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('المنتج'),
              subtitle: Text(details.product ?? '—'),
            ),
            ListTile(
              title: const Text('المبلغ'),
              subtitle: Text(money.format(details.amount ?? 0)),
            ),
            ListTile(
              title: const Text('تاريخ الشراء'),
              subtitle: Text(fmt(details.purchaseDate)),
            ),
            ListTile(
              title: const Text('آخر موعد للإرجاع'),
              subtitle: Text(fmt(details.returnDeadline)),
            ),
            ListTile(
              title: const Text('نهاية الضمان'),
              subtitle: Text(fmt(details.warrantyExpiry)),
            ),
          ],
        ),
      ),
    );
  }
}
