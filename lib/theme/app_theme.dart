import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'font_sizes.dart';

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
    );

    // Apply body text everywhere by default
    final text = base.textTheme.apply(
      fontFamily: 'JetBrainsMono',
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        // Headers only
        headlineLarge: text.headlineLarge?.copyWith(
          fontFamily: 'AeogoBox',
          fontStyle: FontStyle.italic,
          fontSize: FontSizes.headerLarge,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontFamily: 'AeogoBox',
          fontSize: FontSizes.headerMedium,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontFamily: 'AeogoBox',
          fontSize: FontSizes.headerSmall,
        ),

        titleLarge: text.titleLarge?.copyWith(fontSize: FontSizes.titleLarge),
        titleMedium: text.titleMedium?.copyWith(fontSize: FontSizes.titleMedium),
        titleSmall: text.titleSmall?.copyWith(fontSize: FontSizes.titleSmall),

        bodyLarge: text.bodyLarge?.copyWith(fontSize: FontSizes.bodyLarge, height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: FontSizes.bodyMedium, height: 1.4),
        bodySmall: text.bodySmall?.copyWith(fontSize: FontSizes.bodySmall),

        labelLarge: text.labelLarge?.copyWith(fontSize: FontSizes.labelLarge),
        labelMedium: text.labelMedium?.copyWith(fontSize: FontSizes.labelMedium),
        labelSmall: text.labelSmall?.copyWith(fontSize: FontSizes.labelSmall),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      datePickerTheme: DatePickerThemeData(
        headerHeadlineStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: FontSizes.titleMedium,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}