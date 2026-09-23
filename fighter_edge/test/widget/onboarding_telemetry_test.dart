import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('onboarding reports viewed steps without profile details',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final telemetry = MemoryTelemetry();
    await tester.pumpWidget(wrapApp(
      const OnboardingScreen(),
      repo: repo,
      telemetry: telemetry,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(telemetry.records.single.event, TelemetryEvent.onboardingStepViewed);
    expect(telemetry.records.single.parameters, {'step': 1});
  });
}
