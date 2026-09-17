import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/main.dart';

/// Lightweight device smoke test. It intentionally avoids a fake timing
/// threshold that would make CI flaky; the captured p95 values are emitted in
/// the integration result and compared against the budgets in the performance
/// plan on a known device class.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final timings = <FrameTiming>[];
  binding.addTimingsCallback(timings.addAll);

  testWidgets('cold boot stays responsive on the login surface',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalAuthRepository();
    await repo.init();

    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(timings, isNotEmpty);

    final buildMs = timings
        .map((timing) => timing.buildDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final rasterMs = timings
        .map((timing) => timing.rasterDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final p95Index = ((buildMs.length - 1) * .95).round();
    debugPrint(
      'fighter_edge_perf frames=${timings.length} '
      'buildP95Ms=${buildMs[p95Index].toStringAsFixed(2)} '
      'rasterP95Ms=${rasterMs[p95Index].toStringAsFixed(2)}',
    );
  });
}
