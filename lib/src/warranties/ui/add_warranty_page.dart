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


// تم إزالة جميع ثوابت الألوان المخصصة (مثل _kBgDark و _accent و _kHeaderGrad)
// وسنعتمد على Theme.of(context) بالكامل.

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    this.billId,
    this.defaultStartDate,
    this.defaultEndDate,
    this.purchaseDate,
    this.warrantyId,
    this.initialProvider,
    this.prefillAttachmentPath,
    this.prefill,
  });

  static const route = '/add-warranty';

  final String? billId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;
  final DateTime? purchaseDate;
  final String? warrantyId;
  final String? initialProvider;
  final String? prefillAttachmentPath;

  final Map<String, dynamic>? prefill; // ← prefill for EDITING

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

  String? _attachmentLocalPath;
  String? _attachmentName;

  final _fmt = DateFormat('yyyy-MM-dd');
  final _picker = ImagePicker();
  final _notifs = NotificationsService.I;

  bool _saving = false;

  bool get isEdit => widget.warrantyId != null;

  @override
  void initState() {
    super.initState();

    // ---------- Provider ----------
    _providerCtrl.text = (widget.initialProvider ?? '').trim();

    // ---------- DATE LOGIC ----------
    _start = widget.defaultStartDate ?? widget.purchaseDate;

    if (widget.defaultEndDate != null) {
      _end = widget.defaultEndDate;
      _endManual = true;
    } else if (_start != null) {
      _end = DateTime(_start!.year + _years, _start!.month, _start!.day);
    }

    // ---------- Attachment ----------
    if (widget.prefillAttachmentPath != null) {
      _attachmentLocalPath = widget.prefillAttachmentPath!;
      _attachmentName =
          widget.prefillAttachmentPath!.split(Platform.pathSeparator).last;
    }

    // ---------- Load Existing Warranty (if Edit) ----------
    if (isEdit) {
      _loadExistingWarranty();
    }

    // ---------- Prefill from WarrantyDetailPage ----------
    if (widget.prefill != null) {
      final f = widget.prefill!;

      _providerCtrl.text = f['provider'] ?? _providerCtrl.text;
      _productCtrl.text = f['product'] ?? '';
      _serialCtrl.text = f['serial'] ?? '';

      if (f['start'] != null) _start = f['start'];
      if (f['end'] != null) {
        _end = f['end'];
        _endManual = true;
      }

      // Years recalc
      if (_start != null && _end != null) {
        _years = _end!.year - _start!.year;
        _years = _years.clamp(1, 10);
        _yearsCtrl.text = _years.toString();
      }

      if (f['attachment'] != null) {
        _attachmentLocalPath = f['attachment'];
        _attachmentName = f['attachment'].split(Platform.pathSeparator).last;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  // ---------- Load existing warranty ----------
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

    if (d['start_date'] is Timestamp) _start = d['start_date'].toDate();
    if (d['end_date'] is Timestamp) _end = d['end_date'].toDate();

    if (_start != null && _end != null) {
      _years = _end!.year - _start!.year;
      _years = _years.clamp(1, 10);
      _yearsCtrl.text = _years.toString();
    }

    _attachmentLocalPath = d['attachment_local_path'];
    _attachmentName = d['attachment_name'];

    setState(() {});
  }

  // ---------- Date Picker ----------
  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPick,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      // لون الخلفية للـ DatePicker يتم إدارته عبر themeData
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // لضمان أن لون الـ primary color يعمل بشكل جيد في Date Picker
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) onPick(d);
  }

  // ---------- Attachment Picker ----------
  Future<void> _pickAttachment() async {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Scaffold/Container background color will use theme.scaffoldBackgroundColor
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: Text("Camera", style: textStyle),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.iconTheme.color),
              title: Text("Gallery", style: textStyle),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (src == null) return;

    final x = await _picker.pickImage(source: src, imageQuality: 85);
    if (x != null) {
      setState(() {
        _attachmentLocalPath = x.path;
        _attachmentName = x.path.split('/').last;
      });
    }
  }

  // ---------- Save ----------
  Future<void> _save() async {
    if (_start == null) return _msg("Please select start date");
    if (_end == null) return _msg("Please select end date");
    if (_end!.isBefore(_start!)) return _msg("End must be after start");

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

      await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(id)
          .set({
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

      if (product.isNotEmpty)
        await ref.set({'product': product}, SetOptions(merge: true));

      if (serial.isNotEmpty)
        await ref.set({'serial_number': serial}, SetOptions(merge: true));

      if (_attachmentLocalPath != null)
        await ref.set({
          'attachment_local_path': _attachmentLocalPath,
          'attachment_name': _attachmentName,
        }, SetOptions(merge: true));
    }

    // Update bill if linked
    if (widget.billId != null) {
      await BillService.instance.updateBill(
        billId: widget.billId!,
        warrantyCoverage: true,
        warrantyStartDate: _start!,
        warrantyEndDate: _end!,
      );
    }

    // Notifications
    await _notifs.rescheduleWarrantyReminder(
      warrantyId: id,
      provider: provider,
      start: _start!,
      end: _end!,
    );

    if (!mounted) return;
    _msg(isEdit ? "Warranty updated" : "Warranty added ✅");
    Navigator.pop(context, true);
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  // ============================ UI ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // الألوان الديناميكية للحقول (بشكل "زجاجي" خفيف)
    // في الوضع الفاتح، نستخدم لون البطاقة (الأبيض)
    final fieldBgColor = isDark
        ? Colors.white.withOpacity(.06)
        : theme.cardColor;

    // حدود الحقول
    final fieldBorderColor = isDark
        ? Colors.white.withOpacity(.18)
        : theme.primaryColor.withOpacity(0.3);

    // لون النص والأيقونات الخافتة (لـ LabelText و PrefixIcon)
    final dimColor = isDark
        ? Colors.white70
        : Colors.black54;

    // فرض استخدام اللون الأرجواني الثابت للأزرار لضمان ظهورهما (اللون المحدد في ثيمك)
    const accentColor = Color(0xFF6C3EFF); // Purple Brand

    // لون النص الأساسي (للنص المدخل والنص الرئيسي في الـ Pickers)
    final textColor = theme.textTheme.bodyMedium!.color!;

    // لون النص على الزر الأساسي (أبيض ثابت لضمان التباين مع اللون الأرجواني الداكن)
    final onAccentColor = Colors.white;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        // استخدام لون الخلفية من الثيم (scaffoldBackgroundColor)
        backgroundColor: theme.scaffoldBackgroundColor,

        appBar: AppBar(
          // فرض لون خلفية AppBar ليتطابق مع Scaffold
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          // استخدام textColor من الثيم للعنوان وزر الرجوع
          foregroundColor: textColor,
          title: Text(isEdit ? "Edit Warranty" : "Add Warranty"),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            // تمرير accentColor
            child: _GradBtn(
              text: _saving
                  ? "Saving..."
                  : (isEdit ? "Update" : "Save"),
              icon: Icons.save,
              onTap: _saving ? null : _save,
              accentColor: accentColor,
              // تمرير لون النص الذي سيكون على الزر
              onAccentColor: onAccentColor,
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // حقول الإدخال تستخدم _GlassField
            _GlassField(
              label: "Provider / Store",
              controller: _providerCtrl,
              icon: Icons.store_outlined,
              fieldBgColor: fieldBgColor,
              fieldBorderColor: fieldBorderColor,
              dimColor: dimColor,
              textColor: textColor,
            ),
            const SizedBox(height: 12),

            _GlassField(
              label: "Product",
              controller: _productCtrl,
              icon: Icons.shopping_bag_outlined,
              fieldBgColor: fieldBgColor,
              fieldBorderColor: fieldBorderColor,
              dimColor: dimColor,
              textColor: textColor,
            ),
            const SizedBox(height: 12),

            _GlassField(
              label: "Serial number (optional)",
              controller: _serialCtrl,
              icon: Icons.confirmation_number_outlined,
              fieldBgColor: fieldBgColor,
              fieldBorderColor: fieldBorderColor,
              dimColor: dimColor,
              textColor: textColor,
            ),
            const SizedBox(height: 12),

            // Years field يستخدم نمط موحد
            _yearsField(fieldBgColor, fieldBorderColor, dimColor, textColor),
            const SizedBox(height: 12),

            // *** تم تعديل _attachmentPicker ليستخدم اللون الأرجواني للبوكس المحيط في Light Mode ***
            _attachmentPicker(fieldBgColor, fieldBorderColor, accentColor, onAccentColor, textColor, dimColor),

            const SizedBox(height: 12),

            // حقول التاريخ تستخدم _GlassPicker
            _GlassPicker(
              left: "Warranty start date",
              right: _start == null ? "Select" : _fmt.format(_start!),
              icon: Icons.date_range,
              onTap: () => _pickDate(
                initial: _start ?? DateTime.now(),
                onPick: (d) {
                  setState(() {
                    _start = d;
                    if (!_endManual) {
                      _end = DateTime(
                        _start!.year + _years,
                        _start!.month,
                        _start!.day,
                      );
                    }
                  });
                },
              ),
              fieldBgColor: fieldBgColor,
              fieldBorderColor: fieldBorderColor,
              dimColor: dimColor,
              textColor: textColor,
            ),

            const SizedBox(height: 12),

            // End Date
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
              fieldBgColor: fieldBgColor,
              fieldBorderColor: fieldBorderColor,
              dimColor: dimColor,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Years ----------
  Widget _yearsField(Color bgColor, Color borderColor, Color dimColor, Color textColor) {
    // توحيد نمط الـ Container (باستخدام نفس خصائص _GlassField)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse, color: dimColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Warranty years (1–10)",
                style: TextStyle(color: textColor)),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _yearsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                isDense: true,
                border: const UnderlineInputBorder(),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                setState(() {
                  _years = (n == null || n < 1)
                      ? 1
                      : (n > 10 ? 10 : n);
                  _yearsCtrl.text = _years.toString();
                  if (!_endManual && _start != null) {
                    _end = DateTime(
                      _start!.year + _years,
                      _start!.month,
                      _start!.day,
                    );
                  }
                });
              },
            ),
          )
        ],
      ),
    );
  }

  // ---------- Attach image ----------
  Widget _attachmentPicker(Color bgColor, Color borderColor, Color accentColor, Color onAccentColor, Color textColor, Color dimColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // *** تطبيق اللون الأرجواني على البوكس المحيط في Light Mode ***
    // تحديد لون الخلفية للبوكس المحيط
    final Color boxBgColor = isLight
        ? accentColor.withOpacity(0.15) // أرجواني فاتح جداً كخلفية للبوكس في Light Mode
        : bgColor; // استخدام الخلفية المعتادة (شبه شفافة) في Dark Mode

    // تحديد لون النص والأيقونات داخل هذا البوكس
    final Color contentFgColor = isLight
        ? accentColor // استخدام اللون الأرجواني الداكن للنص على خلفية فاتحة
        : onAccentColor; // استخدام الأبيض على خلفية داكنة

    // الألوان لزر "Attach image" الصغير (لضمان أنه داكن وواضح في Light Mode)
    final Color buttonBg = isLight ? accentColor : accentColor;
    final Color buttonFg = onAccentColor; // أبيض دائماً على زر أرجواني داكن

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // لون الخلفية هنا هو اللون الأرجواني الفاتح الآن
        color: boxBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // زر "Attach image" الصغير (لون خلفيته أرجواني غامق ونصه أبيض)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pickAttachment,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                // استخدام لون الخلفية المخصص للزر الصغير
                color: buttonBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // استخدام لون النص الأمامي المخصص
                  Icon(Icons.attach_file, size: 16, color: buttonFg),
                  const SizedBox(width: 6),
                  // استخدام لون النص الأمامي المخصص
                  Text("Attach image", style: TextStyle(color: buttonFg)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _attachmentName ??
                  _attachmentLocalPath ??
                  "No image",
              // استخدام contentFgColor للنص داخل البوكس الأرجواني
              style: TextStyle(color: contentFgColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ------- UI widgets -------
class _GlassField extends StatelessWidget {
// ... (باقي الودجت الفرعية بدون تغيير)
  final TextEditingController controller;
  final String label;
  final IconData icon;

  // خصائص الألوان الجديدة
  final Color fieldBgColor;
  final Color fieldBorderColor;
  final Color dimColor;
  final Color textColor;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.fieldBgColor,
    required this.fieldBorderColor,
    required this.dimColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // تم التأكد من استخدام textColor و dimColor بالشكل الصحيح
    return Container(
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorderColor),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(color: dimColor),
          prefixIcon: Icon(icon, color: dimColor),
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

  // خصائص الألوان الجديدة
  final Color fieldBgColor;
  final Color fieldBorderColor;
  final Color dimColor;
  final Color textColor;

  const _GlassPicker({
    required this.left,
    required this.right,
    required this.icon,
    required this.onTap,
    required this.fieldBgColor,
    required this.fieldBorderColor,
    required this.dimColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // تم التأكد من استخدام textColor و dimColor بالشكل الصحيح
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: fieldBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fieldBorderColor),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(left, style: TextStyle(color: textColor))),
            // النص الذي يتغير لونه بشكل صحيح
            Text(right, style: TextStyle(color: dimColor)),
            const SizedBox(width: 8),
            Icon(icon, color: dimColor),
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

  // خاصية اللون الأساسي
  final Color accentColor;
  // جديد: لون النص على الزر
  final Color onAccentColor;

  const _GradBtn({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.accentColor,
    required this.onAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          // استخدام اللون الأساسي (primaryColor) الذي يعمل في كلا الوضعين
          color: accentColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // استخدام onAccentColor للون الأيقونة (لونه أبيض ثابت لضمان التباين)
              Icon(icon, color: onAccentColor),
              const SizedBox(width: 8),
              // استخدام onAccentColor للون النص (لونه أبيض ثابت لضمان التباين)
              Text(text,
                  style: TextStyle(
                      color: onAccentColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
