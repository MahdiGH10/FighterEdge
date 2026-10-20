import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/theme/glass_policy.dart';
import 'package:fighter_edge/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  GlassPolicy policy = const GlassPolicy(),
  bool highContrast = false,
  double width = 390,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: GlassPolicyScope(
          policy: policy,
          child: BackdropGroup(
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          ),
        ),
      ),
    );

const _navLabel = SizedBox(height: 56, width: 390, child: Text('Home'));

void main() {
  setUp(GlassBlurBudget.debugReset);

  group('GlassSurface', () {
    testWidgets('blurs at the full level and counts against the budget',
        (tester) async {
      await tester.pumpWidget(
          _host(const GlassSurface(kind: GlassKind.nav, child: _navLabel)));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(GlassBlurBudget.live, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(GlassBlurBudget.live, 0, reason: 'dispose gives the slot back');
    });

    testWidgets('no blur when slow frames drop it to tinted', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(kind: GlassKind.nav, child: _navLabel),
        policy: const GlassPolicy(slowFrames: true),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(GlassBlurBudget.live, 0);
      final fill = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(GlassSurface), matching: find.byType(ColoredBox)));
      expect(fill.color, GlassColors.navFillTinted);
    });

    testWidgets('solid when Reduce transparency is on', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(kind: GlassKind.sheet, child: _navLabel),
        policy: const GlassPolicy(reduceTransparency: true),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      final fill = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(GlassSurface), matching: find.byType(ColoredBox)));
      expect(fill.color, AppColors.surfaceElevated);
    });

    testWidgets('solid in high contrast, without any policy scope',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const Scaffold(
            body: GlassSurface(kind: GlassKind.nav, child: _navLabel),
          ),
        ),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      final fill = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(GlassSurface), matching: find.byType(ColoredBox)));
      expect(fill.color, AppColors.surface);
    });

    testWidgets('a hidden tab (tickers off) draws and counts no blur',
        (tester) async {
      await tester.pumpWidget(_host(
        const TickerMode(
          enabled: false,
          child: GlassSurface(kind: GlassKind.nav, child: _navLabel),
        ),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(GlassBlurBudget.live, 0);
    });

    testWidgets('three blurs are fine, a fourth is reported', (tester) async {
      Widget surfaces(int n) => _host(Column(children: [
            for (var i = 0; i < n; i++)
              const GlassSurface(
                  kind: GlassKind.nav, child: SizedBox(height: 8)),
          ]));
      await tester.pumpWidget(surfaces(3));
      expect(GlassBlurBudget.live, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      GlassBlurBudget.debugReset();

      await tester.pumpWidget(surfaces(4));
      expect(tester.takeException(), isFlutterError);
    });

    testWidgets('level override beats the policy', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(
            kind: GlassKind.nav, level: GlassLevel.solid, child: _navLabel),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('rounded sheet corners clip the surface', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(
          kind: GlassKind.sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(height: 100, width: 390),
        ),
      ));
      final clip = tester.widget<ClipRRect>(find.descendant(
          of: find.byType(GlassSurface), matching: find.byType(ClipRRect)));
      expect(clip.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)));
    });

    testWidgets('a hero kind is refused', (tester) async {
      expect(
        () => GlassSurface(kind: GlassKind.hero, child: const SizedBox()),
        throwsAssertionError,
      );
    });
  });

  group('GlassCard', () {
    testWidgets('never blurs, at any level', (tester) async {
      for (final policy in const [
        GlassPolicy(),
        GlassPolicy(slowFrames: true),
        GlassPolicy(reduceTransparency: true),
      ]) {
        await tester.pumpWidget(_host(
          const GlassCard(child: Text('Today')),
          policy: policy,
        ));
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('Today'), findsOneWidget);
      }
      expect(GlassBlurBudget.live, 0);
    });

    testWidgets('keeps its tint at full and tinted, goes solid when reduced',
        (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('Today'))));
      expect(
          find.descendant(
              of: find.byType(GlassCard), matching: find.byType(CustomPaint)),
          findsWidgets);

      await tester.pumpWidget(_host(
        const GlassCard(child: Text('Today')),
        policy: const GlassPolicy(slowFrames: true),
      ));
      expect(
          find.descendant(
              of: find.byType(GlassCard), matching: find.byType(CustomPaint)),
          findsWidgets);

      await tester.pumpWidget(_host(
        const GlassCard(child: Text('Today')),
        policy: const GlassPolicy(reduceTransparency: true),
      ));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(GlassCard), matching: find.byType(DecoratedBox)));
      expect((box.decoration as BoxDecoration).color, AppColors.surfaceAlt);
    });

    testWidgets('lays out inside 320px at 200% text without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 640), textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: GlassCard(
                  child: Text('Wrestling, 6 rounds, about 50 minutes')),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
