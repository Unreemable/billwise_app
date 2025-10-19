import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../data/warranty_service.dart';
import '../../bills/data/bill_service.dart';
import '../../notifications/notifications_service.dart';

class AddWarrantyPage extends StatefulWidget {
  const AddWarrantyPage({
    super.key,
    this.billId,
    this.defaultStartDate,
    this.defaultEndDate,
    this.warrantyId,           // != null يعني تعديل
    this.initialProvider,
  });

  static const route = '/add-warranty';

  final String? billId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;
  final String? warrantyId;
  final String? initialProvider;

  @override
  State<AddWarrantyPage> createState() => _AddWarrantyPageState();
}

class _AddWarrantyPageState extends State<AddWarrantyPage> {
  // Controllers
  final _providerCtrl = TextEditingController();
  final _serialCtrl   = TextEditingController();

  // Dates
  late DateTime _start;
  late DateTime _end;
  final _fmt = DateFormat('yyyy-MM-dd');

  bool _saving = false;

  final _notifs = NotificationsService.I;

  bool get isEdit  => widget.warrantyId != null;
  bool get hasBill => widget.billId != null;

  // ===== مرفق (صورة/ PDF) =====
  PlatformFile? _pickedFile;          // ملف مختار قبل الرفع
  String _existingAttachmentUrl  = ''; // لو كان فيه مرفق قديم
  String _existingAttachmentName = '';
  String _existingAttachmentMime = '';

  @override
  void initState() {
    super.initState();

    _providerCtrl.text = (widget.initialProvider ?? '').trim();

    // تهيئة آمنة للتواريخ لتجنب LateInitializationError
    _start = widget.defaultStartDate ?? DateTime.now();
    _end   = widget.defaultEndDate   ?? _start.add(const Duration(days: 365));
    if (_end.isBefore(_start)) {
      _end = _start.add(const Duration(days: 1));
    }

    // لو تعديل: حمّل البيانات من Firestore
    if (isEdit) {
      _loadExistingWarranty();
    }

    // اطلب أذونات الإشعارات بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifs.requestPermissions(context);
    });
  }

  Future<void> _loadExistingWarranty() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(widget.warrantyId!)
          .get();

      if (!mounted || !doc.exists) return;
      final data = doc.data()!;

      // provider
      final providerFromDb = (data['provider'] ?? '').toString();
      if (_providerCtrl.text.trim().isEmpty && providerFromDb.isNotEmpty) {
        _providerCtrl.text = providerFromDb;
      }

      // serial
      _serialCtrl.text = (data['serial_number'] ?? '').toString();

      // dates
      final startTs = data['start_date'];
      final endTs   = data['end_date'];
      if (startTs is Timestamp) _start = startTs.toDate();
      if (endTs   is Timestamp) _end   = endTs.toDate();
      if (_end.isBefore(_start)) {
        _end = _start.add(const Duration(days: 1));
      }

      // attachment
      _existingAttachmentUrl  = (data['attachment_url']  ?? '').toString();
      _existingAttachmentName = (data['attachment_name'] ?? '').toString();
      _existingAttachmentMime = (data['attachment_mime'] ?? '').toString();

      setState(() {});
    } catch (_) {
      // تجاهل بهدوء؛ نعرض القيم الحالية
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  // ================= المرفقات =================

  Future<void> _pickAttachment() async {
    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick image from gallery'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Pick PDF file'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    try {
      if (choice == 'image') {
        final img = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (img != null) {
          final f = File(img.path);
          setState(() {
            _pickedFile = PlatformFile(
              name: img.name,
              path: img.path,
              size: f.existsSync() ? f.lengthSync() : 0,
            );
          });
        }
      } else if (choice == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() => _pickedFile = result.files.first);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Could not open picker: $e');
    }
  }

  Future<void> _removeAttachment() async {
    // حذف مرفق موجود سابقًا (وضع التعديل، ولم يتم اختيار ملف جديد)
    if (isEdit && _pickedFile == null && _existingAttachmentUrl.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance
            .ref('warranties/${widget.warrantyId!}/attachment');
        final meta = await ref.getMetadata().catchError((_) => null);
        if (meta != null) {
          await ref.delete();
        }
        await FirebaseFirestore.instance
            .collection('Warranties')
            .doc(widget.warrantyId!)
            .set({
          'attachment_url' : FieldValue.delete(),
          'attachment_name': FieldValue.delete(),
          'attachment_mime': FieldValue.delete(),
        }, SetOptions(merge: true));

        setState(() {
          _existingAttachmentUrl  = '';
          _existingAttachmentName = '';
          _existingAttachmentMime = '';
        });
        _snack('Attachment removed');
      } catch (e) {
        _snack('Failed to remove file: $e');
      }
    } else {
      // إلغاء الملف المختار محليًا
      setState(() => _pickedFile = null);
    }
  }

  Future<Map<String, String>?> _uploadAttachment(String warrantyId) async {
    if (_pickedFile == null) return null;
    final path = _pickedFile!.path;
    if (path == null) return null;

    final file = File(path);
    final name = _pickedFile!.name;
    final dot  = name.lastIndexOf('.');
    final ext  = (dot != -1 ? name.substring(dot + 1) : 'bin').toLowerCase();

    final mime = ext == 'pdf'
        ? 'application/pdf'
        : 'image/${ext == 'jpg' ? 'jpeg' : ext}';

    final ref = FirebaseStorage.instance
        .ref('warranties/$warrantyId/attachment');

    await ref.putFile(file, SettableMetadata(contentType: mime));
    final url = await ref.getDownloadURL();

    return {'url': url, 'name': name, 'mime': mime};
  }

  // ================= التواريخ =================

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

  // ================= حفظ / حذف =================

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _snack('Please sign in first');
        return;
      }
      if (_end.isBefore(_start)) {
        _snack('End date must be on/after start date');
        return;
      }

      final provider = _providerCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _providerCtrl.text.trim();
      final serial = _serialCtrl.text.trim();

      late final String warrantyId;

      if (isEdit) {
        warrantyId = widget.warrantyId!;
        await WarrantyService.instance.updateWarranty(
          id: warrantyId,
          provider: provider,
          startDate: _start,
          endDate: _end,
        );

        final docRef = FirebaseFirestore.instance
            .collection('Warranties')
            .doc(warrantyId);

        await docRef.set(
          serial.isEmpty
              ? {'serial_number': FieldValue.delete()}
              : {'serial_number': serial},
          SetOptions(merge: true),
        );

        final uploaded = await _uploadAttachment(warrantyId);
        if (uploaded != null) {
          await docRef.set({
            'attachment_url' : uploaded['url'],
            'attachment_name': uploaded['name'],
            'attachment_mime': uploaded['mime'],
          }, SetOptions(merge: true));

          _existingAttachmentUrl  = uploaded['url']!;
          _existingAttachmentName = uploaded['name']!;
          _existingAttachmentMime = uploaded['mime']!;
          _pickedFile = null;
        }
      } else {
        // إنشاء جديد
        warrantyId = await WarrantyService.instance.createWarranty(
          billId: widget.billId,
          startDate: _start,
          endDate: _end,
          provider: provider,
          userId: uid,
        );

        final docRef = FirebaseFirestore.instance
            .collection('Warranties')
            .doc(warrantyId);

        if (serial.isNotEmpty) {
          await docRef.set({'serial_number': serial}, SetOptions(merge: true));
        }

        final uploaded = await _uploadAttachment(warrantyId);
        if (uploaded != null) {
          await docRef.set({
            'attachment_url' : uploaded['url'],
            'attachment_name': uploaded['name'],
            'attachment_mime': uploaded['mime'],
          }, SetOptions(merge: true));

          _existingAttachmentUrl  = uploaded['url']!;
          _existingAttachmentName = uploaded['name']!;
          _existingAttachmentMime = uploaded['mime']!;
          _pickedFile = null;
        }
      }

      // مزامنة مع الفاتورة إن وُجدت
      if (hasBill) {
        await BillService.instance.updateBill(
          billId: widget.billId!,
          warrantyCoverage: true,
          warrantyStartDate: _start,
          warrantyEndDate: _end,
        );
      }

      // إعادة جدولة تذكير الضمان
      await _notifs.rescheduleWarrantyReminder(
        warrantyId: warrantyId,
        provider: provider,
        start: _start,
        end: _end,
      );

      if (!mounted) return;
      _snack(isEdit ? 'Warranty updated ✅' : 'Warranty saved ✅');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    try {
      await WarrantyService.instance.deleteWarranty(widget.warrantyId!);
      try {
        await FirebaseStorage.instance
            .ref('warranties/${widget.warrantyId!}/attachment')
            .delete();
      } catch (_) {}
      if (!mounted) return;
      _snack('Warranty deleted');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  // ================= UI =================

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final attachmentName = _pickedFile?.name.isNotEmpty == true
        ? _pickedFile!.name
        : (_existingAttachmentName.isNotEmpty
        ? _existingAttachmentName
        : 'No file');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Warranty' : 'Add Warranty'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving
                  ? null
                  : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete warranty?'),
                    content: const Text(
                        'Are you sure you want to delete this warranty?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) await _delete();
              },
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!hasBill)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                        child:
                        Text('This warranty is not linked to a bill.')),
                  ],
                ),
              ),

            // Provider
            TextField(
              controller: _providerCtrl,
              decoration: const InputDecoration(
                labelText: 'Provider / Store',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            // Serial
            TextField(
              controller: _serialCtrl,
              decoration: const InputDecoration(
                labelText: 'Serial number (optional)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            // Attachment
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach file'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pickedFile != null || _existingAttachmentUrl.isNotEmpty)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: _removeAttachment,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Start date
            ListTile(
              title: const Text('Warranty start date'),
              subtitle: Text(_fmt.format(_start)),
              trailing: const Icon(Icons.date_range),
              onTap: () => _pickDate(
                initial: _start,
                onPick: (d) => setState(() {
                  _start = d;
                  if (_end.isBefore(_start)) _end = _start.add(const Duration(days: 1));
                }),
              ),
            ),

            // End date
            ListTile(
              title: const Text('Warranty end date'),
              subtitle: Text(_fmt.format(_end)),
              trailing: const Icon(Icons.verified_user),
              onTap: () => _pickDate(
                initial: _end.isBefore(_start) ? _start : _end,
                onPick: (d) => setState(() => _end = d),
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : (isEdit ? 'Update' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}
