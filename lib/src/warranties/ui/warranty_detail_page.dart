import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

// ===== نفس ألوان وستايل الهوم =====
const Color _kBgDark  = Color(0xFF0E0722);
const Color _kGrad1   = Color(0xFF6C3EFF);
const Color _kGrad2   = Color(0xFF934DFE);
const Color _kGrad3   = Color(0xFF3E8EFD);
const Color _kCard    = Color(0x1AFFFFFF);
const Color _kTextDim = Colors.white70;

const LinearGradient _kHeaderGrad = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
      backgroundColor: _kBgDark,
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
                    Text('Edit warranty',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 12),

                    _GlassField(
                      controller: titleCtrl,
                      label: 'Title',
                      icon: Icons.text_fields,
                    ),
                    const SizedBox(height: 8),

                    _GlassField(
                      controller: productCtrl,
                      label: 'Product / Provider',
                      icon: Icons.verified_user_outlined,
                    ),
                    const SizedBox(height: 12),

                    _GlassRow(
                      left: 'Start date:  ${_ymd(start)}',
                      onPick: () async => await pickDate(ctx, start, (v) => setLocal(() => start = v)),
                    ),
                    const SizedBox(height: 8),
                    _GlassRow(
                      left: 'Expiry date:  ${_ymd(end)}',
                      onPick: () async => await pickDate(ctx, end, (v) => setLocal(() => end = v)),
                    ),

                    const SizedBox(height: 16),
                    _GradButton(
                      text: 'Save changes',
                      icon: Icons.save,
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
        backgroundColor: _kBgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Warranty'),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
          actions: const [_LogoStub()],
        ),

        // شريط أزرار عائم متناسق
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _GradButton(
                    text: 'Edit',
                    icon: Icons.edit,
                    onPressed: _openEditSheet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradButton(
                    text: 'Delete',
                    icon: Icons.delete_outline,
                    bgFrom: Colors.redAccent,
                    bgTo: Colors.red,
                    onPressed: _deleteWarranty,
                  ),
                ),
              ],
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // العنوان والشارة
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
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
                                color: Colors.white.withOpacity(.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Expires ${_fmtPretty(_d.warrantyExpiry)}',
                                style: const TextStyle(color: Colors.white),
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

// ===== عناصر واجهة صغيرة متناسقة مع الهوم =====
Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 160,
        child: Text(k, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
    ],
  ),
);

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

// ===== حقول زجاجية وأزرار متدرجة للشيت =====
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _GlassField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _GlassRow extends StatelessWidget {
  final String left;
  final VoidCallback onPick;
  const _GlassRow({required this.left, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      height: 48,
      child: Row(
        children: [
          Expanded(child: Text(left, style: const TextStyle(color: Colors.white))),
          IconButton(
            tooltip: 'Pick date',
            onPressed: onPick,
            icon: const Icon(Icons.event, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color bgFrom;
  final Color bgTo;

  const _GradButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.bgFrom = _kGrad1,
    this.bgTo   = _kGrad3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [bgFrom, bgTo]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: bgTo.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
