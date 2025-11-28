import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../../bills/ui/bill_list_page.dart';
import 'warranty_detail_page.dart';

// ===== ثيم الألوان (نفس ألوان صفحة الهوم) =====
const Color _kBgDark   = Color(0xFF18102F);   // زي ما هو
const Color _kGrad1    = Color(0xFF9B5CFF);   // Violet أفتح ومريح
const Color _kGrad2    = Color(0xFF6C3EFF);   // البنفسجي الأساسي
const Color _kGrad3    = Color(0xFFC58CFF);   // Lavender وردي ناعم بدل الأزرق
const Color _kCard = Color(0xFF22183C);   // كروت Expiring
const Color _kTextDim  = Colors.white70;

// تدرّج الهيدر العلوي
const LinearGradient _kHeaderGrad = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ============ البار السفلي المتدرّج (Warranties / Bills + Home) ============
class GradientBottomBar extends StatelessWidget {
  final int selectedIndex;               // 0 = Warranties, 1 = Bills
  final ValueChanged<int> onTap;
  final Color startColor;
  final Color endColor;

  const GradientBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.startColor = const Color(0xFF6C3EFF),
    this.endColor   = const Color(0xFF3E8EFD),
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [startColor, endColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // زر تبويب الضمانات
                  _BottomItem(
                    icon: Icons.verified_user_rounded,
                    label: 'Warranties',
                    selected: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(width: 18),
                  // زر الهوم في النص
                  _FabDot(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).pushNamed('/home');
                    },
                  ),
                  const SizedBox(width: 18),
                  // زر تبويب الفواتير
                  _BottomItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Bills',
                    selected: selectedIndex == 1,
                    onTap: () => onTap(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// عنصر داخل البار السفلي (أيقونة + نص)
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _BottomItem({required this.icon, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white70;
    final selectedBg = Colors.white.withOpacity(.16);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// الدائرة الوسطية (الهوم) في البار السفلي
class _FabDot extends StatelessWidget {
  final VoidCallback? onTap;
  const _FabDot({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C3EFF), Color(0xFFC58CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF934DFE).withOpacity(.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.home_filled, color: Colors.white),
      ),
    );
  }
}

// ===============================================================
//              صفحة قائمة الضمانات WarrantyListPage
// ===============================================================

class WarrantyListPage extends StatefulWidget {
  const WarrantyListPage({super.key});
  static const route = '/warranties';

  @override
  State<WarrantyListPage> createState() => _WarrantyListPageState();
}

// خيارات الفرز المتاحة
enum _WarrantiesSort { newest, oldest, nearExpiry }

class _WarrantyListPageState extends State<WarrantyListPage> {
  final _searchCtrl = TextEditingController();   // حقل البحث
  _WarrantiesSort _sort = _WarrantiesSort.newest; // الفرز الافتراضي: الأحدث أولاً

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== دوال مساعدة =====

  // تنسيق التاريخ كـ yyyy-MM-dd
  String _fmt(DateTime? x) {
    if (x == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${x.year}-${two(x.month)}-${two(x.day)}';
  }

  // إزالة الوقت من التاريخ (نخليه تاريخ فقط)
  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  // توليد Chip يوضح حالة الضمان: active | expired | upcoming
  Chip _statusChip(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return const Chip(label: Text('—'));
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

  // بناء الـ Stream اللي يجيب الضمانات من Firestore بناءً على الفرز الحالي
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

        // ===== AppBar =====
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Warranties'),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGrad)),
        ),



        // ===== جسم الصفحة =====
        body: uid == null
        // لو المستخدم مو مسجّل دخول
            ? const Center(
          child: Text(
            'Please sign in to view your warranties.',
            style: TextStyle(color: Colors.white),
          ),
        )
            : Column(
          children: [
            // شريط البحث
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SearchBar(
                controller: _searchCtrl,
                hint: 'Search by provider or product',
                onChanged: (_) => setState(() {}),
              ),
            ),

            // شرائح الفرز (Newest / Oldest / Near expiry)
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

            // قائمة الضمانات (من Firestore + بحث + فرز)
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildStream(uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snap.data!.docs;

                  // فلترة النتائج بحسب نص البحث
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final provider = (d['provider'] ?? '').toString().toLowerCase();
                      final title    = (d['title'] ?? '').toString().toLowerCase();
                      final product  = (d['product_name'] ?? '').toString().toLowerCase();
                      return provider.contains(q) || title.contains(q) || product.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No warranties yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
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
                      final end   = (d['end_date'] as Timestamp?)?.toDate().toLocal();
                      final provider     = (d['provider'] ?? 'Warranty').toString();
                      final productName  = (d['product_name'] ?? '').toString();
                      final title        = (d['title'] ?? provider).toString();

                      return Container(
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                          // اسم المتجر في العنوان
                          title: Text(
                            provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),

                          // باقي المعلومات (اسم المنتج + التواريخ + البار + الحالة)
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (productName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 4),
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

                          // الضغط على العنصر يفتح صفحة تفاصيل الضمان
                          onTap: () {
                            final details = WarrantyDetails(
                              id: doc.id,
                              title: title,
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

// ================= شريط البحث عن الضمانات =================
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
          // زر X لمسح النص إذا كان في شيء مكتوب
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

// ============== شريحة الفرز (Sort chip) ==============
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