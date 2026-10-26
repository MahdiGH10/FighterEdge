import 'dart:async';

import 'package:fighter_edge/data/read_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distinguishes loading, empty, ready, stale and recovery', () async {
    final source = StreamController<List<int>>();
    final seen = <ReadState<List<int>>>[];
    final subscription =
        readStates(source.stream, isEmpty: (v) => v.isEmpty).listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.loading);

    source.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.empty);

    source.add([1]);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.ready);

    source.addError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.stale);
    expect(seen.last.value, [1]);

    source.add([2]);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.ready);
    expect(seen.last.value, [2]);
    await subscription.cancel();
    await source.close();
  });

  test('errors before a first snapshot are failed, not empty', () async {
    final source = StreamController<String?>();
    final seen = <ReadState<String?>>[];
    final subscription =
        readStates(source.stream, isEmpty: (v) => v == null).listen(seen.add);
    source.addError(StateError('denied'));
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.failed);
    await subscription.cancel();
    await source.close();
  });

  test('a missing first snapshot fails after a deadline', () async {
    final source = StreamController<int>();
    final seen = <ReadState<int>>[];
    final subscription = readStates(
      source.stream,
      isEmpty: (_) => false,
      firstSnapshotTimeout: const Duration(milliseconds: 5),
    ).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.last.phase, ReadPhase.failed);
    source.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.phase, ReadPhase.ready);
    await subscription.cancel();
    await source.close();
  });

  test('a stream that closes without a snapshot is failed', () async {
    final states =
        await readStates(Stream<int>.empty(), isEmpty: (_) => false).toList();
    expect(states.map((state) => state.phase), [
      ReadPhase.loading,
      ReadPhase.failed,
    ]);
  });
}
