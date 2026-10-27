import 'domain/notification_channel.dart';

/// One local notification the gateway should hold, already localized.
///
/// [fireAt] is a local wall-clock moment: the gateway converts it with the
/// device time zone when it schedules, which is where daylight saving is
/// handled. [route] is the only payload and carries no data.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.channel,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.route,
  });

  final int id;
  final NotificationChannel channel;
  final DateTime fireAt;
  final String title;
  final String body;
  final String route;
}

/// A tap on a delivered notification. Carries the id it was scheduled with
/// and the route payload, nothing else.
class NotificationTap {
  const NotificationTap({required this.id, this.route});

  final int? id;
  final String? route;
}

/// Provider-neutral boundary for local reminders.
///
/// Mirrors the billing gateway: product code depends on this interface,
/// never on a notifications SDK directly, so tests and platforms without
/// local notification support (web, desktop) get a safe no-op instead of a
/// runtime failure.
abstract class ReminderGateway {
  /// Whether this platform can actually schedule local notifications. UI that
  /// offers reminders should hide or explain itself when this is false rather
  /// than let the user flip a switch that does nothing.
  bool get isAvailable;

  /// Asks the OS for notification permission. Returns whether it was granted.
  /// Safe to call repeatedly: already-granted or already-denied is not an
  /// error. [provisional] asks iOS for quiet delivery without a prompt; other
  /// platforms ignore it.
  Future<bool> requestPermission({bool provisional = false});

  /// Whether the OS currently lets the app post notifications. Never prompts.
  Future<bool> areNotificationsAllowed();

  /// Makes the plan-owned set of pending notifications exactly [reminders]:
  /// plan-owned ones that are no longer wanted are cancelled, the rest are
  /// scheduled (an existing id is replaced, never duplicated). Notifications
  /// that older versions of the app scheduled directly (weekly training
  /// reminders and the trial-end reminder) are cancelled too.
  Future<void> replaceScheduled(List<ScheduledReminder> reminders);

  /// Clears every plan-owned notification, and anything an older version of
  /// the app scheduled directly.
  Future<void> cancelAll();

  /// Shows a notification right now (a remote push that arrived while the app
  /// was in front). Returns whether it was shown. Not plan-owned: the
  /// scheduler never cancels it.
  Future<bool> showNow({
    required int id,
    required String title,
    required String body,
  }) async =>
      false;

  /// Taps on delivered notifications while the app is running.
  Stream<NotificationTap> get taps => const Stream.empty();

  /// The tap that launched the app from a closed state, once. Null when the
  /// app was started some other way.
  Future<NotificationTap?> takeLaunchTap() async => null;
}
