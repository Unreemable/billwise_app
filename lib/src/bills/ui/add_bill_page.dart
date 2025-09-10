import 'package:flutter/material.dart';
import '../../warranties/ui/add_warranty_page.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key, this.suggestWarranty = false});
  static const route = '/add-bill';

  /// استخدمي هذا مع الـ OCR: إذا لقيتي (ضمان / warranty / warranties)
  /// Navigator.pushNamed(context, AddBillPage.route, arguments: {'suggestWarranty': true});
  static Route<dynamic> routeWithArgs(RouteSettings settings) {
    final args = (settings.arguments as Map?) ?? {};
    final suggest = (args['suggestWarranty'] as bool?) ?? false;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => AddBillPage(suggestWarranty: suggest),
    );
  }

  final bool suggestWarranty;

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  int _tab = 0; // 0 = Bill, 1 = Warranty

  final _store = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.suggestWarranty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('تم رصد كلمة "ضمان" — هل تريدين تعبئة نموذج الضمان؟'),
            action: SnackBarAction(
              label: 'نعم',
              onPressed: () => setState(() => _tab = 1),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _store.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bill Information')),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Bill'), icon: Icon(Icons.receipt_long)),
                  ButtonSegment(value: 1, label: Text('Warranty'), icon: Icon(Icons.verified)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tab == 0 ? _BillForm(_store, _amount, _date) : const AddWarrantyPage(embedded: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillForm extends StatelessWidget {
  final TextEditingController store;
  final TextEditingController amount;
  final TextEditingController date;

  const _BillForm(this.store, this.amount, this.date);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: store,
          decoration: const InputDecoration(
            labelText: 'اسم المتجر',
            prefixIcon: Icon(Icons.store_mall_directory_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'المبلغ',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: date,
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              helpText: 'تاريخ الشراء',
            );
            if (picked != null) {
              date.text = '${picked.year}-${picked.month}-${picked.day}';
            }
          },
          decoration: const InputDecoration(
            labelText: 'تاريخ الشراء',
            prefixIcon: Icon(Icons.event),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {/* لاحقًا: حفظ الفاتورة */},
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
        ),
      ],
    );
  }
}
