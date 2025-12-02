import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0E0722), // الخلفية الداكنة (#0E0722)
  primaryColor: const Color(0xFF9B5CFF), // اللون الأرجواني المطلوب
  cardColor: const Color(0xFF171636), // لون البطاقة (أغمق من الخلفية)
  canvasColor: const Color(0xFF171636), // لون السطح للحقول

  colorScheme: const ColorScheme.dark(
    // تحديد primaryColor مرة أخرى للتأكد من اعتماده
    primary: Color(0xFF9B5CFF),
    // لون السطح (surface) للحقول والبطاقات
    surface: Color(0xFF171636),
    // لون النص على السطح الداكن
    onSurface: Colors.white,
    // لون للخلفية الأساسية
    background: Color(0xFF0E0722),
  ),

  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    bodyLarge: TextStyle(color: Colors.white),
  ),

  iconTheme: const IconThemeData(color: Colors.white),
);