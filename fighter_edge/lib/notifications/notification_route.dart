/// Where a tap on a notification lands. The payload of a notification is a
/// route string and nothing else, and it is checked here before it is used:
/// only the fixed paths the planner emits are accepted.
enum NotificationDestination {
  /// The Home tab.
  home,

  /// The Train tab, with the week and today's session.
  train,

  /// The Fuel tab.
  fuel,

  /// The weekly review screen, for the week that is ready to review.
  review,
}

class NotificationRoute {
  NotificationRoute._();

  static final RegExp _allowed = RegExp(
    r'^(/home|/fuel|/review|/train/session/[A-Za-z0-9._-]+)$',
  );

  /// [raw] when it is a route the app accepts, otherwise null.
  static String? parse(String? raw) =>
      raw != null && _allowed.hasMatch(raw) ? raw : null;

  /// Where a route leads. A session has no screen of its own: its reminder
  /// opens the Train tab, where the week lists it and today's session can be
  /// started.
  static NotificationDestination destination(String route) {
    if (route == '/fuel') return NotificationDestination.fuel;
    if (route == '/home') return NotificationDestination.home;
    if (route == '/review') return NotificationDestination.review;
    return NotificationDestination.train;
  }
}
