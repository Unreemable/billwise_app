import 'dart:ui' as ui; // لاستخدام TextDirection.ltr
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../data/bill_service.dart';
import 'add_bill_page.dart';
import 'bill_detail_page.dart';
// استيراد صفحة تفاصيل الضمان (تمت إضافته لحل الخطأ)
import '../../warranties/ui/warranty_detail_page.dart';
// لو حابة تفتحي تبويب الضمانات:
import '../../warranties/ui/warranty_list_page.dart';

// تم حذف جميع ثوابت الألوان المخصصة هنا واعتماد الثيم بدلاً منها

// ===== ثوابت الألوان الداكنة (للمزج في Dark Mode فقط) =====
const Color _kGrad1    = Color(0xFF9B5CFF);   // Violet أفتح ومريح
const Color _kGrad2    = Color(0xFF6C3EFF);   // البنفسجي الأساسي
const Color _kGrad3    = Color(0xFFC58CFF);   // Lavender وردي ناعم بدل الأزرق
// ========================================================

/// ============ الشريط السفلي المتدرّج (مُعاد استخدامه من الهوم) ============
class GradientBottomBar extends StatelessWidget {
  /// 0 = Warranties, 1 = Bills
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
    // استخدام لون أغمق قليلاً في Light Mode لضمان التباين مع الخلفية اللافندر
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
                  // الظل يظل داكنًا دائمًا لتمييز الشريط
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
                    // تمرير اللون الأساسي لزر الهوم
                    onTap: () {
                      // رجوع لصفحة الهوم (root navigator)
                      Navigator.of(context, rootNavigator: true)
                          .pushNamed('/home');
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

/// عنصر واحد في الشريط السفلي (أيقونة + نص)
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // الألوان داخل الشريط السفلي ثابتة (أبيض/أبيض خافت) لأن خلفيته داكنة (أرجواني) في كلا الوضعين
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

/// الزر الدائري في النص المستخدم للرجوع للهوم
class _FabDot extends StatelessWidget {
  final VoidCallback? onTap;
  final Color accentColor;
  const _FabDot({this.onTap, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    // التدرج هنا يستخدم اللون الأرجواني الممرر
    final start = accentColor;
    final end = accentColor.withOpacity(0.8);

    return InkWell(
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [start, end],
          ),
          boxShadow: [
            BoxShadow(
              // الظل ثابت (أرجواني خافت)
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

/// صفحة قائمة الفواتير:
/// - تعرض كل الفواتير للمستخدم الحالي
/// - تدعم البحث، والفرز، واستعراض حالة الاسترجاع/الاستبدال بسرعة
/// - تستخدم نفس الشريط السفلي المتدرج مع الهوم/الضمانات
class BillListPage extends StatefulWidget {
  const BillListPage({super.key});
  static const route = '/bills';

  @override
  State<BillListPage> createState() => _BillListPageState();
}

/// خيارات الفرز:
/// - newest:   الأحدث أولاً (حسب created_at)
/// - oldest:   الأقدم أولاً
/// - nearExpiry: حسب أقرب تاريخ انتهاء (استرجاع/استبدال/ضمان)
enum _BillSort { newest, oldest, nearExpiry }

/// ✅ الحالة العامة لكل فاتورة (تُعرض في التايل):
/// - active:       الاسترجاع ما زال متاح
/// - exchangeOnly: الاسترجاع منتهي، الاستبدال ما زال متاح
/// - expired:      كل شيء منتهي
enum _BillOverallStatus {
  active,        // 🟢 الاسترجاع ما زال صالح
  exchangeOnly,  // 🟠 الاسترجاع منتهي، الاستبدال متاح
  expired,       // 🔴 الاسترجاع والاستبدال منتهية (أو غير موجودة)
}

class _BillListPageState extends State<BillListPage> {
  final _searchCtrl = TextEditingController();
  final _money = NumberFormat.currency(
    locale: 'en',
    symbol: 'SAR ',
    decimalDigits: 2,
  );
  _BillSort _sort = _BillSort.newest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================ توابع مساعدة (نصوص وألوان) ================

  /// إزالة جزء الوقت من التاريخ: نهتم فقط بالسنة/الشهر/اليوم.
  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// عدد الأشهر بين تاريخين (سنة + شهر فقط).
  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  // ==== منطق الحالة العامة لكل فاتورة (الكرت) ====

  /// حساب الحالة العامة للفاتورة بناءً على تواريخ الاسترجاع والاستبدال:
  _BillOverallStatus _overallStatusForBill(
      DateTime? returnUtc,
      DateTime? exchangeUtc,
      ) {
    final today = _onlyDate(DateTime.now());
    final ret = returnUtc == null ? null : _onlyDate(returnUtc.toLocal());
    final ex  = exchangeUtc == null ? null : _onlyDate(exchangeUtc.toLocal());

    // 🟢 الاسترجاع ما زال داخل الفترة (قبل تاريخ النهاية)
    if (ret != null && today.isBefore(ret)) {
      return _BillOverallStatus.active;
    }

    // 🟠 الاسترجاع انتهى (today >= ret) لكن الاستبدال ما زال متاح
    if (ex != null &&
        (today.isBefore(ex) || today.isAtSameMomentAs(ex))) {
      return _BillOverallStatus.exchangeOnly;
    }

    // 🔴 لا استرجاع ولا استبدال متاحين (أو غير مضافين)
    return _BillOverallStatus.expired;
  }

  /// بناء شِب صغير (Chip) للحالة أسفل كل عنصر فاتورة:
  Widget _billStatusChip(BuildContext context, DateTime? returnUtc, DateTime? exchangeUtc) {
    final status = _overallStatusForBill(returnUtc, exchangeUtc);

    late Color color;
    late String text;
    IconData icon = Icons.check_circle_rounded;

    switch (status) {
      case _BillOverallStatus.active:       // 🟢
        color = Colors.green;
        text = 'active';
        break;
      case _BillOverallStatus.exchangeOnly: // 🟠
        color = Colors.orange;
        text = 'active';
        break;
      case _BillOverallStatus.expired:      // 🔴
        color = Colors.red;
        text = 'expired';
        icon = Icons.close_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Chip(
        avatar: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  /// منطق الألوان لسياسة استرجاع 3 أيام (تقدّم خلال 3 أيام).
  Color? _threeDayReturnColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;

    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;

    if (diff < 0) return Colors.blueGrey; // قبل بداية الفترة
    if (diff == 0) return Colors.green;   // اليوم الأول
    if (diff == 1) return Colors.orange;  // اليوم الثاني
    if (diff == 2) return Colors.red;     // اليوم الثالث (الأخير)
    return Colors.grey;                   // بعد 3 أيام
  }

  /// تسمية نصية لسياسة استرجاع 3 أيام.
  String? _threeDayReturnLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;

    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;

    if (diff < 0) return 'Starts soon';
    if (diff == 0) return 'Day 1 of 3';
    if (diff == 1) return 'Day 2 of 3';
    if (diff == 2) return 'Final day (3 of 3)';
    return 'Expired';
  }

  /// منطق الألوان لسياسة استبدال 7 أيام.
  Color? _sevenDayExchangeColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;

    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1; // اليوم رقم [1..7]

    if (diff <= 0) return Colors.blueGrey;               // لم تبدأ الفترة بعد
    if (diff >= 1 && diff <= 3) return Colors.green;     // بداية الفترة
    if (diff >= 4 && diff <= 6) return Colors.orange;    // منتصف الفترة
    if (diff == 7) return Colors.red;                    // اليوم الأخير
    return Colors.grey;                                  // بعد 7 أيام
  }

  /// تسمية نصية لسياسة استبدال 7 أيام.
  String? _sevenDayExchangeLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;

    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1; // اليوم رقم [1..7]

    if (diff <= 0) return 'Starts soon';
    if (diff >= 1 && diff <= 3) return 'Days 1–3 of 7';
    if (diff >= 4 && diff <= 6) return 'Days 4–6 of 7';
    if (diff == 7) return 'Final day (7 of 7)';
    return 'Expired';
  }

  /// منطق ألوان الضمان (شهور + تقسيم لثلاث مراحل).
  Color? _warrantyColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());

    // قبل بداية الضمان
    if (today.isBefore(s)) return Colors.blueGrey;
    // عند أو بعد تاريخ الانتهاء → منتهي
    if (!today.isBefore(e)) return Colors.grey;

    // حالة خاصة: ضمان سنتين تقريباً (24 شهر)
    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;   // السنة الأولى
      if (elapsedMonths < 18) return Colors.orange;  // السنة الثانية (أول 6 شهور)
      return Colors.red;                             // السنة الثانية (آخر 6 شهور)
    }

    // الحالة العامة: تقسيم الضمان لثلاثة أثلاث حسب الأيام
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return Colors.grey;
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();

    if (elapsedDays < t1) return Colors.green;   // الثلث الأول
    if (elapsedDays < t2) return Colors.orange;  // الثلث الثاني
    return Colors.red;                           // الثلث الأخير
  }

  /// تسمية نصية لمرحلة الضمان (سنة/ثلث).
  String? _warrantyLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());

    if (today.isBefore(s)) return 'Starts soon';
    if (!today.isBefore(e)) return 'Expired';

    // منطق خاص للـسنتين
    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return 'Year 1 of 2';
      if (elapsedMonths < 18) return 'Year 2 (first 6 months)';
      return 'Year 2 (final 6 months)';
    }

    // منطق عام لثلاثة أثلاث
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return 'Expired';
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();

    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

  /// يبني بلوك كامل لسياسة واحدة (مؤشر + ExpiryProgress) لـ:
  /// - Return
  /// - Exchange
  /// - Warranty
  ///
  /// يختار منطق اللون/التسمية بناءً على [title].
  Widget _policyBlock({
    required BuildContext context,
    required String title,
    required DateTime? start,
    required DateTime? end,
  }) {
    if (start == null || end == null) return const SizedBox.shrink();

    final kind = title.toLowerCase();
    final isReturn = kind == 'return';
    final isExchange = kind == 'exchange';
    final isWarranty = kind == 'warranty';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // *** الحل: تثبيت اللون الأسود الصريح في Light Mode، والأبيض في Dark Mode ***
    final policyTextColor = isDark ? Colors.white : Colors.black;

    // اختيار منطق اللون/التسمية حسب نوع السياسة
    final threeDayColor = isReturn ? _threeDayReturnColor(start, end) : null;
    final threeDayLabel = isReturn ? _threeDayReturnLabel(start, end) : null;

    final sevenDayColor = isExchange ? _sevenDayExchangeColor(start, end) : null;
    final sevenDayLabel = isExchange ? _sevenDayExchangeLabel(start, end) : null;

    final warrantyColor = isWarranty ? _warrantyColor(start, end) : null;
    final warrantyLabel = isWarranty ? _warrantyLabel(start, end) : null;

    // اللون النهائي المستخدم في ExpiryProgress
    final barColor = threeDayColor ?? sevenDayColor ?? warrantyColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // *** هذا هو النص الخارجي الملون يدوياً (أسود/أبيض) ***
        Text(
          title,
          style: TextStyle(
            color: policyTextColor, // تثبيت اللون ديناميكياً
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),

        if (threeDayColor != null) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: threeDayColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                threeDayLabel ?? 'Return (3-day window)',
                style: TextStyle(
                  color: policyTextColor, // تم الإصلاح: أسود/أبيض صريح
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (sevenDayColor != null) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: sevenDayColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sevenDayLabel ?? 'Exchange (7-day window)',
                style: TextStyle(
                  color: policyTextColor, // تم تثبيت اللون هنا
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (warrantyColor != null) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: warrantyColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                warrantyLabel ?? 'Warranty (3 segments)',
                style: TextStyle(
                  color: policyTextColor, // تم تثبيت اللون هنا
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // *** تم إخفاء العنوان الداخلي لمنع التكرار والاختفاء (showTitle: false) ***
        ExpiryProgress(
          title: title,
          startDate: start,
          endDate: end,
          dense: true,
          showInMonths: isWarranty,
          barColor: barColor,
          showTitle: false, // <-- هذا هو الحل لإخفاء النص الأبيض الافتراضي
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  DateTime? _nearestExpiry(Map<String, dynamic> d) {
    DateTime? parseTs(dynamic v) => (v is Timestamp) ? v.toDate().toLocal() : null;
    DateTime? minDate(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isBefore(b) ? a : b;
    }
    final ret = parseTs(d['return_deadline']);
    final ex  = parseTs(d['exchange_deadline']);
    final w   = parseTs(d['warranty_end_date']);
    final m = minDate(minDate(ret, ex), w);
    return m == null ? null : DateTime(m.year, m.month, m.day);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // الألوان الموحدة
    final accentColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium!.color!; // أسود/أبيض
    final dimColor = isDark ? Colors.white70 : Colors.black54; // نص خافت

    // لون البطاقة
    final cardBgColor = theme.cardColor;
    // لون حد البطاقة
    final cardStrokeColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

    // ====== إصلاح شريط البحث وفلاتر الفرز للوضع الداكن ======
    // في Dark Mode: نستخدم تدرج أرجواني ساطع للبحث.
    // في Light Mode: نستخدم لون أرجواني خفيف أو لون عادي.
    final searchGradient = isDark
        ? LinearGradient(
      colors: [accentColor, accentColor.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : null; // لا تدرج في Light Mode، نستخدم لون ثابت للخلفية

    final searchBgColor = isDark
        ? Colors.transparent // مع التدرج نستخدم شفافية هنا
        : Colors.grey.shade100; // لون خلفية فاتح للحقل في Light Mode

    final searchFgColor = isDark ? Colors.white : textColor;
    final searchHintColor = isDark ? Colors.white70 : Colors.black45;

    // الظل ثابت في Dark Mode، وخفيف جداً في Light Mode
    final searchShadowColor = isDark ? accentColor.withOpacity(0.45) : Colors.black.withOpacity(0.05);
    // ========================================================

    // خلفية مربعات التصفية غير المختارة في Dark Mode (أرجواني خافت)
    final chipBackgroundDark = accentColor.withOpacity(0.12);


    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // الخلفية من الثيم

        // ===== AppBar بدون سهم رجوع (لأنه في شريط تنقّل سفلي) =====
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: theme.scaffoldBackgroundColor, // خلفية من الثيم
          elevation: 0,
          title: Text(
            'Bills',
            style: TextStyle(color: textColor),
          ),
          // تم حذف flexibleSpace
        ),



        // زر عائم لإضافة فاتورة جديدة
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const AddBillPage()),
            );
            if (mounted) setState(() {}); // إعادة تحميل بعد الإضافة
          },
          backgroundColor: accentColor, // لون أرجواني
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),

        body: uid == null
        // إذا المستخدم غير مسجّل الدخول، نعرض رسالة بسيطة
            ? Center(
          child: Text(
            'Please sign in to view your bills.',
            style: TextStyle(color: textColor),
          ),
        )
            : Column(
          children: [
            // ====== شريط البحث (عنوان/متجر) ======
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // لون خلفية ثابت في Light Mode
                  color: searchBgColor,
                  // تدرج في Dark Mode فقط
                  gradient: searchGradient,
                  boxShadow: [
                    BoxShadow(
                      color: searchShadowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: searchFgColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                          color: searchFgColor,
                          fontSize: 16,
                        ),
                        cursorColor: searchFgColor,
                        decoration: InputDecoration(
                          hintText: 'Search by title or store',
                          hintStyle: TextStyle(color: searchHintColor),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: searchFgColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ====== فلاتر الفرز: Newest / Oldest / Near expiry ======
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sort == _BillSort.newest,
                    onSelected: (_) =>
                        setState(() => _sort = _BillSort.newest),
                    labelStyle: TextStyle(
                      // النص أبيض عند الاختيار، أو لون النص العادي للثيم
                      color: _sort == _BillSort.newest
                          ? Colors.white
                          : textColor,
                    ),
                    selectedColor: accentColor, // خلفية أرجوانية عند الاختيار
                    backgroundColor: isDark
                        ? chipBackgroundDark // خلفية داكنة مائلة للشفافية
                        : Colors.grey.shade100, // خلفية فاتحة خفيفة في Light Mode
                  ),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sort == _BillSort.oldest,
                    onSelected: (_) =>
                        setState(() => _sort = _BillSort.oldest),
                    labelStyle: TextStyle(
                      color: _sort == _BillSort.oldest
                          ? Colors.white
                          : textColor,
                    ),
                    selectedColor: accentColor,
                    backgroundColor: isDark
                        ? chipBackgroundDark
                        : Colors.grey.shade100,
                  ),
                  ChoiceChip(
                    label: const Text('Near expiry'),
                    selected: _sort == _BillSort.nearExpiry,
                    onSelected: (_) =>
                        setState(() => _sort = _BillSort.nearExpiry),
                    labelStyle: TextStyle(
                      color: _sort == _BillSort.nearExpiry
                          ? Colors.white
                          : textColor,
                    ),
                    selectedColor: accentColor,
                    backgroundColor: isDark
                        ? chipBackgroundDark
                        : Colors.grey.shade100,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ====== قائمة الفواتير (Stream من Firestore) ======
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: BillService.instance.streamBillsSnapshot(
                  userId: uid,
                  orderBy: 'created_at',
                  descending: _sort != _BillSort.oldest,
                ),
                builder: (context, s) {
                  if (s.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${s.error}',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }
                  if (!s.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // المستندات الخام من Firestore
                  var docs = s.data!.docs;

                  // ===== فلتر البحث على العميل (title + shop_name) =====
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final title = (d['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final shop = (d['shop_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      return title.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No bills found.',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }

                  // ===== فرز إضافي حسب "Near expiry" إذا تم اختياره =====
                  if (_sort == _BillSort.nearExpiry) {
                    docs.sort((a, b) {
                      final ax = _nearestExpiry(a.data());
                      final bx = _nearestExpiry(b.data());
                      if (ax == null && bx == null) return 0;
                      if (ax == null) return 1;
                      if (bx == null) return -1;
                      return ax.compareTo(bx);
                    });
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16,
                    ),
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final title  =
                      (d['title'] ?? '—').toString();
                      final shop   =
                      (d['shop_name'] ?? '—').toString();
                      final amount =
                      (d['total_amount'] as num?)?.toDouble();

                      final purchase = (d['purchase_date']
                      as Timestamp?)
                          ?.toDate()
                          .toLocal();
                      final ret = (d['return_deadline']
                      as Timestamp?)
                          ?.toDate()
                          .toLocal();
                      final ex = (d['exchange_deadline']
                      as Timestamp?)
                          ?.toDate()
                          .toLocal();

                      final hasWarranty =
                          (d['warranty_coverage'] as bool?) ?? false;
                      final wEnd = (d['warranty_end_date']
                      as Timestamp?)
                          ?.toDate()
                          .toLocal();

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBgColor, // لون البطاقة من الثيم
                          borderRadius:
                          BorderRadius.circular(12),
                          border: Border.all(color: cardStrokeColor), // حد خفيف
                        ),
                        child: ListTile(
                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            shop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${title == shop ? '' : '$title • '}${amount == null ? '-' : _money.format(amount)}',
                                style: TextStyle(
                                  color: dimColor, // نص خافت
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ===== بلوك سياسة الاسترجاع (مع العنوان) =====
                              _policyBlock(
                                context: context,
                                title: 'Return',
                                start: purchase,
                                end: ret,
                              ),
                              const SizedBox(height: 10),

                              // ===== بلوك سياسة الاستبدال (مع العنوان) =====
                              _policyBlock(
                                context: context,
                                title: 'Exchange',
                                start: purchase,
                                end: ex,
                              ),
                              const SizedBox(height: 10),

                              // ملاحظة: لا نعرض شريط الضمان في التايل
                              // (الضمان معروض بشكل أوضح في صفحة التفاصيل)
                              _billStatusChip(context, ret, ex),
                            ],
                          ),
                          // عند الضغط → فتح صفحة تفاصيل الفاتورة مع BillDetails
                          onTap: () {
                            final details = BillDetails(
                              id: doc.id,
                              title: title,
                              product: shop,
                              amount: amount ?? 0,
                              purchaseDate:
                              purchase ?? DateTime.now(),
                              returnDeadline: ret,
                              exchangeDeadline: ex,
                              hasWarranty: hasWarranty,
                              warrantyExpiry: wEnd,
                            );
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) => BillDetailPage(
                                  details: details,
                                ),
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