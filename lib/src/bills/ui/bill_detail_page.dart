import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

class BillDetailPage extends StatelessWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime? d) => d == null ? '—' : '${d.year}-${two(d.month)}-${two(d.day)}';

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(details.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Product/Store'),
              subtitle: Text(details.product ?? '—'),
            ),
            ListTile(
              title: const Text('Amount'),
              subtitle: Text(money.format(details.amount ?? 0)),
            ),
            ListTile(
              title: const Text('Purchase date'),
              subtitle: Text(fmt(details.purchaseDate)),
            ),
            if (details.returnDeadline != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ExpiryProgress(
                    title: 'Return',
                    startDate: details.purchaseDate ?? DateTime.now(),
                    endDate: details.returnDeadline!,
                    showInMonths: false, // days for bills
                  ),
                ),
              ),
            ],
            if (details.warrantyExpiry != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ExpiryProgress(
                    title: 'Warranty',
                    startDate: details.purchaseDate ?? DateTime.now(),
                    endDate: details.warrantyExpiry!,
                    showInMonths: true, // months for warranty
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
