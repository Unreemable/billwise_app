import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../../bills/ui/bill_list_page.dart';
import 'warranty_detail_page.dart';
import './add_warranty_page.dart'; // نحتاجها للزر العائم

// ===== ألوان عامة نستخدمها في الهوم (تم تحويلها لثوابت ديناميكية) =====
const Color _kGrad1    = Color(0xFF9B5CFF);   // Violet أفتح ومريح
const Color _kGrad2    = Color(0xFF6C3EFF);   // البنفسجي الأساسي
const Color _kGrad3    = Color(0xFFC58CFF);   // Lavender وردي ناعم بدل الأزرق

// ===============================================================
//              شريط التنقل السفلي (GradientBottomBar)
//              هذا الجزء يجب أن يعتمد على الثيم أيضاً
// ===============================================================

class GradientBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const GradientBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    // تحديد ألوان التدرج بناءً على وضع الثيم
    final Color startColor = primaryColor;
    final Color endColor = isDark
        ? primaryColor.withOpacity(0.8)
        : primaryColor.withOpacity(0.9);

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
                  _BottomItem(
                    icon: Icons.verified_user_rounded,
                    label: 'Warranties',
                    selected: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(width: 18),
                  _FabDot(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).pushNamed('/home');
                    },
                    accentColor: primaryColor,
                  ),
                  const SizedBox(width: 18),
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
  final Color accentColor;

  const _FabDot({this.onTap, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final start = accentColor;
    final end = accentColor.withOpacity(0.8);

    return InkWell(
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [start, end],
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(.45),
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
  Chip _statusChip(BuildContext context, DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return const Chip(label: Text('—'));
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());
    final textColor = Theme.of(context).textTheme.bodyMedium!.color!;


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

    // هنا يجب أن نضمن أن نص الـ Chip يكون واضحاً في Light Mode
    final chipTextColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.white; // نستخدم الأبيض دائماً على خلفية Chip الملونة بالكامل

    return Chip(
      label: Text(text, style: TextStyle(color: chipTextColor)),
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

  // دالة مساعدة لإنشاء تدرج الـ AppBar
  LinearGradient _appBarGradient(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.primaryColor;

    if (isDark) {
      // تدرج داكن (مطابق للـ Header الأصلي)
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


  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final dimColor = theme.hintColor;
    final accentColor = theme.primaryColor;

    // ألوان البطاقات
    final cardBgColor = theme.cardColor;
    final cardStrokeColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);


    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        // خلفية ديناميكية
        backgroundColor: theme.scaffoldBackgroundColor,

        // ===== AppBar =====
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: textColor, // لون النص والأيقونات
          title: const Text('Warranties'),
          flexibleSpace: Container(decoration: BoxDecoration(gradient: _appBarGradient(context))),
        ),

        // زر عائم لإضافة ضمان جديد
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const AddWarrantyPage()),
            );
            if (mounted) setState(() {});
          },
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),


        // ===== جسم الصفحة =====
        body: uid == null
        // لو المستخدم مو مسجّل دخول
            ? Center(
          child: Text(
            'Please sign in to view your warranties.',
            style: TextStyle(color: textColor),
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
                accentColor: accentColor,
                isDark: isDark,
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
                    accentColor: accentColor,
                    cardBgColor: cardBgColor,
                    textColor: textColor,
                  ),
                  _SortChip(
                    label: 'Oldest',
                    selected: _sort == _WarrantiesSort.oldest,
                    onTap: () => setState(() => _sort = _WarrantiesSort.oldest),
                    accentColor: accentColor,
                    cardBgColor: cardBgColor,
                    textColor: textColor,
                  ),
                  _SortChip(
                    label: 'Near expiry',
                    selected: _sort == _WarrantiesSort.nearExpiry,
                    onTap: () => setState(() => _sort = _WarrantiesSort.nearExpiry),
                    accentColor: accentColor,
                    cardBgColor: cardBgColor,
                    textColor: textColor,
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
                        style: TextStyle(color: textColor),
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
                    return Center(
                      child: Text(
                        'No warranties yet.',
                        style: TextStyle(color: dimColor),
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
                            color: cardBgColor, // لون البطاقة ديناميكي
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardStrokeColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                          // اسم المتجر في العنوان
                          title: Text(
                            provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
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
                                  style: TextStyle(color: dimColor, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Start: ${_fmt(start)} • End: ${_fmt(end)}',
                                style: TextStyle(color: dimColor),
                              ),
                              const SizedBox(height: 8),
                              if (start != null && end != null)
                                ExpiryProgress(
                                  title: 'Warranty expiry',
                                  startDate: start,
                                  endDate: end,
                                  dense: true,
                                  showInMonths: true,
                                  // لن يتم عرض رسالة الحالة يدوياً
                                ),
                              const SizedBox(height: 8),
                              _statusChip(context, start, end),
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
  final Color accentColor;
  final bool isDark;

  const _SearchBar({
    required this.controller,
    required this.hint,
    this.onChanged,
    required this.accentColor,
    required this.isDark,
  });

  // تدرج شريط البحث
  LinearGradient _searchGradient(Color accentColor) {
    if (isDark) {
      return LinearGradient(
        colors: [_kGrad1, _kGrad3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Light Mode: خلفية بيضاء صلبة
      return const LinearGradient(colors: [Colors.white, Colors.white]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ألوان الشريط في Light Mode
    final fgColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _searchGradient(accentColor),
        // حدود صريحة في Light Mode
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? _kGrad2.withOpacity(0.45) : Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: fgColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: fgColor, fontSize: 16),
              cursorColor: accentColor,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
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
              icon: Icon(Icons.close_rounded, color: fgColor),
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
  final Color accentColor;
  final Color cardBgColor;
  final Color textColor;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
    required this.cardBgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // خلفية الشريحة غير المختارة
    final unselectedBg = isDark
        ? accentColor.withOpacity(.12)
        : cardBgColor; // الأبيض في Light Mode

    // لون الحدود
    final borderColor = isDark
        ? Colors.white.withOpacity(.18)
        : Colors.black.withOpacity(.1);

    // لون النص
    final labelColor = selected ? Colors.white : textColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? accentColor : unselectedBg,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
