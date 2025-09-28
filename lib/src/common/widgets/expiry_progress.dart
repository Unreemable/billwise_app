import 'package:flutter/material.dart';
import 'dart:math' as math;

class ExpiryProgress extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final bool dense;

  /// إذا true يظهر الباقي بالأشهر، وإلا بالأيام.
  final bool showInMonths;

  /// لون مخصص لشريط التقدم. إن لم يُمرَّر سيُحسب تلقائياً.
  final Color? barColor;

  const ExpiryProgress({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.title,
    this.dense = false,
    this.showInMonths = false,
    this.barColor, // NEW
  });

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// فرق الأشهر التقريبي متجاهلاً اليوم.
  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  @override
  Widget build(BuildContext context) {
    // استخدم تاريخ بدون وقت لتفادي off-by-one بسبب الساعات
    final start = _dateOnly(startDate);
    final end   = _dateOnly(endDate);
    final now   = _dateOnly(DateTime.now());

    // إن كان المدى معكوساً أو صفر، نتعامل معه بأمان
    final totalDaysRaw = math.max(0, end.difference(start).inDays);
    final totalDays = totalDaysRaw == 0 ? 1 : totalDaysRaw; // لتفادي القسمة على صفر
    final passedDays = now.isBefore(start)
        ? 0
        : math.min(totalDays, now.difference(start).inDays);

    final progress = (passedDays / totalDays).clamp(0.0, 1.0);

    // الباقي (سالب = منتهي)
    final leftDays = end.difference(now).inDays;

    // ====== نص الحالة ======
    String label;
    if (showInMonths) {
      final leftMonths = _monthsBetween(now, end);
      if (leftDays < 0) {
        label = 'Expired';
      } else if (leftMonths <= 0) {
        // أقل من شهر لكن لسه نشط
        label = 'Expires in < 1 month';
      } else if (leftMonths == 1) {
        label = 'Expires in 1 month';
      } else {
        label = 'Expires in $leftMonths months';
      }
    } else {
      if (leftDays < 0) {
        label = 'Expired';
      } else if (leftDays == 0) {
        label = 'Today';
      } else if (leftDays == 1) {
        label = 'Expires in 1 day';
      } else {
        label = 'Expires in $leftDays days';
      }
    }

    // ====== لون الشريط ======
    final effectiveBarColor = barColor ?? () {
      if (leftDays < 0) return Colors.red;      // منتهي
      if (progress >= 0.8) return Colors.red;   // قريب جداً من الانتهاء
      if (progress >= 0.5) return Colors.orange;// منتصف/تحذير
      return Colors.green;                      // آمن
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),

        // شريط التقدم
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: dense ? 4 : 8,
            // لو barColor ممرّر نستخدمه، وإلا اللون المتولد أعلاه
            valueColor: AlwaysStoppedAnimation<Color>(effectiveBarColor),
            backgroundColor: Colors.grey.shade300,
          ),
        ),

        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
