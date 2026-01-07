import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

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
          seedColor: const Color(0xFFF2F2F2),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: const Color(0xFFF2F2F2)
        ),

        // Global text color
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF2F2F2)),
          bodyMedium: TextStyle(color: Color(0xFFF2F2F2)),
          bodySmall: TextStyle(color: Color(0xFFF2F2F2)),
          titleLarge: TextStyle(color: Color(0xFFF2F2F2)),
          titleMedium: TextStyle(color: Color(0xFFF2F2F2)),
          titleSmall: TextStyle(color: Color(0xFFF2F2F2)),
          labelLarge: TextStyle(color: Color(0xFFF2F2F2)),
        )
      ),
      home: const MainScreen(),
    );
  }
}