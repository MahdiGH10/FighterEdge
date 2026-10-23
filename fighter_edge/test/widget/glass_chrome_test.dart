import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/theme/app_icons.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/theme/glass_policy.dart';
import 'package:fighter_edge/widgets/app_scaffold.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:fighter_edge/widgets/glass_sheet.dart';
import 'package:fighter_edge/widgets/glass_surface.dart';
import 'package:fighter_edge/widgets/premium_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {GlassPolicy policy = const GlassPolicy()}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      // In the builder, like the app: routes (sheets) are above `home`.
      builder: (context, child) =>
          GlassPolicyScope(policy: policy, child: child!),
      home: home,
    );

const _items = [
  NavItem(AppIcons.house, 'Home'),
  NavItem(AppIcons.barbell, 'Train'),
];

void main() {
  setUp(GlassBlurBudget.debugReset);

  group('AppBackground', () {
    testWidgets('paints the static glow in its own repaint boundary',
        (tester) async {
      await tester.pumpWidget(
          _app(const Scaffold(body: AppBackground(child: Text('x')))));
      final boundary = find.descendant(
          of: find.byType(AppBackground),
          matching: find.byType(RepaintBoundary));
      expect(boundary, findsWidgets);
      expect(
        find.descendant(of: boundary.first, matching: find.byType(CustomPaint)),
        findsWidgets,
      );
    });

    testWidgets('is the flat ground at the solid level', (tester) async {
      await tester.pumpWidget(_app(
        const Scaffold(body: AppBackground(child: Text('x'))),
        policy: const GlassPolicy(reduceTransparency: true),
      ));
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(AppBackground), matching: find.byType(ColoredBox)));
      expect(box.color, AppColors.background);
    });
  });

  group('AppBottomNav', () {
    testWidgets('is glass and keeps its labels', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        bottomNavigationBar:
            AppBottomNav(items: _items, currentIndex: 0, onTap: (_) {}),
      )));
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('is solid, same geometry, with Reduce transparency',
        (tester) async {
      Future<Size> size(GlassPolicy policy) async {
        await tester.pumpWidget(_app(
          Scaffold(
            bottomNavigationBar:
                AppBottomNav(items: _items, currentIndex: 0, onTap: (_) {}),
          ),
          policy: policy,
        ));
        return tester.getSize(find.byType(AppBottomNav));
      }

      final full = await size(const GlassPolicy());
      final solid = await size(const GlassPolicy(reduceTransparency: true));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(solid, full);
    });
  });

  group('tab chrome', () {
    testWidgets('list bottom padding clears a nav drawn over the body',
        (tester) async {
      late double padding;
      await tester.pumpWidget(_app(Scaffold(
        extendBody: true,
        body: Builder(builder: (context) {
          padding = ScreenScaffold.tabBottomPadding(context);
          return const SizedBox.expand();
        }),
        bottomNavigationBar: const SizedBox(height: 80),
      )));
      expect(padding, 80 + Insets.xxl);
    });

    testWidgets('the header turns to glass only once the list scrolls',
        (tester) async {
      await tester.pumpWidget(_app(
        ScreenScaffold.tab(
          title: 'Today',
          scrollsUnderHeader: true,
          body: Builder(
            builder: (context) => ListView(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 60, child: Text('Row $i')),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(GlassSurface), findsNothing);
      // The first row starts below the header, not under it.
      expect(
          tester.getTopLeft(find.text('Row 0')).dy, greaterThanOrEqualTo(96));

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('a header over pinned controls stays flat', (tester) async {
      await tester.pumpWidget(_app(
        ScreenScaffold.tab(
          title: 'Train',
          body: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('Row $i')),
            ],
          ),
        ),
      ));
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(GlassSurface), findsNothing);
    });
  });

  group('showGlassSheet', () {
    testWidgets('shows the builder on glass and returns its result',
        (tester) async {
      Future<String?>? result;
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showGlassSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (sheet) => TextButton(
                onPressed: () => Navigator.of(sheet).pop('done'),
                child: const Text('Close sheet'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.tap(find.text('Close sheet'));
      await tester.pumpAndSettle();
      expect(await result, 'done');
      expect(find.byType(GlassSurface), findsNothing);
    });

    testWidgets('is an opaque sheet at the solid level', (tester) async {
      await tester.pumpWidget(_app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                builder: (_) => const Text('Body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        policy: const GlassPolicy(reduceTransparency: true),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      final fill = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(GlassSurface), matching: find.byType(ColoredBox)));
      expect(fill.color, AppColors.surfaceElevated);
    });
  });
}
