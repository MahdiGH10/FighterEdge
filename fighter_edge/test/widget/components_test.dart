import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:fighter_edge/widgets/filter_chips.dart';
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
}
