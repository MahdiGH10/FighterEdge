import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_route.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import '../features/weekly_review/domain/review_window.dart';
import '../features/weekly_review/presentation/weekly_review_screen.dart';
import '../state/first_run_controller.dart';
import '../state/glass_policy_controller.dart';
import '../theme/app_haptics.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/coach_marks.dart';
import '../widgets/fade_through.dart';
import 'dashboard_screen.dart';
import 'first_run/first_win_sheet.dart';
import 'notifications/notification_host.dart';
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
  late final NotificationController _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificationController>()
      ..addListener(_openTappedNotification);
    _fuel = context.read<EdgeFuelController>()..addListener(_checkFirstWin);
    _firstRun = context.read<FirstRunController>()..addListener(_checkFirstWin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openTappedNotification();
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
    _notifications.removeListener(_openTappedNotification);
    _fuel.removeListener(_checkFirstWin);
    _firstRun.removeListener(_checkFirstWin);
    super.dispose();
  }

  /// A tap on a notification opens the tab its route names. The route is the
  /// only thing the notification carries; anything on top of the shell
  /// (Settings, a sheet) is closed first so the tab is what the athlete sees.
  void _openTappedNotification() {
    if (!mounted || _notifications.pendingRoute == null) return;
    final route = _notifications.takePendingRoute();
    if (route == null) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    final destination = NotificationRoute.destination(route);
    _goToTab(switch (destination) {
      NotificationDestination.home ||
      NotificationDestination.review =>
        _homeTab,
      NotificationDestination.train => _trainTab,
      NotificationDestination.fuel => _fuelTab,
    });
    if (destination == NotificationDestination.review) _openReview();
  }

  /// The weekly review for the week that is ready, the same one the Home card
  /// offers. When there is none (the review window is Sunday and Monday, and
  /// a decision already made closes it) the athlete is simply on Home.
  void _openReview() {
    final plan = context.read<PlanController>();
    final week = plan.hasPlan ? ReviewWindow.weekFor(plan.today) : null;
    if (week == null || plan.reviewDecision(week) != null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WeeklyReviewScreen(weekStart: week),
    ));
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
    return NotificationHost(
        child: BackdropGroup(
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
    ));
  }
}
