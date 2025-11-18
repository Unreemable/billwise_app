import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ويدجت شريط تقدّم عام.
/// - يستخدم لنفس المنطق لكل من: الاسترجاع، الاستبدال، الضمان.
/// - يختار اللون والنص تلقائياً حسب نوع السياسة (return / exchange / warranty).
class ExpiryProgress extends StatelessWidget {
  final DateTime startDate;   // تاريخ بداية الفترة (شراء / بداية ضمان / ...).
  final DateTime endDate;     // تاريخ نهاية الفترة (آخر يوم استرجاع / استبدال / انتهاء ضمان).
  final String title;         // نوع السياسة: 'return' أو 'exchange' أو 'warranty'.
  final bool dense;           // إذا true يخلي الشريط أنحف (يُستخدم داخل الكروت الصغيرة).

  /// إذا true يحسب الباقي بالـ "أشهر" بدل "أيام" (مفيد للضمان الطويل).
  final bool showInMonths;

  /// لون مخصص للشريط. لو null نستعمل منطق الألوان التلقائي حسب نوع السياسة.
  final Color? barColor;

  /// إذا true يظهر عنوان السياسة فوق الشريط (return / exchange / warranty + الدائرة الملونة).
  final bool showTitle;

  /// إذا true يظهر سطر حالة تحت الشريط (مثلاً: Expires in 5 days).
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

  // ================= دوال مساعدة عامة =================

  /// ترجيع التاريخ بدون وقت (نصفر الساعة/الدقيقة/الثانية)
  /// عشان الحساب يكون على مستوى "اليوم" وليس الساعة.
  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  /// تحسب الفرق بالأشهر بين تاريخين (a إلى b).
  /// نستخدمها أساساً لحساب منطق الضمان (سنة / سنتين / ...).
  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  // ================= منطق الألوان/الليبل الخاص بكل نوع =================

  /// لون شريط "الاسترجاع" إذا كانت المدة 3 أيام فقط.
  /// يرجع null إذا المدة أصلاً ليست 3 أيام (يعني هذه السياسة ليست استرجاع معياري).
  Color? _threeDayReturnColor(DateTime s, DateTime e) {
    // لو الفرق بين البداية والنهاية ليس 3 أيام، نرجع null
    if (e.difference(s).inDays != 3) return null;

    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays;

    if (diff < 0) return Colors.blueGrey; // الفترة لسه ما بدأت.
    if (diff == 0) return Colors.green;   // اليوم الأول من الاسترجاع.
    if (diff == 1) return Colors.orange;  // اليوم الثاني.
    if (diff == 2) return Colors.red;     // اليوم الثالث والأخير.
    return Colors.grey;                   // انتهت فترة الاسترجاع.
  }

  /// نص مرحلة "الاسترجاع" لعرضه جنب الدائرة (مثلاً: Day 1 of 3).
  String? _threeDayReturnLabel(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 3) return null;

    final today = _d(DateTime.now());
    final diff = today.difference(s).inDays;

    if (diff < 0) return 'Starts soon';          // لم تبدأ فترة الاسترجاع.
    if (diff == 0) return 'Day 1 of 3';          // اليوم 1 من 3.
    if (diff == 1) return 'Day 2 of 3';          // اليوم 2 من 3.
    if (diff == 2) return 'Final day (3 of 3)';  // اليوم الأخير.
    return 'Expired';                            // منتهية.
  }

  /// لون شريط "الاستبدال" إذا كانت المدة 7 أيام.
  Color? _sevenDayExchangeColor(DateTime s, DateTime e) {
    if (e.difference(s).inDays != 7) return null;

    final today = _d(DateTime.now());
    // +1 عشان نحسب اليوم الحالي ضمن العد (عدّ شمولي)
    final diff = today.difference(s).inDays + 1;

    if (diff <= 0) return Colors.blueGrey; // الفترة لم تبدأ.
    if (diff >= 1 && diff <= 3) return Colors.green;   // أول 3 أيام.
    if (diff >= 4 && diff <= 6) return Colors.orange;  // الأيام 4–6.
    if (diff == 7) return Colors.red;                  // اليوم السابع (الأخير).
    return Colors.grey;                                // منتهية.
  }

  /// نص مرحلة "الاستبدال" لعرضه جنب الدائرة.
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

  /// منطق ألوان الضمان:
  /// - يتعامل مع ضمان سنتين بشكل خاص (سنة 1 / أول 6 أشهر من سنة 2 / آخر 6 أشهر).
  /// - لو المدة مختلفة، يقسمها إلى ثلاثة أثلاث (أخضر / برتقالي / أحمر).
  Color? _warrantyColor(DateTime s, DateTime e) {
    final today = _d(DateTime.now());

    if (today.isBefore(s)) return Colors.blueGrey; // الضمان لم يبدأ بعد.
    if (!today.isBefore(e)) return Colors.grey;    // الضمان منتهي.

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);

    // حالة ضمان سنتين تقريباً (23–25 شهر: احتياطاً للفروق البسيطة).
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;   // السنة الأولى.
      if (elapsedMonths < 18) return Colors.orange;  // أول 6 أشهر من السنة الثانية.
      return Colors.red;                             // آخر 6 أشهر من السنة الثانية.
    }

    // في حالة مدد مختلفة: نقسم الأيام إلى ثلاثة أجزاء متساوية تقريباً.
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return Colors.grey;

    final t1 = (totalDays / 3).ceil();       // نهاية الثلث الأول.
    final t2 = (2 * totalDays / 3).ceil();   // نهاية الثلث الثاني.

    if (elapsedDays < t1) return Colors.green;   // الثلث الأول.
    if (elapsedDays < t2) return Colors.orange;  // الثلث الثاني.
    return Colors.red;                           // الثلث الأخير.
  }

  /// نص المرحلة للضمان (Year 1 / Year 2 ... أو First third / Second third / Final third).
  String? _warrantyLabel(DateTime s, DateTime e) {
    final today = _d(DateTime.now());

    if (today.isBefore(s)) return 'Starts soon';
    if (!today.isBefore(e)) return 'Expired';

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);

    // حالة ضمان سنتين.
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return 'Year 1 of 2';
      if (elapsedMonths < 18) return 'Year 2 (first 6 months)';
      return 'Year 2 (final 6 months)';
    }

    // مدد أخرى: تقسيم إلى أثلاث.
    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return 'Expired';

    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();

    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

  /// هذه الدالة هي "العقل" الذي يختار منطق الألوان والنص حسب نوع السياسة:
  /// - لو العنوان 'return' → نستخدم منطق الثلاثة أيام.
  /// - لو 'exchange' → نستخدم منطق السبعة أيام.
  /// - لو 'warranty' → منطق الضمان.
  /// - لو غيرها → ما نرجع شيء (نستعمل المنطق العام لاحقاً).
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

    // ===== حساب نسبة التقدم (progress) بين البداية والنهاية =====
    // نتأكد ما في قيم سلبية أو صفرية تسبب مشاكل.
    final totalDaysRaw = math.max(0, e.difference(s).inDays);
    final totalDays = totalDaysRaw == 0 ? 1 : totalDaysRaw;
    final passedDays =
    now.isBefore(s) ? 0 : math.min(totalDays, now.difference(s).inDays);
    final progress = (passedDays / totalDays).clamp(0.0, 1.0);

    // ===== تحسين بصري: حتى لو اليوم الأول، نخلي جزء صغير من الشريط يكون ملوّن =====
    // عشان المستخدم يحس أن الفترة "بدأت" وما يبان الشريط كأنه صفر.
    final bool isActive = !now.isBefore(s) && now.isBefore(e);
    final double minActive = dense ? 0.06 : 0.04; // 6% للشريط النحيف، 4% للعادي.
    final double visualProgress = isActive ? math.max(progress, minActive) : progress;

    // الأيام المتبقية حتى نهاية الفترة.
    final leftDays = e.difference(now).inDays;

    // تحديد أسلوب الألوان والنص حسب نوع السياسة (return/exchange/warranty).
    final style = _autoStyle(title, s, e);

    // ===== نص الحالة أسفل الشريط (بالأيام أو الأشهر) =====
    final String statusText = () {
      if (showInMonths) {
        // استخدام الأشهر (مفيد للضمان).
        if (leftDays < 0) return 'Expired';
        final m = _monthsBetween(now, e);
        if (m <= 0) return 'Expires in < 1 month';
        if (m == 1) return 'Expires in 1 month';
        return 'Expires in $m months';
      } else {
        // استخدام الأيام (مفيد للاسترجاع/الاستبدال).
        if (leftDays < 0) return 'Expired';
        if (leftDays == 0) return 'Expires today';
        if (leftDays == 1) return 'Expires in 1 day';
        return 'Expires in $leftDays days';
      }
    }();

    // ===== اختيار اللون النهائي للشريط =====
    // الأولوية:
    // 1) barColor لو انرسل من برا.
    // 2) منطق النوع (style.color) لو موجود.
    // 3) منطق عام مبني على نسبة التقدم والأيام المتبقية.
    final Color effectiveBarColor = barColor ??
        style.color ??
        (() {
          if (leftDays < 0) return Colors.red;      // منتهي.
          if (progress >= 0.8) return Colors.red;   // قرب ينتهي جداً.
          if (progress >= 0.5) return Colors.orange;// في النصف الثاني.
          return Colors.green;                      // بداية/منتصف آمن.
        })();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ===== العنوان + الدائرة الملونة + نص المرحلة (اختياري) =====
        if (showTitle && title.isNotEmpty)
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // دائرة صغيرة بنفس لون الشريط
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: effectiveBarColor,
                  shape: BoxShape.circle,
                ),
              ),
              // نص المرحلة إذا موجود (مثلاً: Day 1 of 3)
              if (style.stage != null) ...[
                const SizedBox(width: 8),
                Text(
                  style.stage!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        if (showTitle && title.isNotEmpty) const SizedBox(height: 6),

        // ===== شريط التقدّم نفسه =====
        // الخلفية: أبيض شفاف (نفس ستايل التطبيق).
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: dense ? 6 : 8,
            color: Colors.white24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                // نستخدم visualProgress عشان نضمن حد أدنى في حالة Active.
                widthFactor: visualProgress,
                child: Container(color: effectiveBarColor),
              ),
            ),
          ),
        ),

        // ===== سطر الحالة تحت الشريط (اختياري) =====
        if (showStatus) const SizedBox(height: 6),
        if (showStatus)
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}