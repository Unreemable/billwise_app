import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_warranty_page.dart';
import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../data/warranty_service.dart';
import 'warranty_detail_page.dart';

class WarrantyListPage extends StatelessWidget {
  const WarrantyListPage({super.key});
  static const route = '/warranties';

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

  Future<void> _confirmDelete(
      BuildContext context, {
        required String warrantyId,
        required String titleForMsg,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete warranty?'),
        content: Text('Are you sure you want to delete “$titleForMsg”? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await WarrantyService.instance.deleteWarranty(warrantyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Warranties')),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your warranties.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: WarrantyService.instance
            .streamWarrantiesSnapshot(userId: uid, descending: true),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No warranties yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final id = doc.id;
              final d = doc.data();

              final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end = (d['end_date'] as Timestamp?)?.toDate().toLocal();
              final provider = (d['provider'] ?? 'Warranty').toString();
              final billId = (d['bill_id'] as String?) ?? '';

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    provider,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

                  // === القائمة: Edit/Delete ===
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        // افتح صفحة AddWarrantyPage بوضع التعديل
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddWarrantyPage(
                              billId: billId,
                              warrantyId: id,
                              defaultStartDate: start,
                              defaultEndDate: end,
                              initialProvider: provider,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        await _confirmDelete(
                          context,
                          warrantyId: id,
                          titleForMsg: provider,
                        );
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit, size: 18),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline, size: 18),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),

                  // === الضغط على البطاقة يفتح صفحة التفاصيل ===
                  onTap: () {
                    final details = WarrantyDetails(
                      title: provider,
                      product: provider,
                      warrantyStart: start ?? DateTime.now(),
                      warrantyExpiry: end ?? DateTime.now(),
                      returnDeadline: null,
                      reminderDate: null,
                    );
                    Navigator.pushNamed(
                      context,
                      WarrantyDetailPage.route,
                      arguments: details,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
