import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../warranties/ui/add_warranty_page.dart';
import '../data/bill_service.dart';

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

  DateTime? _ocrWarrantyStart;
  DateTime? _ocrWarrantyEnd;

  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;
  bool _warrantySnackShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final prefill = (args['prefill'] as Map?) ?? {};
      final suggestWarranty = args['suggestWarranty'] == true;

      _titleCtrl.text = (prefill['title'] ?? '').toString();
      _shopCtrl.text = (prefill['store'] ?? '').toString();
      final amount = prefill['amount'];
      if (amount != null) _amountCtrl.text = amount.toString();

      if (prefill['purchaseDate'] is String) {
        final d = DateTime.tryParse(prefill['purchaseDate']);
        if (d != null) _purchaseDate = d;
      }
      if (prefill['warrantyStart'] is String) {
        _ocrWarrantyStart = DateTime.tryParse(prefill['warrantyStart']);
      }
      if (prefill['warrantyEnd'] is String) {
        _ocrWarrantyEnd = DateTime.tryParse(prefill['warrantyEnd']);
        _warrantyEnd = _ocrWarrantyEnd;
      }

      if (suggestWarranty && !_hasWarranty) {
        setState(() => _hasWarranty = true);
        if (!_warrantySnackShown) {
          _warrantySnackShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Warranty detected from OCR')),
            );
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shopCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, DateTime initial, ValueChanged<DateTime> onPick) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) onPick(d);
  }

  Future<String?> _saveBillOnly() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty ||
        _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required fields')),
      );
      return null;
    }
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return null;
    }
    if (_hasWarranty && _warrantyEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick warranty end date')),
      );
      return null;
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
      );
      if (!mounted) return id;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill saved ✅')),
      );
      return id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final id = await _saveBillOnly();
    if (id != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAndAddWarranty() async {
    final billId = await _saveBillOnly();
    if (billId == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddWarrantyPage(
        billId: billId,
        defaultStartDate: _ocrWarrantyStart ?? _purchaseDate,
        defaultEndDate: _ocrWarrantyEnd ?? _warrantyEnd ?? _purchaseDate.add(const Duration(days: 365)),
      ),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Bill title/description')),
            TextField(controller: _shopCtrl, decoration: const InputDecoration(labelText: 'Store name')),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (SAR)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Purchase date'),
              subtitle: Text(_fmt.format(_purchaseDate)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(context, _purchaseDate, (d) => setState(() => _purchaseDate = d)),
            ),
            ListTile(
              title: const Text('Return deadline'),
              subtitle: Text(_fmt.format(_returnDeadline)),
              trailing: const Icon(Icons.event),
              onTap: () => _pickDate(context, _returnDeadline, (d) => setState(() => _returnDeadline = d)),
            ),
            ListTile(
              title: const Text('Exchange deadline'),
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
                if (v && _warrantyEnd == null) _warrantyEnd = _ocrWarrantyEnd;
              }),
              title: const Text('Has warranty?'),
            ),
            if (_hasWarranty)
              ListTile(
                title: const Text('Warranty end date'),
                subtitle: Text(_warrantyEnd == null ? '—' : _fmt.format(_warrantyEnd!)),
                trailing: const Icon(Icons.verified_user),
                onTap: () => _pickDate(
                  context,
                  _warrantyEnd ?? _ocrWarrantyEnd ?? _purchaseDate,
                      (d) => setState(() => _warrantyEnd = d),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAndAddWarranty,
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Save & add warranty'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
