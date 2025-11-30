// ======================= BILL DETAIL PAGE ===========================

import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

enum _BillOverallStatus {
  active,
  exchangeOnly,
  expired,
}

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  late BillDetails _d;

  final _money = NumberFormat.currency(
    locale: 'en',
    symbol: 'SAR ',
    decimalDigits: 2,
  );

  String? _receiptPath;
  bool _loadingReceipt = false;
  String? _receiptError;

  DateTime? get _primaryEnd =>
      _d.returnDeadline ?? _d.exchangeDeadline ?? _d.warrantyExpiry;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
    _loadReceiptPath();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  _BillOverallStatus get _overallStatus {
    final today = DateTime.now();
    final ret = _d.returnDeadline;
    final exc = _d.exchangeDeadline;

    if (ret == null && exc == null) {
      return _BillOverallStatus.expired;
    }

    if (ret != null &&
        (today.isBefore(ret) || _isSameDay(today, ret))) {
      return _BillOverallStatus.active;
    }

    if (exc != null &&
        (today.isBefore(exc) || _isSameDay(today, exc))) {
      return _BillOverallStatus.exchangeOnly;
    }

    return _BillOverallStatus.expired;
  }

  Widget _buildOverallStatusPill() {
    final status = _overallStatus;

    late Color color;
    late String label;

    switch (status) {
      case _BillOverallStatus.active:
        color = Colors.green;
        label = 'active';
        break;
      case _BillOverallStatus.exchangeOnly:
        color = Colors.orange;
        label = 'exchange only';
        break;
      case _BillOverallStatus.expired:
        color = Colors.red;
        label = 'expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _loadReceiptPath() async {
    if (_d.id == null) return;
    setState(() {
      _loadingReceipt = true;
      _receiptError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Bills')
          .doc(_d.id)
          .get();
      final path = snap.data()?['receipt_image_path'];
      if (mounted && path is String && path.trim().isNotEmpty) {
        setState(() => _receiptPath = path);
      }
    } catch (e) {
      if (mounted) setState(() => _receiptError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReceipt = false);
    }
  }

  Future<void> _openEditSheet() async {
    if (_d.id == null) return;

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => EditBillSheet(d: _d),
    );

    if (result is Map) {
      final title = result['title'] ?? _d.title;
      final product = result['product'];
      final amount = double.tryParse(result['amount'] ?? '');
      final purchase = result['purchase'] as DateTime;
      final ret = result['ret'] as DateTime?;
      final exc = result['exc'] as DateTime?;

      final payload = <String, dynamic>{
        'title': title.trim().isEmpty ? '—' : title.trim(),
        'shop_name': product,
        'total_amount': amount,
        'purchase_date': Timestamp.fromDate(purchase),
        'return_deadline': ret == null ? null : Timestamp.fromDate(ret),
        'exchange_deadline': exc == null ? null : Timestamp.fromDate(exc),
      };

      await FirebaseFirestore.instance
          .collection('Bills')
          .doc(_d.id)
          .update(payload);

      setState(() {
        _d = BillDetails(
          id: _d.id,
          title: title,
          product: product,
          amount: amount,
          purchaseDate: purchase,
          returnDeadline: ret,
          exchangeDeadline: exc,
          hasWarranty: _d.hasWarranty,
          warrantyExpiry: _d.warrantyExpiry,
        );
      });
    }
  }

  Widget _receiptSection() {
    if (_loadingReceipt) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (_receiptError != null) {
      return Text('Failed to load receipt: $_receiptError',
          style: const TextStyle(color: Colors.red));
    }
    if (_receiptPath == null) {
      return const SizedBox.shrink();
    }

    final isNetwork = _receiptPath!.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Receipt image',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openFullScreenReceipt,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isNetwork
                ? Image.network(_receiptPath!, height: 180, fit: BoxFit.cover)
                : Image.file(File(_receiptPath!), height: 180, fit: BoxFit.cover),
          ),
        ),
        TextButton.icon(
          onPressed: _openFullScreenReceipt,
          icon: const Icon(Icons.open_in_full),
          label: const Text('Open'),
        ),
      ],
    );
  }

  void _openFullScreenReceipt() {
    if (_receiptPath == null) return;
    final isNetwork = _receiptPath!.startsWith('http');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: isNetwork
              ? Image.network(_receiptPath!, fit: BoxFit.contain)
              : Image.file(File(_receiptPath!), fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _ymd(DateTime? d) =>
      d == null
          ? '—'
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Bill'),
          actions: const [_LogoStub()],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B0E3E), Color(0xFF0B0B1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              color: const Color(0xFF19142A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _d.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          if (_primaryEnd != null)
                            _buildOverallStatusPill(),
                        ]),
                    const SizedBox(height: 20),

                    if (_d.returnDeadline != null)
                      _section(title: 'Return', start: _d.purchaseDate, end: _d.returnDeadline!, months: false),

                    if (_d.exchangeDeadline != null) ...[
                      const SizedBox(height: 8),
                      _section(title: 'Exchange', start: _d.purchaseDate, end: _d.exchangeDeadline!, months: false),
                    ],

                    if (_d.warrantyExpiry != null) ...[
                      const SizedBox(height: 8),
                      _section(title: 'Warranty', start: _d.purchaseDate, end: _d.warrantyExpiry!, months: true),
                    ],

                    const SizedBox(height: 12),

                    _kv('Product/Store', _d.product ?? '—'),
                    _kv('Amount', _d.amount == null ? '—' : _money.format(_d.amount)),
                    _kv('Purchase date', _ymd(_d.purchaseDate)),
                    if (_d.returnDeadline != null)
                      _kv('Return deadline', _ymd(_d.returnDeadline)),
                    if (_d.exchangeDeadline != null)
                      _kv('Exchange deadline', _ymd(_d.exchangeDeadline)),
                    if (_d.warrantyExpiry != null)
                      _kv('Warranty expiry', _ymd(_d.warrantyExpiry)),

                    _receiptSection(),
                  ],
                ),
              ),
            ),
          ],
        ),

        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openEditSheet,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _deleteBill,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ),

        backgroundColor: const Color(0xFF0E0A1C),
      ),
    );
  }

  Future<void> _deleteBill() async {
    if (_d.id == null) return;

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

    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('Bills')
          .doc(_d.id)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }
}
class EditBillSheet extends StatefulWidget {
  final BillDetails d;
  const EditBillSheet({super.key, required this.d});

  @override
  State<EditBillSheet> createState() => _EditBillSheetState();
}

class _EditBillSheetState extends State<EditBillSheet> {
  late TextEditingController titleCtrl;
  late TextEditingController productCtrl;
  late TextEditingController amountCtrl;

  late DateTime purchase;
  DateTime? ret;
  DateTime? exc;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.d.title);
    productCtrl = TextEditingController(text: widget.d.product ?? '');
    amountCtrl = TextEditingController(
      text: widget.d.amount == null
          ? ''
          : widget.d.amount!.toStringAsFixed(2),
    );

    purchase = widget.d.purchaseDate;
    ret = widget.d.returnDeadline;
    exc = widget.d.exchangeDeadline;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    productCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  Future<void> pickDate(DateTime? initial, void Function(DateTime?) assign) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? purchase,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) assign(DateTime(picked.year, picked.month, picked.day));
    setState(() {});
  }

  Widget dateRow(String label, DateTime? value, VoidCallback onPick, {VoidCallback? onClear}) {
    return Row(
      children: [
        Expanded(child: Text('$label: ${value == null ? "—" : value.toString().split(" ").first}')),
        IconButton(icon: const Icon(Icons.event), onPressed: onPick),
        if (onClear != null)
          IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit bill', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.text_fields),
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: productCtrl,
            decoration: const InputDecoration(
              labelText: 'Product / Store',
              prefixIcon: Icon(Icons.store),
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount (SAR)',
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),

          const SizedBox(height: 12),

          dateRow(
            'Purchase date',
            purchase,
                () => pickDate(purchase, (v) => purchase = v!),
          ),

          dateRow(
            'Return deadline',
            ret,
                () => pickDate(ret, (v) => ret = v),
            onClear: () => setState(() => ret = null),
          ),

          dateRow(
            'Exchange deadline',
            exc,
                () => pickDate(exc, (v) => exc = v),
            onClear: () => setState(() => exc = null),
          ),

          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save changes'),
            onPressed: () {
              Navigator.pop(context, {
                'title': titleCtrl.text.trim(),
                'product': productCtrl.text.trim().isEmpty
                    ? null
                    : productCtrl.text.trim(),
                'amount': amountCtrl.text.trim(),
                'purchase': purchase,
                'ret': ret,
                'exc': exc,
              });
            },
          ),
        ],
      ),
    );
  }
}

class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('B', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          Text('ill Wise', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      SizedBox(
        width: 160,
        child: Text(k,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            )),
      ),
      Expanded(
        child: Text(
          v,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ],
  ),
);

Widget _section({
  required String title,
  required DateTime start,
  required DateTime end,
  required bool months,
}) {
  return ExpiryProgress(
    title: title,
    startDate: start,
    endDate: end,
    showInMonths: months,
    dense: true,
    showTitle: true,
    showStatus: false,
  );
}
