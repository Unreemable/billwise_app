import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
              final d = doc.data();

              final start = (d['start_date'] as Timestamp?)?.toDate().toLocal();
              final end   = (d['end_date']   as Timestamp?)?.toDate().toLocal();
              final provider = (d['provider'] ?? 'Warranty').toString();

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

                  // 🔁 بدلنا النقاط بسهم للدخول
                  trailing: const Icon(Icons.chevron_right),

                  // فتح صفحة التفاصيل
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
