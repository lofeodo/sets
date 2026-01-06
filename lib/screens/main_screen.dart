import 'package:flutter/material.dart';

import 'workouts_screen.dart';
import 'plots_screen.dart';

class MainScreen extends StatefulWidget 
{
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> 
{
  int _tabIndex = 0;

  final _tabs = const [
    _TabSpec(
      label: 'Workouts',
      icon: Icons.fitness_center,
      screen: WorkoutsScreen(),
    ),
    _TabSpec(
      label: 'Plots',
      icon: Icons.show_chart,
      screen: PlotsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: _tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: _tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabSpec 
{
  final String label;
  final IconData icon;
  final Widget screen;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.screen,
  });
}