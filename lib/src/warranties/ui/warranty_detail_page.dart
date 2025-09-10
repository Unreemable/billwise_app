import 'package:flutter/material.dart';
import '../../common/models.dart';

/// أسماء الأشهر
const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

class WarrantyDetailPage extends StatelessWidget {
  const WarrantyDetailPage({super.key, required this.details});
  static const route = '/warranty-detail';

  final WarrantyDetails details;

  double _progressToExpiry() {
    final total = details.warrantyExpiry.difference(details.warrantyStart).inDays;
    final passed = DateTime.now().difference(details.warrantyStart).inDays;
    if (total <= 0) return 1;
    final p = passed / total;
    return p.clamp(0, 1).toDouble();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final p = _progressToExpiry();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              height: 280,
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'warranty:',
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

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  details.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Expires ${_fmt(details.warrantyExpiry)}',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: p,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 18),

                          _kv('Product:', details.product),
                          _kv('Warranty Start Date', _fmt(details.warrantyStart)),
                          _kv('Warranty Expiry Date', _fmt(details.warrantyExpiry)),
                          if (details.returnDeadline != null)
                            _kv('Return Deadline', _fmt(details.returnDeadline!)),
                          if (details.reminderDate != null)
                            _kv('Warranty Reminder Date', _fmt(details.reminderDate!)),

                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('B',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white)),
        Text('ill Wise',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white70)),
      ],
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 140,
        child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Text(v)),
    ],
  ),
);
