import 'package:flutter/scheduler.dart';

import '../theme/glass_policy.dart';

/// Where raster times come from. The real one wraps the engine's frame timings;
/// tests feed a fake so no frames have to be drawn.
abstract interface class RasterTimingSource {
  /// Starts delivering batches of raster durations to [listener].
  void listen(void Function(List<Duration> rasterTimes) listener);

  /// Stops delivering to [listener].
  void cancel(void Function(List<Duration> rasterTimes) listener);
}

/// The engine's own frame timings, via [SchedulerBinding.addTimingsCallback].
class EngineRasterTimingSource implements RasterTimingSource {
  EngineRasterTimingSource();

  final _wrappers =
      <void Function(List<Duration>), void Function(List<FrameTiming>)>{};

  @override
  void listen(void Function(List<Duration> rasterTimes) listener) {
    void wrapper(List<FrameTiming> timings) =>
        listener([for (final t in timings) t.rasterDuration]);
    _wrappers[listener] = wrapper;
    SchedulerBinding.instance.addTimingsCallback(wrapper);
  }

  @override
  void cancel(void Function(List<Duration> rasterTimes) listener) {
    final wrapper = _wrappers.remove(listener);
    if (wrapper != null) {
      SchedulerBinding.instance.removeTimingsCallback(wrapper);
    }
  }
}

/// What the probe concluded.
enum FrameVerdict {
  /// p90 raster time stayed within the threshold: full glass is fine.
  smooth,

  /// p90 raster time was above the threshold: drop the blur.
  slow,
}

/// Watches the first [frameCount] frames after [start] and reports whether the
/// 90th percentile raster time went above [threshold].
///
/// Percentile by the nearest-rank method, so the result needs no
/// interpolation to explain: sort the times, take the one at rank
/// `ceil(0.9 * n)`.
class FrameProbe {
  FrameProbe({
    RasterTimingSource? source,
    this.frameCount = GlassBudget.probeFrames,
    this.threshold = GlassBudget.slowRasterP90,
  }) : source = source ?? EngineRasterTimingSource();

  final RasterTimingSource source;
  final int frameCount;
  final Duration threshold;

  final _times = <Duration>[];
  void Function(FrameVerdict verdict)? _onDone;
  bool _running = false;

  bool get isRunning => _running;

  /// Frames seen so far in the current run.
  int get framesSeen => _times.length;

  /// Starts watching. [onDone] fires once, when [frameCount] frames are in.
  /// Calling this while already running does nothing.
  void start(void Function(FrameVerdict verdict) onDone) {
    if (_running) return;
    _running = true;
    _times.clear();
    _onDone = onDone;
    source.listen(_onTimings);
  }

  /// Stops without a verdict.
  void stop() {
    if (!_running) return;
    _running = false;
    _onDone = null;
    source.cancel(_onTimings);
  }

  void _onTimings(List<Duration> rasterTimes) {
    if (!_running) return;
    for (final t in rasterTimes) {
      if (_times.length >= frameCount) break;
      _times.add(t);
    }
    if (_times.length < frameCount) return;
    final done = _onDone;
    final verdict = verdictFor(_times, threshold);
    stop();
    done?.call(verdict);
  }

  /// The verdict for a set of raster times.
  static FrameVerdict verdictFor(List<Duration> times, Duration threshold) =>
      percentile90(times) > threshold ? FrameVerdict.slow : FrameVerdict.smooth;

  /// 90th percentile by nearest rank. An empty list is [Duration.zero].
  static Duration percentile90(List<Duration> times) {
    if (times.isEmpty) return Duration.zero;
    final sorted = [...times]..sort();
    final rank = (0.9 * sorted.length).ceil().clamp(1, sorted.length);
    return sorted[rank - 1];
  }
}
