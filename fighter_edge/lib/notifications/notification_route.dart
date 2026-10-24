/// Where a tap on a notification lands. The payload of a notification is a
/// route string and nothing else, and it is checked here before it is used:
/// only the fixed paths the planner emits are accepted.
enum NotificationDestination { home, train, fuel }

class NotificationRoute {
  NotificationRoute._();

  static final RegExp _allowed =
      RegExp(r'^(/home|/fuel|/review|/train/session/[A-Za-z0-9._-]+)$');

  /// [raw] when it is a route the app accepts, otherwise null.
  static String? parse(String? raw) =>
      raw != null && _allowed.hasMatch(raw) ? raw : null;

  /// The tab a route opens. Until the screens behind them are linked
  /// directly, the review and a session open the Train tab.
  static NotificationDestination destination(String route) {
    if (route == '/fuel') return NotificationDestination.fuel;
    if (route == '/home') return NotificationDestination.home;
    return NotificationDestination.train;
  }
}
