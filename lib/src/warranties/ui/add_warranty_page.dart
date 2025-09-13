import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../warranties/data/warranty_service.dart';
import '../../bills/data/bill_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart'; // لـ Timestamp

class AddWarrantyPage extends StatefulWidget {
  final String billId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;
  const AddWarrantyPage({
    super.key,
    required this.billId,
    this.defaultStartDate,
    this.defaultEndDate,
  });
  static const route = '/add-warranty';

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  final _providerCtrl = TextEditingController(text: 'Jarir');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 365));
  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultStartDate != null) _start = widget.defaultStartDate!;
    if (widget.defaultEndDate != null) _end = widget.defaultEndDate!;
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPick) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) onPick(d);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 1) أنشئ الضمان
      await WarrantyService.instance.createWarranty(
        billId: widget.billId,
        startDate: _start,
        endDate: _end,
        provider: _providerCtrl.text.trim().isEmpty ? 'Unknown' : _providerCtrl.text.trim(),
        // userId: FirebaseAuth.instance.currentUser?.uid,
      );
      // 2) حدّث الفاتورة بملخص الضمان
      await BillService.instance.updateBill(widget.billId, {
        'warranty_coverage': true,
        'warranty_end_date': Timestamp.fromDate(_end),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الضمان ✅')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة ضمان')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _providerCtrl, decoration: const InputDecoration(labelText: 'المزوّد / المتجر')),
            ListTile(
              title: const Text('بداية الضمان'),
              subtitle: Text(_fmt.format(_start)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(_start, (d) => setState(() => _start = d)),
            ),
            ListTile(
              title: const Text('نهاية الضمان'),
              subtitle: Text(_fmt.format(_end)),
              trailing: const Icon(Icons.verified_user),
              onTap: () => _pickDate(_end, (d) => setState(() => _end = d)),
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
