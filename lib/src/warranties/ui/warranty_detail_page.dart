// ===================== Warranty Details Page (Unified Product Field) =====================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

// ===== Theme Colors =====
const Color _kBgDark = Color(0xFF0E0722);
const Color _kGrad1 = Color(0xFF6C3EFF);
const Color _kGrad3 = Color(0xFF9B5CFF);
const Color _kCard = Color(0x1AFFFFFF);
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

  // unified fields
  String? _product;      // <-- unified product
  String? _serialNumber;
  String? _attachmentName;

  bool _loadingExtra = false;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
    _loadExtraFields();
  }

  // ===== Load extra fields from Firestore =====
  Future<void> _loadExtraFields() async {
    if (_d.id == null) return;

    setState(() => _loadingExtra = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(_d.id)
          .get();

      if (!mounted || !snap.exists) return;

      final data = snap.data()!;

      final product = (data['product'] ?? '').toString().trim();
      final sn = (data['serial_number'] ?? '').toString().trim();
      final att = (data['attachment_name'] ?? '').toString().trim();

      setState(() {
        _product = product.isEmpty ? null : product;
        _serialNumber = sn.isEmpty ? null : sn;
        _attachmentName = att.isEmpty ? null : att;
      });
    } finally {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  String _fmtPretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // ===== Delete warranty =====
  Future<void> _deleteWarranty() async {
    if (_d.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete warranty?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(_d.id)
          .delete();
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  // ====================== EDIT bottom sheet ======================
  Future<void> _openEditSheet() async {
    final titleCtrl = TextEditingController(text: _d.title);

    // unified product
    final productCtrl = TextEditingController(text: _product ?? '');

    final serialCtrl = TextEditingController(text: _serialNumber ?? '');

    DateTime start = _d.warrantyStart;
    DateTime end = _d.warrantyExpiry;

    Future<void> pickDate(
        BuildContext ctx,
        DateTime initial,
        ValueChanged<DateTime> assign,
        ) async {
      final p = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
      );
      if (p != null) assign(p);
    }

    // ==== open modal sheet =====
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _kBgDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Text('Edit warranty',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),

                _GlassField(
                    controller: titleCtrl,
                    label: 'Provider/stor',
                    icon: Icons.text_fields),
                const SizedBox(height: 8),

                // unified product
                _GlassField(
                    controller: productCtrl,
                    label: 'Product',
                    icon: Icons.shopping_bag_outlined),
                const SizedBox(height: 8),

                _GlassField(
                    controller: serialCtrl,
                    label: 'Serial number (optional)',
                    icon: Icons.confirmation_number_outlined),
                const SizedBox(height: 12),

                _GlassRow(
                  left: 'Start date: ${_ymd(start)}',
                  onPick: () async =>
                      pickDate(ctx, start, (v) => setLocal(() => start = v)),
                ),
                const SizedBox(height: 8),

                _GlassRow(
                  left: 'Expiry date: ${_ymd(end)}',
                  onPick: () async =>
                      pickDate(ctx, end, (v) => setLocal(() => end = v)),
                ),
                const SizedBox(height: 16),

                _GradButton(
                    text: 'Save changes',
                    icon: Icons.save,
                    onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          );
        }),
      ),
    );

    if (saved == true) {
      final newTitle =
      titleCtrl.text.trim().isEmpty ? '—' : titleCtrl.text.trim();
      final newProduct =
      productCtrl.text.trim().isEmpty ? 'Unknown product' : productCtrl.text.trim();
      final serial = serialCtrl.text.trim();

      final docRef = FirebaseFirestore.instance
          .collection('Warranties')
          .doc(_d.id);

      await docRef.update({
        'title': newTitle,
        'product': newProduct,
        'start_date': Timestamp.fromDate(start),
        'end_date'  : Timestamp.fromDate(end),
      });

      await docRef.set({
        if (serial.isNotEmpty)
          'serial_number': serial
        else
          'serial_number': FieldValue.delete(),
      }, SetOptions(merge: true));

      setState(() {
        _product = newProduct;
        _serialNumber = serial.isEmpty ? null : serial;
        _d = WarrantyDetails(
          id: _d.id,
          title: newTitle,
          product: newProduct,
          warrantyStart: start,
          warrantyExpiry: end,
          returnDeadline: _d.returnDeadline,
          reminderDate: _d.reminderDate,
        );
      });
    }
  }

  // ==================== UI ====================
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
          flexibleSpace:
          Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
        ),

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
                  children: [
                    // ===== Header row =====
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: Colors.white),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Expires ${_fmtPretty(_d.warrantyExpiry)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ===== Warranty progress bar =====
                    ExpiryProgress(
                      title: 'Warranty status',
                      startDate: _d.warrantyStart,
                      endDate: _d.warrantyExpiry,
                      showInMonths: true,
                    ),

                    const SizedBox(height: 18),

                    // ===== Details fields =====
                    _kv('Product', _product ?? '—'),
                    _kv('Serial number', _serialNumber ?? '—'),
                    _kv('Warranty start date', _ymd(_d.warrantyStart)),
                    _kv('Warranty expiry date', _ymd(_d.warrantyExpiry)),
                    if (_attachmentName != null)
                      _kv('Attachment', _attachmentName!),

                    if (_loadingExtra)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
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

// ================= Helpers =======================

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    children: [
      SizedBox(
        width: 160,
        child: Text(k,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      Expanded(
          child: Text(v, style: const TextStyle(color: Colors.white))),
    ],
  ),
);

// Glass Field
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
  });

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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// Glass Row
class _GlassRow extends StatelessWidget {
  final String left;
  final VoidCallback onPick;

  const _GlassRow({required this.left, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Expanded(
              child:
              Text(left, style: const TextStyle(color: Colors.white))),
          IconButton(
            onPressed: onPick,
            icon: const Icon(Icons.event, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// Gradient Button
class _GradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bgFrom;
  final Color bgTo;
  final VoidCallback onPressed;

  const _GradButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.bgFrom = _kGrad1,
    this.bgTo = _kGrad3,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [bgFrom, bgTo]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
