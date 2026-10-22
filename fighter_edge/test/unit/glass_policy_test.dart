import 'package:fighter_edge/state/frame_probe.dart';
import 'package:fighter_edge/state/glass_policy_controller.dart';
import 'package:fighter_edge/theme/glass_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feeds raster times by hand, so no frame has to be drawn.
class _FakeSource implements RasterTimingSource {
  void Function(List<Duration>)? listener;
  int listenCalls = 0;

  @override
  void listen(void Function(List<Duration> rasterTimes) listener) {
    this.listener = listener;
    listenCalls++;
  }

  @override
  void cancel(void Function(List<Duration> rasterTimes) listener) {
    if (this.listener == listener) this.listener = null;
  }

  void emit(Iterable<int> millis) =>
      listener?.call([for (final m in millis) Duration(milliseconds: m)]);
}

List<int> _frames(int count, int ms) => List.filled(count, ms);

void main() {
  group('GlassPolicy.resolve', () {
    test('defaults to full glass', () {
      expect(const GlassPolicy().resolve(highContrast: false), GlassLevel.full);
    });

    test('slow frames drop the blur but keep the tint', () {
      expect(const GlassPolicy(slowFrames: true).resolve(highContrast: false),
          GlassLevel.tinted);
    });

    test('reduce transparency goes to solid', () {
      expect(
          const GlassPolicy(reduceTransparency: true)
              .resolve(highContrast: false),
          GlassLevel.solid);
    });

    test('high contrast goes to solid', () {
      expect(const GlassPolicy().resolve(highContrast: true), GlassLevel.solid);
    });

    test('causes combine by taking the lowest level', () {
      expect(
          const GlassPolicy(slowFrames: true, reduceTransparency: true)
              .resolve(highContrast: false),
          GlassLevel.solid);
      expect(const GlassPolicy(slowFrames: true).resolve(highContrast: true),
          GlassLevel.solid);
    });

    test('levels know what they draw', () {
      expect(GlassLevel.full.blurs, isTrue);
      expect(GlassLevel.tinted.blurs, isFalse);
      expect(GlassLevel.solid.blurs, isFalse);
      expect(GlassLevel.tinted.tints, isTrue);
      expect(GlassLevel.solid.tints, isFalse);
    });

    test('policies compare by value', () {
      expect(const GlassPolicy(slowFrames: true),
          const GlassPolicy(slowFrames: true));
      expect(const GlassPolicy(), isNot(const GlassPolicy(slowFrames: true)));
    });
  });

  group('FrameProbe', () {
    test('percentile 90 uses the nearest rank', () {
      final times = [for (var i = 1; i <= 10; i++) Duration(milliseconds: i)];
      expect(FrameProbe.percentile90(times), const Duration(milliseconds: 9));
      expect(FrameProbe.percentile90(const []), Duration.zero);
      expect(FrameProbe.percentile90([const Duration(milliseconds: 7)]),
          const Duration(milliseconds: 7));
    });

    test('a smooth device is reported smooth after 120 frames', () {
      final source = _FakeSource();
      final probe = FrameProbe(source: source);
      FrameVerdict? verdict;
      probe.start((v) => verdict = v);
      source.emit(_frames(60, 5));
      expect(verdict, isNull, reason: '60 of 120 frames is not enough');
      expect(probe.framesSeen, 60);
      source.emit(_frames(60, 5));
      expect(verdict, FrameVerdict.smooth);
      expect(probe.isRunning, isFalse);
      expect(source.listener, isNull, reason: 'the probe stops listening');
    });

    test('one in ten slow frames is still smooth, two in ten is slow', () {
      // 12 of 120 slow frames: the 90th percentile (rank 108) is a fast one.
      var source = _FakeSource();
      var probe = FrameProbe(source: source);
      FrameVerdict? verdict;
      probe.start((v) => verdict = v);
      source.emit([..._frames(108, 4), ..._frames(12, 40)]);
      expect(verdict, FrameVerdict.smooth);

      // 13 slow frames: rank 108 is now slow.
      source = _FakeSource();
      probe = FrameProbe(source: source);
      verdict = null;
      probe.start((v) => verdict = v);
      source.emit([..._frames(107, 4), ..._frames(13, 40)]);
      expect(verdict, FrameVerdict.slow);
    });

    test('exactly at the threshold is not slow', () {
      final source = _FakeSource();
      final probe = FrameProbe(source: source);
      FrameVerdict? verdict;
      probe.start((v) => verdict = v);
      source.emit(_frames(120, 16));
      expect(verdict, FrameVerdict.smooth);
    });

    test('frames beyond the window are ignored', () {
      final source = _FakeSource();
      final probe = FrameProbe(source: source, frameCount: 10);
      FrameVerdict? verdict;
      probe.start((v) => verdict = v);
      source.emit([..._frames(10, 4), ..._frames(50, 90)]);
      expect(verdict, FrameVerdict.smooth);
    });

    test('start twice does not listen twice, and stop gives no verdict', () {
      final source = _FakeSource();
      final probe = FrameProbe(source: source);
      var calls = 0;
      probe.start((_) => calls++);
      probe.start((_) => calls++);
      expect(source.listenCalls, 1);
      probe.stop();
      source.emit(_frames(200, 99));
      expect(calls, 0);
    });
  });

  group('GlassPolicyController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts at full glass', () async {
      final c = GlassPolicyController(probe: FrameProbe(source: _FakeSource()));
      await c.load();
      expect(c.isLoaded, isTrue);
      expect(c.policy, const GlassPolicy());
      c.dispose();
    });

    test('remembers the reduce transparency setting', () async {
      final c = GlassPolicyController(probe: FrameProbe(source: _FakeSource()));
      await c.load();
      await c.setReduceTransparency(true);
      expect(c.policy.reduceTransparency, isTrue);
      c.dispose();

      final again =
          GlassPolicyController(probe: FrameProbe(source: _FakeSource()));
      await again.load();
      expect(again.reduceTransparency, isTrue);
      again.dispose();
    });

    test('a slow verdict is persisted and read back', () async {
      final source = _FakeSource();
      final c = GlassPolicyController(probe: FrameProbe(source: source));
      await c.load();
      c.startProbe();
      expect(c.isProbing, isTrue);
      source.emit(_frames(120, 30));
      await Future<void>.delayed(Duration.zero);
      expect(c.verdict, FrameVerdict.slow);
      expect(c.policy.slowFrames, isTrue);
      c.dispose();

      final again =
          GlassPolicyController(probe: FrameProbe(source: _FakeSource()));
      await again.load();
      expect(again.verdict, FrameVerdict.slow);
      expect(again.policy.resolve(highContrast: false), GlassLevel.tinted);
      again.dispose();
    });

    test('the probe runs once: not before load, not after a verdict', () async {
      final source = _FakeSource();
      final c = GlassPolicyController(probe: FrameProbe(source: source));
      c.startProbe();
      expect(source.listenCalls, 0, reason: 'not loaded yet');
      await c.load();
      expect(source.listenCalls, 1, reason: 'the early request is honoured');
      c.startProbe();
      expect(source.listenCalls, 1);
      source.emit(_frames(120, 4));
      await Future<void>.delayed(Duration.zero);
      expect(c.verdict, FrameVerdict.smooth);
      c.startProbe();
      expect(source.listenCalls, 1, reason: 'a stored verdict is final');
      c.dispose();
    });

    test('ignores a corrupt stored verdict', () async {
      SharedPreferences.setMockInitialValues(
          {GlassPolicyController.probeKey: 'banana'});
      final c = GlassPolicyController(probe: FrameProbe(source: _FakeSource()));
      await c.load();
      expect(c.verdict, isNull);
      c.dispose();
    });
  });
}
