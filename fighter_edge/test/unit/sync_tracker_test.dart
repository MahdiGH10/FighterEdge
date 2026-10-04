import 'package:fighter_edge/observability/error_reporter.dart';
import 'package:fighter_edge/state/sync_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingReporter implements ErrorReporter {
  final reasons = <String?>[];

  @override
  void report(Object error, StackTrace stack,
          {String? reason, bool fatal = false}) =>
      reasons.add(reason);
}

void main() {
  test('a successful write leaves nothing pending', () async {
    final sync = SyncTracker();
    expect(await sync.run('k', 'r', () async {}), isTrue);
    expect(sync.hasFailure, isFalse);
  });

  test('a refused write is reported by reason and offered for retry', () async {
    final reporter = _RecordingReporter();
    final sync = SyncTracker(errorReporter: reporter);
    var notified = 0;
    sync.addListener(() => notified++);

    final ok = await sync.run('weight-1', 'weight_save_failed',
        () async => throw StateError('permission-denied'));

    expect(ok, isFalse);
    expect(sync.hasFailure, isTrue);
    expect(reporter.reasons, ['weight_save_failed']);
    expect(notified, greaterThan(0));
  });

  test('retry clears the failure once the write goes through', () async {
    final sync = SyncTracker();
    var refuse = true;
    await sync.run('k', 'r', () async {
      if (refuse) throw StateError('refused');
    });
    expect(sync.hasFailure, isTrue);

    refuse = false;
    await sync.retry();

    expect(sync.hasFailure, isFalse);
    expect(sync.isRetrying, isFalse);
  });

  test('a retry that fails again stays pending, once', () async {
    final sync = SyncTracker();
    var attempts = 0;
    Future<void> write() async {
      attempts++;
      throw StateError('refused');
    }

    await sync.run('k', 'r', write);
    await sync.run('k', 'r', write);
    await sync.retry();

    expect(attempts, 3);
    expect(sync.hasFailure, isTrue);
  });

  test('clear forgets another account\'s failures', () async {
    final sync = SyncTracker();
    await sync.run('k', 'r', () async => throw StateError('x'));
    sync.clear();
    expect(sync.hasFailure, isFalse);
  });
}
