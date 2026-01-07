import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget
{
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context)
  {
    return MaterialApp( 
      title: 'sets',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      
      // Account for navigation bar
      builder: (context, child)
      {
        if (child == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: child
        );
      },

      home: const MainScreen(),
    );
  }
}