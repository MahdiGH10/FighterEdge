import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/theme/app_typography.dart';
import 'package:fighter_edge/theme/glass_policy.dart';
import 'package:fighter_edge/widgets/glass_surface.dart';
import 'package:fighter_edge/widgets/premium_effects.dart';

/// Frame benchmark for the V2 glass, per level. Run it in PROFILE mode on a
/// real phone (debug timings mean nothing):
///
/// ```powershell
/// flutter test integration_test/glass_frame_benchmark_test.dart --profile -d <device id>
/// ```
///
/// It scrolls a long list under the real chrome (static glow ground, a glass
/// nav, a glass collapsed header, a tinted hero card) at each [GlassLevel] and
/// prints build and raster p50/p90/p99 per level, plus the `GlassPolicy`
/// verdict the app's own probe would reach. There is deliberately no pass or
/// fail threshold: the numbers are compared by eye between levels on one
/// device, and against the 16 ms budget the probe uses
/// ([GlassBudget.slowRasterP90]).
///
/// Do not run this on the emulator: software rendering says nothing about a
/// phone GPU, and the probe exists precisely because the answer differs per
/// device.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final timings = <FrameTiming>[];
  binding.addTimingsCallback(timings.addAll);

  double percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final rank = (p * sorted.length).ceil().clamp(1, sorted.length);
    return sorted[rank - 1];
  }

  String summary(String label, List<FrameTiming> frames) {
    final build = [
      for (final t in frames) t.buildDuration.inMicroseconds / 1000
    ]..sort();
    final raster = [
      for (final t in frames) t.rasterDuration.inMicroseconds / 1000
    ]..sort();
    String row(List<double> v) => 'p50=${percentile(v, .5).toStringAsFixed(2)} '
        'p90=${percentile(v, .9).toStringAsFixed(2)} '
        'p99=${percentile(v, .99).toStringAsFixed(2)}';
    return 'fighter_edge_glass level=$label frames=${frames.length} '
        'build[${row(build)}] raster[${row(raster)}]';
  }

  for (final level in GlassLevel.values) {
    testWidgets('scroll under glass at ${level.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: GlassPolicyScope(
            policy: GlassPolicy(
              slowFrames: level == GlassLevel.tinted,
              reduceTransparency: level == GlassLevel.solid,
            ),
            child: BackdropGroup(
              child: const _BenchmarkScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      timings.clear();
      for (var i = 0; i < 6; i++) {
        await tester.fling(find.byType(ListView), const Offset(0, -900), 2400);
        await tester.pumpAndSettle();
        await tester.fling(find.byType(ListView), const Offset(0, 900), 2400);
        await tester.pumpAndSettle();
      }
      // Frames are delivered a beat after they are drawn.
      await tester.pump(const Duration(milliseconds: 200));

      final line = summary(level.name, List.of(timings));
      debugPrint(line);
      binding.reportData = {
        ...?binding.reportData,
        'glass_${level.name}': line,
      };
      expect(timings, isNotEmpty);
    });
  }
}

/// A tab-like screen: ground glow, a hero card, a long solid list, glass nav
/// and a glass header that the list scrolls under.
class _BenchmarkScreen extends StatelessWidget {
  const _BenchmarkScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  Insets.xl, 120, Insets.xl, Insets.bottomClearance + 40),
              itemCount: 240,
              itemBuilder: (context, i) => i == 0
                  ? const GlassCard(
                      child: Text('Today', style: TextStyle(fontSize: 24)),
                    )
                  : Container(
                      margin: const EdgeInsets.only(top: Insets.sm),
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? AppColors.surface
                            : AppColors.ember.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: Text('Row $i',
                          style: AppType.body(color: AppColors.textPrimary)),
                    ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassSurface(
                kind: GlassKind.nav,
                edge: GlassEdge.bottom,
                child: SizedBox(height: 96, width: double.infinity),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const GlassSurface(
        kind: GlassKind.nav,
        child: SizedBox(height: 84, width: double.infinity),
      ),
    );
  }
}
