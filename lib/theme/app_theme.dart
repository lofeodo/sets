import 'package:flutter/material.dart';

class AppTheme
{
  static ThemeData dark()
  {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      fontFamily: 'Inter',

      textTheme: const TextTheme(
        // Headers
        headlineLarge: TextStyle(
          fontFamily: 'AeogoBox',
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'AeogoBox',
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontFamily: 'AeogoBox',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),

        // Body
        bodyLarge: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}