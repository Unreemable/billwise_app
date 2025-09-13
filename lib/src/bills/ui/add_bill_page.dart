import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../bills/data/bill_service.dart';
import '../../warranties/ui/add_warranty_page.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});
  static const route = '/add-bill';

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _titleCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime _returnDeadline = DateTime.now().add(const Duration(days: 7));
  DateTime _exchangeDeadline = DateTime.now().add(const Duration(days: 14));

  bool _hasWarranty = false;
  DateTime? _warrantyEnd;

  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;

  Future<void> _pickDate(BuildContext ctx, DateTime initial, ValueChanged<DateTime> onPick) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) onPick(d);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _shopCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كمّلي الحقول الأساسية')));
      return;
    }
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ غير صالح')));
      return;
    }
    if (_hasWarranty && _warrantyEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختاري نهاية الضمان')));
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await BillService.instance.createBill(
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate,
        totalAmount: amount,
        returnDeadline: _returnDeadline,
        exchangeDeadline: _exchangeDeadline,
        warrantyCoverage: _hasWarranty,
        warrantyEndDate: _warrantyEnd,
        // userId: FirebaseAuth.instance.currentUser?.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة ✅')));

      // لو فيه ضمان نفتح صفحة إضافة الضمان مباشرة
      if (_hasWarranty) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddWarrantyPage(
            billId: id,
            defaultStartDate: _purchaseDate,
            defaultEndDate: _warrantyEnd!,
          ),
        ));
      }
      if (mounted) Navigator.of(context).pop(); // رجوع للقائمة
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة فاتورة')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'عنوان/وصف الفاتورة')),
            TextField(controller: _shopCtrl, decoration: const InputDecoration(labelText: 'اسم المتجر')),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('تاريخ الشراء'),
              subtitle: Text(_fmt.format(_purchaseDate)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(context, _purchaseDate, (d) => setState(() => _purchaseDate = d)),
            ),
            ListTile(
              title: const Text('موعد آخر للإرجاع'),
              subtitle: Text(_fmt.format(_returnDeadline)),
              trailing: const Icon(Icons.event),
              onTap: () => _pickDate(context, _returnDeadline, (d) => setState(() => _returnDeadline = d)),
            ),
            ListTile(
              title: const Text('موعد آخر للاستبدال'),
              subtitle: Text(_fmt.format(_exchangeDeadline)),
              trailing: const Icon(Icons.event_repeat),
              onTap: () => _pickDate(context, _exchangeDeadline, (d) => setState(() => _exchangeDeadline = d)),
            ),
            const Divider(),
            SwitchListTile(
              value: _hasWarranty,
              onChanged: (v) => setState(() {
                _hasWarranty = v;
                if (!v) _warrantyEnd = null;
              }),
              title: const Text('فيه ضمان؟'),
            ),
            if (_hasWarranty)
              ListTile(
                title: const Text('نهاية الضمان'),
                subtitle: Text(_warrantyEnd == null ? '—' : _fmt.format(_warrantyEnd!)),
                trailing: const Icon(Icons.verified_user),
                onTap: () => _pickDate(context, _warrantyEnd ?? _purchaseDate,
                        (d) => setState(() => _warrantyEnd = d)),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
