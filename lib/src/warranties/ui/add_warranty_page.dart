import 'package:flutter/material.dart';

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({super.key, this.embedded = false});
  static const route = '/add-warranty';

  /// لو كانت داخل AddBillPage نعرض زر حفظ فقط بدون AppBar مستقل
  final bool embedded;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  final _product = TextEditingController();
  final _purchaseDate = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _duration = ValueNotifier<int>(12);
  final _expiry = TextEditingController();
  final _billNumber = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _product.dispose();
    _purchaseDate.dispose();
    _warrantyStart.dispose();
    _expiry.dispose();
    _billNumber.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, String help) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: help,
    );
    if (picked != null) {
      ctrl.text = '${picked.year}-${picked.month}-${picked.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _product,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purchaseDate,
          readOnly: true,
          onTap: () => _pickDate(_purchaseDate, 'Date of Purchase'),
          decoration: const InputDecoration(
            labelText: 'Date of Purchase',
            prefixIcon: Icon(Icons.event),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _warrantyStart,
          readOnly: true,
          onTap: () => _pickDate(_warrantyStart, 'Warranty Start Date'),
          decoration: const InputDecoration(
            labelText: 'Warranty Start Date',
            prefixIcon: Icon(Icons.event_available),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _duration,
          builder: (_, months, __) => Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: months,
                  items: const [6, 12, 24, 36]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m أشهر')))
                      .toList(),
                  onChanged: (v) => _duration.value = v ?? 12,
                  decoration: const InputDecoration(
                    labelText: 'Warranty Duration',
                    prefixIcon: Icon(Icons.timelapse),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _expiry,
                  readOnly: true,
                  onTap: () => _pickDate(_expiry, 'Expiry Date'),
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    prefixIcon: Icon(Icons.event_busy),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _billNumber,
          decoration: const InputDecoration(
            labelText: 'Bill Number (optional)',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {/* لاحقًا: حفظ الضمان */},
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Warranty Information')),
        body: content,
      ),
    );
  }
}
