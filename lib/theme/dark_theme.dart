import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0E0722), // Hintergrund dunkel
  primaryColor: const Color(0xFF6C3EFF),
  cardColor: const Color(0x1AFFFFFF),

  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    bodyLarge: TextStyle(color: Colors.white),
  ),

  iconTheme: const IconThemeData(color: Colors.white),
);
