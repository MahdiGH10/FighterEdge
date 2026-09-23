import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:fighter_edge/widgets/filter_chips.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
import 'package:fighter_edge/widgets/progress_ring.dart';
import 'package:fighter_edge/widgets/stat_card.dart';

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: child));

void main() {
  group('StatCard', () {
    testWidgets('renders label, value, unit and delta; onTap fires',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(StatCard(
        label: 'Weight',
        value: '77.2',
        unit: 'kg',
        delta: '0.3 kg',
        onTap: () => tapped = true,
      )));

      expect(find.text('WEIGHT'), findsOneWidget); // label is upper-cased
      expect(find.text('77.2'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('0.3 kg'), findsOneWidget);

      await tester.tap(find.byType(StatCard));
      expect(tapped, isTrue);
    });
  });

  group('FilterChips', () {
    testWidgets('reports the tapped index', (tester) async {
      int? picked;
      await tester.pumpWidget(host(FilterChips(
        options: const ['Week', 'Month', 'Plan'],
        selectedIndex: 0,
        onSelected: (i) => picked = i,
        scrollable: false,
      )));

      await tester.tap(find.text('Plan'));
      expect(picked, 2);
    });

    // No layout may hide an option without saying so.
    const levels = ['Beginner', 'Intermediate', 'Advanced', 'Advanced+'];
    void expectOnScreen(WidgetTester tester, String label) {
      final r = tester.getRect(find.text(label));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(
          screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue,
          reason: '"$label" is fully on screen');
    }

    testWidgets('columns lays a fixed set out as a grid', (tester) async {
      await tester.pumpWidget(host(FilterChips(
        options: levels,
        selectedIndex: 3,
        onSelected: (_) {},
        columns: 2,
      )));
      for (final l in levels) {
        expectOnScreen(tester, l);
      }
      final y = [for (final l in levels) tester.getCenter(find.text(l)).dy];
      expect(y[0], y[1]);
      expect(y[2], y[3]);
      expect(y[2], greaterThan(y[0]), reason: 'two rows of two');
    });

    testWidgets('at large text, fixed rows wrap instead of hiding options',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final columns in [null, 2]) {
        await tester.pumpWidget(host(FilterChips(
          options: levels,
          selectedIndex: 3,
          onSelected: (_) {},
          scrollable: false,
          columns: columns,
        )));
        expect(find.byType(Wrap), findsOneWidget);
        for (final l in levels) {
          expectOnScreen(tester, l);
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a scrolling row keeps the selected chip in view',
        (tester) async {
      final options = [for (var i = 0; i < 10; i++) 'Option number $i'];
      var selected = 9;
      late StateSetter setState;
      await tester.pumpWidget(host(StatefulBuilder(builder: (context, set) {
        setState = set;
        return FilterChips(
          options: options,
          selectedIndex: selected,
          onSelected: (_) {},
        );
      })));
      await tester.pumpAndSettle();
      expectOnScreen(tester, options[9]);

      setState(() => selected = 0);
      await tester.pumpAndSettle();
      expectOnScreen(tester, options[0]);
      // The page itself did not move — only the row scrolled.
      expect(tester.getTopLeft(find.byType(FilterChips)).dy, 0);
    });
  });

  group('ProgressRing', () {
    testWidgets('paints and shows its child without error', (tester) async {
      await tester.pumpWidget(host(const ProgressRing(
        progress: 1.5, // out of range -> must clamp, not throw
        child: Text('GO'),
      )));
      expect(find.text('GO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppBottomNav', () {
    testWidgets('reports the tapped tab index', (tester) async {
      int? picked;
      await tester.pumpWidget(host(AppBottomNav(
        currentIndex: 0,
        onTap: (index) => picked = index,
        items: const [
          NavItem(Icons.home_rounded, 'Home'),
          NavItem(Icons.fitness_center_rounded, 'Train'),
          NavItem(Icons.local_fire_department_rounded, 'Fuel'),
          NavItem(Icons.menu_rounded, 'More'),
        ],
      )));

      await tester.tap(find.text('More'));
      expect(picked, 3);
    });
  });

  group('Buttons', () {
    testWidgets('keep their whole label when two share a phone-width row',
        (tester) async {
      // The dashboard's START CAMP / LOG MEAL pair, at a 390pt screen minus
      // the card and page gutters.
      await tester.pumpWidget(host(Center(
        child: SizedBox(
          width: 326,
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton('Start camp',
                    icon: Icons.play_arrow, expand: true, onPressed: () {}),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: GhostButton('Log meal',
                    icon: Icons.restaurant, expand: true, onPressed: () {}),
              ),
            ],
          ),
        ),
      )));

      for (final label in ['START CAMP', 'LOG MEAL']) {
        final paragraph =
            tester.renderObject<RenderParagraph>(find.text(label));
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      // Tight on room, the icons give way before the words do.
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('keep their icon when there is room', (tester) async {
      await tester.pumpWidget(host(PrimaryButton('Start camp',
          icon: Icons.play_arrow, expand: true, onPressed: () {})));
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });
}
