import 'package:flutter/material.dart';

class ExpiryProgress extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final bool dense;

  /// If true → show remaining in months; else days.
  final bool showInMonths;

  const ExpiryProgress({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.title,
    this.dense = false,
    this.showInMonths = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays;
    final passedDays = now.difference(startDate).inDays;
    final progress = totalDays > 0 ? (passedDays / totalDays).clamp(0.0, 1.0) : 1.0;

    // كم باقي
    final leftDays = endDate.difference(now).inDays;

    // تحديد النص
    String label;
    if (showInMonths) {
      final leftMonths = (leftDays / 30).floor();
      label = leftMonths < 0 ? 'Expired' : 'Expires in $leftMonths months';
    } else {
      if (leftDays < 0) {
        label = 'Expired';
      } else if (leftDays == 0) {
        label = 'Today';
      } else {
        label = 'Expires in $leftDays days';
      }
    }

    // اختيار اللون حسب الوقت
    Color barColor;
    if (leftDays < 0) {
      barColor = Colors.red; // منتهي
    } else if (progress >= 0.8) {
      barColor = Colors.red; // قريب جدًا
    } else if (progress >= 0.5) {
      barColor = Colors.orange; // متوسط (تحذير)
    } else {
      barColor = Colors.green; // آمن
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: dense ? 4 : 8,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
