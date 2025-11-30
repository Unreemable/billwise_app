// ===================== Add Warranty Page (OCR-aware + purchaseDate support) =====================
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../data/warranty_service.dart';
import '../../bills/data/bill_service.dart';
import '../../notifications/notifications_service.dart';

// ===== Unified Dark Theme =====
const Color _kBgDark = Color(0xFF0E0722);
const Color _kTextDim = Colors.white70;

// ===== Buttons Colors =====
const Color _accent = Color(0xFF9B5CFF);

// ===== Header Gradient =====
const LinearGradient _kHeaderGrad = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    this.billId,
    this.defaultStartDate,
    this.defaultEndDate,
    this.warrantyId,
    this.initialProvider,
    this.prefillAttachmentPath,
    this.purchaseDate,           // 👈 NEW (from bill)
  });

  static const route = '/add-warranty';

  final String? billId;
  final DateTime? defaultStartDate;   // from OCR
  final DateTime? defaultEndDate;     // from OCR
  final DateTime? purchaseDate;       // from AddBillPage
  final String? warrantyId;
  final String? initialProvider;
  final String? prefillAttachmentPath;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  final _providerCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController(text: '1');

  DateTime? _start;
  DateTime? _end;
  int _years = 1;
  bool _endManual = false;

  final _fmt = DateFormat('yyyy-MM-dd');
  final _picker = ImagePicker();
  final _notifs = NotificationsService.I;

  bool _saving = false;
  bool get isEdit => widget.warrantyId != null;

  String? _attachmentLocalPath;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();

    _providerCtrl.text = (widget.initialProvider ?? '').trim();

    // ============================
    //    🔥 Warranty Start Logic
    // ============================
    // 1) OCR start → استخدمه
    // 2) OCR ما جاب → استخدم purchaseDate من الفاتورة
    // 3) لو ولا واحد → ينتظر المستخدم يختار
    _start = widget.defaultStartDate ??
        widget.purchaseDate ??
        null;

    // ============================
    //    🔥 Warranty End Logic
    // ============================
    if (widget.defaultEndDate != null) {
      // جاي من OCR
      _end = widget.defaultEndDate;
      _endManual = true; // بما إن OCR أعطى تاريخ جاهز
    } else if (_start != null) {
      // نستخدم الحساب التلقائي
      _end = DateTime(_start!.year + _years, _start!.month, _start!.day);
    }

    // Handle attachment
    final p = widget.prefillAttachmentPath;
    if (p != null && p.isNotEmpty) {
      _attachmentLocalPath = p;
      _attachmentName = p.split(Platform.pathSeparator).last;
    }

    if (isEdit) _loadExistingWarranty();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  // Calculate end date
  void _recalcEnd() {
    if (_start == null) return;
    _end = DateTime(_start!.year + _years, _start!.month, _start!.day);
  }

  Future<void> _loadExistingWarranty() async {
    final doc = await FirebaseFirestore.instance
        .collection('Warranties')
        .doc(widget.warrantyId!)
        .get();

    if (!doc.exists) return;
    final d = doc.data()!;

    _providerCtrl.text = (d['provider'] ?? '').toString();
    _productCtrl.text = (d['product'] ?? '').toString();
    _serialCtrl.text = (d['serial_number'] ?? '').toString();

    if (d['start_date'] is Timestamp) {
      _start = d['start_date'].toDate();
    }
    if (d['end_date'] is Timestamp) {
      _end = d['end_date'].toDate();
    }

    if (_start != null && _end != null) {
      _years = _end!.year - _start!.year;
      if (_years < 1) _years = 1;
      if (_years > 10) _years = 10;
      _yearsCtrl.text = _years.toString();
    }

    _attachmentLocalPath = d['attachment_local_path'];
    _attachmentName = d['attachment_name'];

    setState(() {});
  }

  // Pick date
  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPick,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) onPick(d);
  }

  // Pick image
  Future<void> _pickAttachment() async {
    final s = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (s == null) return;

    final x = await _picker.pickImage(source: s, imageQuality: 85);
    if (x != null) {
      setState(() {
        _attachmentLocalPath = x.path;
        _attachmentName = x.path.split(Platform.pathSeparator).last;
      });
    }
  }

  // Save
  Future<void> _save() async {
    if (_start == null) return _msg("Please select start date");
    if (_end == null) return _msg("Please select end date");
    if (_end!.isBefore(_start!)) return _msg("End date must be after start");

    setState(() => _saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final provider = _providerCtrl.text.trim().isEmpty
        ? "Unknown"
        : _providerCtrl.text.trim();

    final product = _productCtrl.text.trim();
    final serial = _serialCtrl.text.trim();

    String id;

    if (isEdit) {
      id = widget.warrantyId!;
      await WarrantyService.instance.updateWarranty(
        id: id,
        provider: provider,
        startDate: _start!,
        endDate: _end!,
      );

      final ref = FirebaseFirestore.instance.collection('Warranties').doc(id);
      await ref.set({
        'product': product.isEmpty ? FieldValue.delete() : product,
        'serial_number': serial.isEmpty ? FieldValue.delete() : serial,
        if (_attachmentLocalPath != null)
          'attachment_local_path': _attachmentLocalPath,
        if (_attachmentName != null)
          'attachment_name': _attachmentName,
      }, SetOptions(merge: true));
    } else {
      id = await WarrantyService.instance.createWarranty(
        billId: widget.billId,
        provider: provider,
        startDate: _start!,
        endDate: _end!,
        userId: uid,
      );

      final ref = FirebaseFirestore.instance.collection('Warranties').doc(id);
      if (product.isNotEmpty) {
        await ref.set({'product': product}, SetOptions(merge: true));
      }
      if (serial.isNotEmpty) {
        await ref.set({'serial_number': serial}, SetOptions(merge: true));
      }
      if (_attachmentLocalPath != null) {
        await ref.set({
          'attachment_local_path': _attachmentLocalPath,
          'attachment_name': _attachmentName,
        }, SetOptions(merge: true));
      }
    }

    // Update bill warranty flags
    if (widget.billId != null) {
      await BillService.instance.updateBill(
        billId: widget.billId!,
        warrantyCoverage: true,
        warrantyStartDate: _start!,
        warrantyEndDate: _end!,
      );
    }

    await _notifs.rescheduleWarrantyReminder(
      warrantyId: id,
      provider: provider,
      start: _start!,
      end: _end!,
    );

    if (!mounted) return;
    _msg(isEdit ? 'Warranty updated' : 'Warranty added');
    Navigator.pop(context);
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ============================ UI ============================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBgDark,

        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(isEdit ? 'Edit Warranty' : 'Add Warranty'),
          foregroundColor: Colors.white,
          flexibleSpace:
          Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _GradBtn(
              text: _saving ? 'Saving...' : (isEdit ? 'Update' : 'Save'),
              icon: Icons.save,
              onTap: _saving ? null : _save,
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _GlassField(
              label: "Provider / Store",
              controller: _providerCtrl,
              icon: Icons.store_outlined,
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Product",
              controller: _productCtrl,
              icon: Icons.shopping_bag_outlined,
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Serial number (optional)",
              controller: _serialCtrl,
              icon: Icons.confirmation_number_outlined,
            ),
            const SizedBox(height: 12),

            // Years
            _yearsField(),

            const SizedBox(height: 12),

            // Attachment
            _attachmentPicker(),

            const SizedBox(height: 12),

            // Start date
            _GlassPicker(
              left: "Warranty start date",
              right: _start == null ? "Select" : _fmt.format(_start!),
              icon: Icons.date_range,
              onTap: () => _pickDate(
                initial: _start ?? DateTime.now(),
                onPick: (d) {
                  setState(() {
                    _start = d;
                    if (!_endManual) _recalcEnd();
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // End date
            _GlassPicker(
              left: "Warranty end date",
              right: _end == null ? "Calculated" : _fmt.format(_end!),
              icon: Icons.verified_user,
              onTap: () => _pickDate(
                initial: _end ?? _start ?? DateTime.now(),
                onPick: (d) {
                  setState(() {
                    _end = d;
                    _endManual = true;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearsField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timelapse, color: Colors.white70),
          const SizedBox(width: 8),
          const Expanded(
            child: Text("Warranty years (1–10)",
                style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _yearsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                setState(() {
                  _years = (n == null || n < 1) ? 1 : (n > 10 ? 10 : n);
                  _yearsCtrl.text = _years.toString();
                  if (!_endManual) _recalcEnd();
                });
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _attachmentPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          _TinyBtn(
            text: "Attach image",
            icon: Icons.attach_file,
            onTap: _pickAttachment,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _attachmentName ??
                  _attachmentLocalPath ??
                  "No image",
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =================== UI Widgets ===================

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
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _GlassPicker extends StatelessWidget {
  final String left;
  final String right;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPicker({
    required this.left,
    required this.right,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(left, style: const TextStyle(color: Colors.white))),
            Text(right, style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _GradBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _GradBtn({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          color: _accent,
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

class _TinyBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _TinyBtn({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
