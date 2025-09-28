import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

class WarrantyDetailPage extends StatefulWidget {
  const WarrantyDetailPage({super.key, required this.details});
  static const route = '/warranty-detail';

  final WarrantyDetails details;

  @override
  State<WarrantyDetailPage> createState() => _WarrantyDetailPageState();
}

class _WarrantyDetailPageState extends State<WarrantyDetailPage> {
  late WarrantyDetails _d;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
  }

  String _fmtPretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  String _ymd(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===== Delete =====
  Future<void> _deleteWarranty() async {
    if (_d.id == null || _d.id!.isEmpty) {
      _toast('Missing document id.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete warranty?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('Warranties').doc(_d.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  // ===== Edit =====
  Future<void> _openEditSheet() async {
    if (_d.id == null || _d.id!.isEmpty) {
      _toast('Missing document id.');
      return;
    }

    final titleCtrl   = TextEditingController(text: _d.title);
    final productCtrl = TextEditingController(text: _d.product);
    DateTime start = DateTime(_d.warrantyStart.year, _d.warrantyStart.month, _d.warrantyStart.day);
    DateTime end   = DateTime(_d.warrantyExpiry.year, _d.warrantyExpiry.month, _d.warrantyExpiry.day);

    Future<void> pickDate(BuildContext ctx, DateTime initial, void Function(DateTime) assign) async {
      final picked = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
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
            left: 16, right: 16, top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Edit warranty', style: Theme.of(ctx).textTheme.titleLarge),
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
                        labelText: 'Product / Provider',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: Text('Start date:  ${_ymd(start)}')),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            await pickDate(ctx, start, (v) => setLocal(() => start = v));
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text('Expiry date:  ${_ymd(end)}')),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            await pickDate(ctx, end, (v) => setLocal(() => end = v));
                          },
                        ),
                      ],
                    ),

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
      final product = productCtrl.text.trim().isEmpty ? 'Warranty' : productCtrl.text.trim();

      final payload = <String, dynamic>{
        'title'      : title,
        'provider'   : product,
        'start_date' : Timestamp.fromDate(start),
        'end_date'   : Timestamp.fromDate(end),
      };

      try {
        await FirebaseFirestore.instance.collection('Warranties').doc(_d.id).update(payload);

        setState(() {
          _d = WarrantyDetails(
            id: _d.id,
            title: title,
            product: product,
            warrantyStart: start,
            warrantyExpiry: end,
            returnDeadline: _d.returnDeadline,
            reminderDate: _d.reminderDate,
          );
        });

        _toast('Saved successfully');
      } catch (e) {
        _toast('Save failed: $e');
      }
    }

    titleCtrl.dispose();
    productCtrl.dispose();
  }

  // ===== UI =====
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
          title: const Text('Warranty'),
          actions: const [
            _LogoStub(), // هنا يظهر اللوقو يمين العنوان
          ],
        ),

        // زرين تحت يمين
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'fabEditWarranty',
              onPressed: _openEditSheet,
              tooltip: 'Edit',
              child: const Icon(Icons.edit),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.small(
              heroTag: 'fabDeleteWarranty',
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              onPressed: _deleteWarranty,
              tooltip: 'Delete',
              child: const Icon(Icons.delete_outline),
            ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Expires ${_fmtPretty(_d.warrantyExpiry)}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress (months)
                    ExpiryProgress(
                      title: 'Warranty status',
                      startDate: _d.warrantyStart,
                      endDate: _d.warrantyExpiry,
                      showInMonths: true,
                    ),

                    const SizedBox(height: 18),

                    _kv('Product', _d.product),
                    _kv('Warranty start date', _ymd(_d.warrantyStart)),
                    _kv('Warranty expiry date', _ymd(_d.warrantyExpiry)),
                    if (_d.returnDeadline != null)
                      _kv('Return deadline', _ymd(_d.returnDeadline)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== small reusable bits
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
class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'B',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        Text(
          'ill Wise',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
