import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_colors.dart';
import 'reminder_gateway.dart';

/// On-device local notifications, via `flutter_local_notifications`.
///
/// One fixed notification id per weekday (`_idFor`), so re-scheduling a
/// training week just replaces each day's own notification instead of
/// growing without bound. Uses [AndroidScheduleMode.inexactAllowWhileIdle]
/// deliberately: a training reminder does not need to fire on the second, and
/// staying inexact means the app never needs the sensitive
/// `SCHEDULE_EXACT_ALARM` permission that exact alarms require on modern
/// Android and that draws extra Play Store scrutiny for no real benefit here.
class LocalReminderGateway implements ReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'training_reminders';
  static const _channelName = 'Training reminders';
  static const _channelDescription =
      'Nudges to train and log on the days you picked.';

  /// `DateTime.monday`(1)..`DateTime.sunday`(7) map directly onto a small,
  /// stable id range that nothing else in the app uses.
  static int _idFor(int weekday) => 6100 + weekday;

  @override
  bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final here = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(here.identifier));
    } catch (_) {
      // Falls back to whatever `tz.local` already defaults to. A reminder
      // that fires at the wrong local hour still beats one that never fires
      // because a timezone lookup failed.
    }
    // A flat white silhouette, not the full-color app icon: Android tints
    // status-bar icons itself, and a colored icon there just renders as a
    // solid white blob with the mark lost. See assets/icon/ for the source.
    const android = AndroidInitializationSettings('ic_notification');
    // Without Darwin settings the plugin never initializes on iOS and every
    // reminder silently fails (audit R-8). Permission is requested
    // explicitly from Settings, never as a side effect of initializing.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Null on API levels below 33, which never prompt for this at all —
        // notifications are on by default there, so treat null as granted.
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(alert: true, sound: true);
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required TimeOfDay time,
  }) async {
    if (!isAvailable) return;
    try {
      await _ensureInitialized();
      // Every id this gateway ever schedules lives in the same small range,
      // so clearing all of them first and re-adding the requested days keeps
      // this idempotent without tracking what was scheduled last time.
      await _plugin.cancelAll();
      for (final weekday in weekdays) {
        await _plugin.zonedSchedule(
          id: _idFor(weekday),
          title: 'Training day',
          body: "It's on the plan today. Log it when you're done.",
          scheduledDate: _nextInstanceOf(weekday, time),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.defaultImportance,
              icon: 'ic_notification',
              // The accent Android tints the silhouette and app-name text
              // with in the notification shade.
              color: AppColors.primary,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (_) {
      // Scheduling failure must not surface as an app error — Settings still
      // reflects what the user asked for even if delivery degrades.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!isAvailable) return;
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOf(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
