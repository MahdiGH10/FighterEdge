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
        'feature': 'edgeFuelAiCoach',
        'trigger': 'fighter_brief',
        'message': 'Please help me lose 10 kg',
      }),
      {'feature': 'edgeFuelAiCoach', 'trigger': 'fighter_brief'},
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
}
