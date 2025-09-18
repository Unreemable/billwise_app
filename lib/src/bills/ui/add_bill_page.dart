import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../warranties/ui/add_warranty_page.dart';
import '../data/bill_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({
    super.key,
    this.prefill,                 // ← بيانات اختيارية من OCR
    this.suggestWarranty = false, // ← فعل سويتش الضمان إذا وُجدت نهاية الضمان
  });

  static const route = '/add-bill';

  final Map<String, dynamic>? prefill;
  final bool suggestWarranty;

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _titleCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // التواريخ nullable تبدأ null (الإضافة اليدوية فاضية)
  DateTime? _purchaseDate;
  DateTime? _returnDeadline;
  DateTime? _exchangeDeadline;

  bool _hasWarranty = false;
  DateTime? _warrantyStart; // NEW
  DateTime? _warrantyEnd;

  DateTime? _ocrWarrantyStart;
  DateTime? _ocrWarrantyEnd;

  // NEW: أيام السياسات المستنتجة من نص الفاتورة (OCR)
  int? _retDays; // عدد أيام الاسترجاع
  int? _exDays;  // عدد أيام الاستبدال

  // الصورة
  final _picker = ImagePicker();
  String? _receiptImagePath;

  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;
  bool _warrantySnackShown = false;

  // === Helpers لتنظيف قيم OCR ===
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final d = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (d == null) return null;
    if (d.year < 2015 || d.year > 2100) return null; // حماية DatePicker
    return d;
  }

  num? _parseAmount(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    return num.tryParse(s);
  }

  // NEW: استنتاج عدد الأيام من نص السياسة (يدعم العربية/الإنجليزية والأرقام العربية)
  int? _extractDays(dynamic v) {
    if (v == null) return null;
    var normalized = v.toString().trim();

    // استبدال الأرقام العربية بأرقام إنجليزية
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < eastern.length; i++) {
      normalized = normalized.replaceAll(eastern[i], i.toString());
    }

    final lower = normalized.toLowerCase();

    final m = RegExp(
      r'(\d{1,3})\s*(day|days|يوم|يوماً|يوما|ايام|أيام)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m != null) return int.tryParse(m.group(1)!);

    if (RegExp(r'(يومان|يومين)').hasMatch(lower)) return 2;
    if (RegExp(r'\b(a day)\b').hasMatch(lower)) return 1;
    if (RegExp(r'(يوم|يوماً|يوما)').hasMatch(lower)) return 1;

    return int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  // NEW: حساب الديدلاين مع شمول يوم الشراء
  DateTime _deadlineFrom(DateTime start, int days, {bool includeStart = true}) {
    final base = DateTime(start.year, start.month, start.day);
    final add = includeStart ? (days - 1) : days;
    return base.add(Duration(days: add));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // دمج prefill القادمة من constructor و/أو RouteSettings.arguments
    Map<String, dynamic> prefill = {};
    bool suggestWarranty = widget.suggestWarranty;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final fromArgs = (args['prefill'] as Map?) ?? {};
      prefill = {...prefill, ...fromArgs};
      if (args['suggestWarranty'] == true) suggestWarranty = true;
    }
    if (widget.prefill != null) {
      prefill = {...prefill, ...widget.prefill!};
    }

    // نصوص
    _titleCtrl.text = (prefill['title'] ?? _titleCtrl.text).toString();
    _shopCtrl.text  = (prefill['store'] ?? _shopCtrl.text).toString();

    final amt = _parseAmount(prefill['amount']);
    if (amt != null) _amountCtrl.text = amt.toString();

    // تواريخ الفاتورة
    _purchaseDate     ??= _parseDate(prefill['purchaseDate']);
    _returnDeadline   ??= _parseDate(prefill['returnDeadline']);
    _exchangeDeadline ??= _parseDate(prefill['exchangeDeadline']);

    // سياسات الاسترجاع/الاستبدال
    _retDays ??= _extractDays(
      prefill['returnDays'] ??
          prefill['returnPolicy'] ??
          prefill['return_text'] ??
          prefill['return'] ??
          prefill['policy'],
    );
    _exDays ??= _extractDays(
      prefill['exchangeDays'] ??
          prefill['exchangePolicy'] ??
          prefill['exchange_text'] ??
          prefill['exchange'] ??
          prefill['policy'],
    );

    // احسبي الديدلاين تلقائياً من تاريخ الشراء
    if (_purchaseDate != null) {
      if (_retDays != null && _returnDeadline == null) {
        _returnDeadline = _deadlineFrom(_purchaseDate!, _retDays!, includeStart: true);
      }
      if (_exDays != null && _exchangeDeadline == null) {
        _exchangeDeadline = _deadlineFrom(_purchaseDate!, _exDays!, includeStart: true);
      }
    }

    // تواريخ الضمان من OCR
    _ocrWarrantyStart = _parseDate(prefill['warrantyStart']);
    _ocrWarrantyEnd   = _parseDate(prefill['warrantyEnd']);

    // املئي حقول الضمان إن وُجدت من OCR
    _warrantyStart ??= _ocrWarrantyStart;
    _warrantyEnd   ??= _ocrWarrantyEnd;

    // مسار الصورة
    final path = (prefill['receiptPath'] ?? '') as String;
    if (path.isNotEmpty) _receiptImagePath = path;

    // فعّلي سويتش الضمان تلقائيًا لو طلبنا ذلك
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shopCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
      BuildContext ctx,
      DateTime? initial,
      ValueChanged<DateTime> onPick,
      ) async {
    final min = DateTime(2015);
    final max = DateTime(2100);
    var init = initial ?? DateTime.now();
    if (init.isBefore(min)) init = min;
    if (init.isAfter(max))  init = max;

    final d = await showDatePicker(
      context: ctx,
      initialDate: init,
      firstDate: min,
      lastDate: max,
    );
    if (d != null) onPick(d);
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final x = await _picker.pickImage(source: source, imageQuality: 85);
    if (x != null) setState(() => _receiptImagePath = x.path);
  }

  Future<String?> _saveBillOnly() async {
    // تأكد من تسجيل الدخول
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      return null;
    }

    // حقول مطلوبة
    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty ||
        _amountCtrl.text.trim().isEmpty ||
        _purchaseDate == null ||
        _returnDeadline == null ||
        _exchangeDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
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

    // لو الضمان مفعّل لازم start + end
    if (_hasWarranty && (_warrantyStart == null || _warrantyEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick warranty start & end date')),
      );
      return null;
    }

    setState(() => _saving = true);
    try {
      final id = await BillService.instance.createBill(
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,       // بعد التحقق
        totalAmount: amount,
        returnDeadline: _returnDeadline!,
        exchangeDeadline: _exchangeDeadline!,
        warrantyCoverage: _hasWarranty,
        warrantyStartDate: _warrantyStart,  // NEW
        warrantyEndDate: _warrantyEnd,
        userId: uid,                        // مهم
        receiptImagePath: _receiptImagePath,
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

    final baseStart = _warrantyStart ?? _ocrWarrantyStart ?? _purchaseDate ?? DateTime.now();
    final baseEnd   = _warrantyEnd   ?? _ocrWarrantyEnd   ?? baseStart.add(const Duration(days: 365));

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddWarrantyPage(
        billId: billId,
        defaultStartDate: baseStart,
        defaultEndDate: baseEnd,
      ),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtOrDash(DateTime? d) => d == null ? '—' : _fmt.format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Bill title/description'),
            ),
            TextField(
              controller: _shopCtrl,
              decoration: const InputDecoration(labelText: 'Store name'),
            ),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (SAR)'),
              keyboardType: const TextInputType.numberWithOptions(
                signed: false, decimal: true,
              ),
            ),
            const SizedBox(height: 12),

            // اختيار الصورة ومعاينة الاسم
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickReceipt,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach receipt'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _receiptImagePath == null
                        ? 'No file'
                        : _receiptImagePath!.split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // التواريخ
            ListTile(
              title: const Text('Purchase date'),
              subtitle: Text(_fmtOrDash(_purchaseDate)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(context, _purchaseDate, (d) {
                setState(() {
                  _purchaseDate = d;
                  if (_retDays != null) {
                    _returnDeadline = _deadlineFrom(d, _retDays!, includeStart: true);
                  }
                  if (_exDays != null) {
                    _exchangeDeadline = _deadlineFrom(d, _exDays!, includeStart: true);
                  }
                });
              }),
            ),
            ListTile(
              title: const Text('Return deadline'),
              subtitle: Text(_fmtOrDash(_returnDeadline)),
              trailing: const Icon(Icons.event),
              onTap: () => _pickDate(context, _returnDeadline, (d) {
                setState(() => _returnDeadline = d);
              }),
            ),
            ListTile(
              title: const Text('Exchange deadline'),
              subtitle: Text(_fmtOrDash(_exchangeDeadline)),
              trailing: const Icon(Icons.event_repeat),
              onTap: () => _pickDate(context, _exchangeDeadline, (d) {
                setState(() => _exchangeDeadline = d);
              }),
            ),

            const Divider(),

            SwitchListTile(
              value: _hasWarranty,
              onChanged: (v) => setState(() {
                _hasWarranty = v;
                if (!v) {
                  _warrantyStart = null;
                  _warrantyEnd = null;
                } else {
                  _warrantyStart ??= _ocrWarrantyStart ?? _purchaseDate;
                  _warrantyEnd   ??= _ocrWarrantyEnd   ?? _purchaseDate?.add(const Duration(days: 365));
                }
              }),
              title: const Text('Has warranty?'),
            ),
            if (_hasWarranty) ...[
              ListTile(
                title: const Text('Warranty start date'),
                subtitle: Text(_fmtOrDash(_warrantyStart)),
                trailing: const Icon(Icons.shield_outlined),
                onTap: () => _pickDate(
                  context,
                  _warrantyStart ?? _purchaseDate ?? DateTime.now(),
                      (d) => setState(() => _warrantyStart = d),
                ),
              ),
              ListTile(
                title: const Text('Warranty end date'),
                subtitle: Text(_fmtOrDash(_warrantyEnd)),
                trailing: const Icon(Icons.verified_user),
                onTap: () => _pickDate(
                  context,
                  _warrantyEnd ?? _warrantyStart ?? _purchaseDate ?? DateTime.now(),
                      (d) => setState(() => _warrantyEnd = d),
                ),
              ),
            ],

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
