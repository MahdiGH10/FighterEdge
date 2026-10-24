import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/copy_lint.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_planner.dart';
import 'package:fighter_edge/notifications/notification_copy.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_test_helpers.dart';

/// A number followed by a unit that would be a measurement.
final _measurement = RegExp(
  r'\d\s*(kg|kgs|lb|lbs|kcal|cal|calories|g|grams)\b',
  caseSensitive: false,
);

/// Sample arguments covering every placeholder the copy reads.
const _args = {
  'sessionAt': '18:00',
  'fuelWindowAt': '15:30',
  'discipline': 'boxing',
  'weekday': 'monday',
  'daysToFight': '7',
  'daysLeft': '2',
};

void main() {
  for (final language in ['en', 'de']) {
    group('copy in $language', () {
      final copy = NotificationCopy.forLocale(Locale(language));

      test('every key renders a title and a body', () {
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args);
          expect(text, isNotNull, reason: key);
          expect(text!.title.trim(), isNotEmpty, reason: key);
          expect(text.body.trim(), isNotEmpty, reason: key);
        }
      });

      test('no placeholder is left unfilled', () {
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args)!;
          for (final s in [text.title, text.body]) {
            expect(s, isNot(contains('{')), reason: key);
            expect(s, isNot(contains('}')), reason: key);
            expect(s, isNot(contains('null')), reason: key);
          }
        }
      });

      test('every key passes the copy lint and the banned-advice validator',
          () {
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args)!;
          for (final s in [text.title, text.body]) {
            final report = CopyLint.lint(s);
            expect(report.isClean, isTrue, reason: '$key: "$s" -> $report');
          }
        }
      });

      test('no digit is followed by kg, lb, kcal or another unit', () {
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args)!;
          for (final s in [text.title, text.body]) {
            expect(_measurement.hasMatch(s), isFalse, reason: '$key: "$s"');
          }
        }
      });

      test('no copy talks about weight cuts, fluids or fasting', () {
        final banned = RegExp(
          r'(sauna|diuretic|laxative|fasting|dehydrat|sweat suit|water load|'
          r'\bcut\b|sodium|natrium|abkoch|fasten|entwässer)',
          caseSensitive: false,
        );
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args)!;
          for (final s in [text.title, text.body]) {
            expect(banned.hasMatch(s), isFalse, reason: '$key: "$s"');
          }
        }
      });

      test('no guilt, streak or missed-session wording', () {
        final tone = RegExp(
          r'(missed|streak|behind|guilt|verpasst|serie|rückstand|schuld)',
          caseSensitive: false,
        );
        for (final key in NotificationCopy.contentKeys) {
          final text = copy.resolve(key, _args)!;
          for (final s in [text.title, text.body]) {
            expect(tone.hasMatch(s), isFalse, reason: '$key: "$s"');
          }
        }
      });
    });
  }

  test('the lint pattern does catch what it is meant to catch', () {
    for (final bad in ['70 kg', '70kg', '150 lb', '2000 kcal']) {
      expect(_measurement.hasMatch(bad), isTrue, reason: bad);
    }
    expect(_measurement.hasMatch('Training at 6:00 PM'), isFalse);
    expect(_measurement.hasMatch('Training um 18:00'), isFalse);
  });

  test('times read the way the language expects', () {
    final en = NotificationCopy.forLocale(const Locale('en'));
    final de = NotificationCopy.forLocale(const Locale('de'));
    expect(en.resolve('notif.session.soon', {'sessionAt': '18:00'})!.body,
        contains('6:00 PM'));
    expect(en.resolve('notif.session.soon', {'sessionAt': '06:45'})!.body,
        contains('6:45 AM'));
    expect(en.resolve('notif.session.soon', {'sessionAt': '12:05'})!.body,
        contains('12:05 PM'));
    expect(en.resolve('notif.session.soon', {'sessionAt': '00:30'})!.body,
        contains('12:30 AM'));
    expect(de.resolve('notif.session.soon', {'sessionAt': '06:45'})!.body,
        contains('06:45'));
  });

  test('German is really German and English really English', () {
    final en = NotificationCopy.forLocale(const Locale('en'));
    final de = NotificationCopy.forLocale(const Locale('de'));
    for (final key in NotificationCopy.contentKeys) {
      if (key == 'notif.trial.ending') continue;
      expect(
        de.resolve(key, _args)!.body,
        isNot(en.resolve(key, _args)!.body),
        reason: key,
      );
    }
  });

  test('any other language falls back to English', () {
    final fr = NotificationCopy.forLocale(const Locale('fr'));
    final en = NotificationCopy.forLocale(const Locale('en'));
    expect(fr.resolve('notif.review.weekly', {})!.title,
        en.resolve('notif.review.weekly', {})!.title);
  });

  test('an unknown key has no words, so it is never shown raw', () {
    final copy = NotificationCopy.forLocale(const Locale('en'));
    expect(copy.resolve('notif.nope', {}), isNull);
    expect(
      copy.resolve('notif.tip.${NotificationPlanner.tipCount}', {}),
      isNull,
    );
  });

  test('the planner only ever emits keys the copy can word', () {
    final emitted = <String>{};
    for (final type in FuelDayType.values) {
      emitted.addAll([
        for (final n in run(
          settings: allOn,
          horizonDays: 30,
          sessions: [for (var i = 0; i < 30; i++) session(i)],
          fuel: {for (var i = 0; i < 30; i++) day(i): type},
          fightDate: day(9),
          trialEndsAt: day(8, 12),
          weighInWeekdays: {DateTime.wednesday},
        ))
          n.contentKey,
      ]);
    }
    for (final channel in NotificationChannel.values) {
      emitted.addAll([
        for (final n in run(
          settings: on([channel]),
          horizonDays: 30,
          sessions: [for (var i = 0; i < 30; i++) session(i)],
          fuel: {for (var i = 0; i < 30; i++) day(i): FuelDayType.hard},
          fightDate: day(9),
          trialEndsAt: day(8, 12),
          weighInWeekdays: {1, 2, 3, 4, 5, 6, 7},
        ))
          n.contentKey,
      ]);
    }
    expect(emitted, isNotEmpty);
    expect(NotificationCopy.contentKeys, containsAll(emitted));
  });

  test('there is copy for every tip the planner can pick', () {
    for (var i = 0; i < NotificationPlanner.tipCount; i++) {
      expect(NotificationCopy.contentKeys, contains('notif.tip.$i'));
    }
  });
}
