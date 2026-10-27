import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_colors.dart';
import 'domain/notification_channel.dart';
import 'reminder_gateway.dart';

/// On-device local notifications, via `flutter_local_notifications`.
///
/// The notifications the planner owns are scheduled one by one with
/// `zonedSchedule`, each under the planner's stable id, so scheduling the same
/// plan twice replaces instead of duplicating. A plan-owned notification is
/// recognised by its payload, which is always a route starting with `/`. The
/// older direct reminders (weekly training, trial end) have no payload and are
/// cancelled by [replaceScheduled], as the planner owns those notices now.
///
/// Uses [AndroidScheduleMode.inexactAllowWhileIdle] deliberately: a reminder
/// does not need to fire on the second, and staying inexact means the app
/// never needs the sensitive `SCHEDULE_EXACT_ALARM` permission that exact
/// alarms require on modern Android and that draws extra Play Store scrutiny
/// for no real benefit here.
class LocalReminderGateway implements ReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationTap>.broadcast();
  bool _initialized = false;

  /// iOS keeps at most 64 pending local notifications and drops the rest.
  /// The planner looks seven days ahead, so this is a backstop, not a limit
  /// anyone should reach.
  static const _maxPending = 60;

  /// The weekly training reminders older versions scheduled directly:
  /// `DateTime.monday`(1)..`DateTime.sunday`(7) added to this base. They are
  /// cancelled on every run so nobody gets both kinds.
  static const _legacyTrainingBase = 6100;

  /// The one-off trial-end notification an older version scheduled directly.
  /// The planner owns that notice now; this id is cancelled on every run so a
  /// device upgraded with one still pending never gets two.
  static const _legacyTrialReminderId = 6200;

  static const _trialChannelName = 'Subscription reminders';
  static const _trialChannelDescription =
      'A heads-up before your free trial ends.';

  static const _androidIcon = 'ic_notification';

  /// The channel remote pushes arrive on. Created at start-up so a push that
  /// lands while the app is closed already has it.
  static const pushChannelId = 'fe_push';
  static const _pushChannelName = 'Messages from Fighter Edge';

  @override
  bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _syncTimeZone();
    // A flat white silhouette, not the full-color app icon: Android tints
    // status-bar icons itself, and a colored icon there just renders as a
    // solid white blob with the mark lost. See assets/icon/ for the source.
    const android = AndroidInitializationSettings(_androidIcon);
    // Without Darwin settings the plugin never initializes on iOS and every
    // reminder silently fails (audit R-8). Permission is requested
    // explicitly, never as a side effect of initializing.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            pushChannelId,
            _pushChannelName,
            importance: Importance.defaultImportance,
          ),
        );
    _initialized = true;
  }

  /// Reads the device zone again. Called on every schedule, so a trip to
  /// another time zone is picked up the next time the app reconciles.
  Future<void> _syncTimeZone() async {
    try {
      final here = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(here.identifier));
    } catch (_) {
      // Falls back to whatever `tz.local` already is. A reminder that fires
      // at the wrong local hour still beats one that never fires because a
      // timezone lookup failed.
    }
  }

  void _onResponse(NotificationResponse response) {
    if (_taps.isClosed) return;
    _taps.add(NotificationTap(id: response.id, route: response.payload));
  }

  @override
  Future<NotificationTap?> takeLaunchTap() async {
    if (!isAvailable) return null;
    try {
      await _ensureInitialized();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final response = details.notificationResponse;
      if (response == null) return null;
      return NotificationTap(id: response.id, route: response.payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission({bool provisional = false}) async {
    if (!isAvailable) return false;
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Null on API levels below 33, which never prompt for this at all:
        // notifications are on by default there, so treat null as granted.
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        sound: true,
        provisional: provisional,
      );
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> areNotificationsAllowed() async {
    if (!isAvailable) return false;
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceScheduled(List<ScheduledReminder> reminders) async {
    if (!isAvailable) return;
    try {
      await _ensureInitialized();
      await _syncTimeZone();
      await _cancelLegacy();

      final wanted = ([...reminders]
            ..sort((a, b) => a.fireAt.compareTo(b.fireAt)))
          .take(_maxPending)
          .toList();
      final wantedIds = {for (final r in wanted) r.id};

      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (_isPlanOwned(p) && !wantedIds.contains(p.id)) {
          await _plugin.cancel(id: p.id);
        }
      }
      for (final r in wanted) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          payload: r.route,
          scheduledDate: _zoned(r.fireAt),
          notificationDetails: _details(r.channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Scheduling failure must not surface as an app error. The next
      // reconcile tries again.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!isAvailable) return;
    try {
      await _ensureInitialized();
      await _cancelLegacy();
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (_isPlanOwned(p)) await _plugin.cancel(id: p.id);
      }
    } catch (_) {}
  }

  @override
  Future<bool> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!isAvailable) return false;
    try {
      await _ensureInitialized();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        // No payload: a push is not a plan-owned reminder, so the scheduler
        // never cancels it.
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            pushChannelId,
            _pushChannelName,
            importance: Importance.defaultImportance,
            icon: _androidIcon,
            color: AppColors.primary,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Plan-owned notifications always carry a route payload.
  static bool _isPlanOwned(PendingNotificationRequest request) =>
      request.payload?.startsWith('/') ?? false;

  Future<void> _cancelLegacy() async {
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _plugin.cancel(id: _legacyTrainingBase + weekday);
    }
    await _plugin.cancel(id: _legacyTrialReminderId);
  }

  /// Wall-clock time in the device zone. A time that does not exist on a
  /// spring-forward day moves forward by the missing hour.
  static tz.TZDateTime _zoned(DateTime wall) => tz.TZDateTime(
        tz.local,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      );

  static NotificationDetails _details(NotificationChannel channel) {
    final info = _channelInfo(channel);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'fe_${channel.name}',
        info.name,
        channelDescription: info.description,
        importance: Importance.defaultImportance,
        icon: _androidIcon,
        // The accent Android tints the silhouette and app-name text with in
        // the notification shade.
        color: AppColors.primary,
      ),
      // One thread per channel groups them in the iOS notification centre.
      iOS: DarwinNotificationDetails(
        presentSound: true,
        threadIdentifier: channel.name,
      ),
    );
  }

  static ({String name, String description}) _channelInfo(
    NotificationChannel channel,
  ) =>
      switch (channel) {
        NotificationChannel.sessionReminder => (
            name: 'Session reminders',
            description: 'A reminder before your usual training time.',
          ),
        NotificationChannel.fuelWindow => (
            name: 'Fuel window',
            description: 'A heads-up before a hard session.',
          ),
        NotificationChannel.weeklyReview => (
            name: 'Weekly review',
            description: 'Your Sunday look back at the week.',
          ),
        NotificationChannel.fightCountdown => (
            name: 'Fight countdown',
            description: 'A note a week and a day before your fight.',
          ),
        NotificationChannel.weighIn => (
            name: 'Weight check-ins',
            description: 'A reminder to log your weight, if you track it.',
          ),
        NotificationChannel.proteinGap => (
            name: 'Evening nudge',
            description: 'One evening note on training days.',
          ),
        NotificationChannel.fighterTip => (
            name: 'Fighter tips',
            description: 'A short tip now and then.',
          ),
        NotificationChannel.trialEnding => (
            name: _trialChannelName,
            description: _trialChannelDescription,
          ),
      };
}
