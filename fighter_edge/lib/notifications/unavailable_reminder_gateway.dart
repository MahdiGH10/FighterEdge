import 'reminder_gateway.dart';

/// Safe fallback for tests, web, and desktop: never touches a notifications
/// SDK, never schedules anything, never throws.
class UnavailableReminderGateway implements ReminderGateway {
  const UnavailableReminderGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission({bool provisional = false}) async => false;

  @override
  Future<bool> areNotificationsAllowed() async => false;

  @override
  Future<void> replaceScheduled(List<ScheduledReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Stream<NotificationTap> get taps => const Stream.empty();

  @override
  Future<NotificationTap?> takeLaunchTap() async => null;
}
