import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../billing/trial_reminder.dart';
import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../notifications/reminder_gateway.dart';
import '../state/first_run_controller.dart';
import '../state/glass_policy_controller.dart';
import '../theme/app_haptics.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/coach_marks.dart';
import '../widgets/fade_through.dart';
import 'dashboard_screen.dart';
import 'first_run/first_win_sheet.dart';
import 'nutrition_screen.dart';
import 'profile_screen.dart';
import 'training_camp_screen.dart';
import '../privacy/consent.dart';
import '../privacy/consent_sheet.dart';

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

  static const _navCount = 4;

  List<NavItem> _navItems(BuildContext context) {
    final l = L.of(context);
    return [
      NavItem(AppIcons.house, l.navHome, activeIcon: AppIconsFill.house),
      NavItem(AppIcons.barbell, l.navTrain, activeIcon: AppIconsFill.barbell),
      NavItem(AppIcons.forkKnife, l.navFuel,
          activeIcon: AppIconsFill.forkKnife),
      NavItem(AppIcons.user, l.navProfile, activeIcon: AppIconsFill.user),
    ];
  }

  final _navKeys = List.generate(_navCount, (_) => GlobalKey());

  /// Tabs built so far: built on first visit, then kept.
  final _visited = <int>{};
  final _checklistKey = GlobalKey();

  late final EdgeFuelController _fuel;
  late final FirstRunController _firstRun;
  late final AuthController _auth;
  late final TrialReminderCoordinator _trialReminder;

  /// Keeps the "trial ends in 2 days" notification in line with the
  /// server-fed access state. Never decides access itself.
  void _syncTrialReminder() {
    if (!mounted) return;
    final l = L.of(context);
    _trialReminder.sync(
      _auth.accessState,
      title: l.trialReminderTitle,
      body: l.trialReminderBody,
    );
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>()..addListener(_syncTrialReminder);
    _trialReminder = TrialReminderCoordinator(
      gateway: context.read<ReminderGateway>(),
    );
    _fuel = context.read<EdgeFuelController>()..addListener(_checkFirstWin);
    _firstRun = context.read<FirstRunController>()..addListener(_checkFirstWin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTrialReminder();
      _askForConsentOnce();
      // The shell is the first screen that draws glass, so this is where the
      // device finds out whether it can afford the blur. Runs once per install.
      if (mounted) context.read<GlassPolicyController>().startProbe();
    });
  }

  /// First time in the app: ask about analytics and crash reports before
  /// anything is collected (audit M-2).
  void _askForConsentOnce() {
    if (!mounted) return;
    final consent = context.read<ConsentController>();
    if (consent.needsDecision) showConsentSheet(context, consent);
  }

  @override
  void dispose() {
    _fuel.removeListener(_checkFirstWin);
    _firstRun.removeListener(_checkFirstWin);
    _auth.removeListener(_syncTrialReminder);
    // The shell leaves the tree on sign-out: the next account must not
    // inherit this one's reminder.
    if (_auth.user == null) _trialReminder.cancel();
    super.dispose();
  }

  void _goToTab(int i) {
    // Leaving Fuel on a past/future day would leave Home's Corner Brief
    // showing that day too, since it reads the same controller.
    if (_index == _fuelTab && i != _fuelTab) _fuel.showToday();
    setState(() => _index = i);
  }

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
            'is what builds your week.',
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

  Widget _page(int index) => switch (index) {
        _homeTab => DashboardScreen(
            onNavigate: _goToTab,
            checklistKey: _checklistKey,
            onStartTour: _startTour,
          ),
        _trainTab => const TrainingCampScreen(),
        _fuelTab => const NutritionScreen(),
        _ => const ProfileScreen(asTab: true),
      };

  @override
  Widget build(BuildContext context) {
    _visited.add(_index);
    // One backdrop group for the whole shell: the nav, a collapsed header and a
    // sheet over a tab share one copy of what is behind them.
    return BackdropGroup(
      child: Scaffold(
        // The glass nav is drawn over the body, so lists scroll under it. Their
        // bottom padding clears it: ScreenScaffold.tabBottomPadding.
        extendBody: true,
        // Tabs are peers: nothing slides, because nothing moved. Every tab the
        // athlete has opened stays mounted, so its scroll position, sub-tab and
        // segment are still there on return; tabs never opened are not built,
        // and hidden tabs have their tickers paused.
        body: FadeThrough(
          switchKey: _index,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _navCount; i++)
                _visited.contains(i)
                    ? TickerMode(enabled: i == _index, child: _page(i))
                    : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          items: _navItems(context),
          currentIndex: _index,
          onTap: _goToTab,
          itemKeys: _navKeys,
        ),
      ),
    );
  }
}
