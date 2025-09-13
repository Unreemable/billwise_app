import 'package:flutter/material.dart';

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    this.embedded = false,
    this.prefill,
  });

  static const route = '/add-warranty';

  /// لو كانت داخل AddBillPage نعرض المحتوى بدون AppBar.
  final bool embedded;

  /// قيم جاهزة من OCR:
  /// {
  ///   'warrantyMonths': int?,
  ///   'warrantyStart': String? (ISO8601),
  ///   'warrantyExpiry': String? (ISO8601),
  ///   'purchaseDate': String? (ISO8601), // اختياري
  ///   'productName': String?            // اختياري
  /// }
  final Map<String, dynamic>? prefill;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  final _product = TextEditingController();
  final _purchaseDate = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _expiry = TextEditingController();
  final _billNumber = TextEditingController();
  final _notes = TextEditingController();
  final _months = ValueNotifier<int>(12);

  @override
  void initState() {
    super.initState();
    _applyPrefill();
  }

  @override
  void dispose() {
    _product.dispose();
    _purchaseDate.dispose();
    _warrantyStart.dispose();
    _expiry.dispose();
    _billNumber.dispose();
    _notes.dispose();
    _months.dispose();
    super.dispose();
  }

  // ========== Helpers ==========
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseYmd(String v) {
    if (v.isEmpty) return null;
    final p = v.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  void _recalcExpiry() {
    final start = _parseYmd(_warrantyStart.text);
    if (start == null) return;
    final m = _months.value;
    final end = DateTime(start.year, start.month + m, start.day);
    _expiry.text = _fmt(end);
  }

  void _applyPrefill() {
    final p = widget.prefill;
    if (p == null) return;

    // product (اختياري)
    final prod = p['productName'] as String?;
    if (prod != null && prod.trim().isNotEmpty) _product.text = prod.trim();

    // purchase date (اختياري)
    final pd = p['purchaseDate'] as String?;
    final pdDt = pd != null ? DateTime.tryParse(pd) : null;
    if (pdDt != null) _purchaseDate.text = _fmt(pdDt);

    // months
    final m = p['warrantyMonths'];
    if (m is int && m > 0) _months.value = m;

    // start/end
    final s = p['warrantyStart'] as String?;
    final e = p['warrantyExpiry'] as String?;

    final sDt = s != null ? DateTime.tryParse(s) : null;
    final eDt = e != null ? DateTime.tryParse(e) : null;

    if (sDt != null) _warrantyStart.text = _fmt(sDt);
    if (eDt != null) {
      _expiry.text = _fmt(eDt);
    } else if (sDt != null) {
      // احسب الانتهاء من البداية + الأشهر (إن ما وصل expiry جاهز)
      final end = DateTime(sDt.year, sDt.month + _months.value, sDt.day);
      _expiry.text = _fmt(end);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl, String help) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseYmd(ctrl.text) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: help,
    );
    if (picked != null) {
      ctrl.text = _fmt(picked);
      if (ctrl == _warrantyStart) _recalcExpiry();
    }
  }

  // ========== UI ==========
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
          valueListenable: _months,
          builder: (_, months, __) => Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: months,
                  items: const [6, 12, 24, 36]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m أشهر')))
                      .toList(),
                  onChanged: (v) {
                    _months.value = v ?? 12;
                    _recalcExpiry();
                  },
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
          onPressed: () {
            // TODO: اربطي الحفظ بالفايرستور وربطه بالـ bill_id إذا فتحتيه من الفاتورة
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حفظ الضمان (تجريبي).')),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
        ),
      ],
    );

    if (widget.embedded) return Directionality(textDirection: TextDirection.rtl, child: content);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Warranty Information')),
        body: content,
      ),
    );
  }
}
