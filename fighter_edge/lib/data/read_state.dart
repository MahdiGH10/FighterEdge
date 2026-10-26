import 'dart:async';

/// A read's status is separate from its value. In particular, a failed read
/// must never be mistaken for an empty collection or a missing document.
enum ReadPhase { loading, empty, ready, stale, failed }

class ReadState<T> {
  const ReadState(this.phase, [this.value]);

  final ReadPhase phase;
  final T? value;

  bool get isLoading => phase == ReadPhase.loading;
  bool get isFailed => phase == ReadPhase.failed;
  bool get isStale => phase == ReadPhase.stale;
  bool get isUsable => phase == ReadPhase.empty || phase == ReadPhase.ready;
}

/// Adds read status to a repository stream. Only the first snapshot has a
/// deadline: a healthy live stream can be quiet for days after that.
/// A later stream error preserves the last value as stale; retry re-subscribes.
Stream<ReadState<T>> readStates<T>(
  Stream<T> source, {
  required bool Function(T) isEmpty,
  Duration firstSnapshotTimeout = const Duration(seconds: 10),
}) {
  late StreamController<ReadState<T>> controller;
  StreamSubscription<T>? subscription;
  Timer? firstSnapshotTimer;
  T? lastValue;
  var hasSnapshot = false;
  var hasFailure = false;
  controller = StreamController<ReadState<T>>(
    onListen: () {
      controller.add(const ReadState(ReadPhase.loading));
      firstSnapshotTimer = Timer(firstSnapshotTimeout, () {
        if (!hasSnapshot && !controller.isClosed) {
          controller.add(const ReadState(ReadPhase.failed));
        }
      });
      subscription = source.listen(
        (value) {
          firstSnapshotTimer?.cancel();
          hasSnapshot = true;
          lastValue = value;
          controller.add(ReadState(
            isEmpty(value) ? ReadPhase.empty : ReadPhase.ready,
            value,
          ));
        },
        onError: (Object _, StackTrace __) {
          firstSnapshotTimer?.cancel();
          hasFailure = true;
          if (!controller.isClosed) {
            controller.add(ReadState(
              hasSnapshot ? ReadPhase.stale : ReadPhase.failed,
              lastValue,
            ));
          }
        },
        onDone: () {
          firstSnapshotTimer?.cancel();
          if (!hasSnapshot && !hasFailure && !controller.isClosed) {
            controller.add(const ReadState(ReadPhase.failed));
          }
          controller.close();
        },
      );
    },
    onCancel: () async {
      firstSnapshotTimer?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
