import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import 'add_warranty_page.dart';

// ===== ثوابت الألوان الداكنة (للمزج في Dark Mode فقط) =====
const Color _kBgDarkColor = Color(0xFF0E0722);
const Color _kCardDarkColor = Color(0x1AFFFFFF); // شبه شفاف
const Color _kGrad1 = Color(0xFF6C3EFF);
const Color _kGrad3 = Color(0xFF9B5CFF);
const Color _kTextDimDark = Colors.white70;

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

  String? _product;
  String? _serialNumber;

  // NEW: attachment info
  String? _attachmentName;
  String? _attachmentLocalPath;

  bool _loadingExtra = false;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
    _loadExtraFields();
  }

  // ===== Load product, serial, AND attachment =====
  Future<void> _loadExtraFields() async {
    if (_d.id == null) return;

    setState(() => _loadingExtra = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Warranties')
          .doc(_d.id!)
          .get();

      if (!mounted || !snap.exists) return;

      final data = snap.data()!;

      setState(() {
        final p = (data['product'] ?? '').toString().trim();
        final s = (data['serial_number'] ?? '').toString().trim();

        _product = p.isEmpty ? null : p;
        _serialNumber = s.isEmpty ? null : s;

        _attachmentLocalPath =
            (data['attachment_local_path'] ?? '').toString().trim();
        _attachmentName =
            (data['attachment_name'] ?? '').toString().trim();
        if (_attachmentName != null && _attachmentName!.isEmpty) {
          _attachmentName = null;
        }
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
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final textSub = theme.hintColor;
    final dangerColor = theme.colorScheme.error;


    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Delete warranty?', style: TextStyle(color: textColor)),
        content: Text('This action cannot be undone.', style: TextStyle(color: textSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: textSub))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: dangerColor),
              child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('Warranties')
        .doc(_d.id!)
        .delete();

    if (mounted) Navigator.pop(context);
  }

  // دالة مساعدة لإنشاء تدرج الـ AppBar
  LinearGradient _headerGradient(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isDark) {
      return const LinearGradient(
        colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Light Mode: خلفية فاتحة (مطابقة لـ Scaffold)
      return LinearGradient(
        colors: [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
  }


  // ====================== UI ======================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final dimColor = theme.hintColor;
    final cardBg = theme.cardColor;
    final accentColor = theme.primaryColor;
    final appBarFgColor = isDark ? Colors.white : textColor;

    // تثبيت ألوان البوكسات الداكنة في Dark Mode
    final detailCardColor = isDark ? _kCardDarkColor : cardBg;

    final cardBorderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,

        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: appBarFgColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Warranty', style: TextStyle(color: appBarFgColor)),
          flexibleSpace:
          Container(decoration: BoxDecoration(gradient: _headerGradient(context))),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _GradBtn(
                    text: 'Edit',
                    icon: Icons.edit,
                    onTap: () async {
                      final updated = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddWarrantyPage(
                            warrantyId: _d.id,
                            prefill: {
                              'title': _d.title,
                              'product': _product,
                              'serial': _serialNumber,
                              'start': _d.warrantyStart,
                              'expiry': _d.warrantyExpiry,
                              'attachment': _attachmentLocalPath,
                            },
                          ),
                        ),
                      );

                      if (updated == true) {
                        await _loadExtraFields();   // يعيد تحميل الصورة/السيريال/الاسم
                        setState(() {});            // تحديث الواجهة
                      }
                    },
                    accentColor: accentColor,
                    danger: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradBtn(
                    text: 'Delete',
                    icon: Icons.delete_outline,
                    onTap: _deleteWarranty,
                    accentColor: accentColor,
                    danger: true,
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
                color: detailCardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== Header row =====
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: dimColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(.1) : accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : accentColor.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Expires ${_fmtPretty(_d.warrantyExpiry)}',
                            style: TextStyle(color: textColor, fontSize: 12),
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

                    // ===== Details =====
                    _kv(context, 'Product', _product ?? '—'),
                    _kv(context, 'Serial number', _serialNumber ?? '—'),
                    _kv(context, 'Warranty start date', _ymd(_d.warrantyStart)),
                    _kv(context, 'Warranty expiry date', _ymd(_d.warrantyExpiry)),

                    // =======================
                    //     IMAGE PREVIEW
                    // =======================
                    if (_attachmentLocalPath != null &&
                        _attachmentLocalPath!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text("Attachment image",
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_attachmentLocalPath!),
                              fit: BoxFit.cover,
                              height: 200,
                              width: double.infinity,
                            ),
                          ),

                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _FullImageViewer(
                                      path: _attachmentLocalPath!,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.open_in_full,
                                  color: accentColor),
                              label: Text("Open",
                                  style: TextStyle(color: accentColor)),
                            ),
                          ),
                        ],
                      ),

                    if (_loadingExtra)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
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

Widget _kv(BuildContext context, String k, String v) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium!.color!;
  final dimColor = theme.hintColor;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(k,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v, style: TextStyle(color: dimColor))),
      ],
    ),
  );
}

// ========= Gradient Button =========
class _GradBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
  final bool danger;

  const _GradBtn({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.accentColor,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dangerColor = theme.colorScheme.error;

    final Color bgFrom = danger ? dangerColor : accentColor;
    final Color bgTo = danger ? dangerColor.withOpacity(0.8) : accentColor.withOpacity(0.8);


    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 6),
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

// ========= Full-screen image viewer =========
class _FullImageViewer extends StatelessWidget {
  final String path;
  const _FullImageViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}