import 'notification_channel.dart';

/// One notification that was delivered. Ids and timestamps only: no content,
/// no arguments, nothing about the athlete.
class NotificationRecord {
  const NotificationRecord({
    required this.channel,
    required this.notificationId,
    required this.firedAt,
    this.ignored = false,
  });

  final NotificationChannel channel;

  /// The `PlannedNotification.id` it was scheduled with.
  final int notificationId;

  /// Local wall-clock time it was delivered.
  final DateTime firedAt;

  /// True when there was no tap and no app open within 24 hours of
  /// [firedAt]. The caller works this out and supplies it. Leave it false
  /// while the 24 hours are still running.
  final bool ignored;

  @override
  bool operator ==(Object other) =>
      other is NotificationRecord &&
      other.channel == channel &&
      other.notificationId == notificationId &&
      other.firedAt == firedAt &&
      other.ignored == ignored;

  @override
  int get hashCode => Object.hash(channel, notificationId, firedAt, ignored);
}

/// Recent delivered notifications, in any order.
class NotificationHistory {
  NotificationHistory([Iterable<NotificationRecord> records = const []])
      : records = List.unmodifiable(records);

  final List<NotificationRecord> records;

  /// This history with [record] added.
  NotificationHistory add(NotificationRecord record) =>
      NotificationHistory([...records, record]);

  /// This history without any record of [channel]. Use it when the user
  /// chooses to keep an auto-paused channel, which starts its count again.
  NotificationHistory withoutChannel(NotificationChannel channel) =>
      NotificationHistory(records.where((r) => r.channel != channel));
}

/// How many ignored notifications in a row pause a channel.
const int autoPauseAfterIgnored = 3;

/// Channels that went quiet because the last [autoPauseAfterIgnored]
/// notifications on them (newest first, counting only records fired at or
/// before [now]) were all ignored. An opened one ends the run. The
/// transactional trial notice is never auto-paused.
///
/// Nothing here un-pauses a channel on its own: the app asks the user once
/// and then calls [NotificationHistory.withoutChannel].
Set<NotificationChannel> autoPausedChannels(
  NotificationHistory history,
  DateTime now,
) {
  final paused = <NotificationChannel>{};
  for (final channel in NotificationChannel.values) {
    if (channel.isTransactional) continue;
    final newestFirst = history.records
        .where((r) => r.channel == channel && !r.firedAt.isAfter(now))
        .toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    var run = 0;
    for (final r in newestFirst) {
      if (!r.ignored) break;
      run++;
      if (run >= autoPauseAfterIgnored) {
        paused.add(channel);
        break;
      }
    }
  }
  return paused;
}
