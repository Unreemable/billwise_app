import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';


const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

class BillDetailPage extends StatelessWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  String _pretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  String _ymd(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// أقرب “انتهاء” نستخدمه للبادج والبار العلوي
  DateTime? get _primaryEnd =>
      details.returnDeadline ?? details.exchangeDeadline ?? details.warrantyExpiry;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);

    return Directionality(
      textDirection: ui.TextDirection.ltr,

      child: Scaffold(
        body: Stack(
          children: [
            // Header gradient (نفس ستايل صفحة الضمان)
            Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),

            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Top bar (رجوع + عنوان + لوجو بسيط)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bill',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      const _LogoStub(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ==== Header Card ====
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  details.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (_primaryEnd != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Expires ${_pretty(_primaryEnd!)}',
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // (1) الأشرطة أولاً
                          if (details.purchaseDate != null && details.returnDeadline != null) ...[
                            _section(
                              title: 'Return',
                              start: details.purchaseDate!,
                              end: details.returnDeadline!,
                              months: false,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (details.purchaseDate != null && details.exchangeDeadline != null) ...[
                            _section(
                              title: 'Exchange',
                              start: details.purchaseDate!,
                              end: details.exchangeDeadline!,
                              months: false,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (details.purchaseDate != null && details.warrantyExpiry != null) ...[
                            _section(
                              title: 'Warranty',
                              start: details.purchaseDate!,
                              end: details.warrantyExpiry!,
                              months: true,
                            ),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 6),

                          // (2) التفاصيل بعد الأشرطة
                          _kv('Product/Store', details.product ?? '—'),
                          _kv('Amount', money.format(details.amount)),
                          _kv('Purchase date', _ymd(details.purchaseDate)),
                          if (details.returnDeadline != null)
                            _kv('Return deadline', _ymd(details.returnDeadline)),
                          if (details.exchangeDeadline != null)
                            _kv('Exchange deadline', _ymd(details.exchangeDeadline)),
                          if (details.warrantyExpiry != null)
                            _kv('Warranty expiry', _ymd(details.warrantyExpiry)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== small reusable bits =====

class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('B', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
        Text('ill Wise', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
      ],
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 160, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v)),
    ],
  ),
);

Widget _section({
  required String title,
  required DateTime start,
  required DateTime end,
  required bool months,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ExpiryProgress(
        title: title,
        startDate: start,
        endDate: end,
        showInMonths: months,
        dense: true,
      ),
    ],
  );
}
