import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/models/meal.dart';
import 'package:fighter_edge/state/app_state.dart';

void main() {
  test('repository-backed state starts empty instead of flashing demo data',
      () {
    final repository = InMemoryDataRepository();
    final state = AppState(dataRepository: repository);

    expect(state.weights, isEmpty);
    expect(state.meals, isEmpty);
    expect(state.sessions, isEmpty);

    state.dispose();
    repository.dispose();
  });

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

    test('calculates the average weight', () {
      final s = AppState();
      expect(s.sevenDayAverage, greaterThan(0));
    });

    test('converts between kg and the display unit both ways', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      // Let the saved settings load first, or the load lands after the toggle
      // below and quietly undoes it.
      await pumpEventQueue();
      expect(s.displayWeight(80), 80);
      expect(s.weightToKg(80), 80);

      await s.setUseMetricUnits(false);
      expect(s.weightUnitLabel, 'lb');
      expect(s.displayWeight(80), closeTo(176.37, 0.01));
      expect(s.weightToKg(s.displayWeight(80)), closeTo(80, 1e-9));
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

    test('custom meals are added to the selected day', () {
      final s = AppState();
      s.shiftNutritionDate(1);
      expect(s.meals, isEmpty);

      s.addMeal(Meal(
        name: 'Post sparring',
        items: 'Rice bowl',
        calories: 720,
        protein: 45,
        carbs: 90,
        fats: 14,
        eaten: true,
      ));

      expect(s.meals.single.name, 'Post sparring');
      expect(s.consumedCalories, 720);
    });
  });

  group('AppState — sessions', () {
    test('logging a session stores completion metadata and history', () {
      final s = AppState();
      final session = s.sessions.firstWhere((item) => !item.completed);

      s.completeSession(session, rpe: 9, note: 'Hard rounds');

      final logged = s.sessions.firstWhere((item) => item.id == session.id);
      expect(logged.completed, isTrue);
      expect(logged.completedAt, isNotNull);
      expect(logged.rpe, 9);
      expect(logged.note, 'Hard rounds');
      expect(s.completedSessionsDesc.first.id, session.id);
    });
  });
}
