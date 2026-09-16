import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'dashboard_screen.dart';
import 'nutrition_screen.dart';
import 'profile_screen.dart';
import 'training_camp_screen.dart';

/// Root scaffold that owns the persistent bottom navigation and
/// keeps each tab alive via an IndexedStack.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _navItems = [
    NavItem(Icons.home_filled, 'Home'),
    NavItem(Icons.fitness_center, 'Train'),
    NavItem(Icons.restaurant, 'Fuel'),
    NavItem(Icons.person, 'Profile'),
  ];

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigate: _goToTab),
      const TrainingCampScreen(),
      const NutritionScreen(),
      const ProfileScreen(asTab: true),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _index,
        onTap: _goToTab,
      ),
    );
  }
}
