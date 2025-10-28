// ================== Warranties List (Home-like styling) ==================
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import 'warranty_detail_page.dart';

// ===== نفس ألوان الهوم =====
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

class WarrantyListPage extends StatefulWidget {
  const WarrantyListPage({super.key});
  static const route = '/warranties';

  @override
  State<WarrantyListPage> createState() => _WarrantyListPageState();
}

enum _WarrantiesSort { newest, oldest, nearExpiry }

class _WarrantyListPageState extends State<WarrantyListPage> {
  final _searchCtrl = TextEditingController();
  _WarrantiesSort _sort = _WarrantiesSort.newest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== Helpers =====
  String _fmt(DateTime? x) {
    if (x == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${x.year}-${two(x.month)}-${two(x.day)}';
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Chip _statusChip(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) {
      return const Chip(label: Text('—'));
    }
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());

    late final String text;
    late final Color color;

    if (today.isBefore(s)) {
      text = 'upcoming';
      color = Colors.blueGrey;
    } else if (!today.isBefore(e)) {
      text = 'expired';
      color = Colors.red;
    } else {
      text = 'active';
      color = Colors.green;
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream(String uid) {
    final col = FirebaseFirestore.instance.collection('Warranties');
    Query<Map<String, dynamic>> q = col.where('user_id', isEqualTo: uid);

    switch (_sort) {
      case _WarrantiesSort.newest:
        q = q.orderBy('created_at', descending: true);
        break;
      case _WarrantiesSort.oldest:
        q = q.orderBy('created_at', descending: false);
        break;
      case _WarrantiesSort.nearExpiry:
      // يتطلب فهرس مركّب: user_id == ... + end_date ASC
        q = q.orderBy('end_date', descending: false);
        break;
    }
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBgDark,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Warranties'),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
        ),
        body: uid == null
            ? const Center(
          child: Text('Please sign in to view your warranties.', style: TextStyle(color: Colors.white)),
        )
            : Column(
          children: [
            // ===== Search (نفس شريط بحث الهوم) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SearchBar(
                controller: _searchCtrl,
                hint: 'Search by provider or title',
                onChanged: (_) => setState(() {}),
              ),
            ),

            // ===== Sort chips بنفس الستايل ====>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SortChip(
                    label: 'Newest',
                    selected: _sort == _WarrantiesSort.newest,
                    onTap: () => setState(() => _sort = _WarrantiesSort.newest),
                  ),
                  _SortChip(
                    label: 'Oldest',
                    selected: _sort == _WarrantiesSort.oldest,
                    onTap: () => setState(() => _sort = _WarrantiesSort.oldest),
                  ),
                  _SortChip(
                    label: 'Near expiry',
                    selected: _sort == _WarrantiesSort.nearExpiry,
                    onTap: () => setState(() => _sort = _WarrantiesSort.nearExpiry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ===== List =====
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildStream(uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snap.data!.docs;

                  // Filter by search text (بدون حذف العناصر نهائياً)
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final provider = (d['provider'] ?? '').toString().toLowerCase();
                      final title = (d['title'] ?? '').toString().toLowerCase();
                      return provider.contains(q) || title.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No warranties yet.', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
                      final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();
                      final provider = (d['provider'] ?? 'Warranty').toString();

                      return Container(
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                'Start: ${_fmt(start)} • End: ${_fmt(end)}',
                                style: const TextStyle(color: _kTextDim),
                              ),
                              const SizedBox(height: 8),
                              if (start != null && end != null)
                                ExpiryProgress(
                                  title: 'Warranty expiry',
                                  startDate: start,
                                  endDate: end,
                                  dense: true,
                                  showInMonths: true,
                                ),
                              const SizedBox(height: 8),
                              _statusChip(start, end),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                          onTap: () {
                            final details = WarrantyDetails(
                              id: doc.id,
                              title: provider,
                              product: provider,
                              warrantyStart: start ?? DateTime.now(),
                              warrantyExpiry: end ?? DateTime.now(),
                              returnDeadline: null,
                              reminderDate: null,
                            );
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => WarrantyDetailPage(details: details),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= Search Bar (بنفس الهوم) =================
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SearchBar({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_kGrad1, _kGrad3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kGrad2.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                if (onChanged != null) onChanged!('');
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ============== Sort chip بنفس لغة التصميم ==============
class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? Colors.white.withOpacity(.12) : Colors.white.withOpacity(.06),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
