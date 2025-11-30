import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../warranties/ui/add_warranty_page.dart';
import '../data/bill_service.dart';
import '../../notifications/notifications_service.dart';

/// شاشة إضافة / تعديل فاتورة في BillWise
class AddBillPage extends StatefulWidget {
  const AddBillPage({
    super.key,
    this.billId,
    this.prefill,
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
  static const _bg = Color(0xFF0B0B2E);
  static const _card = Color(0xFF171636);
  static const _cardStroke = Color(0x1FFFFFFF);
  static const _textDim = Color(0xFFBFC3D9);
  static const _accent = Color(0xFF8A46F9);
  static const _danger = Color(0xFFEF5350);
  static const _headerGrad = LinearGradient(
    colors: [Color(0xFF0B0B2E), Color(0xFF21124C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final _titleCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  final _notifs = NotificationsService.I;

  DateTime? _purchaseDate;
  DateTime? _returnDeadline;
  DateTime? _exchangeDeadline;

  bool _returnManual = false;
  bool _exchangeManual = false;

  bool _enableReturn = true;
  bool _enableExchange = true;

  bool _hasWarranty = false;
  DateTime? _ocrWarrantyStart;
  DateTime? _ocrWarrantyEnd;

  int? _retDays;
  int? _exDays;

  final _picker = ImagePicker();
  String? _receiptImagePath;

  final _fmt = DateFormat('yyyy-MM-dd');

  bool _saving = false;
  bool _loadingExisting = false;
  bool _checkingWarranty = false;
  bool _hasExistingWarranty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    final d = DateTime.tryParse(v.toString());
    if (d == null) return null;
    if (d.year < 2015 || d.year > 2100) return null;
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

  DateTime _deadlineFrom(DateTime start, int days, {bool includeStart = false}) {
    final base = DateTime(start.year, start.month, start.day);
    final add = includeStart ? (days - 1) : days;
    return base.add(Duration(days: add));
  }

  String _fmtOrDash(DateTime? d) => d == null ? '—' : _fmt.format(d);

  void _applyAutoWindowsFromPurchase(DateTime purchase) {
    final defRet = _retDays ?? 3;
    final defEx = _exDays ?? 7;

    if (!_returnManual) _returnDeadline = _deadlineFrom(purchase, defRet);
    if (!_exchangeManual) _exchangeDeadline = _deadlineFrom(purchase, defEx);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.billId != null && !_loadingExisting) {
      _loadExisting(widget.billId!);
    } else if (widget.billId == null) {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bill not found')));
        Navigator.of(context).pop();
        return;
      }

      _titleCtrl.text = (data['title'] ?? '').toString();
      _shopCtrl.text = (data['shop_name'] ?? '').toString();
      final amount = data['total_amount'];
      if (amount != null) _amountCtrl.text = amount.toString();

      _purchaseDate = _parseDate(data['purchase_date']);
      _returnDeadline = _parseDate(data['return_deadline']);
      _exchangeDeadline = _parseDate(data['exchange_deadline']);

      _returnManual = _returnDeadline != null;
      _exchangeManual = _exchangeDeadline != null;

      _enableReturn = _returnDeadline != null;
      _enableExchange = _exchangeDeadline != null;

      _hasWarranty = (data['warranty_coverage'] as bool?) ?? false;
      _receiptImagePath = (data['receipt_image_path'] as String?);

      final snap = await FirebaseFirestore.instance
          .collection('Warranties')
          .where('bill_id', isEqualTo: billId)
          .limit(1)
          .get();

      _hasExistingWarranty = snap.docs.isNotEmpty;

      setState(() {});
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _checkingWarranty = false;
      });
    }
  }

  bool _prefillApplied = false;

  /// ============================
  ///   OCR Prefill + أول منتج = عنوان
  ///   + دعم warrantyStart / warrantyEnd
  /// ============================
  void _applyPrefillOnce() {
    if (_prefillApplied) return;
    _prefillApplied = true;

    Map<String, dynamic> prefill = {};
    bool suggestWarranty = widget.suggestWarranty;

    // 1) Prefill from navigation args
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final fromArgs = (args['prefill'] as Map?) ?? {};
      prefill = {...prefill, ...fromArgs};
      if (args['suggestWarranty'] == true) suggestWarranty = true;
    }

    // 2) Prefill from widget
    if (widget.prefill != null) {
      prefill = {...prefill, ...widget.prefill!};
    }

    // ============================
    //  🟣 العنوان = أول منتج
    // ============================
    if (prefill['items'] is List && prefill['items'].isNotEmpty) {
      final first = prefill['items'].first;

      if (first is Map && first['name'] != null) {
        _titleCtrl.text = first['name'].toString();
      } else if (first is String) {
        _titleCtrl.text = first;
      }
    } else {
      _titleCtrl.text = (prefill['title'] ?? _titleCtrl.text).toString();
    }

    // ============================
    //  🟣 المتجر Store name
    // ============================
    _shopCtrl.text = (prefill['store'] ??
        prefill['shop'] ??
        prefill['shop_name'] ??
        '')
        .toString();

    // ============================
    //  🟣 Purchase date
    // ============================
    _purchaseDate ??= _parseDate(prefill['purchase_date']);

    // ============================
    //  🟣 Warranty Start / End
    // ============================
    _ocrWarrantyStart = _parseDate(prefill['warrantyStart']);
    _ocrWarrantyEnd = _parseDate(prefill['warrantyEnd']);

    // لو ما في purchase date → خليها من warrantyStart
    if (_purchaseDate == null && _ocrWarrantyStart != null) {
      _purchaseDate = _ocrWarrantyStart;
    }

    // ============================
    //  🟣 المبلغ Amount
    // ============================
    final amt = _parseAmount(prefill['amount'] ?? prefill['total_amount']);
    if (amt != null) _amountCtrl.text = amt.toString();

    // ============================
    //  🟣 Return / Exchange windows
    // ============================
    _retDays ??= _extractDays(prefill['return_text'] ??
        prefill['return'] ??
        prefill['returnPolicy'] ??
        prefill['policy']);

    _exDays ??= _extractDays(prefill['exchange_text'] ??
        prefill['exchange'] ??
        prefill['exchangePolicy'] ??
        prefill['policy']);

    if (_purchaseDate != null) {
      _returnDeadline ??=
          _deadlineFrom(_purchaseDate!, (_retDays ?? 3));
      _exchangeDeadline ??=
          _deadlineFrom(_purchaseDate!, (_exDays ?? 7));
    }

    // ============================
    //  🟣 Receipt Path
    // ============================
    final path = (prefill['receiptPath'] ?? '') as String;
    if (path.isNotEmpty) _receiptImagePath = path;

    // ============================
    //  🟣 OCR detected warranty
    // ============================
    if (suggestWarranty && !_hasWarranty) {
      _hasWarranty = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty detected from OCR')),
        );
      });
    }

    _enableReturn = _returnDeadline != null;
    _enableExchange = _exchangeDeadline != null;

    setState(() {});
  }


  // ===== Pickers =====

  Future<void> _pickDate(
      BuildContext ctx,
      DateTime? initial,
      ValueChanged<DateTime> onPick,
      ) async {
    final min = DateTime(2015);
    final max = DateTime(2100);

    var init = initial ?? DateTime.now();
    if (init.isBefore(min)) init = min;
    if (init.isAfter(max)) init = max;

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

    final x = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (x != null) {
      setState(() => _receiptImagePath = x.path);
    }
  }
  // ===== منطق الحفظ =====

  Future<String?> _saveNewBill() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      return null;
    }

    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty ||
        _amountCtrl.text.trim().isEmpty ||
        _purchaseDate == null) {
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
      if (_enableReturn) {
        _returnDeadline ??= _deadlineFrom(_purchaseDate!, (_retDays ?? 3));
      }
      if (_enableExchange) {
        _exchangeDeadline ??= _deadlineFrom(_purchaseDate!, (_exDays ?? 7));
      }

      final id = await BillService.instance.createBill(
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        totalAmount: amount,
        returnDeadline: _enableReturn ? _returnDeadline : null,
        exchangeDeadline: _enableExchange ? _exchangeDeadline : null,
        warrantyCoverage: _hasWarranty,
        userId: uid,
        receiptImagePath: _receiptImagePath,
      );

      await _tryRescheduleWithUX(
        billId: id,
        title: _titleCtrl.text.trim(),
        shop: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        returnDeadline: _enableReturn ? _returnDeadline : null,
        exchangeDeadline: _enableExchange ? _exchangeDeadline : null,
      );

      if (!mounted) return id;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bill saved ✅')));

      return id;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateBill() async {
    if (widget.billId == null) return;

    if (_titleCtrl.text.trim().isEmpty ||
        _shopCtrl.text.trim().isEmpty ||
        _amountCtrl.text.trim().isEmpty ||
        _purchaseDate == null) {
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
      if (_enableReturn) {
        _returnDeadline ??= _deadlineFrom(_purchaseDate!, (_retDays ?? 3));
      }
      if (_enableExchange) {
        _exchangeDeadline ??= _deadlineFrom(_purchaseDate!, (_exDays ?? 7));
      }

      await BillService.instance.updateBill(
        billId: widget.billId!,
        title: _titleCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        totalAmount: amount,
        returnDeadline: _enableReturn ? _returnDeadline : null,
        exchangeDeadline: _enableExchange ? _exchangeDeadline : null,
        warrantyCoverage: _hasWarranty,
        receiptImagePath: _receiptImagePath,
      );

      await _tryRescheduleWithUX(
        billId: widget.billId!,
        title: _titleCtrl.text.trim(),
        shop: _shopCtrl.text.trim(),
        purchaseDate: _purchaseDate!,
        returnDeadline: _enableReturn ? _returnDeadline : null,
        exchangeDeadline: _enableExchange ? _exchangeDeadline : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bill updated ✅')));

      Navigator.of(context).pop();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await BillService.instance.deleteBill(widget.billId!);
      await _notifs.cancelBillReminders(widget.billId!);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bill deleted')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    // إذا الفاتورة لها ضمان سابق → لا نسمح بإضافة جديد
    if (widget.billId != null && _hasExistingWarranty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warranty already exists')),
      );
      return;
    }

    // ================================
    //   حالة تعديل فاتورة موجودة
    // ================================
    if (widget.billId != null) {
      await _updateBill();
      if (!mounted) return;

      final baseStart = _ocrWarrantyStart ?? _purchaseDate ?? DateTime.now();
      final baseEnd = _ocrWarrantyEnd ?? baseStart.add(const Duration(days: 365));

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddWarrantyPage(
            billId: widget.billId!,
            defaultStartDate: baseStart,
            defaultEndDate: baseEnd,
            initialProvider: _shopCtrl.text.trim(),

            // 🔥 أهم سطرين — هنا نرسل صورة الفاتورة + تاريخ الشراء
            prefillAttachmentPath: _receiptImagePath,
            purchaseDate: _purchaseDate,
          ),
        ),
      );

      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ================================
    //   حالة إنشاء فاتورة جديدة
    // ================================
    final newId = await _saveNewBill();
    if (newId == null || !mounted) return;

    final baseStart = _ocrWarrantyStart ?? _purchaseDate ?? DateTime.now();
    final baseEnd = _ocrWarrantyEnd ?? baseStart.add(const Duration(days: 365));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWarrantyPage(
          billId: newId,
          defaultStartDate: baseStart,
          defaultEndDate: baseEnd,
          initialProvider: _shopCtrl.text.trim(),

          // 🔥 أيضاً هنا
          prefillAttachmentPath: _receiptImagePath,
          purchaseDate: _purchaseDate,
        ),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _tryRescheduleWithUX({
    required String billId,
    required String title,
    required String shop,
    required DateTime purchaseDate,
    DateTime? returnDeadline,
    DateTime? exchangeDeadline,
  }) async {
    try {
      await _notifs.rescheduleBillReminders(
        billId: billId,
        title: title,
        shop: shop,
        purchaseDate: purchaseDate,
        returnDeadline: returnDeadline,
        exchangeDeadline: exchangeDeadline,
      );
    } catch (e) {
      final msg = e.toString();

      if (!mounted) return;

      if (msg.contains('exact_alarms_not_permitted')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bill saved but system blocked exact alarms.\n'
                  'Settings → Apps → Special access → Alarms & reminders → Allow',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved but notifications failed: $e')));
      }
    }
  }

  InputDecoration _filled(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: const Color(0xFF202048),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: _textDim),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardStroke),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.billId != null;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(isEdit ? 'Edit Bill' : 'Add Bill'),
          actions: [
            if (isEdit)
              IconButton(
                tooltip: 'Delete',
                onPressed: _saving ? null : _deleteBill,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _headerGrad),
          ),
        ),

        body: _loadingExisting
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: ListView(
            children: [
              _sectionCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: _filled('Bill title/description',
                          icon: Icons.text_format),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _shopCtrl,
                      decoration: _filled('Store name',
                          icon: Icons.store),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountCtrl,
                      decoration: _filled('Amount (SAR)',
                          icon: Icons.attach_money),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          onPressed: _pickReceipt,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attach image'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _receiptImagePath == null
                                ? 'No image'
                                : _receiptImagePath!.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _textDim),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Purchase Date Section
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Purchase date',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _fmtOrDash(_purchaseDate),
                        style: const TextStyle(color: Colors.white),
                      ),
                      leading: const Icon(Icons.date_range),
                      trailing: const Icon(Icons.edit_calendar),
                      iconColor: _textDim,
                      textColor: Colors.white,
                      onTap: () =>
                          _pickDate(context, _purchaseDate, (d) {
                            setState(() {
                              _purchaseDate = d;
                              _applyAutoWindowsFromPurchase(d);
                            });
                          }),
                    ),

                    const Divider(height: 12, color: _cardStroke),

                    // Return deadline
                    Row(
                      children: [
                        const Icon(Icons.event, color: _textDim),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Return deadline')),
                        Switch(
                          value: _enableReturn,
                          activeColor: _accent,
                          onChanged: (v) {
                            setState(() {
                              _enableReturn = v;
                              if (v &&
                                  _returnDeadline == null &&
                                  _purchaseDate != null) {
                                _returnDeadline = _deadlineFrom(
                                    _purchaseDate!, (_retDays ?? 3));
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    Opacity(
                      opacity: _enableReturn ? 1 : .5,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _enableReturn
                              ? _fmtOrDash(_returnDeadline)
                              : ' (Optional)',
                          style:
                          const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.edit),
                        iconColor: _textDim,
                        onTap: _enableReturn
                            ? () => _pickDate(
                          context,
                          _returnDeadline ??
                              _purchaseDate ??
                              DateTime.now(),
                              (d) => setState(() {
                            _returnManual = true;
                            _returnDeadline = d;
                          }),
                        )
                            : null,
                        onLongPress: _enableReturn
                            ? () {
                          setState(() {
                            _returnManual = false;
                            _returnDeadline = null;
                          });
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Return deadline cleared')),
                          );
                        }
                            : null,
                      ),
                    ),

                    const Divider(height: 12, color: _cardStroke),

                    // Exchange deadline
                    Row(
                      children: [
                        const Icon(Icons.event_repeat,
                            color: _textDim),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Exchange deadline')),
                        Switch(
                          value: _enableExchange,
                          activeColor: _accent,
                          onChanged: (v) {
                            setState(() {
                              _enableExchange = v;
                              if (v &&
                                  _exchangeDeadline == null &&
                                  _purchaseDate != null) {
                                _exchangeDeadline = _deadlineFrom(
                                    _purchaseDate!,
                                    (_exDays ?? 7));
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    Opacity(
                      opacity: _enableExchange ? 1 : .5,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _enableExchange
                              ? _fmtOrDash(_exchangeDeadline)
                              : ' (Optional)',
                          style:
                          const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.edit),
                        iconColor: _textDim,
                        onTap: _enableExchange
                            ? () => _pickDate(
                          context,
                          _exchangeDeadline ??
                              _purchaseDate ??
                              DateTime.now(),
                              (d) => setState(() {
                            _exchangeManual = true;
                            _exchangeDeadline = d;
                          }),
                        )
                            : null,
                        onLongPress: _enableExchange
                            ? () {
                          setState(() {
                            _exchangeManual = false;
                            _exchangeDeadline = null;
                          });
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                                content: Text('Exchange cleared')),
                          );
                        }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Warranty toggle
              _sectionCard(
                child: SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  value: _hasWarranty,
                  onChanged: (v) =>
                      setState(() => _hasWarranty = v),
                  title: const Text('Has warranty?'),
                  subtitle: (_hasWarranty && widget.billId != null)
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_checkingWarranty)
                        const SizedBox(height: 6),
                      if (_checkingWarranty)
                        const LinearProgressIndicator(
                            minHeight: 2),
                      if (!_checkingWarranty &&
                          _hasExistingWarranty)
                        const Padding(
                          padding:
                          EdgeInsets.only(top: 6),
                          child: Text(
                            'A warranty already exists for this bill.',
                            style:
                            TextStyle(color: _textDim),
                          ),
                        ),
                    ],
                  )
                      : null,
                ),
              ),

              const SizedBox(height: 22),

              // Save buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? (isEdit ? 'Updating…' : 'Saving…')
                            : (isEdit ? 'Update' : 'Save'),
                      ),
                    ),
                  ),

                  if (_hasWarranty &&
                      !(isEdit && _hasExistingWarranty)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF2C2B52),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed:
                        _saving ? null : _saveAndAddWarranty,
                        icon:
                        const Icon(Icons.verified_user),
                        label: Text(
                          isEdit
                              ? 'Update & add'
                              : 'Save & add',
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              if (isEdit)
                TextButton.icon(
                  onPressed: _saving ? null : _deleteBill,
                  icon: const Icon(Icons.delete_outline,
                      color: _danger),
                  label: const Text(
                    'Delete bill',
                    style: TextStyle(color: _danger),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
