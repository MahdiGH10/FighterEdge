import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/notifications/notification_copy.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_scheduler.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';
import 'notification_test_helpers.dart';

/// The inputs PR 3 connects: fuel day types, the fight date and the trial end.
/// Every case is a fixed moment (Monday 1 June 2026, 09:00).
void main() {
  late FakeReminderGateway gateway;
  late NotificationScheduler scheduler;
  final en = NotificationCopy.forLocale(const Locale('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeReminderGateway(allowed: true);
    scheduler = NotificationScheduler(
      gateway: gateway,
      historyStore: NotificationHistoryStore(),
    );
  });

  Future<ReconcileResult> reconcile({
    DateTime? at,
    required NotificationInputs inputs,
    required Iterable<NotificationChannel> channels,
    bool pauseAll = false,
    bool pauseNutrition = false,
  }) =>
      scheduler.reconcile(
        now: at ?? now,
        settings: on(
          channels,
          pauseAll: pauseAll,
          pauseNutrition: pauseNutrition,
        ),
        inputs: inputs,
        copy: en,
        signedIn: true,
        systemAllowed: true,
      );

  group('fuel window', () {
    NotificationInputs hardDays({int? age = 30, FuelDayType? type}) =>
        NotificationInputs(
          sessions: [
            for (var i = 0; i < 4; i++) session(i),
          ],
          fuelDayTypes: {
            for (var i = 0; i < 4; i++) day(i): type ?? FuelDayType.hard,
          },
          ageYears: age,
        );

    test('a hard day with the fuel window on gets its note', () async {
      await reconcile(
        inputs: hardDays(),
        channels: [NotificationChannel.fuelWindow],
      );
      expect(gateway.pending, isNotEmpty);
      final r = gateway.pending.values.first;
      expect(r.channel, NotificationChannel.fuelWindow);
      expect(r.title, 'Fuel window is open');
      expect(r.body, contains('6:00 PM'));
      // A time and words, no number about the body or food.
      expect(r.body, isNot(matches(RegExp(r'\d\s*(g|kg|kcal|cal)\b'))));
    });

    test('with the session reminder on too, they arrive as one note', () async {
      await reconcile(
        inputs: hardDays(),
        channels: [
          NotificationChannel.sessionReminder,
          NotificationChannel.fuelWindow,
        ],
      );
      final today = gateway.pending.values.first;
      expect(today.channel, NotificationChannel.sessionReminder);
      expect(today.title, startsWith('Session at'));
      expect(today.body, contains('fuel window is open'));
    });

    test('easy and rest days get none', () async {
      await reconcile(
        inputs: hardDays(type: FuelDayType.easy),
        channels: [NotificationChannel.fuelWindow],
      );
      expect(gateway.pending, isEmpty);
    });

    test('fight-week days get none', () async {
      await reconcile(
        inputs: hardDays(type: FuelDayType.fightWeek),
        channels: [NotificationChannel.fuelWindow],
      );
      expect(gateway.pending, isEmpty);
    });

    test('under 18 or unknown age get none, whatever is switched on', () async {
      for (final age in [null, 15, 17]) {
        await reconcile(
          inputs: hardDays(age: age),
          channels: NotificationChannel.values,
        );
        expect(
          gateway.pending.values.where((r) => r.channel.isNutrition),
          isEmpty,
          reason: 'age $age',
        );
        expect(
          gateway.pending.values.any((r) => r.body.contains('fuel window')),
          isFalse,
          reason: 'age $age',
        );
      }
    });

    test('Pause nutrition hides it', () async {
      await reconcile(
        inputs: hardDays(),
        channels: [NotificationChannel.fuelWindow],
        pauseNutrition: true,
      );
      expect(gateway.pending, isEmpty);
    });
  });

  group('fight countdown', () {
    NotificationInputs fightIn(int days) => NotificationInputs(
          fightDate: day(days),
          ageYears: 30,
        );

    test('a note 7 days and 1 day before, nothing about a cut', () async {
      await reconcile(
        inputs: fightIn(9),
        channels: [NotificationChannel.fightCountdown],
        at: day(0),
      );
      // 7 days before day 9 is day 2; 1 day before is day 8 (beyond a week
      // from day 0, so not planned yet).
      final fightNotes = gateway.pending.values.toList();
      expect(fightNotes, hasLength(1));
      expect(fightNotes.single.fireAt, day(2, 9));
      expect(fightNotes.single.title, 'One week to fight day');

      await reconcile(
        inputs: fightIn(9),
        channels: [NotificationChannel.fightCountdown],
        at: day(3),
      );
      expect(gateway.pending.values.single.fireAt, day(8, 9));
      expect(gateway.pending.values.single.title, 'Fight day is tomorrow');
    });

    test('words never mention weight, a cut or the weigh-in', () async {
      for (final title in [
        en.resolve('notif.fight.week', {})!,
        en.resolve('notif.fight.tomorrow', {})!,
      ]) {
        final text = '${title.title} ${title.body}'.toLowerCase();
        for (final banned in ['cut', 'weigh', 'weight', 'water', 'kg', 'lb']) {
          expect(text, isNot(contains(banned)), reason: banned);
        }
      }
    });

    test('no fight, no note; the channel off, no note', () async {
      await reconcile(
        inputs: const NotificationInputs(ageYears: 30),
        channels: [NotificationChannel.fightCountdown],
      );
      expect(gateway.pending, isEmpty);
      await reconcile(inputs: fightIn(9), channels: const []);
      expect(gateway.pending, isEmpty);
    });
  });

  group('the trial notice', () {
    NotificationInputs trialEnding(DateTime ends) =>
        NotificationInputs(trialEndsAt: ends, ageYears: null);

    test('one notice, two days before the trial ends, at 10:00', () async {
      await reconcile(
        inputs: trialEnding(day(5, 12)),
        channels: [NotificationChannel.trialEnding],
      );
      final notice = gateway.pending.values.single;
      expect(notice.channel, NotificationChannel.trialEnding);
      expect(notice.fireAt, day(3, 10));
      expect(notice.title, 'Your free trial ends in 2 days');
      expect(notice.route, '/home');
    });

    test('it is gone when the trial converts or lapses', () async {
      await reconcile(
        inputs: trialEnding(day(5, 12)),
        channels: [NotificationChannel.trialEnding],
      );
      expect(gateway.pending, hasLength(1));

      await reconcile(
        inputs: const NotificationInputs(),
        channels: [NotificationChannel.trialEnding],
      );
      expect(gateway.pending, isEmpty);
    });

    test('it is sent once, not again after it fired', () async {
      await reconcile(
        inputs: trialEnding(day(5, 12)),
        channels: [NotificationChannel.trialEnding],
      );
      // After its time: delivered, and not planned a second time.
      await reconcile(
        at: day(3, 11),
        inputs: trialEnding(day(5, 12)),
        channels: [NotificationChannel.trialEnding],
      );
      expect(gateway.pending, isEmpty);
    });

    test('Pause all does not silence it', () async {
      await reconcile(
        inputs: trialEnding(day(5, 12)),
        channels: [NotificationChannel.trialEnding],
        pauseAll: true,
      );
      expect(gateway.pending, hasLength(1));
    });

    test('a trial that ends within two days gets no notice', () async {
      await reconcile(
        inputs: trialEnding(day(1, 12)),
        channels: [NotificationChannel.trialEnding],
      );
      expect(gateway.pending, isEmpty);
    });

    test('it does not use up the day\'s one slot', () async {
      await reconcile(
        inputs: NotificationInputs(
          trialEndsAt: day(5, 12),
          sessions: [for (var i = 0; i < 6; i++) session(i)],
          ageYears: 30,
        ),
        channels: [
          NotificationChannel.trialEnding,
          NotificationChannel.sessionReminder,
        ],
      );
      final onTrialDay = gateway.pending.values
          .where((r) => r.fireAt.day == day(3).day)
          .map((r) => r.channel)
          .toSet();
      expect(onTrialDay, {
        NotificationChannel.trialEnding,
        NotificationChannel.sessionReminder,
      });
    });
  });

  group('through the controller', () {
    late DateTime clock;
    var inputs = const NotificationInputs();
    var signedIn = true;

    NotificationController build() => NotificationController(
          gateway: gateway,
          now: () => clock,
          debounce: const Duration(milliseconds: 50),
        );

    setUp(() {
      clock = now;
      inputs = const NotificationInputs();
      signedIn = true;
    });

    Future<void> attach(NotificationController c) => c.attach(
          readInputs: () => inputs,
          readLocale: () => const Locale('en'),
          readSignedIn: () => signedIn,
        );

    test('the trial notice needs no switch, and no other channel is on',
        () async {
      inputs = NotificationInputs(trialEndsAt: day(5, 12));
      final c = build();
      await c.load();
      await attach(c);
      await c.reconcileNow();

      expect(c.settings.enabledChannels, isEmpty);
      expect(c.enabledCount, 0);
      expect(gateway.pending.values.single.channel,
          NotificationChannel.trialEnding);
      c.dispose();
    });

    test('nothing is scheduled while the OS does not allow notifications',
        () async {
      gateway.allowed = false;
      inputs = NotificationInputs(trialEndsAt: day(5, 12));
      final c = build();
      await c.load();
      await attach(c);
      await c.reconcileNow();
      expect(gateway.pending, isEmpty);

      // Once the athlete grants permission (for any reminder), it follows.
      gateway.allowed = true;
      await c.refreshPermission();
      await c.reconcileNow();
      expect(gateway.pending, hasLength(1));
      c.dispose();
    });

    test('sign-out cancels it', () async {
      inputs = NotificationInputs(trialEndsAt: day(5, 12));
      final c = build();
      await c.load();
      await attach(c);
      await c.reconcileNow();
      expect(gateway.pending, hasLength(1));

      await c.clearScheduled();
      expect(gateway.pending, isEmpty);
      c.dispose();
    });

    test('a lapse or conversion cancels it on the next reconcile', () async {
      inputs = NotificationInputs(trialEndsAt: day(5, 12));
      final c = build();
      await c.load();
      await attach(c);
      await c.reconcileNow();
      expect(gateway.pending, hasLength(1));

      inputs = const NotificationInputs();
      await c.reconcileNow();
      expect(gateway.pending, isEmpty);
      c.dispose();
    });

    test('the fuel window and fight countdown can be switched on', () async {
      inputs = NotificationInputs(
        sessions: [for (var i = 0; i < 4; i++) session(i)],
        fuelDayTypes: {for (var i = 0; i < 4; i++) day(i): FuelDayType.hard},
        fightDate: day(9),
        ageYears: 30,
      );
      final c = build();
      await c.load();
      await attach(c);
      expect(await c.setChannelEnabled(NotificationChannel.fuelWindow, true),
          isTrue);
      expect(
          await c.setChannelEnabled(NotificationChannel.fightCountdown, true),
          isTrue);
      await c.reconcileNow();

      final channels = gateway.pending.values.map((r) => r.channel).toSet();
      expect(channels, contains(NotificationChannel.fuelWindow));
      expect(c.enabledCount, 2);

      // Nutrition paused (or numbers hidden): every nutrition reminder goes,
      // whatever its switch says, and the others stay.
      inputs = NotificationInputs(
        sessions: inputs.sessions,
        fuelDayTypes: inputs.fuelDayTypes,
        fightDate: inputs.fightDate,
        ageYears: inputs.ageYears,
        nutritionRemindersAllowed: false,
      );
      await c.reconcileNow();
      expect(
        gateway.pending.values.where((r) => r.channel.isNutrition),
        isEmpty,
      );
      expect(
        gateway.pending.values.map((r) => r.channel),
        contains(NotificationChannel.fightCountdown),
      );
      c.dispose();
    });

    test('a quiet fuel window or fight countdown is asked about like the rest',
        () async {
      // Auto-pause applies to every offered channel.
      expect(
          NotificationController.userChannels,
          containsAll([
            NotificationChannel.sessionReminder,
            NotificationChannel.fuelWindow,
            NotificationChannel.weeklyReview,
            NotificationChannel.fightCountdown,
          ]));
      expect(NotificationController.userChannels,
          isNot(contains(NotificationChannel.trialEnding)));
    });
  });
}
