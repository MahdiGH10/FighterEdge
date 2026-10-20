import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/glass_policy.dart';
import 'frame_probe.dart';

/// The device-wide inputs of [GlassPolicy]: the "Reduce transparency" setting
/// and what the frame probe found, both remembered on the device.
///
/// Device-wide rather than per account, like the language: how fast the phone
/// draws belongs to the phone.
class GlassPolicyController extends ChangeNotifier {
  GlassPolicyController({FrameProbe? probe}) : _probe = probe ?? FrameProbe();

  static const reduceTransparencyKey = 'settings.reduceTransparency';
  static const probeKey = 'glass.frameProbe.v1';

  final FrameProbe _probe;

  bool _reduceTransparency = false;
  FrameVerdict? _verdict;
  bool _loaded = false;
  bool _probeRequested = false;
  bool _disposed = false;

  bool get reduceTransparency => _reduceTransparency;

  /// The persisted probe result, or null when the probe has not finished.
  FrameVerdict? get verdict => _verdict;
  bool get isLoaded => _loaded;
  bool get isProbing => _probe.isRunning;

  GlassPolicy get policy => GlassPolicy(
        reduceTransparency: _reduceTransparency,
        slowFrames: _verdict == FrameVerdict.slow,
      );

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _reduceTransparency = prefs.getBool(reduceTransparencyKey) ?? false;
      _verdict = switch (prefs.getString(probeKey)) {
        'smooth' => FrameVerdict.smooth,
        'slow' => FrameVerdict.slow,
        _ => null,
      };
    } catch (_) {
      // No stored value is the default: full glass, probe not run yet.
    }
    _loaded = true;
    if (_disposed) return;
    notifyListeners();
    if (_probeRequested) startProbe();
  }

  Future<void> setReduceTransparency(bool value) async {
    if (_reduceTransparency == value) return;
    _reduceTransparency = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(reduceTransparencyKey, value);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  /// Starts the frame probe, once per install. Call it when the first screen
  /// that draws glass is up. If [load] has not finished yet the start is
  /// remembered and happens when it does. Does nothing after a result is
  /// stored or while the probe is already running.
  void startProbe() {
    _probeRequested = true;
    if (!_loaded || _verdict != null || _probe.isRunning) return;
    _probe.start(_onVerdict);
  }

  Future<void> _onVerdict(FrameVerdict verdict) async {
    if (_disposed) return;
    _verdict = verdict;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(probeKey, verdict.name);
    } catch (_) {
      // The result still applies for this session; the probe runs again next
      // launch.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _probe.stop();
    super.dispose();
  }
}

/// Puts the app-wide [GlassPolicy] into the tree, from the
/// [GlassPolicyController] above it. Place it once, above the navigator, so
/// pushed routes and sheets see it too.
class GlassPolicyHost extends StatelessWidget {
  const GlassPolicyHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final policy = context.select<GlassPolicyController, GlassPolicy>(
      (controller) => controller.policy,
    );
    return GlassPolicyScope(policy: policy, child: child);
  }
}
