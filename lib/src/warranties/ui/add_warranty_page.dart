import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../data/warranty_service.dart';
import '../../bills/data/bill_service.dart';
import '../../notifications/notifications_service.dart';
import 'dart:ui' as ui;

// ===== ألوان وستايل موحّد مستخدم في كامل التطبيق =====
const Color _kBgDark  = Color(0xFF0E0722);
const Color _kTextDim = Colors.white70;
const Color _kGrad1   = Color(0xFF6C3EFF);
const Color _kGrad2   = Color(0xFF934DFE);
const Color _kGrad3   = Color(0xFF3E8EFD);

// تدرّج الهيدر مثل باقي الصفحات
const LinearGradient _kHeaderGrad = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    this.billId,                 // لو فيه billId يعني الضمان مرتبط بفاتورة
    this.defaultStartDate,       // تاريخ بداية جاهز (يجي من الفاتورة)
    this.defaultEndDate,         // تاريخ نهاية جاهز
    this.warrantyId,             // لو غير null = تعديل
    this.initialProvider,        // اسم المتجر الجاي من AddBill
    this.prefillAttachmentPath,  // مسار صورة جاهزة لنسخها كمرفق
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
  // ===== المتحكمات الخاصة بحقوق الإدخال =====
  final _providerCtrl    = TextEditingController();   // اسم المتجر
  final _productNameCtrl = TextEditingController();   // اسم المنتج (اختياري)
  final _serialCtrl      = TextEditingController();   // الرقم التسلسلي

  // ===== التواريخ =====
  late DateTime _start;  // بداية الضمان
  late DateTime _end;    // نهاية الضمان
  final _fmt = DateFormat('yyyy-MM-dd');

  bool _saving = false;  // فلاج لمنع التكرار أثناء الحفظ
  final _notifs = NotificationsService.I; // خدمة الإشعارات

  bool get isEdit => widget.warrantyId != null;  // هل نحن في وضع التعديل؟
  bool get hasBill => widget.billId != null;     // هل الضمان مرتبط بفاتورة؟

  // ===== بيانات المرفق (صورة محلية فقط) =====
  final _picker = ImagePicker();
  String? _attachmentLocalPath; // مسار الصورة على الجهاز
  String? _attachmentName;      // الاسم الظاهر للمستخدم

  @override
  void initState() {
    super.initState();

    // تعبئة اسم المتجر لو وصل من صفحة الفاتورة
    _providerCtrl.text = (widget.initialProvider ?? '').trim();

    // تهيئة التواريخ (افتراضي = اليوم + سنة)
    _start = widget.defaultStartDate ?? DateTime.now();
    _end   = widget.defaultEndDate   ?? _start.add(const Duration(days: 365));

    // في حالة خطأ (النهاية قبل البداية) نعدلها تلقائياً
    if (_end.isBefore(_start)) {
      _end = _start.add(const Duration(days: 1));
    }

    // لو وصلنا صورة جاهزة نستخدمها كمرفق مباشرة
    final prefillPath = (widget.prefillAttachmentPath ?? '').trim();
    if (prefillPath.isNotEmpty) {
      _attachmentLocalPath = prefillPath;
      _attachmentName = prefillPath.split(Platform.pathSeparator).last;
    }

    // تحميل بيانات الضمان في حالة التعديل
    if (isEdit) {
      _loadExistingWarranty();
    }

    // طلب أذونات الإشعارات بعد بناء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  // ===== جلب بيانات الضمان في حالة التعديل =====
  Future<void> _loadExistingWarranty() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(widget.warrantyId!)
          .get();

      if (!mounted || !doc.exists) return;
      final data = doc.data()!;

      // اسم المتجر
      final providerFromDb = (data['provider'] ?? '').toString();
      if (_providerCtrl.text.trim().isEmpty && providerFromDb.isNotEmpty) {
        _providerCtrl.text = providerFromDb;
      }

      // اسم المنتج (اختياري)
      final productNameFromDb = (data['product_name'] ?? '').toString();
      if (productNameFromDb.isNotEmpty) {
        _productNameCtrl.text = productNameFromDb;
      }

      // الرقم التسلسلي
      _serialCtrl.text = (data['serial_number'] ?? '').toString();

      // التواريخ
      final startTs = data['start_date'];
      final endTs   = data['end_date'];
      if (startTs is Timestamp) _start = startTs.toDate();
      if (endTs   is Timestamp) _end   = endTs.toDate();
      if (_end.isBefore(_start)) _end = _start.add(const Duration(days: 1));

      // بيانات المرفق المخزّن
      final existingLocal = (data['attachment_local_path'] ?? '') as String? ?? '';
      final existingName  = (data['attachment_name'] ?? '') as String? ?? '';
      if (existingLocal.isNotEmpty) {
        _attachmentLocalPath = existingLocal;
        _attachmentName = existingName.isNotEmpty
            ? existingName
            : existingLocal.split(Platform.pathSeparator).last;
      }

      setState(() {});
    } catch (_) {
      // تجاهل أي خطأ بدون إزعاج المستخدم
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _productNameCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  // ===== اختيار صورة المرفق (كاميرا أو معرض) =====
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
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 85, // ضغط الصورة للحفاظ على الحجم
      );
      if (x != null) {
        setState(() {
          _attachmentLocalPath = x.path;
          _attachmentName = x.path.split(Platform.pathSeparator).last;
        });
      }
    } catch (e) {
      _snack('تعذّر فتح ${source == ImageSource.camera ? "الكاميرا" : "المعرض"}');
    }
  }

  // ===== حذف المرفق =====
  Future<void> _removeAttachment() async {
    // لو كنا في تعديل نحذف الحقول من Firestore
    if (isEdit &&
        (_attachmentLocalPath != null || (_attachmentName?.isNotEmpty ?? false))) {
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

    // حذف من الواجهة
    setState(() {
      _attachmentLocalPath = null;
      _attachmentName = null;
    });
    _snack('تم حذف المرفق');
  }

  // ===== اختيار تاريخ =====
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

  // ===== حفظ الضمان (إضافة أو تعديل) =====
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _snack('سجّل الدخول أولاً');
        return;
      }

      // حماية من مشاكل التواريخ
      if (_end.isBefore(_start)) {
        _snack('تاريخ النهاية يجب أن يكون بعد البداية');
        return;
      }

      final provider = _providerCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _providerCtrl.text.trim();
      final productName = _productNameCtrl.text.trim();
      final serial      = _serialCtrl.text.trim();

      late final String warrantyId;

      // ===== وضع التعديل =====
      if (isEdit) {
        warrantyId = widget.warrantyId!;

        // تحديث الحقول الأساسية
        await WarrantyService.instance.updateWarranty(
          id: warrantyId,
          provider: provider,
          startDate: _start,
          endDate: _end,
        );

        final docRef =
        FirebaseFirestore.instance.collection('Warranties').doc(warrantyId);

        // تحديث/حذف الرقم التسلسلي
        await docRef.set(
          serial.isEmpty
              ? {'serial_number': FieldValue.delete()}
              : {'serial_number': serial},
          SetOptions(merge: true),
        );

        // تحديث/حذف اسم المنتج
        await docRef.set(
          productName.isEmpty
              ? {'product_name': FieldValue.delete()}
              : {'product_name': productName},
          SetOptions(merge: true),
        );

        // تحديث/حذف المرفق
        await docRef.set({
          if (_attachmentLocalPath != null && _attachmentLocalPath!.isNotEmpty)
            'attachment_local_path': _attachmentLocalPath,
          if (_attachmentName != null && _attachmentName!.isNotEmpty)
            'attachment_name': _attachmentName,
          if (_attachmentLocalPath == null || _attachmentLocalPath!.isEmpty)
            'attachment_local_path': FieldValue.delete(),
          if (_attachmentName == null || _attachmentName!.isEmpty)
            'attachment_name': FieldValue.delete(),
        }, SetOptions(merge: true));

      } else {
        // ===== إنشاء ضمان جديد =====
        warrantyId = await WarrantyService.instance.createWarranty(
          billId: widget.billId,
          startDate: _start,
          endDate: _end,
          provider: provider,
          userId: uid,
        );

        final docRef =
        FirebaseFirestore.instance.collection('Warranties').doc(warrantyId);

        if (serial.isNotEmpty) {
          await docRef.set({'serial_number': serial}, SetOptions(merge: true));
        }
        if (productName.isNotEmpty) {
          await docRef.set({'product_name': productName}, SetOptions(merge: true));
        }

        if (_attachmentLocalPath != null && _attachmentLocalPath!.isNotEmpty) {
          await docRef.set({
            'attachment_local_path': _attachmentLocalPath,
            if (_attachmentName != null && _attachmentName!.isNotEmpty)
              'attachment_name': _attachmentName,
          }, SetOptions(merge: true));
        }
      }

      // ===== تحديث الفاتورة لو الضمان مرتبط بها =====
      if (hasBill) {
        await BillService.instance.updateBill(
          billId: widget.billId!,
          warrantyCoverage: true,
          warrantyStartDate: _start,
          warrantyEndDate: _end,
        );
      }

      // ===== إعادة جدولة تذكير الضمان =====
      try {
        await _notifs.rescheduleWarrantyReminder(
          warrantyId: warrantyId,
          provider: provider,
          start: _start,
          end: _end,
        );
      } catch (_) {}

      if (!mounted) return;
      _snack(isEdit ? 'تم تحديث الضمان' : 'تم حفظ الضمان');
      Navigator.of(context).pop();

    } catch (e) {
      if (mounted) _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== حذف الضمان =====
  Future<void> _delete() async {
    try {
      await WarrantyService.instance.deleteWarranty(widget.warrantyId!);
      _snack('تم حذف الضمان');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('خطأ: $e');
    }
  }

  // ===== سنackbar مختصر =====
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final shownName = (_attachmentLocalPath == null || _attachmentLocalPath!.isEmpty)
        ? 'No image'
        : (_attachmentName ?? _attachmentLocalPath!.split(Platform.pathSeparator).last);

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text(isEdit ? 'Edit Warranty' : 'Add Warranty'),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'Delete',
                onPressed: _saving
                    ? null
                    : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete warranty?'),
                      content: const Text('Are you sure you want to delete this warranty?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) await _delete();
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

        // ===== محتوى الصفحة =====
        body: AbsorbPointer(
          absorbing: _saving, // يمنع اللمس أثناء الحفظ
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // رسالة توضيح إذا الضمان غير مرتبط بفاتورة
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
                      Icon(Icons.info_outline, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('This warranty is not linked to a bill.', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

              // حقل اسم المتجر
              _GlassField(
                controller: _providerCtrl,
                label: 'Provider / Store',
                icon: Icons.store_outlined,
              ),
              const SizedBox(height: 12),

              // حقل اسم المنتج
              _GlassField(
                controller: _productNameCtrl,
                label: 'Product name (optional)',
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(height: 12),

              // الرقم التسلسلي
              _GlassField(
                controller: _serialCtrl,
                label: 'Serial number (optional)',
                icon: Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 12),

              // صف المرفق
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        shownName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_attachmentLocalPath != null && _attachmentLocalPath!.isNotEmpty)
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: _removeAttachment,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // تاريخ بداية الضمان
              _GlassRow(
                left: 'Warranty start date',
                right: _fmt.format(_start),
                rightIcon: Icons.date_range,
                onTap: () => _pickDate(
                  initial: _start,
                  onPick: (d) => setState(() {
                    _start = d;
                    if (_end.isBefore(_start)) _end = _start.add(const Duration(days: 1));
                  }),
                ),
              ),

              const SizedBox(height: 10),

              // تاريخ نهاية الضمان
              _GlassRow(
                left: 'Warranty end date',
                right: _fmt.format(_end),
                rightIcon: Icons.verified_user,
                onTap: () => _pickDate(
                  initial: _end.isBefore(_start) ? _start : _end,
                  onPick: (d) => setState(() => _end = d),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== ويدجت حقل زجاجي موحّد =====
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

// ===== صف تفاعلي يستخدم لاختيار التواريخ =====
class _GlassRow extends StatelessWidget {
  final String left;
  final String right;
  final IconData rightIcon;
  final VoidCallback onTap;
  const _GlassRow({
    required this.left,
    required this.right,
    required this.rightIcon,
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
            Expanded(child: Text(left, style: const TextStyle(color: Colors.white))),
            Text(right, style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Icon(rightIcon, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// ===== زر كبير بتدرّج لوني =====
class _GradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
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

// ===== زر صغير لتحديد المرفق =====
class _TinyGradButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  const _TinyGradButton({required this.text, required this.icon, required this.onPressed});

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