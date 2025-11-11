import 'package:flutter/material.dart';
import 'dart:math' as math;

/// شريط تقدّم موحّد + منطق ألوان موحّد
class ExpiryProgress extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final bool dense;

  /// إذا true يظهر الباقي بالأشهر (يفيد للضمان).
  final bool showInMonths;

  /// لون مخصص. إن لم يُمرَّر سنستخدم المنطق الموحَّد حسب نوع السياسة.
  final Color? barColor;

  /// إظهار العنوان فوق الشريط.
  final bool showTitle;

  /// إظهار سطر الحالة تحت الشريط.
  final bool showStatus;

  const ExpiryProgress({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.title,
    this.dense = false,
    this.showInMonths = false,
    this.barColor,
    this.showTitle = true,
    this.showStatus = true,
  });

  // ================= Helpers عامة =================
  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  // ================= منطق الألوان/الليبل الموحّد =================

  Color? _threeDayReturnColor(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 3) return null;
    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return Colors.blueGrey; // لم يبدأ
    if (diff == 0) return Colors.green;   // اليوم 1
    if (diff == 1) return Colors.orange;  // اليوم 2
    if (diff == 2) return Colors.red;     // اليوم 3 (الأخير)
    return Colors.grey;                   // منتهي
  }

  String? _threeDayReturnLabel(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 3) return null;
    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return 'Starts soon';
    if (diff == 0) return 'Day 1 of 3';
    if (diff == 1) return 'Day 2 of 3';
    if (diff == 2) return 'Final day (3 of 3)';
    return 'Expired';
  }

  Color? _sevenDayExchangeColor(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 7) return null;
    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays + 1; // عدّ شمولي
    if (diff <= 0) return Colors.blueGrey; // لم يبدأ
    if (diff >= 1 && diff <= 3) return Colors.green;
    if (diff >= 4 && diff <= 6) return Colors.orange;
    if (diff == 7) return Colors.red;      // اليوم الأخير
    return Colors.grey;                    // منتهي
  }

  String? _sevenDayExchangeLabel(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 7) return null;
    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays + 1;
    if (diff <= 0) return 'Starts soon';
    if (diff >= 1 && diff <= 3) return 'Days 1–3 of 7';
    if (diff >= 4 && diff <= 6) return 'Days 4–6 of 7';
    if (diff == 7) return 'Final day (7 of 7)';
    return 'Expired';
  }

  Color? _warrantyColor(DateTime s, DateTime e) {
    final today = _d(DateTime.now());
    if (today.isBefore(s)) return Colors.blueGrey; // Starts soon
    if (!today.isBefore(e)) return Colors.grey;    // Expired

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);

    // ضمان سنتين تقريبًا
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;   // سنة 1
      if (elapsedMonths < 18) return Colors.orange;  // أول 6 أشهر من السنة 2
      return Colors.red;                              // آخر 6 أشهر
    }

    // مدد مختلفة: تقسيم إلى أثلاث بالأيام
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return Colors.grey;
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return Colors.green;
    if (elapsedDays < t2) return Colors.orange;
    return Colors.red;
  }

  String? _warrantyLabel(DateTime s, DateTime e) {
    final today = _d(DateTime.now());
    if (today.isBefore(s)) return 'Starts soon';
    if (!today.isBefore(e)) return 'Expired';

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return 'Year 1 of 2';
      if (elapsedMonths < 18) return 'Year 2 (first 6 months)';
      return 'Year 2 (final 6 months)';
    }

    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return 'Expired';
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

  // يختار اللون والليبل تلقائيًا حسب العنوان
  ({Color? color, String? stage}) _autoStyle(String title, DateTime s, DateTime e) {
    final kind = title.toLowerCase();
    if (kind == 'return') {
      return (color: _threeDayReturnColor(s, e), stage: _threeDayReturnLabel(s, e));
    } else if (kind == 'exchange') {
      return (color: _sevenDayExchangeColor(s, e), stage: _sevenDayExchangeLabel(s, e));
    } else if (kind == 'warranty') {
      return (color: _warrantyColor(s, e), stage: _warrantyLabel(s, e));
    }
    return (color: null, stage: null);
  }

  @override
  Widget build(BuildContext context) {
    final s = _d(startDate);
    final e = _d(endDate);
    final now = _d(DateTime.now());

    // حساب النسبة (آمن ضد القيم المعكوسة/الصفرية)
    final totalDaysRaw = math.max(0, e.difference(s).inDays);
    final totalDays = totalDaysRaw == 0 ? 1 : totalDaysRaw;
    final passedDays = now.isBefore(s) ? 0 : math.min(totalDays, now.difference(s).inDays);
    final progress = (passedDays / totalDays).clamp(0.0, 1.0);

    // NEW: حدّ أدنى بصري في حالة Active (اليوم داخل النافذة) — حتى Day 1 ما يختفي اللون
    final bool isActive = !now.isBefore(s) && now.isBefore(e);
    final double minActive = dense ? 0.06 : 0.04; // 6% للشريط النحيف، 4% للعادي
    final double visualProgress = isActive ? math.max(progress, minActive) : progress;

    // الباقي
    final leftDays = e.difference(now).inDays;

    // ستايل تلقائي حسب نوع السياسة
    final style = _autoStyle(title, s, e);

    // نص الحالة (expires in …)
    final String statusText = () {
      if (showInMonths) {
        if (leftDays < 0) return 'Expired';
        final m = _monthsBetween(now, e);
        if (m <= 0) return 'Expires in < 1 month';
        if (m == 1) return 'Expires in 1 month';
        return 'Expires in $m months';
      } else {
        if (leftDays < 0) return 'Expired';
        if (leftDays == 0) return 'Expires today';
        if (leftDays == 1) return 'Expires in 1 day';
        return 'Expires in $leftDays days';
      }
    }();

    // لون الشريط النهائي
    final Color effectiveBarColor = barColor ??
        style.color ??
        (() {
          if (leftDays < 0) return Colors.red;
          if (progress >= 0.8) return Colors.red;
          if (progress >= 0.5) return Colors.orange;
          return Colors.green;
        })();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle && title.isNotEmpty)
          Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: effectiveBarColor, shape: BoxShape.circle)),
              if (style.stage != null) ...[
                const SizedBox(width: 8),
                Text(style.stage!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ],
          ),
        if (showTitle && title.isNotEmpty) const SizedBox(height: 6),

        // شريط التقدّم (خلفية موحّدة مثل الهوم: أبيض شفاف)
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: dense ? 6 : 8,
            color: Colors.white24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: visualProgress, // ← بدلاً من progress
                child: Container(color: effectiveBarColor),
              ),
            ),
          ),
        ),

        if (showStatus) const SizedBox(height: 6),
        if (showStatus)
          Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
