import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'theme/app_colors.dart';

class MyApp extends StatelessWidget
{
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context)
  {
    return MaterialApp( 
      title: 'sets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        
        // Background color
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),

        // Color system
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary
        ),

        // Global text color
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textPrimary),
          titleLarge: TextStyle(color: AppColors.textPrimary),
          titleMedium: TextStyle(color: AppColors.textPrimary),
          titleSmall: TextStyle(color: AppColors.textPrimary),
          labelLarge: TextStyle(color: AppColors.textPrimary),
        )
      ),
      home: const MainScreen(),
    );
  }
}