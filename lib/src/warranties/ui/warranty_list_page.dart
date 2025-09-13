import 'package:flutter/material.dart';
import '../../common/models.dart';
import 'warranty_detail_page.dart';


class WarrantyListPage extends StatelessWidget {
  const WarrantyListPage({super.key});
  static const route = '/warranties';

  @override
  Widget build(BuildContext context) {
    final items = List.generate(10, (i) => 'ضمان منتج #${i + 1} • ينتهي بعد ${10 - i} أشهر');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('All Warranties')),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => Card(
            child: ListTile(
              title: Text(items[i]),
              subtitle: const Text('رقم الفاتورة: BW-2025 • الحالة: ساري'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                // نموذج بيانات تجريبي — لاحقًا نربطه بقاعدة البيانات
                final d = WarrantyDetails(
                  title: 'Extra',
                  product: 'Dell Laptop',
                  warrantyStart: DateTime(2024, 8, 5),
                  warrantyExpiry: DateTime(2025, 8, 15),
                  returnDeadline: DateTime(2024, 8, 4),
                  reminderDate: DateTime(2025, 8, 5),
                );
                Navigator.pushNamed(
                  context,
                  WarrantyDetailPage.route,
                  arguments: d,
                );
              },
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: items.length,
        ),
      ),
    );
  }
}
