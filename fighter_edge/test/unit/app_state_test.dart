import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/state/app_state.dart';

void main() {
  group('AppState — weight', () {
    test('seed exposes latest weight and weekly delta', () {
      final s = AppState();
      expect(s.latestWeight, closeTo(77.2, 0.001));
      // 77.2 (Jun 3) minus 77.5 (May 27) = -0.3
      expect(s.weeklyDelta, closeTo(-0.3, 0.001));
    });

    test('weights are returned oldest-first, history newest-first', () {
      final s = AppState();
      final asc = s.weights;
      expect(asc.first.date.isBefore(asc.last.date), isTrue);
      final desc = s.weightHistoryDesc;
      expect(desc.first.date.isAfter(desc.last.date), isTrue);
    });

    test('adding a weigh-in updates latest, delta and count', () {
      final s = AppState();
      final n = s.weights.length;
      s.addWeight(DateTime.now(), 76.0);
      expect(s.weights.length, n + 1);
      expect(s.latestWeight, 76.0);
      expect(s.weeklyDelta, closeTo(76.0 - 77.2, 0.001));
    });

    test('an out-of-order date still sorts correctly', () {
      final s = AppState();
      s.addWeight(DateTime(2024, 5, 10), 78.0); // between existing entries
      final asc = s.weights;
      for (var i = 1; i < asc.length; i++) {
        expect(asc[i].date.isBefore(asc[i - 1].date), isFalse);
      }
    });

    test('reading weights does not mutate internal ordering', () {
      final s = AppState();
      final firstRead = s.weights.map((e) => e.date).toList();
      s.weights; // second read
      final secondRead = s.weights.map((e) => e.date).toList();
      expect(secondRead, firstRead);
    });
  });

  group('AppState — nutrition', () {
    test('seed totals match the design mock', () {
      final s = AppState();
      expect(s.consumedCalories, 2356);
      expect(s.consumedProtein, 165);
      expect(s.consumedCarbs, 235);
      expect(s.consumedFats, 72);
      expect(s.target.calories, 2600);
    });

    test('toggling a meal adjusts every macro total', () {
      final s = AppState();
      final breakfast = s.meals.firstWhere((m) => m.name == 'Breakfast');
      final cal = s.consumedCalories;
      final pro = s.consumedProtein;
      s.toggleMeal(breakfast); // was eaten -> now off
      expect(s.consumedCalories, cal - breakfast.calories);
      expect(s.consumedProtein, pro - breakfast.protein);
      s.toggleMeal(breakfast); // back on
      expect(s.consumedCalories, cal);
    });

    test('all meals off yields zero consumption', () {
      final s = AppState();
      for (final m in s.meals.where((m) => m.eaten).toList()) {
        s.toggleMeal(m);
      }
      expect(s.consumedCalories, 0);
      expect(s.consumedProtein, 0);
      expect(s.consumedCarbs, 0);
      expect(s.consumedFats, 0);
    });
  });
}
