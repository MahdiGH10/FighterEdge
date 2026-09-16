import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'dashboard_screen.dart';
import 'nutrition_screen.dart';
import 'profile_screen.dart';
import 'training_camp_screen.dart';

/// Root scaffold that owns the persistent bottom navigation.
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
    final activePage = switch (_index) {
      0 => DashboardScreen(onNavigate: _goToTab),
      1 => const TrainingCampScreen(),
      2 => const NutritionScreen(),
      _ => const ProfileScreen(asTab: true),
    };

    return Scaffold(
      body: activePage,
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _index,
        onTap: _goToTab,
      ),
    );
  }
}
