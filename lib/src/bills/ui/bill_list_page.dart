import 'package:flutter/material.dart';
import '../../common/models.dart';
import 'bill_detail_page.dart';

class BillListPage extends StatelessWidget {
  const BillListPage({super.key});
  static const route = '/bills';

  @override
  Widget build(BuildContext context) {
    final bills = List.generate(12, (i) => 'فاتورة متجر #${i + 1} - ${120 + i} SAR');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('All Bills')),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => Card(
            child: ListTile(
              title: Text(bills[i]),
              subtitle: const Text('تفاصيل مختصرة • تاريخ اليوم'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                // نموذج بيانات تجريبي — لاحقًا نربطه بقاعدة البيانات
                final d = BillDetails(
                  title: 'Carrefour',
                  product: 'Air Fryer',
                  amount: 299,
                  purchaseDate: DateTime(2024, 8, 1),
                  returnDeadline: DateTime(2024, 8, 15),
                  warrantyExpiry: DateTime(2025, 8, 1),
                );
                Navigator.pushNamed(context, BillDetailPage.route, arguments: d);
              },
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: bills.length,
        ),
      ),
    );
  }
}
