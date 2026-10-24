import 'notification_channel.dart';

/// One notification the gateway should schedule. Pure data.
///
/// Time zone and daylight saving are the gateway's job: [fireAt] is a local
/// wall-clock moment, and the gateway converts it with the device zone at
/// scheduling time. Nothing sensitive goes in here: [args] holds only plain
/// labels such as a discipline key or a weekday, and [route] is a deep-link
/// path, never data. Real copy comes from the ARB files via [contentKey].
class PlannedNotification {
  PlannedNotification({
    required this.id,
    required this.channel,
    required this.fireAt,
    required this.contentKey,
    Map<String, String> args = const {},
    required this.route,
  }) : args = Map.unmodifiable(args);

  /// Stable across re-planning, see [stableId].
  final int id;
  final NotificationChannel channel;
  final DateTime fireAt;

  /// A key like `notif.session.soon`.
  final String contentKey;
  final Map<String, String> args;

  /// A deep-link route such as `/train/session/<id>`, `/fuel`, `/review`,
  /// `/home`.
  final String route;

  /// A positive 31-bit int derived only from the channel, the local date and
  /// an optional [discriminator] (the session id), so planning the same day
  /// twice yields the same id and never schedules a duplicate. FNV-1a.
  static int stableId(
    NotificationChannel channel,
    DateTime localDate, [
    String discriminator = '',
  ]) {
    final text = '${channel.name}|${localDate.year}-${localDate.month}-'
        '${localDate.day}|$discriminator';
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.channel == channel &&
      other.fireAt == fireAt &&
      other.contentKey == contentKey &&
      other.route == route &&
      other.args.length == args.length &&
      other.args.entries.every(
        (e) => args.containsKey(e.key) && args[e.key] == e.value,
      );

  @override
  int get hashCode => Object.hash(
        id,
        channel,
        fireAt,
        contentKey,
        route,
        Object.hashAllUnordered(
          args.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'PlannedNotification(${channel.name}, $fireAt, $contentKey, $route)';
}
