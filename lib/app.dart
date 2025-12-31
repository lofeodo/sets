import 'package:flutter/material.dart';
import 'screens/workouts_screen.dart';

class MyApp extends StatelessWidget
{
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context)
  {
    return MaterialApp( 
      title: 'sets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WorkoutsScreen(),
    );
  }
}