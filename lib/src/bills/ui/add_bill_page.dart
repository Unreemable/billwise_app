import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../warranties/ui/add_warranty_page.dart';
import '../data/bill_service.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({
    super.key,
    this.billId,                // تعديل إن وجد
    this.prefill,               // بيانات OCR (للإضافة)
    this.suggestWarranty = false,
  });

  static const route = '/add-bill';

  final String? billId;
  final Map<String, dynamic>? prefill;
  final bool suggestWarranty;

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _titleCtrl  = TextEditingController();
  final _shopCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();

  // التواريخ (nullable في الإضافة اليدوية)
  DateTime? _purchaseDate;
  DateTime? _returnDeadline;
  DateTime? _exchangeDeadline;

  // سويتش فقط — بدون حقول تواريخ للضمان في هذه الصفحة
  bool _hasWarranty = false;

  // من OCR فقط لاستخدامها كتاريخ افتراضي في صفحة الضمان
  DateTime? _ocrWarrantyStart;
  DateTime? _ocrWarrantyEnd;

  // أيام السياسات المستنتجة من OCR
  int? _retDays; // الاسترجاع
  int? _exDays;  // الاستبدال

  // المرفق
  final _picker = ImagePicker();
  String? _receiptImagePath;

  final _fmt = DateFormat('yyyy-MM-dd');
  bool _saving = false;

  // تحميل فاتورة موجودة (وضع التعديل)
  bool _loadingExisting = false;

  // فحص وجود ضمان مرتبط بهذه الفاتورة (في وضع التعديل)
  bool _checkingWarranty = false;
  bool _hasExistingWarranty = false;

  // ================= Helpers =================
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final d = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (d == null) return null;
    if (d.year < 2015 || d.year > 2100) return null; // حماية
    return d;
  }

  num? _parseAmount(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    return num.tryParse(s);
  }

  int? _extractDays(dynamic v) {
    if (v == null) return null;
    var normalized = v.toString().trim();

    // تحويل أرقام عربية
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < eastern.length; i++) {
      normalized = normalized.replaceAll(eastern[i], i.toString());
    }

    final lower = normalized.toLowerCase();
    final m = RegExp(r'(\d{1,3})\s*(day|days|يوم|يوماً|يوما|ايام|أيام)', caseSensitive: false)
        .firstMatch(lower);
    if (m != null) return int.tryParse(m.group(1)!);

    if (RegExp(r'(يومان|يومين)').hasMatch(lower)) return 2;
    if (RegExp(r'\b(a day)\b').hasMatch(lower)) return 1;
    if (RegExp(r'(يوم|يوماً|يوما)').hasMatch(lower)) return 1;

    return int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  // يحسب الديدلاين ويشمل يوم الشراء (31/03 + 3 أيام ⇒ 02/04)
  DateTime _deadlineFrom(DateTime start, int days, {bool includeStart = true}) {
    final base = DateTime(start.year, start.month, start.day);
    final add = includeStart ? (days - 1) : days;
    return base.add(Duration(days: add));
  }

  String _fmtOrDash(DateTime? d) => d == null ? '—' : _fmt.format(d);

  // ================= تحميل/دمج البيانات =================
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // لو في billId = تعديل → حمّل الفاتورة وتوقف عن استخدام prefill
    if (widget.billId != null && !_loadingExisting) {
      _loadExisting(widget.billId!);
      return;
    }

    // في حالة الإضافة فقط: دمج prefill من constructor أو من Route args
    if (widget.billId == null) {
      _applyPrefillOnce();
    }
  }

  Future<void> _loadExisting(String billId) async {
    setState(() {
      _loadingExisting = true;
      _checkingWarranty = true;
    });
    try {
      final data = await BillService.instance.getBill(billId);
      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill not found')),
        );
        Navigator.of(context).pop();
        return;
      }

      // تعبئة الحقول الأساسية فقط
      _titleCtrl.text  = (data['title'] ?? '').toString();
      _shopCtrl.text   = (data['shop_name'] ?? '').toString();
      final amount     = data['total_amount'];
      if (amount != null) _amountCtrl.text = amount.toString();

      _purchaseDate     = (data['purchase_date'] as Timestamp?)?.toDate();
      _returnDeadline   = (data['return_deadline'] as Timestamp?)?.toDate();
      _exchangeDeadline = (data['exchange_deadline'] as Timestamp?)?.toDate();

      _hasWarranty      = (data['warranty_coverage'] as bool?) ?? false;
      _receiptImagePath = (data['receipt_image_path'] as String?);

      // ✅ فحص هل يوجد Warranty مرتبط بهذه الفاتورة
      final snap = await FirebaseFirestore.instance
          .collection('Warranties')
          .where('bill_id', isEqualTo: billId)
          .limit(1)
          .get();
      _hasExistingWarranty = snap.docs.isNotEmpty;

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bill: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingExisting = false;
          _checkingWarranty = false;
        });
      }
    }
  }

  bool _prefillApplied = false;
  void _applyPrefillOnce() {
    if (_prefillApplied) return;
    _prefillApplied = true;

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

    // تواريخ
    _purchaseDate     ??= _parseDate(prefill['purchaseDate']);
    _returnDeadline   ??= _parseDate(prefill['returnDeadline']);
    _exchangeDeadline ??= _parseDate(prefill['exchangeDeadline']);

    // سياسات مستخرجة من OCR
    _retDays ??= _extractDays(prefill['returnDays'] ?? prefill['returnPolicy'] ?? prefill['return_text'] ?? prefill['return'] ?? prefill['policy']);
    _exDays  ??= _extractDays(prefill['exchangeDays'] ?? prefill['exchangePolicy'] ?? prefill['exchange_text'] ?? prefill['exchange'] ?? prefill['policy']);

    if (_purchaseDate != null) {
      if (_retDays != null && _returnDeadline == null) {
        _returnDeadline = _deadlineFrom(_purchaseDate!, _retDays!, includeStart: true);
      }
      if (_exDays != null && _exchangeDeadline == null) {
        _exchangeDeadline = _deadlineFrom(_purchaseDate!, _exDays!, includeStart: true);
      }
    }

    // الضمان من OCR (للتواريخ الافتراضية لاحقًا في صفحة الضمان فقط)
    _ocrWarrantyStart = _parseDate(prefill['warrantyStart']);
    _ocrWarrantyEnd   = _parseDate(prefill['warrantyEnd']);

    // صورة
    final path = (prefill['receiptPath'] ?? '') as String;
    if (path.isNotEmpty) _receiptImagePath = path;

    // تفعيل الضمان تلقائيًا لو طلبنا
    if (suggestWarranty && !_hasWarranty) {
      _hasWarranty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty detected from OCR')),
        );
      });
    }

    setState(() {});
  }

  // ================= Pickers =================
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

  // ================= Save / Update / Delete =================
  Future<String?> _saveNewBill() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      return null;
    }

    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty  ||
        _amountCtrl.text.trim().isEmpty||
        _purchaseDate == null          ||
        _returnDeadline == null        ||
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

    setState(() => _saving = true);
    try {
      final id = await BillService.instance.createBill(
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        totalAmount: amount,
        returnDeadline: _returnDeadline!,
        exchangeDeadline: _exchangeDeadline!,
        warrantyCoverage: _hasWarranty, // فقط العلم
        userId: uid,
        receiptImagePath: _receiptImagePath,
      );
      if (!mounted) return id;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill saved ✅')),
      );
      return id;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateBill() async {
    if (widget.billId == null) return;

    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty  ||
        _amountCtrl.text.trim().isEmpty||
        _purchaseDate == null          ||
        _returnDeadline == null        ||
        _exchangeDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await BillService.instance.updateBill(
        billId: widget.billId!,
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        totalAmount: amount,
        returnDeadline: _returnDeadline!,
        exchangeDeadline: _exchangeDeadline!,
        warrantyCoverage: _hasWarranty, // فقط العلم
        // لا نمرّر تواريخ ضمان من صفحة الفاتورة
        receiptImagePath: _receiptImagePath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill updated ✅')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBill() async {
    if (widget.billId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete bill?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BillService.instance.deleteBill(widget.billId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill deleted ✅')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (widget.billId == null) {
      final id = await _saveNewBill();
      if (id != null && mounted) Navigator.of(context).pop();
    } else {
      await _updateBill();
    }
  }

  Future<void> _saveAndAddWarranty() async {
    // في وضع التعديل: لا تسمح بإضافة ضمان جديد إذا كان موجود مسبقًا
    if (widget.billId != null && _hasExistingWarranty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A warranty already exists for this bill.')),
      );
      return;
    }

    // في التعديل: حدّث ثم افتح صفحة الضمان
    if (widget.billId != null) {
      await _updateBill();
      if (!mounted) return;
      final baseStart = _ocrWarrantyStart ?? _purchaseDate ?? DateTime.now();
      final baseEnd   = _ocrWarrantyEnd   ?? baseStart.add(const Duration(days: 365));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddWarrantyPage(
          billId: widget.billId!,
          defaultStartDate: baseStart,
          defaultEndDate: baseEnd,
        ),
      ));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // إضافة جديدة: أنشئ أولًا
    final newId = await _saveNewBill();
    if (newId == null || !mounted) return;

    final baseStart = _ocrWarrantyStart ?? _purchaseDate ?? DateTime.now();
    final baseEnd   = _ocrWarrantyEnd   ?? baseStart.add(const Duration(days: 365));

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddWarrantyPage(
        billId: newId,
        defaultStartDate: baseStart,
        defaultEndDate: baseEnd,
      ),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  // ================= UI =================
  @override
  void dispose() {
    _titleCtrl.dispose();
    _shopCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.billId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Bill' : 'Add Bill'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _deleteBill,
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
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

            // صورة المرفق
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
                    _receiptImagePath == null ? 'No file' : _receiptImagePath!.split('/').last,
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

            // سويتش فقط — بدون أي حقول للضمان هنا
            SwitchListTile(
              value: _hasWarranty,
              onChanged: (v) => setState(() => _hasWarranty = v),
              title: const Text('Has warranty?'),
            ),

            if (_hasWarranty && isEdit && _checkingWarranty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (_hasWarranty && isEdit && _hasExistingWarranty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'A warranty already exists for this bill.',
                ),
              ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving
                        ? (isEdit ? 'Updating...' : 'Saving...')
                        : (isEdit ? 'Update' : 'Save')),
                  ),
                ),
                const SizedBox(width: 12),
                if (_hasWarranty && !(isEdit && _hasExistingWarranty))
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveAndAddWarranty,
                      icon: const Icon(Icons.verified_user),
                      label: Text(isEdit
                          ? 'Update & add warranty'
                          : 'Save & add warranty'),
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
