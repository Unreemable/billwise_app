// ===================== Warranty Details Page (with image preview + open) =====================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
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
          .doc(_d.id)
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

    await FirebaseFirestore.instance
        .collection('Warranties')
        .doc(_d.id)
        .delete();

    if (mounted) Navigator.pop(context);
  }

  // ====================== UI ======================
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
                  child: _GradBtn(
                    text: 'Edit',
                    icon: Icons.edit,
                    onTap: () {
                      // would open edit page OR sheet (not changed here)
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradBtn(
                    text: 'Delete',
                    icon: Icons.delete_outline,
                    bgFrom: Colors.redAccent,
                    bgTo: Colors.red,
                    onTap: _deleteWarranty,
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
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

                    // ===== Details =====
                    _kv('Product', _product ?? '—'),
                    _kv('Serial number', _serialNumber ?? '—'),
                    _kv('Warranty start date', _ymd(_d.warrantyStart)),
                    _kv('Warranty expiry date', _ymd(_d.warrantyExpiry)),

                    // =======================
                    //     IMAGE PREVIEW
                    // =======================
                    if (_attachmentLocalPath != null &&
                        _attachmentLocalPath!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text("Attachment image",
                              style: TextStyle(
                                  color: Colors.white,
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
                              icon: const Icon(Icons.open_in_full,
                                  color: Colors.white),
                              label: const Text("Open",
                                  style: TextStyle(color: Colors.white)),
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
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
    ],
  ),
);

// ========= Gradient Button =========
class _GradBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bgFrom;
  final Color bgTo;
  final VoidCallback onTap;

  const _GradBtn({
    required this.text,
    required this.icon,
    required this.onTap,
    this.bgFrom = _kGrad1,
    this.bgTo = _kGrad3,
  });

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
