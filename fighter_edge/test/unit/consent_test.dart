import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/observability/error_reporter.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/privacy/consent.dart';

class _RecordingSink implements ConsentSink {
  final applied = <ConsentChoices>[];

  @override
  Future<void> apply(ConsentChoices choices) async => applied.add(choices);
}

class _RecordingReporter implements ErrorReporter {
  var count = 0;

  @override
  void report(Object error, StackTrace stack,
          {String? reason, bool fatal = false}) =>
      count++;
}

/// Audit M-2: nothing is collected before the athlete decides.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install is undecided and collects nothing', () async {
    final sink = _RecordingSink();
    final consent = ConsentController(sink: sink);
    expect(consent.needsDecision, isFalse, reason: 'not loaded yet');

    await consent.load();

    expect(consent.needsDecision, isTrue);
    expect(consent.analyticsAllowed, isFalse);
    expect(consent.crashReportsAllowed, isFalse);
    final applied = sink.applied.single;
    expect(applied.analytics, isFalse);
    expect(applied.crashReports, isFalse);
  });

  test('a decision is applied, persisted, and not asked again', () async {
    final sink = _RecordingSink();
    await ConsentController(sink: sink).decide(ConsentChoices.all);
    expect(sink.applied.last.analytics, isTrue);

    final reopened = ConsentController(sink: sink);
    await reopened.load();
    expect(reopened.needsDecision, isFalse);
    expect(reopened.analyticsAllowed, isTrue);
    expect(reopened.crashReportsAllowed, isTrue);
  });

  test('each purpose can be withdrawn on its own', () async {
    final consent = ConsentController();
    await consent.decide(ConsentChoices.all);
    await consent.setAnalytics(false);
    expect(consent.analyticsAllowed, isFalse);
    expect(consent.crashReportsAllowed, isTrue);
    await consent.setCrashReports(false);
    expect(consent.crashReportsAllowed, isFalse);
  });

  test('telemetry is dropped without analytics consent', () async {
    final consent = ConsentController();
    await consent.load();
    final inner = MemoryTelemetry();
    final gated = ConsentGatedTelemetry(inner, consent);

    gated.track(TelemetryEvent.paywallViewed);
    expect(inner.records, isEmpty);

    await consent.setAnalytics(true);
    gated.track(TelemetryEvent.paywallViewed);
    expect(inner.records, hasLength(1));

    await consent.setAnalytics(false);
    gated.track(TelemetryEvent.paywallViewed);
    expect(inner.records, hasLength(1));
  });

  test('error reports are dropped without crash-report consent', () async {
    final consent = ConsentController();
    await consent.load();
    final inner = _RecordingReporter();
    final gated = ConsentGatedErrorReporter(inner, consent);

    gated.report(StateError('x'), StackTrace.current);
    expect(inner.count, 0);

    await consent.setCrashReports(true);
    gated.report(StateError('x'), StackTrace.current);
    expect(inner.count, 1);
  });
}
