import 'dart:io';
import 'package:flutter/material.dart';
import '../../warranties/ui/add_warranty_page.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({
    super.key,
    this.suggestWarranty = false,
    this.prefill,
  });

  static const route = '/add-bill';

  /// يظهر تبويب الـ Warranty تلقائيًا عند وجود كلمات (warranty/ضمان/…)
  final bool suggestWarranty;

  /// بيانات قادمة من OCR (اختيارية):
  /// {
  ///   'store': String?,
  ///   'amount': double? | String?,
  ///   'date': String? (ISO8601),
  ///   'warrantyMonths': int?,
  ///   'warrantyStart': String? (ISO8601),
  ///   'warrantyExpiry': String? (ISO8601),
  ///   'imagePath': String?,
  ///   'rawText': String?
  /// }
  final Map<String, dynamic>? prefill;

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  int _tab = 0; // 0 = Bill, 1 = Warranty

  final _store = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();

  File? _receiptImage;
  Map<String, dynamic>? _prefill;

  @override
  void initState() {
    super.initState();
    _applyPrefill();
    _maybeSuggestWarranty();
  }

  void _applyPrefill() {
    // خزّن نسخة قابلة للاستخدام
    _prefill = widget.prefill;

    final p = _prefill;
    if (p == null) return;

    // المتجر
    final store = p['store'] as String?;
    if (store != null && store.trim().isNotEmpty) {
      _store.text = store.trim();
    }

    // المبلغ
    final amount = p['amount'];
    if (amount != null) {
      if (amount is num) {
        _amount.text = amount.toString();
      } else if (amount is String && amount.trim().isNotEmpty) {
        _amount.text = amount.trim();
      }
    }

    // التاريخ
    final dateIso = p['date'] as String?;
    if (dateIso != null && dateIso.isNotEmpty) {
      // نعرضه بصيغة yyyy-mm-dd
      final date = DateTime.tryParse(dateIso);
      if (date != null) {
        _date.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    }

    // صورة الفاتورة
    final imagePath = p['imagePath'] as String?;
    if (imagePath != null && imagePath.isNotEmpty) {
      _receiptImage = File(imagePath);
    }
  }

  void _maybeSuggestWarranty() {
    // أي دليل على وجود ضمان → اقترح الانتقال لتبويب الضمان
    final hasOCRWarranty =
        (_prefill?['warrantyMonths'] != null) ||
            (_prefill?['warrantyStart'] != null) ||
            (_prefill?['warrantyExpiry'] != null);

    if (widget.suggestWarranty || hasOCRWarranty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('تم رصد معلومات/كلمة "ضمان" — هل تريدين تعبئة نموذج الضمان؟'),
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'تاريخ الشراء',
    );
    if (picked != null) {
      _date.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
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
                child: _tab == 0
                    ? _BillForm(
                  store: _store,
                  amount: _amount,
                  date: _date,
                  onPickDate: _pickDate,
                  receiptImage: _receiptImage,
                  onSave: () {
                    // TODO: ربط الحفظ بقاعدة البيانات/Storage إذا رغبت
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ الفاتورة (تجريبي).')),
                    );
                  },
                )
                    : AddWarrantyPage(
                  embedded: true,
                  // نمرّر prefill بسيطًا عبر الحقول النصية (اختياري لاحقًا)
                ),
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
  final VoidCallback onPickDate;
  final File? receiptImage;
  final VoidCallback onSave;

  const _BillForm({
    required this.store,
    required this.amount,
    required this.date,
    required this.onPickDate,
    required this.onSave,
    this.receiptImage,
  });

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
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'المبلغ',
            prefixIcon: Icon(Icons.attach_money),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: date,
          readOnly: true,
          onTap: onPickDate,
          decoration: const InputDecoration(
            labelText: 'تاريخ الشراء',
            prefixIcon: Icon(Icons.event),
          ),
        ),
        if (receiptImage != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              receiptImage!,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
        ),
      ],
    );
  }
}
