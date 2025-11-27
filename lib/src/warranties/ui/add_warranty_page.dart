// ===================== Add Warranty Page (Unified Product Field) =====================
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

// ===== Unified Colors (same across app) =====
const Color _kBgDark = Color(0xFF0E0722);
const Color _kTextDim = Colors.white70;
const Color _kGrad1 = Color(0xFF6C3EFF);
const Color _kGrad3 = Color(0xFF3E8EFD);

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
  });

  static const route = '/add-warranty';

  final String? billId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;
  final String? warrantyId;
  final String? initialProvider;
  final String? prefillAttachmentPath;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  // ================= Controllers =================
  final _providerCtrl = TextEditingController(); // Provider / Store
  final _productCtrl = TextEditingController();  // Unified Product
  final _serialCtrl = TextEditingController();   // Optional
  final _yearsCtrl = TextEditingController();    // Warranty years

  DateTime? _start;
  DateTime? _end;
  int _years = 1;
  bool _endManual = false;

  final _formatter = DateFormat('yyyy-MM-dd');
  final _picker = ImagePicker();
  final _notifs = NotificationsService.I;

  bool _saving = false;
  bool get isEdit => widget.warrantyId != null;
  bool get hasBill => widget.billId != null;

  String? _attachmentLocalPath;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();

    _providerCtrl.text = (widget.initialProvider ?? '').trim();
    _yearsCtrl.text = '1';

    final path = (widget.prefillAttachmentPath ?? '').trim();
    if (path.isNotEmpty) {
      _attachmentLocalPath = path;
      _attachmentName = path.split(Platform.pathSeparator).last;
    }

    if (isEdit) _loadExistingWarranty();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  // ===== Auto-calc end date =====
  void _recalcEnd() {
    if (_start == null) return;
    _end = DateTime(_start!.year + _years, _start!.month, _start!.day);
  }

  // ===== Load data for editing =====
  Future<void> _loadExistingWarranty() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(widget.warrantyId!)
          .get();
      if (!mounted || !doc.exists) return;
      final data = doc.data()!;

      final provider = (data['provider'] ?? '').toString();
      if (_providerCtrl.text.trim().isEmpty && provider.isNotEmpty) {
        _providerCtrl.text = provider;
      }

      _productCtrl.text = (data['product'] ?? '').toString();
      _serialCtrl.text = (data['serial_number'] ?? '').toString();

      final startTs = data['start_date'];
      final endTs = data['end_date'];
      if (startTs is Timestamp) _start = startTs.toDate();
      if (endTs is Timestamp) _end = endTs.toDate();

      if (_start != null && _end != null) {
        final y = _end!.year - _start!.year;
        if (y >= 1 && y <= 10) {
          _years = y;
          _yearsCtrl.text = y.toString();
        } else {
          _endManual = true;
        }
      }

      final att = (data['attachment_local_path'] ?? '').toString();
      final name = (data['attachment_name'] ?? '').toString();
      if (att.isNotEmpty) {
        _attachmentLocalPath = att;
        _attachmentName = name.isEmpty
            ? att.split(Platform.pathSeparator).last
            : name;
      }

      setState(() {});
    } catch (_) {}
  }

  // ===== Pick image attachment =====
  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;

    final x = await _picker.pickImage(source: source, imageQuality: 85);
    if (x != null) {
      setState(() {
        _attachmentLocalPath = x.path;
        _attachmentName = x.path.split(Platform.pathSeparator).last;
      });
    }
  }

  Future<void> _removeAttachment() async {
    if (isEdit) {
      try {
        await FirebaseFirestore.instance
            .collection('Warranties')
            .doc(widget.warrantyId!)
            .set({
          'attachment_local_path': FieldValue.delete(),
          'attachment_name': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    setState(() {
      _attachmentLocalPath = null;
      _attachmentName = null;
    });
  }

  // ===== Pick date =====
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

  // ===== Save warranty (add or edit) =====
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _snack('Please sign in first');

      if (_start == null) return _snack('Select start date');
      if (_end == null) return _snack('Select end date');

      if (_end!.isBefore(_start!)) {
        return _snack('End date must be after start date');
      }

      final provider = _providerCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _providerCtrl.text.trim();

      final product = _productCtrl.text.trim();
      final serial = _serialCtrl.text.trim();

      late final String warrantyId;

      if (isEdit) {
        warrantyId = widget.warrantyId!;

        await WarrantyService.instance.updateWarranty(
          id: warrantyId,
          provider: provider,
          startDate: _start!,
          endDate: _end!,
        );

        final doc = FirebaseFirestore.instance
            .collection('Warranties')
            .doc(warrantyId);

        await doc.set(
            product.isEmpty
                ? {'product': FieldValue.delete()}
                : {'product': product},
            SetOptions(merge: true));

        await doc.set(
            serial.isEmpty
                ? {'serial_number': FieldValue.delete()}
                : {'serial_number': serial},
            SetOptions(merge: true));

        await doc.set({
          if (_attachmentLocalPath != null)
            'attachment_local_path': _attachmentLocalPath,
          if (_attachmentName != null) 'attachment_name': _attachmentName,
          if (_attachmentLocalPath == null)
            'attachment_local_path': FieldValue.delete(),
          if (_attachmentName == null)
            'attachment_name': FieldValue.delete(),
        }, SetOptions(merge: true));
      } else {
        warrantyId = await WarrantyService.instance.createWarranty(
          billId: widget.billId,
          startDate: _start!,
          endDate: _end!,
          provider: provider,
          userId: uid,
        );

        final doc = FirebaseFirestore.instance
            .collection('Warranties')
            .doc(warrantyId);

        if (product.isNotEmpty) {
          await doc.set({'product': product}, SetOptions(merge: true));
        }
        if (serial.isNotEmpty) {
          await doc.set({'serial_number': serial}, SetOptions(merge: true));
        }
        if (_attachmentLocalPath != null) {
          await doc.set({
            'attachment_local_path': _attachmentLocalPath,
            'attachment_name': _attachmentName,
          }, SetOptions(merge: true));
        }
      }

      if (hasBill) {
        await BillService.instance.updateBill(
          billId: widget.billId!,
          warrantyCoverage: true,
          warrantyStartDate: _start!,
          warrantyEndDate: _end!,
        );
      }

      try {
        await _notifs.rescheduleWarrantyReminder(
          warrantyId: warrantyId,
          provider: provider,
          start: _start!,
          end: _end!,
        );
      } catch (_) {}

      if (!mounted) return;
      _snack(isEdit ? 'Warranty updated' : 'Warranty added');
      Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    try {
      await WarrantyService.instance.deleteWarranty(widget.warrantyId!);
      await _notifs.cancelWarrantyReminder(widget.warrantyId!);
      Navigator.pop(context);
    } catch (_) {}
  }

  void _snack(String m) {
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
          foregroundColor: Colors.white,
          title: Text(isEdit ? 'Edit Warranty' : 'Add Warranty'),
          flexibleSpace:
          Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _saving ? null : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete warranty?'),
                      content: const Text('This cannot be undone.'),
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
                  if (ok == true) _delete();
                },
              ),
          ],
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _GradButton(
              text: _saving ? 'Saving...' : (isEdit ? 'Update' : 'Save'),
              icon: Icons.save,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),

        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (!hasBill)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(.18)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('This warranty is not linked to a bill.',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

              // ===== Provider =====
              _GlassField(
                controller: _providerCtrl,
                label: 'Provider / Store',
                icon: Icons.store_outlined,
              ),
              const SizedBox(height: 12),

              // ===== Unified Product =====
              _GlassField(
                controller: _productCtrl,
                label: 'Product',
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(height: 12),

              // ===== Serial number =====
              _GlassField(
                controller: _serialCtrl,
                label: 'Serial number (optional)',
                icon: Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 12),

              // ===== Years =====
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      child: Text('Warranty years (1–10)',
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
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          setState(() {
                            if (n == null || n <= 0) {
                              _years = 1;
                            } else if (n > 10) {
                              _years = 10;
                              _yearsCtrl.text = '10';
                              _yearsCtrl.selection =
                              const TextSelection.collapsed(offset: 2);
                            } else {
                              _years = n;
                            }
                            if (!_endManual) _recalcEnd();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Attachment =====
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Row(
                  children: [
                    _TinyGradButton(
                      text: 'Attach image',
                      icon: Icons.attach_file,
                      onPressed: _pickAttachment,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _attachmentLocalPath == null
                            ? 'No image'
                            : (_attachmentName ??
                            _attachmentLocalPath!
                                .split(Platform.pathSeparator)
                                .last),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_attachmentLocalPath != null)
                      IconButton(
                        icon:
                        const Icon(Icons.close, color: Colors.white70),
                        onPressed: _removeAttachment,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Start date =====
              _GlassRow(
                left: 'Warranty start date',
                right: _start == null
                    ? 'Select'
                    : _formatter.format(_start!),
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
              const SizedBox(height: 10),

              // ===== End date =====
              _GlassRow(
                left: 'Warranty end date',
                right: _end == null
                    ? 'Calculated'
                    : _formatter.format(_end!),
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
      ),
    );
  }
}

// =================== Reusable Widgets ===================

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

class _GlassRow extends StatelessWidget {
  final String left;
  final String right;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassRow({
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
              child: Text(left, style: const TextStyle(color: Colors.white)),
            ),
            Text(right, style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _GradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kGrad1, _kGrad3]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyGradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _TinyGradButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kGrad1, _kGrad3]),
          borderRadius: BorderRadius.circular(10),
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
