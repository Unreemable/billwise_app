import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import 'warranty_detail_page.dart';

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
    } else if (today.isAfter(e) || today.isAtSameMomentAs(e)) {
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
      // يتطلب فهرس user_id + end_date ASC
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
        appBar: AppBar(title: const Text('Warranties')),
        body: uid == null
            ? const Center(child: Text('Please sign in to view your warranties.'))
            : Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by provider or title',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),

            // Sort chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sort == _WarrantiesSort.newest,
                    onSelected: (_) => setState(() => _sort = _WarrantiesSort.newest),
                  ),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sort == _WarrantiesSort.oldest,
                    onSelected: (_) => setState(() => _sort = _WarrantiesSort.oldest),
                  ),
                  ChoiceChip(
                    label: const Text('Near expiry'),
                    selected: _sort == _WarrantiesSort.nearExpiry,
                    onSelected: (_) => setState(() => _sort = _WarrantiesSort.nearExpiry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildStream(uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snap.data!.docs;

                  // Filter by search text
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
                    return const Center(child: Text('No warranties yet.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
                      final end   = (d['end_date'] as Timestamp?)?.toDate().toLocal();
                      final provider = (d['provider'] ?? 'Warranty').toString();

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(provider, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start: ${_fmt(start)} • End: ${_fmt(end)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              if (start != null && end != null)
                                ExpiryProgress(
                                  title: 'Warranty expiry',
                                  startDate: start,
                                  endDate: end,
                                  dense: true,
                                  showInMonths: true,
                                ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _statusChip(start, end),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
                            // ✅ افتح التفاصيل مباشرة على الـroot
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: details)),
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
