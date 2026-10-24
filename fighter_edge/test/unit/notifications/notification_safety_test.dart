import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_history.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/domain/planned_notification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_test_helpers.dart';

/// Numbers with a unit that would be a measurement.
final _measurement = RegExp(
  r'\d\s*(kg|kgs|lb|lbs|kcal|cal|calories|g|grams)\b',
  caseSensitive: false,
);

/// Words the notification content must never contain.
final _banned = RegExp(
  r'(\bmissed\b|\bstreak|\bbehind\b|\bcheat|\bearn\b|\bearned\b|sauna|'
  r'diuretic|laxative|\bfasting\b|dehydrat|sweat suit|water load|\bcut\b|'
  r'\bweigh-in\b|\bgood food\b|\bbad food\b|\bsodium\b)',
  caseSensitive: false,
);

/// Every combination worth sweeping for content.
List<PlannedNotification> _sweep() {
  final out = <PlannedNotification>[];
  final disciplines = [null, ...Discipline.values];
  for (final discipline in disciplines) {
    for (final settings in [
      allOn,
      on(NotificationChannel.values, usualHour: 6, usualMinute: 45),
      on(NotificationChannel.values, quiet: const QuietHours.hm(0, 0, 0, 0)),
    ]) {
      for (final type in FuelDayType.values) {
        for (final age in [null, 15, 18, 40]) {
          out.addAll(run(
            settings: settings,
            age: age,
            horizonDays: 21,
            sessions: [
              for (var i = 0; i < 21; i++)
                session(
                  i,
                  discipline: discipline,
                  status: i % 5 == 4
                      ? SessionStatus.completed
                      : SessionStatus.planned,
                ),
            ],
            fuel: {for (var i = 0; i < 21; i++) day(i): type},
            fightDate: day(9),
            trialEndsAt: day(8, 12),
            weighInWeekdays: {DateTime.wednesday, DateTime.saturday},
          ));
        }
      }
    }
  }
  // Also each channel alone, so lower-priority content is not hidden by the
  // daily cap.
  for (final channel in NotificationChannel.values) {
    out.addAll(run(
      settings: on([channel]),
      horizonDays: 21,
      sessions: [for (var i = 0; i < 21; i++) session(i)],
      fuel: {for (var i = 0; i < 21; i++) day(i): FuelDayType.hard},
      fightDate: day(9),
      trialEndsAt: day(8, 12),
      weighInWeekdays: {1, 2, 3, 4, 5, 6, 7},
    ));
  }
  return out;
}

void main() {
  late List<PlannedNotification> everything;
  setUpAll(() => everything = _sweep());

  test('the sweep reaches every channel', () {
    expect(
      {for (final n in everything) n.channel},
      NotificationChannel.values.toSet(),
    );
  });

  test('content keys, args and routes carry no measurement or banned word', () {
    final problems = <String>[];
    for (final n in everything) {
      final texts = [
        n.contentKey,
        n.route,
        for (final e in n.args.entries) ...[e.key, e.value],
      ];
      for (final t in texts) {
        if (_measurement.hasMatch(t) || _banned.hasMatch(t)) {
          problems.add('${n.channel.name}: $t');
        }
      }
    }
    expect(problems.toSet(), isEmpty);
  });

  test('the scanners do catch what they are meant to catch', () {
    for (final bad in [
      '70 kg',
      '70kg',
      '150 lb',
      '2000 kcal',
      '300 cal',
    ]) {
      expect(_measurement.hasMatch(bad), isTrue, reason: bad);
    }
    for (final bad in [
      'You missed it',
      'streak',
      'behind plan',
      'cheat day',
      'earn it',
      'sauna',
      'diuretic',
      'laxative',
      'fasting',
      'dehydration',
    ]) {
      expect(_banned.hasMatch(bad), isTrue, reason: bad);
    }
    // Harmless text is allowed: times and "learn".
    expect(_measurement.hasMatch('18:00'), isFalse);
    expect(_banned.hasMatch('notif.tip.learn'), isFalse);
  });

  test('args only ever use the small set of plain keys', () {
    const allowed = {
      'discipline',
      'weekday',
      'sessionAt',
      'fuelWindowAt',
      'daysToFight',
      'daysLeft',
    };
    final keys = {for (final n in everything) ...n.args.keys};
    expect(keys.difference(allowed), isEmpty);
  });

  test('arg values are plain labels, times or day counts', () {
    final shape = RegExp(r'^([A-Za-z]+|\d{2}:\d{2}|\d{1,2})$');
    for (final n in everything) {
      for (final e in n.args.entries) {
        expect(shape.hasMatch(e.value), isTrue, reason: '${e.key}=${e.value}');
      }
    }
  });

  test('routes are fixed paths or a session id path', () {
    final route = RegExp(r'^(/home|/fuel|/review|/train/session/s-\d+)$');
    for (final n in everything) {
      expect(route.hasMatch(n.route), isTrue, reason: n.route);
    }
  });

  test('content keys sit in the notif namespace', () {
    for (final n in everything) {
      expect(n.contentKey, startsWith('notif.'));
    }
  });

  test('no fuel, weigh-in or protein for under-18 or unknown age in the sweep',
      () {
    for (final age in [null, 15, 17]) {
      final plan = run(
        age: age,
        settings: allOn,
        horizonDays: 21,
        sessions: [for (var i = 0; i < 21; i++) session(i)],
        fuel: {for (var i = 0; i < 21; i++) day(i): FuelDayType.hard},
        weighInWeekdays: {1, 2, 3, 4, 5, 6, 7},
      );
      for (final n in plan) {
        expect(n.channel.isNutrition, isFalse, reason: '$age ${n.channel}');
        expect(n.args.containsKey('fuelWindowAt'), isFalse);
      }
    }
  });

  test('a history of only ids and times is all the planner learns', () {
    // The history type has no field for content or arguments.
    final record = NotificationRecord(
      channel: NotificationChannel.fighterTip,
      notificationId: 1,
      firedAt: day(0),
    );
    expect(record.toString(), isNot(contains('kg')));
  });

  group('domain purity', () {
    final files = Directory('lib/notifications/domain')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('the folder is there', () {
      expect(files.length, greaterThanOrEqualTo(5));
    });

    test('no Flutter, Firebase, network or platform import and no clock', () {
      final forbidden = <RegExp>[
        RegExp(r'''import\s+['"]package:flutter'''),
        RegExp(
          r'''import\s+['"]package:(firebase|cloud_firestore|cloud_functions)''',
        ),
        RegExp(
            r'''import\s+['"]package:(http|dio|clock|shared_preferences)[/']'''),
        RegExp(r'''import\s+['"]dart:(io|ui|html|isolate)['"]'''),
        RegExp(r'DateTime\.now\('),
      ];
      final violations = <String>[];
      for (final file in files) {
        for (final line in file.readAsLinesSync()) {
          if (line.trimLeft().startsWith('//')) continue;
          if (forbidden.any((p) => p.hasMatch(line))) {
            violations.add('${file.path}: ${line.trim()}');
          }
        }
      }
      expect(violations, isEmpty);
    });
  });
}
