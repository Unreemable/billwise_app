import 'dart:io';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../data/firestore_service.dart';
import '../../warranties/ui/add_warranty_page.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({
    super.key,
    this.suggestWarranty = false,
    this.prefill,
  });

  static const route = '/add-bill';

  /// يفتح تبويب Warranty تلقائيًا إذا كانت true (قادمة من OCR)
  final bool suggestWarranty;

  /// بيانات قادمة من OCR (اختيارية)
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
    _openWarrantyTabIfDetected();
  }

  void _applyPrefill() {
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

  /// يفتح تبويب الضمان مباشرة إذا اكتشفنا كلمة/معلومات ضمان من OCR
  void _openWarrantyTabIfDetected() {
    final hasOCRWarranty =
        (_prefill?['warrantyMonths'] != null) ||
            (_prefill?['warrantyStart'] != null) ||
            (_prefill?['warrantyExpiry'] != null);

    if (widget.suggestWarranty || hasOCRWarranty) {
      _tab = 1; // افتح تبويب الضمان
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('تم رصد كلمة/معلومات "ضمان" — فتحنا نموذج الضمان تلقائيًا.'),
            duration: Duration(seconds: 3),
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
                  onSave: () async {
                    // ====== حفظ فعلي على Firestore/Storage ======
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يجب تسجيل الدخول')),
                        );
                        return;
                      }
                      final uid = user.uid;

                      // المدخلات
                      final amt = double.tryParse(_amount.text.trim()) ?? 0;
                      final ds = _date.text.trim(); // yyyy-mm-dd
                      if (ds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('رجاءً حددي تاريخ الشراء')),
                        );
                        return;
                      }
                      final parts = ds.split('-');
                      if (parts.length != 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('صيغة التاريخ غير صحيحة')),
                        );
                        return;
                      }
                      final pDate = DateTime(
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                        int.parse(parts[2]),
                      );

                      // إشارات/معلومات الضمان القادمة من OCR
                      final hasWarranty = widget.suggestWarranty ||
                          (_prefill?['warrantyMonths'] != null) ||
                          (_prefill?['warrantyStart'] != null) ||
                          (_prefill?['warrantyExpiry'] != null);

                      final wMonths = _prefill?['warrantyMonths'] as int?;
                      final wStartIso = _prefill?['warrantyStart'] as String?;
                      final wEndIso = _prefill?['warrantyExpiry'] as String?;
                      final wStart = wStartIso != null ? DateTime.tryParse(wStartIso) : null;
                      final wEnd = wEndIso != null ? DateTime.tryParse(wEndIso) : null;

                      // إنشاء Bill + (اختياري) Warranty
                      await FirestoreService.instance.createBillAndMaybeWarrantyFromOCR(
                        uid: uid,
                        purchaseDate: pDate,
                        totalAmount: amt,
                        hasWarranty: hasWarranty,
                        receiptImage: _receiptImage,
                        warrantyMonths: wMonths,
                        warrantyStart: wStart ?? pDate,
                        warrantyEnd: wEnd ??
                            (wMonths != null
                                ? DateTime(pDate.year, pDate.month + wMonths, pDate.day)
                                : null),
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ الفاتورة بنجاح')),
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذّر الحفظ: $e')),
                      );
                    }
                  },
                )
                    : AddWarrantyPage(
                  embedded: true,
                  prefill: {
                    'warrantyMonths': _prefill?['warrantyMonths'],
                    'warrantyStart': _prefill?['warrantyStart'],
                    'warrantyExpiry': _prefill?['warrantyExpiry'],
                  },
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
