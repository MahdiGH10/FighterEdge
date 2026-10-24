import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'domain/notification_channel.dart';
import 'domain/notification_history.dart';
import 'domain/planned_notification.dart';

/// A notification the app handed to the OS and expects to be delivered at
/// [fireAt]. Ids and times only.
class ScheduledEntry {
  const ScheduledEntry({
    required this.id,
    required this.channel,
    required this.fireAt,
  });

  final int id;
  final NotificationChannel channel;
  final DateTime fireAt;
}

/// A notification whose time has passed, with what the athlete did with it.
class DeliveredEntry {
  const DeliveredEntry({
    required this.id,
    required this.channel,
    required this.firedAt,
    this.opened = false,
    this.ignored = false,
  });

  final int id;
  final NotificationChannel channel;
  final DateTime firedAt;

  /// The athlete tapped it.
  final bool opened;

  /// Not tapped within 24 hours.
  final bool ignored;

  DeliveredEntry copyWith({bool? opened, bool? ignored}) => DeliveredEntry(
        id: id,
        channel: channel,
        firedAt: firedAt,
        opened: opened ?? this.opened,
        ignored: ignored ?? this.ignored,
      );
}

/// What the app knows about its own notifications: what is waiting to fire
/// and what already did. The OS does not tell a closed app when a local
/// notification is delivered, so a scheduled entry counts as delivered once
/// its time has passed.
///
/// Immutable, pure, and clock-free: callers pass `now`. Metrics (sent, opened,
/// ignored) stay in this object and on the device. Nothing here carries
/// content.
class NotificationLedger {
  const NotificationLedger({
    this.scheduled = const [],
    this.delivered = const [],
  });

  /// How long an unopened notification waits before it counts as ignored.
  static const Duration ignoredAfter = Duration(hours: 24);

  /// Old records stop mattering to auto-pause long before this.
  static const int maxDelivered = 100;
  static const Duration keepFor = Duration(days: 90);

  final List<ScheduledEntry> scheduled;
  final List<DeliveredEntry> delivered;

  /// Moves everything whose time has passed into [delivered] and marks
  /// unopened ones older than [ignoredAfter] as ignored.
  NotificationLedger settle(DateTime now) {
    final due = [
      for (final s in scheduled)
        if (!s.fireAt.isAfter(now)) s
    ];
    final waiting = [
      for (final s in scheduled)
        if (s.fireAt.isAfter(now)) s
    ];

    final all = <DeliveredEntry>[
      ...delivered,
      for (final s in due)
        DeliveredEntry(id: s.id, channel: s.channel, firedAt: s.fireAt),
    ]
        .map((d) {
          final stale = !d.opened &&
              !d.ignored &&
              now.difference(d.firedAt) > ignoredAfter;
          return stale ? d.copyWith(ignored: true) : d;
        })
        .where((d) => now.difference(d.firedAt) <= keepFor)
        .toList()
      ..sort((a, b) => a.firedAt.compareTo(b.firedAt));

    final trimmed = all.length > maxDelivered
        ? all.sublist(all.length - maxDelivered)
        : all;
    return NotificationLedger(scheduled: waiting, delivered: trimmed);
  }

  /// This ledger with [plan] as the whole set of waiting notifications.
  NotificationLedger withScheduled(List<PlannedNotification> plan) =>
      NotificationLedger(
        scheduled: [
          for (final p in plan)
            ScheduledEntry(id: p.id, channel: p.channel, fireAt: p.fireAt),
        ],
        delivered: delivered,
      );

  /// The athlete tapped notification [id]. A tap that arrives before the
  /// ledger noticed the notification fired counts as delivered and opened.
  NotificationLedger opened(int id, DateTime now) {
    final index = delivered.lastIndexWhere((d) => d.id == id);
    if (index >= 0) {
      return NotificationLedger(
        scheduled: scheduled,
        delivered: [
          for (final (i, d) in delivered.indexed)
            i == index ? d.copyWith(opened: true, ignored: false) : d,
        ],
      );
    }
    final pending = scheduled.where((s) => s.id == id).toList();
    if (pending.isEmpty) return this;
    final tapped = pending.first;
    return NotificationLedger(
      scheduled: [
        for (final s in scheduled)
          if (s.id != id) s
      ],
      delivered: [
        ...delivered,
        DeliveredEntry(
          id: tapped.id,
          channel: tapped.channel,
          firedAt: tapped.fireAt.isAfter(now) ? now : tapped.fireAt,
          opened: true,
        ),
      ],
    );
  }

  /// Forgets everything about [channel]. Used when the athlete answers the
  /// auto-pause question, which starts the channel's count again.
  NotificationLedger withoutChannel(NotificationChannel channel) =>
      NotificationLedger(
        scheduled: [
          for (final s in scheduled)
            if (s.channel != channel) s
        ],
        delivered: [
          for (final d in delivered)
            if (d.channel != channel) d
        ],
      );

  /// The history the planner reads.
  NotificationHistory toHistory() => NotificationHistory([
        for (final d in delivered)
          NotificationRecord(
            channel: d.channel,
            notificationId: d.id,
            firedAt: d.firedAt,
            ignored: d.ignored,
          ),
      ]);

  /// Delivered counts per channel, for on-device metrics.
  ({int sent, int opened, int ignored}) countsFor(NotificationChannel c) {
    final mine = delivered.where((d) => d.channel == c).toList();
    return (
      sent: mine.length,
      opened: mine.where((d) => d.opened).length,
      ignored: mine.where((d) => d.ignored).length,
    );
  }
}

/// Keeps the [NotificationLedger] on the device as versioned JSON in
/// `SharedPreferences`. A missing, bad or newer value reads as empty.
class NotificationHistoryStore {
  NotificationHistoryStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const key = 'notifications.history';
  static const int version = 1;

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<NotificationLedger> load() async {
    try {
      final raw = (await _prefs).getString(key);
      return raw == null ? const NotificationLedger() : decode(raw);
    } catch (_) {
      return const NotificationLedger();
    }
  }

  Future<void> save(NotificationLedger ledger) async {
    try {
      await (await _prefs).setString(key, encode(ledger));
    } catch (_) {
      // Counting is best effort; the next run starts from what was saved.
    }
  }

  static String encode(NotificationLedger ledger) => jsonEncode({
        'v': version,
        'scheduled': [
          for (final s in ledger.scheduled)
            {
              'id': s.id,
              'c': s.channel.name,
              't': s.fireAt.toIso8601String(),
            },
        ],
        'delivered': [
          for (final d in ledger.delivered)
            {
              'id': d.id,
              'c': d.channel.name,
              't': d.firedAt.toIso8601String(),
              'o': d.opened,
              'i': d.ignored,
            },
        ],
      });

  static NotificationLedger decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['v'] != version) {
        return const NotificationLedger();
      }
      final scheduled = <ScheduledEntry>[];
      for (final item in (json['scheduled'] as List? ?? const [])) {
        if (item is! Map) continue;
        final channel = _channel(item['c']);
        final at = DateTime.tryParse('${item['t']}');
        final id = item['id'];
        if (channel == null || at == null || id is! int) continue;
        scheduled.add(ScheduledEntry(id: id, channel: channel, fireAt: at));
      }
      final delivered = <DeliveredEntry>[];
      for (final item in (json['delivered'] as List? ?? const [])) {
        if (item is! Map) continue;
        final channel = _channel(item['c']);
        final at = DateTime.tryParse('${item['t']}');
        final id = item['id'];
        if (channel == null || at == null || id is! int) continue;
        delivered.add(DeliveredEntry(
          id: id,
          channel: channel,
          firedAt: at,
          opened: item['o'] == true,
          ignored: item['i'] == true,
        ));
      }
      return NotificationLedger(scheduled: scheduled, delivered: delivered);
    } catch (_) {
      return const NotificationLedger();
    }
  }

  static NotificationChannel? _channel(Object? name) {
    for (final c in NotificationChannel.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
