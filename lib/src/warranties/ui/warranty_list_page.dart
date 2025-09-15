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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Warranties')),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your warranties.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Top-level collection with user filter — no composite index needed
        stream: WarrantyService.instance.streamWarranties(userId: uid),
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
              final d = docs[i].data();
              final start = (d['start_date'] as Timestamp?)?.toDate();
              final end   = (d['end_date']   as Timestamp?)?.toDate();
              final status = (d['status'] ?? 'active').toString();
              final months = (d['months'] as int?) ?? 0;
              final provider = (d['provider'] ?? 'Warranty').toString();

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  title: Text(provider,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid ${months > 0 ? '$months mo' : ''} • '
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
                          showInMonths: true, // show remaining in months
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
