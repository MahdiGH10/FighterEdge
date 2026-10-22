import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/billing/trial_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

final _now = DateTime(2026, 10, 20, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderGateway gateway;
  late TrialReminderCoordinator coordinator;
  var now = _now;

  setUp(() {
    now = _now;
    gateway = FakeReminderGateway();
    coordinator = TrialReminderCoordinator(gateway: gateway, now: () => now);
  });

  Future<void> sync(AccessState access) =>
      coordinator.sync(access, title: 'Trial ends', body: 'Soon');

  group('reminderAt', () {
    test('is two days before the trial ends', () {
      final ends = _now.add(const Duration(days: 7));
      expect(TrialReminderCoordinator.reminderAt(AccessState.trial(ends), _now),
          ends.subtract(const Duration(days: 2)));
    });

    test('is null when less than two days are left, or past', () {
      for (final hours in [47, 1, 0, -5]) {
        final ends = _now.add(Duration(hours: hours));
        expect(
            TrialReminderCoordinator.reminderAt(AccessState.trial(ends), _now),
            isNull,
            reason: '$hours h left');
      }
    });

    test('is null outside a dated trial', () {
      expect(
          TrialReminderCoordinator.reminderAt(const AccessState.active(), _now),
          isNull);
      expect(
          TrialReminderCoordinator.reminderAt(
              const AccessState.readOnly(), _now),
          isNull);
      expect(
          TrialReminderCoordinator.reminderAt(
              const AccessState.unknown(), _now),
          isNull);
    });

    test('an unknown state over a trial still counts the cached trial', () {
      final ends = _now.add(const Duration(days: 6));
      expect(
          TrialReminderCoordinator.reminderAt(
              AccessState.unknown(lastKnown: AccessState.trial(ends)), _now),
          ends.subtract(const Duration(days: 2)));
    });
  });

  group('sync', () {
    test('schedules once for a running trial and never prompts', () async {
      final ends = _now.add(const Duration(days: 7));
      await sync(AccessState.trial(ends));
      await sync(AccessState.trial(ends));

      expect(gateway.trialReminderAt, ends.subtract(const Duration(days: 2)));
      expect(gateway.trialReminderTitle, 'Trial ends');
      expect(gateway.trialReminderSchedules, 1);
      // No permission prompt, on first launch or at trial start.
      expect(gateway.permissionRequests, 0);
    });

    test('moves the reminder when the trial end moves', () async {
      final ends = _now.add(const Duration(days: 7));
      await sync(AccessState.trial(ends));
      final later = ends.add(const Duration(days: 1));
      await sync(AccessState.trial(later));
      expect(gateway.trialReminderAt, later.subtract(const Duration(days: 2)));
      expect(gateway.trialReminderSchedules, 2);
    });

    test('schedules nothing when fewer than two days are left', () async {
      await sync(AccessState.trial(_now.add(const Duration(days: 1))));
      expect(gateway.trialReminderAt, isNull);
      expect(gateway.trialReminderSchedules, 0);
    });

    test('cancels when the trial converts, lapses or ends early', () async {
      final ends = _now.add(const Duration(days: 7));
      await sync(AccessState.trial(ends));
      expect(gateway.trialReminderAt, isNotNull);

      await sync(const AccessState.active());
      expect(gateway.trialReminderAt, isNull);
      expect(gateway.trialReminderCancels, 1);

      await sync(AccessState.trial(ends));
      await sync(const AccessState.readOnly());
      expect(gateway.trialReminderAt, isNull);
      expect(gateway.trialReminderCancels, 2);
    });

    test('a passing unknown state keeps the reminder', () async {
      final ends = _now.add(const Duration(days: 7));
      await sync(AccessState.trial(ends));
      await sync(const AccessState.unknown());
      expect(gateway.trialReminderAt, isNotNull);
      expect(gateway.trialReminderCancels, 0);
    });

    test('clears a reminder left from an earlier launch once, then rests',
        () async {
      // A fresh coordinator (new launch) cannot know what the OS still holds.
      await sync(const AccessState.active());
      await sync(const AccessState.active());
      await sync(const AccessState.readOnly());
      expect(gateway.trialReminderCancels, 1);
    });

    test('does nothing where notifications are unavailable', () async {
      gateway.available = false;
      await sync(AccessState.trial(_now.add(const Duration(days: 7))));
      await sync(const AccessState.readOnly());
      expect(gateway.trialReminderSchedules, 0);
      expect(gateway.trialReminderCancels, 0);
    });

    test('cancel() drops it (sign-out)', () async {
      await sync(AccessState.trial(_now.add(const Duration(days: 7))));
      await coordinator.cancel();
      expect(gateway.trialReminderAt, isNull);
    });
  });
}
