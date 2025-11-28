import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: const Color(0xFFF7F3FF), // Lavender Light
  primaryColor: const Color(0xFF6C3EFF),            // Purple Brand
  cardColor: Colors.white,

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF7F3FF),
    elevation: 0,
    foregroundColor: Colors.black87,
  ),

  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
    bodyLarge: TextStyle(color: Colors.black87),
  ),

  iconTheme: const IconThemeData(color: Colors.black87),
);
