import 'package:flutter/material.dart';
import 'dart:math' as math;

class ExpiryProgress extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final bool dense;
  final bool showInMonths;
  final Color? barColor;
  final bool showTitle;
  final bool showStatus;

  // إضافة متغير للتحكم بلون النص من الخارج
  final Color? textColor;

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
    this.textColor, // استقبال اللون الاختياري
  });

  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  Color? _threeDayReturnColor(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 3) return null;

    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays;

    if (diff < 0) return Colors.blueGrey;
    if (diff == 0) return Colors.green;
    if (diff == 1) return Colors.orange;
    if (diff == 2) return Colors.red;
    return Colors.grey;
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
    final diff = today.difference(s).inDays + 1;

    if (diff <= 0) return Colors.blueGrey;
    if (diff >= 1 && diff <= 3) return Colors.green;
    if (diff >= 4 && diff <= 6) return Colors.orange;
    if (diff == 7) return Colors.red;
    return Colors.grey;
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

    if (today.isBefore(s)) return Colors.blueGrey;
    if (!today.isBefore(e)) return Colors.grey;

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);

    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;
      if (elapsedMonths < 18) return Colors.orange;
      return Colors.red;
    }

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

    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();

    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

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
    // تحديد الثيم الحالي
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تحديد الألوان بناءً على (1) المتغير الممرر، أو (2) الثيم
    final mainTextColor = textColor ?? (isDark ? Colors.white : Colors.black87);
    final subTextColor = textColor?.withOpacity(0.7) ?? (isDark ? Colors.white70 : Colors.black54);
    final trackColor = isDark ? Colors.white24 : Colors.black12;

    final s = _d(startDate);
    final e = _d(endDate);
    final now = _d(DateTime.now());

    final totalDaysRaw = math.max(0, e.difference(s).inDays);
    final totalDays = totalDaysRaw == 0 ? 1 : totalDaysRaw;
    final passedDays =
    now.isBefore(s) ? 0 : math.min(totalDays, now.difference(s).inDays);
    final progress = (passedDays / totalDays).clamp(0.0, 1.0);

    final isActive = !now.isBefore(s) && now.isBefore(e);
    final double minActive = dense ? 0.06 : 0.04;
    final double visualProgress = isActive ? math.max(progress, minActive) : progress;

    final leftDays = e.difference(now).inDays;

    final style = _autoStyle(title, s, e);

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
      children: [
        if (showTitle && title.isNotEmpty)
          Row(
            children: [
              Text(
                title[0].toUpperCase() +
                    title.substring(1).toLowerCase(),
                style: TextStyle(
                  color: mainTextColor, // استخدام اللون الديناميكي
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: effectiveBarColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (style.stage != null) ...[
                const SizedBox(width: 8),
                Text(
                  style.stage!,
                  style: TextStyle(
                    color: subTextColor, // استخدام اللون الديناميكي الخافت
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

        if (showTitle) const SizedBox(height: 6),

        // شريط التقدم
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: dense ? 6 : 8,
                color: trackColor, // لون الخلفية للشريط (يتغير حسب الثيم)
              ),
              FractionallySizedBox(
                widthFactor: visualProgress,
                child: Container(
                  height: dense ? 6 : 8,
                  color: effectiveBarColor,
                ),
              ),
            ],
          ),
        ),

        if (showStatus) const SizedBox(height: 6),
        if (showStatus)
          Text(
            statusText,
            style: TextStyle(
              color: subTextColor, // استخدام اللون الديناميكي الخافت
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}