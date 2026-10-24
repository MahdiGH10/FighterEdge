import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import '../../features/fight_camp/presentation/fight_camp_controller.dart';
import '../../features/training_plan/presentation/plan_controller.dart';
import '../../notifications/notification_controller.dart';
import '../../notifications/notification_inputs_reader.dart';
import '../../state/locale_controller.dart';
import 'auto_pause_sheet.dart';

/// Keeps the notification schedule in line with the app while the signed-in
/// shell is on screen.
///
/// It asks the [NotificationController] to reconcile on every event that can
/// change what should be scheduled: the app starting or coming back to the
/// front (which also catches a time-zone change), the training plan or the log
/// changing (a session done, skipped or moved), a booked fight, the Fuel
/// setup, a language change, and the signed-in account or its trial changing.
/// The controller waits a moment so a burst of these becomes one run.
///
/// It also asks the one gentle question when a channel went quiet after
/// unopened notifications, and clears the schedule when the account signs out.
class NotificationHost extends StatefulWidget {
  const NotificationHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost>
    with WidgetsBindingObserver {
  late final NotificationController _controller;
  late final PlanController _plan;
  late final LocaleController _locale;
  late final AuthController _auth;
  late final FightCampController _fightCamp;
  late final EdgeFuelController _edgeFuel;
  late final NutritionModeController _nutritionMode;
  late final NotificationInputsReader _reader;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<NotificationController>();
    _plan = context.read<PlanController>();
    _locale = context.read<LocaleController>();
    _auth = context.read<AuthController>();
    _fightCamp = context.read<FightCampController>();
    _edgeFuel = context.read<EdgeFuelController>();
    _nutritionMode = context.read<NutritionModeController>();
    _reader = NotificationInputsReader(
      plan: _plan,
      fightCamp: _fightCamp,
      edgeFuel: _edgeFuel,
      auth: _auth,
      nutritionMode: _nutritionMode,
    );
    WidgetsBinding.instance.addObserver(this);
    _plan.addListener(_changed);
    _locale.addListener(_changed);
    _auth.addListener(_changed);
    _fightCamp.addListener(_changed);
    _edgeFuel.addListener(_changed);
    _nutritionMode.addListener(_changed);
    _controller.addListener(_maybeAsk);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.attach(
        readInputs: _reader.read,
        readLocale: _currentLocale,
        readSignedIn: () => _auth.user != null,
      );
      _maybeAsk();
    });
  }

  Locale _currentLocale() =>
      _locale.locale ?? ui.PlatformDispatcher.instance.locale;

  void _changed() => _controller.requestReconcile();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _controller.refreshPermission();
    _controller.requestReconcile();
    _maybeAsk();
  }

  /// A change of the system language matters when the app follows it.
  @override
  void didChangeLocales(List<Locale>? locales) => _changed();

  void _maybeAsk() {
    if (!mounted || _asking) return;
    final channel = _controller.channelToConfirm;
    if (channel == null) return;
    // Wait until the shell is the screen in front, so the question never lands
    // on top of something the athlete is in the middle of.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _asking = true;
    _controller.markAsked(channel);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _asking = false;
        return;
      }
      final keep = await showAutoPauseSheet(context, channel);
      _asking = false;
      if (keep == null) return;
      if (keep) {
        await _controller.keepChannel(channel);
      } else {
        await _controller.turnOffChannel(channel);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _plan.removeListener(_changed);
    _locale.removeListener(_changed);
    _auth.removeListener(_changed);
    _fightCamp.removeListener(_changed);
    _edgeFuel.removeListener(_changed);
    _nutritionMode.removeListener(_changed);
    _controller.removeListener(_maybeAsk);
    // The shell leaves the tree on sign-out: the next account must not
    // inherit this one's reminders.
    final signedOut = _auth.user == null;
    _controller.detach();
    if (signedOut) _controller.clearScheduled();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
