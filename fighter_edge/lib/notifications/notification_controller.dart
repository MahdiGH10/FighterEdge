import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'domain/notification_channel.dart';
import 'domain/notification_settings.dart';
import 'notification_copy.dart';
import 'notification_history_store.dart';
import 'notification_route.dart';
import 'notification_scheduler.dart';
import 'notification_settings_store.dart';
import 'reminder_gateway.dart';

/// What the screens read and change about notifications, and the one place
/// that decides when to reconcile.
///
/// It holds the athlete's [NotificationSettings], whether the OS lets the app
/// post, the channel (if any) that went quiet and needs a question, and the
/// route a tapped notification asked for. Every change that could alter the
/// schedule ends in [requestReconcile], which waits a moment so a burst of
/// changes (a plan edit and a log entry) becomes one run.
///
/// Where reminders cannot fire ([ReminderGateway.isAvailable] false) it does
/// nothing and touches no storage.
class NotificationController extends ChangeNotifier {
  NotificationController({
    required ReminderGateway gateway,
    NotificationSettingsStore? settingsStore,
    NotificationHistoryStore? historyStore,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 400),
  })  : _gateway = gateway,
        _settingsStore = settingsStore ?? NotificationSettingsStore(),
        _scheduler = NotificationScheduler(
          gateway: gateway,
          historyStore: historyStore ?? NotificationHistoryStore(),
        ),
        _now = now ?? DateTime.now;

  /// The channels the Settings screen offers. Weigh-in, protein and tips get
  /// a row when their slice lands. The trial notice is a billing notice, not
  /// a choice, so it has no row (see [_planSettings]).
  static const List<NotificationChannel> userChannels = [
    NotificationChannel.sessionReminder,
    NotificationChannel.fuelWindow,
    NotificationChannel.weeklyReview,
    NotificationChannel.fightCountdown,
  ];

  final ReminderGateway _gateway;
  final NotificationSettingsStore _settingsStore;
  final NotificationScheduler _scheduler;
  final DateTime Function() _now;

  /// How long after a change the reconcile runs.
  final Duration debounce;

  NotificationSettings _settings = NotificationSettings();
  bool _loaded = false;
  bool _permissionRequested = false;
  bool? _systemAllowed;
  Set<NotificationChannel> _autoPaused = const {};
  final Set<NotificationChannel> _asked = {};
  String? _pendingRoute;

  NotificationInputs Function()? _readInputs;
  Locale Function()? _readLocale;
  bool Function()? _readSignedIn;

  Timer? _timer;
  StreamSubscription<NotificationTap>? _tapSub;
  bool _running = false;
  bool _dirty = false;
  bool _disposed = false;

  /// Runs the reconcile loop's work to completion; tests wait on it.
  Future<void> _idle = Future.value();

  bool get isAvailable => _gateway.isAvailable;
  bool get loaded => _loaded;
  NotificationSettings get settings => _settings;

  /// False until the OS has been asked, or when it said no.
  bool? get systemAllowed => _systemAllowed;

  /// True when the athlete was asked and the OS now refuses, so Settings can
  /// say where to turn notifications back on.
  bool get showPermissionNote =>
      isAvailable && _permissionRequested && _systemAllowed == false;

  /// The settings the planner sees. The trial-ending notice is a billing
  /// notice the athlete does not switch on: it is always allowed here, and the
  /// planner still skips it when there is no trial, when it was already sent,
  /// and when the OS does not let the app post. Pause all does not silence it.
  NotificationSettings get _planSettings =>
      _settings.withChannel(NotificationChannel.trialEnding, true);

  /// How many of the offered channels are on, for the Settings row.
  int get enabledCount =>
      userChannels.where((c) => _settings.isEnabled(c)).length;

  /// A channel that went quiet after unopened notifications and has not been
  /// asked about yet in this run. At most one is returned at a time.
  NotificationChannel? get channelToConfirm {
    for (final c in userChannels) {
      if (_autoPaused.contains(c) &&
          _settings.isEnabled(c) &&
          !_asked.contains(c)) {
        return c;
      }
    }
    return null;
  }

  /// The route of a tapped notification, until [takePendingRoute] collects it.
  String? get pendingRoute => _pendingRoute;

  /// Loads the saved settings (running the one-time migration from the old
  /// camp-reminders switch) and starts listening for taps.
  Future<void> load() async {
    if (!isAvailable) {
      _loaded = true;
      return;
    }
    _settings = await _settingsStore.load();
    _permissionRequested = await _settingsStore.loadPermissionRequested();
    _systemAllowed = await _gateway.areNotificationsAllowed();
    _tapSub ??= _gateway.taps.listen(_onTap);
    if (_disposed) return;
    _loaded = true;
    notifyListeners();
    requestReconcile();
  }

  /// Connects the controller to the rest of the app. [readInputs] is called
  /// at every reconcile, so it always sees the current plan.
  Future<void> attach({
    required NotificationInputs Function() readInputs,
    required Locale Function() readLocale,
    required bool Function() readSignedIn,
  }) async {
    _readInputs = readInputs;
    _readLocale = readLocale;
    _readSignedIn = readSignedIn;
    if (!isAvailable) return;
    final launch = await _gateway.takeLaunchTap();
    if (launch != null) await _onTap(launch);
    requestReconcile();
  }

  void detach() {
    _readInputs = null;
    _readLocale = null;
    _readSignedIn = null;
    _timer?.cancel();
  }

  /// Takes every plan-owned notification off the OS and forgets what was
  /// waiting. For sign-out: the next account must not inherit these. The
  /// settings stay; they belong to the device.
  Future<void> clearScheduled() async {
    if (!isAvailable) return;
    try {
      await _scheduler.reconcile(
        now: _now(),
        settings: _settings,
        inputs: const NotificationInputs(),
        copy: NotificationCopy.forLocale(const Locale('en')),
        signedIn: false,
        systemAllowed: false,
      );
    } catch (_) {}
  }

  /// Schedules a reconcile soon. Safe to call as often as needed.
  void requestReconcile() {
    if (_disposed || !isAvailable || !_loaded || _readInputs == null) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(reconcileNow()));
  }

  /// Reconciles immediately. Concurrent calls collapse: a call made while one
  /// is running makes it run once more when it finishes.
  Future<void> reconcileNow() {
    _timer?.cancel();
    if (_disposed || !isAvailable || !_loaded || _readInputs == null) {
      return Future.value();
    }
    if (_running) {
      _dirty = true;
      return _idle;
    }
    return _idle = _runLoop();
  }

  Future<void> _runLoop() async {
    _running = true;
    try {
      do {
        _dirty = false;
        await _reconcileOnce();
      } while (_dirty && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcileOnce() async {
    final readInputs = _readInputs;
    final readLocale = _readLocale;
    final readSignedIn = _readSignedIn;
    if (readInputs == null || readLocale == null || readSignedIn == null) {
      return;
    }
    try {
      final allowed = await _gateway.areNotificationsAllowed();
      final result = await _scheduler.reconcile(
        now: _now(),
        settings: _planSettings,
        inputs: readInputs(),
        copy: NotificationCopy.forLocale(readLocale()),
        signedIn: readSignedIn(),
        systemAllowed: allowed,
      );
      if (_disposed) return;
      var changed = false;
      if (_systemAllowed != allowed) {
        _systemAllowed = allowed;
        changed = true;
      }
      if (!setEquals(_autoPaused, result.autoPaused)) {
        _autoPaused = result.autoPaused;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {
      // A failed reconcile must never reach the screen. The next trigger
      // tries again.
    }
  }

  /// Checks the OS permission again, for when the app returns from the
  /// system settings.
  Future<void> refreshPermission() async {
    if (!isAvailable) return;
    final allowed = await _gateway.areNotificationsAllowed();
    if (_disposed || allowed == _systemAllowed) return;
    _systemAllowed = allowed;
    notifyListeners();
    requestReconcile();
  }

  // ---- Changing settings ----

  /// Switches a channel on or off. Turning one on asks the OS for permission
  /// first when needed; if it says no, the channel stays off and this returns
  /// false (Settings then shows the system-settings note).
  Future<bool> setChannelEnabled(
    NotificationChannel channel,
    bool enabled,
  ) async {
    if (!enabled) {
      _update(_settings.withChannel(channel, false));
      return true;
    }
    if (!await _ensurePermission(channel)) return false;
    _update(_settings.withChannel(channel, true));
    return true;
  }

  /// The athlete said yes to the primer: ask the OS, and turn the session
  /// reminder on if it agrees.
  Future<bool> enableSessionReminders() =>
      setChannelEnabled(NotificationChannel.sessionReminder, true);

  Future<bool> _ensurePermission(NotificationChannel channel) async {
    if (!isAvailable) return false;
    // iOS can deliver the weekly review quietly with no prompt at all; every
    // other channel needs the full permission.
    final provisional =
        channel == NotificationChannel.weeklyReview && _systemAllowed != true;
    final granted = await _gateway.requestPermission(provisional: provisional);
    if (_disposed) return granted;
    _permissionRequested = true;
    _systemAllowed = granted;
    unawaited(_settingsStore.savePermissionRequested(true));
    notifyListeners();
    return granted;
  }

  void setUsualTime(int hour, int minute) => _update(
        _settings.copyWith(
            usualTrainingHour: hour, usualTrainingMinute: minute),
      );

  void setSessionLead(int minutes) =>
      _update(_settings.copyWith(sessionLeadMinutes: minutes));

  void setQuietHours(QuietHours quietHours) =>
      _update(_settings.copyWith(quietHours: quietHours));

  void setPauseAll(bool value) => _update(_settings.copyWith(pauseAll: value));

  void _update(NotificationSettings next) {
    if (next == _settings) return;
    _settings = next;
    unawaited(_settingsStore.save(next));
    notifyListeners();
    requestReconcile();
  }

  // ---- The auto-pause question ----

  /// Marks [channel] as asked about for this run, so the question is not
  /// repeated until the app opens again.
  void markAsked(NotificationChannel channel) {
    _asked.add(channel);
  }

  /// The athlete wants the channel back: its count starts again.
  Future<void> keepChannel(NotificationChannel channel) async {
    _asked.add(channel);
    await _scheduler.clearChannel(channel, _now());
    _autoPaused = {..._autoPaused}..remove(channel);
    notifyListeners();
    requestReconcile();
  }

  /// The athlete does not want the channel: it goes off and its count resets,
  /// so turning it on later starts clean.
  Future<void> turnOffChannel(NotificationChannel channel) async {
    _asked.add(channel);
    await _scheduler.clearChannel(channel, _now());
    _autoPaused = {..._autoPaused}..remove(channel);
    _update(_settings.withChannel(channel, false));
    notifyListeners();
  }

  // ---- Taps ----

  Future<void> _onTap(NotificationTap tap) async {
    final id = tap.id;
    if (id != null) {
      try {
        await _scheduler.recordOpened(id, _now());
      } catch (_) {}
    }
    final route = NotificationRoute.parse(tap.route);
    if (_disposed || route == null) return;
    _pendingRoute = route;
    notifyListeners();
  }

  /// Hands the tapped route to whoever opens it, once.
  String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_tapSub?.cancel());
    super.dispose();
  }
}
