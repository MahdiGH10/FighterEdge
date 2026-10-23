import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/observability/telemetry.dart';

void main() {
  test('all product event names meet the Analytics naming contract', () {
    for (final event in TelemetryEvent.values) {
      expect(event.eventName, matches(RegExp(r'^[a-z][a-z0-9_]{0,39}$')));
    }
  });

  test('only event-specific fixed codes and bounded counts can be recorded',
      () {
    final telemetry = MemoryTelemetry();
    telemetry.track(TelemetryEvent.onboardingCompleted, parameters: {
      'goal': 'lose_weight',
      'days_per_week': 4,
      'detailed': 1,
      'email': 'person@example.com',
      'weight': 77,
      'name': 'A private name',
    });
    expect(telemetry.records.single.parameters, {
      'goal': 'lose_weight',
      'days_per_week': 4,
      'detailed': 1,
    });

    expect(
      safeTelemetryParameters(TelemetryEvent.paywallViewed, {
        'feature': 'cornerCoach',
        'trigger': 'corner_coach',
        'message': 'Please help me lose 10 kg',
      }),
      {'feature': 'cornerCoach', 'trigger': 'corner_coach'},
    );
    expect(
      safeTelemetryParameters(TelemetryEvent.reactionDrillFinished, {
        'discipline': 'private free text',
        'level': 'advanced',
      }),
      {'level': 'advanced'},
    );
    expect(
      safeTelemetryParameters(TelemetryEvent.onboardingStepViewed, {
        'step': 8,
      }),
      isEmpty,
    );
    expect(
      safeTelemetryParameters(TelemetryEvent.paywallViewed, {
        'status': 'active',
        'goal': 'lose_weight',
      }),
      isEmpty,
      reason: 'valid values for other events must not cross the boundary',
    );
  });

  test('trial events carry only a billing period and the read-only trigger',
      () {
    expect(TelemetryEvent.trialStarted.eventName, 'trial_started');
    expect(TelemetryEvent.trialConverted.eventName, 'trial_converted');
    for (final event in [
      TelemetryEvent.trialStarted,
      TelemetryEvent.trialConverted
    ]) {
      expect(
        safeTelemetryParameters(event, {
          'billing_period': 'annual',
          'uid': 'firebase-uid-1',
          'email': 'a@b.test',
          'receipt': 'token',
        }),
        {'billing_period': 'annual'},
      );
      expect(
        safeTelemetryParameters(event, {'billing_period': 'weekly'}),
        isEmpty,
      );
    }
    expect(
      safeTelemetryParameters(TelemetryEvent.paywallViewed, {
        'feature': 'direct',
        'trigger': 'read_only',
      }),
      {'feature': 'direct', 'trigger': 'read_only'},
    );
  });
}
