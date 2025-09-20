import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/warranty_service.dart';
import '../../bills/data/bill_service.dart';

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    required this.billId,
    this.defaultStartDate,
    this.defaultEndDate,
    this.warrantyId,       // لو نبي تعديل
    this.initialProvider,  // اسم مزوّد مبدئي (اختياري)
  });

  static const route = '/add-warranty';

  final String billId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;

  // في حالة التعديل
  final String? warrantyId;
  final String? initialProvider;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  late final TextEditingController _providerCtrl;
  late DateTime _start;
  late DateTime _end;
  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;

  bool get isEdit => widget.warrantyId != null;

  @override
  void initState() {
    super.initState();
    // ما عاد "Jarir" افتراضي، بس نعرض اللي جاي من OCR أو نخلي الحقل فاضي
    _providerCtrl = TextEditingController(
      text: (widget.initialProvider ?? '').trim(),
    );

    _start = widget.defaultStartDate ?? DateTime.now();
    _end   = widget.defaultEndDate   ?? DateTime.now().add(const Duration(days: 365));

    // ضمان أن النهاية بعد/تساوي البداية
    if (_end.isBefore(_start)) {
      _end = _start.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPick,
  }) async {
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in first')),
        );
        return;
      }

      // تأكيد صحة التواريخ
      if (_end.isBefore(_start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date must be on/after start date')),
        );
        return;
      }

      final provider = _providerCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _providerCtrl.text.trim();

      if (isEdit) {
        // تعديل الضمان
        await WarrantyService.instance.updateWarranty(
          id: widget.warrantyId!,
          provider: provider,
          startDate: _start,
          endDate: _end,
        );
      } else {
        // إنشاء الضمان
        await WarrantyService.instance.createWarranty(
          billId: widget.billId,
          startDate: _start,
          endDate: _end,
          provider: provider,
          userId: uid,
        );
      }

      // في الحالتين: حدّث الفاتورة
      await BillService.instance.updateBill(
        billId: widget.billId,
        warrantyCoverage: true,
        warrantyStartDate: _start,
        warrantyEndDate: _end,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Warranty updated ✅' : 'Warranty saved ✅')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!isEdit) return; // أمان
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete warranty?'),
        content: const Text('Are you sure you want to delete this warranty?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      // 1) حذف الضمان
      await WarrantyService.instance.deleteWarranty(widget.warrantyId!);
      // 2) تحديث الفاتورة (تعطيل الضمان ومسح تواريخه)
      await BillService.instance.updateBill(
        billId: widget.billId,
        warrantyCoverage: false,
        warrantyStartDate: null,
        warrantyEndDate: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warranty deleted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Warranty' : 'Add Warranty'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _providerCtrl,
              decoration: const InputDecoration(labelText: 'Provider / Store'),
              textInputAction: TextInputAction.next,
            ),

            ListTile(
              title: const Text('Warranty start date'),
              subtitle: Text(_fmt.format(_start)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(
                initial: _start,
                onPick: (d) => setState(() {
                  _start = d;
                  if (_end.isBefore(_start)) {
                    _end = _start;
                  }
                }),
              ),
            ),

            ListTile(
              title: const Text('Warranty end date'),
              subtitle: Text(_fmt.format(_end)),
              trailing: const Icon(Icons.verified_user),
              onTap: () => _pickDate(
                initial: _end.isBefore(_start) ? _start : _end,
                onPick: (d) => setState(() => _end = d),
              ),
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : (isEdit ? 'Update' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}
