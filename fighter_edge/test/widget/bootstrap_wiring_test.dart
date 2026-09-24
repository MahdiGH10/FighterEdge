import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/observability/error_reporter.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/training/reaction/coach_voice.dart';

import '../helpers/test_harness.dart';

class _MarkedReminders implements ReminderGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required TimeOfDay time,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

class _MarkedVoice extends SilentCoachVoice {
  const _MarkedVoice();
}

class _MarkedReporter extends NoopErrorReporter {
  const _MarkedReporter();
}

/// Guards audit A-1: the production bootstrap built a reminder gateway and
/// then never handed it to the app, so reminders were dead on every device
/// while every test (which injects its own) stayed green.
void main() {
  testWidgets('every production dependency reaches the provider tree',
      (tester) async {
    final reminders = _MarkedReminders();
    const voice = _MarkedVoice();
    final telemetry = MemoryTelemetry();
    const reporter = _MarkedReporter();
    final edgeFuelRepo = InMemoryEdgeFuelRepository();
    const aiGateway = FakeEdgeFuelAiGateway();

    final dependencies = AppDependencies(
      authRepo: await makeRepo(),
      dataRepo: InMemoryDataRepository(),
      edgeFuelRepo: edgeFuelRepo,
      edgeFuelAiGateway: aiGateway,
      billingGateway: FakeBillingGateway(),
      reminderGateway: reminders,
      coachVoice: voice,
      telemetry: telemetry,
      errorReporter: reporter,
    );

    await tester.pumpWidget(FighterEdgeApp.fromDependencies(dependencies));
    await tester.pump();

    final context = tester.element(find.byType(Navigator).first);
    T read<T>() => Provider.of<T>(context, listen: false);

    expect(identical(read<ReminderGateway>(), reminders), isTrue);
    expect(identical(read<CoachVoice>(), voice), isTrue);
    expect(identical(read<Telemetry>(), telemetry), isTrue);
    expect(identical(read<ErrorReporter>(), reporter), isTrue);
    expect(identical(read<EdgeFuelRepository>(), edgeFuelRepo), isTrue);
    expect(identical(read<EdgeFuelAiGateway>(), aiGateway), isTrue);
  });
}
