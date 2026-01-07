import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Background color
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),

      // Color system
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),

      // Default body font
      fontFamily: 'Inter',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // ===== HEADERS (AeogoBox) =====
        headlineLarge: const TextStyle(
          fontFamily: 'AeogoBox',
          fontSize: 40,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'AeogoBox',
          fontSize: 35,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'VT323',
          fontSize: 30,
          color: AppColors.textPrimary,
        ),

        // ===== BODY (Inter) =====
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.4,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),

        // ===== LABELS =====
        labelLarge: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          color: AppColors.textPrimary,
        ),
        titleSmall: const TextStyle(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}