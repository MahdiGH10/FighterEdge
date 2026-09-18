import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../state/first_run_controller.dart';
import '../theme/app_haptics.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/coach_marks.dart';
import '../widgets/fade_through.dart';
import 'dashboard_screen.dart';
import 'first_run/first_win_sheet.dart';
import 'nutrition_screen.dart';
import 'profile_screen.dart';
import 'training_camp_screen.dart';

/// Root scaffold that owns the persistent bottom navigation.
///
/// Also hosts the first-week layer, because it is the one widget that outlives
/// tab switches: the tour needs the nav bar, and the first meal is logged in
/// Fuel but celebrated wherever the user is.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _homeTab = 0;
  static const _trainTab = 1;
  static const _fuelTab = 2;
  static const _profileTab = 3;

  static const _navItems = [
    NavItem(Icons.home_filled, 'Home'),
    NavItem(Icons.fitness_center, 'Train'),
    NavItem(Icons.restaurant, 'Fuel'),
    NavItem(Icons.person, 'Profile'),
  ];

  final _navKeys = List.generate(_navItems.length, (_) => GlobalKey());
  final _checklistKey = GlobalKey();

  late final EdgeFuelController _fuel;
  late final FirstRunController _firstRun;

  @override
  void initState() {
    super.initState();
    _fuel = context.read<EdgeFuelController>()..addListener(_checkFirstWin);
    _firstRun = context.read<FirstRunController>()..addListener(_checkFirstWin);
  }

  @override
  void dispose() {
    _fuel.removeListener(_checkFirstWin);
    _firstRun.removeListener(_checkFirstWin);
    super.dispose();
  }

  void _goToTab(int i) => setState(() => _index = i);

  /// Fires the first-win moment the first time a meal shows up in today's log,
  /// however it got there (quick add, food search, a recipe).
  void _checkFirstWin() {
    if (!_firstRun.isActive || _firstRun.firstMealLogged) return;
    if (!_fuel.isToday || _fuel.entries.isEmpty) return;
    if (!_firstRun.markFirstMealLogged()) return;
    AppHaptics.success();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFirstWinSheet(context);
    });
  }

  Future<void> _startTour() async {
    if (_index != _homeTab) _goToTab(_homeTab);
    await showCoachMarks(context, [
      CoachMarkStep(
        target: _checklistKey,
        title: 'Your first week',
        body: 'Four small wins to get your camp moving. Logging a meal '
            'lands the first one.',
      ),
      CoachMarkStep(
        target: _navKeys[_trainTab],
        title: 'Train',
        body: 'Your week of sessions. Tick one off when it’s done — that '
            'is what builds your streak.',
      ),
      CoachMarkStep(
        target: _navKeys[_fuelTab],
        title: 'Fuel',
        body: 'Log meals against your EdgeFuel target. Quick add is one tap.',
      ),
      CoachMarkStep(
        target: _navKeys[_profileTab],
        title: 'Profile',
        body: 'Your weight trend, history and settings live here.',
      ),
    ]);
    // Finished or skipped, it has been seen. It does not come back.
    await _firstRun.markTourDone();
  }

  @override
  Widget build(BuildContext context) {
    final activePage = switch (_index) {
      _homeTab => DashboardScreen(
          onNavigate: _goToTab,
          checklistKey: _checklistKey,
          onStartTour: _startTour,
        ),
      _trainTab => const TrainingCampScreen(),
      _fuelTab => const NutritionScreen(),
      _ => const ProfileScreen(asTab: true),
    };

    return Scaffold(
      // Tabs are peers: nothing slides, because nothing moved.
      body: FadeThrough(switchKey: _index, child: activePage),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _index,
        onTap: _goToTab,
        itemKeys: _navKeys,
      ),
    );
  }
}
