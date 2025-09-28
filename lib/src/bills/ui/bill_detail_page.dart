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

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  late BillDetails _d;
  final _money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);

  DateTime? get _primaryEnd =>
      _d.returnDeadline ?? _d.exchangeDeadline ?? _d.warrantyExpiry;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
  }

  String _pretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  String _ymd(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ===== Actions =====

  Future<void> _deleteBill() async {
    if (_d.id == null) return;

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
      await FirebaseFirestore.instance.collection('Bills').doc(_d.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _openEditSheet() async {
    if (_d.id == null) return;

    final titleCtrl   = TextEditingController(text: _d.title);
    final productCtrl = TextEditingController(text: _d.product ?? '');
    final amountCtrl  = TextEditingController(
      text: _d.amount == null ? '' : _d.amount!.toStringAsFixed(2),
    );

    DateTime purchase = _d.purchaseDate;
    DateTime? ret = _d.returnDeadline;
    DateTime? exc = _d.exchangeDeadline;
    DateTime? wEnd = _d.warrantyExpiry;

    Future<void> pickDate(BuildContext ctx, DateTime? initial, void Function(DateTime?) assign) async {
      final now = DateTime.now();
      final base = initial ?? purchase;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: base,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) assign(DateTime(picked.year, picked.month, picked.day));
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              Widget dateRow(String label, DateTime? value, VoidCallback onPick, {VoidCallback? onClear}) {
                return Row(
                  children: [
                    Expanded(child: Text('$label:  ${_ymd(value)}')),
                    IconButton(icon: const Icon(Icons.event), onPressed: onPick),
                    if (onClear != null)
                      IconButton(icon: const Icon(Icons.clear), onPressed: onClear, tooltip: 'Clear'),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Edit bill', style: Theme.of(ctx).textTheme.titleLarge),
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

                    Row(
                      children: [
                        Expanded(child: Text('Purchase date:  ${_ymd(purchase)}')),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            await pickDate(ctx, purchase, (v) => setLocal(() { if (v != null) purchase = v; }));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    dateRow('Return deadline', ret, () async {
                      await pickDate(ctx, ret, (v) => setLocal(() => ret = v));
                    }, onClear: () => setLocal(() => ret = null)),

                    dateRow('Exchange deadline', exc, () async {
                      await pickDate(ctx, exc, (v) => setLocal(() => exc = v));
                    }, onClear: () => setLocal(() => exc = null)),

                    dateRow('Warranty expiry', wEnd, () async {
                      await pickDate(ctx, wEnd, (v) => setLocal(() => wEnd = v));
                    }, onClear: () => setLocal(() => wEnd = null)),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save changes'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      final title   = titleCtrl.text.trim().isEmpty ? '—' : titleCtrl.text.trim();
      final product = productCtrl.text.trim().isEmpty ? null : productCtrl.text.trim();
      final amount  = double.tryParse(amountCtrl.text.trim());

      final payload = <String, dynamic>{
        'title': title,
        'shop_name': product,
        'total_amount': amount,
        'purchase_date': Timestamp.fromDate(purchase),
        'return_deadline': ret == null ? null : Timestamp.fromDate(ret!),
        'exchange_deadline': exc == null ? null : Timestamp.fromDate(exc!),
        'warranty_end_date': wEnd == null ? null : Timestamp.fromDate(wEnd!),
      };

      try {
        await FirebaseFirestore.instance.collection('Bills').doc(_d.id).update(payload);

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
            warrantyExpiry: wEnd,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }

    titleCtrl.dispose();
    productCtrl.dispose();
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          title: const Text('Bill'),
          actions: const [
            _LogoStub(), // اللوقو فوق
          ],
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (_primaryEnd != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Expires ${_pretty(_primaryEnd!)}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

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

                    const SizedBox(height: 6),
                    _kv('Product/Store', _d.product ?? '—'),
                    _kv('Amount', _d.amount == null ? '—' : _money.format(_d.amount)),
                    _kv('Purchase date', _ymd(_d.purchaseDate)),
                    if (_d.returnDeadline != null) _kv('Return deadline', _ymd(_d.returnDeadline)),
                    if (_d.exchangeDeadline != null) _kv('Exchange deadline', _ymd(_d.exchangeDeadline)),
                    if (_d.warrantyExpiry != null) _kv('Warranty expiry', _ymd(_d.warrantyExpiry)),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ===== زرار Edit + Delete تحت يمين =====
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'billEditFab',
              onPressed: _openEditSheet,
              tooltip: 'Edit',
              child: const Icon(Icons.edit),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'billDeleteFab',
              onPressed: _deleteBill,
              tooltip: 'Delete',
              child: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== small reusable bits =====

class _LogoStub extends StatelessWidget {
  const _LogoStub();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('B', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
        Text('ill Wise', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
      ],
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 160, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v)),
    ],
  ),
);

Widget _section({
  required String title,
  required DateTime start,
  required DateTime end,
  required bool months,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ExpiryProgress(
        title: title,
        startDate: start,
        endDate: end,
        showInMonths: months,
        dense: true,
      ),
    ],
  );
}
