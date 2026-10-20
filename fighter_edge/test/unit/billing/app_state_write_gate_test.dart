import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/meal.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppState _state(AccessState access, {void Function()? onBlocked}) {
  SharedPreferences.setMockInitialValues({});
  final state = AppState()
    ..accessSource = (() => access)
    ..onWriteBlocked = onBlocked;
  addTearDown(state.dispose);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const readOnly = AccessState.readOnly();
  final trial = AccessState.trial(DateTime.now().add(const Duration(days: 3)));

  group('requireWrite', () {
    test('is open until the app supplies an access state', () {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      addTearDown(state.dispose);
      expect(state.requireWrite(), isTrue);
    });

    test('allows trial, active and unconfirmed-unknown accounts', () {
      for (final access in [
        trial,
        const AccessState.active(),
        const AccessState.unknown(),
        const AccessState.unknown(lastKnown: AccessState.active()),
      ]) {
        expect(_state(access).requireWrite(), isTrue, reason: '$access');
      }
    });

    test('refuses a read-only account and says so once per attempt', () {
      var blocked = 0;
      final state = _state(readOnly, onBlocked: () => blocked++);
      expect(state.requireWrite(), isFalse);
      expect(state.requireWrite(), isFalse);
      expect(blocked, 2);
    });

    test('reads the access source fresh each time', () {
      var access = const AccessState.active();
      SharedPreferences.setMockInitialValues({});
      final state = AppState()..accessSource = (() => access);
      addTearDown(state.dispose);
      expect(state.canWrite, isTrue);
      access = const AccessState.readOnly();
      expect(state.canWrite, isFalse);
    });
  });

  group('a read-only account cannot save new data', () {
    test('weight, meals and training are refused; nothing changes', () {
      var blocked = 0;
      final state = _state(readOnly, onBlocked: () => blocked++);
      final weights = state.weights.length;
      final meals = state.meals.length;
      final log = state.trainingLog.length;
      final firstMeal = state.meals.first;
      final eaten = firstMeal.eaten;
      final firstSession = state.sessions.first;
      final wasDone = firstSession.completed;

      state.addWeight(DateTime(2026, 10, 20), 70);
      state.toggleMeal(firstMeal);
      state.addMeal(Meal(
        id: 'm-new',
        name: 'Rice',
        items: 'Rice',
        calories: 300,
        protein: 5,
        carbs: 60,
        fats: 1,
        eaten: true,
      ));
      state.toggleSession(firstSession);
      state.completeSession(firstSession);
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'manual-1',
        completedAt: DateTime(2026, 10, 20, 18),
        source: TrainingSource.manual,
        title: 'Run',
      ));

      expect(blocked, 6);
      expect(state.weights.length, weights);
      expect(state.meals.length, meals);
      expect(state.meals.first.eaten, eaten);
      expect(state.trainingLog.length, log);
      expect(state.sessions.first.completed, wasDone);
    });

    test('the same calls work in a trial', () {
      final state = _state(trial);
      final weights = state.weights.length;
      final log = state.trainingLog.length;

      state.addWeight(DateTime(2026, 10, 20), 70);
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'manual-1',
        completedAt: DateTime(2026, 10, 20, 18),
        source: TrainingSource.manual,
        title: 'Run',
      ));

      expect(state.weights.length, weights + 1);
      expect(state.trainingLog.length, log + 1);
    });

    test('views, units and onboarding stay available', () async {
      final state = _state(readOnly);
      // Reading history, plan and weights.
      expect(state.weights, isNotEmpty);
      expect(state.weightHistoryDesc, isNotEmpty);
      expect(state.sessions, isNotEmpty);
      expect(state.completedSessionsDesc, isA<List<TrainingSession>>());
      expect(state.trainingLog, isA<List<TrainingLogEntry>>());
      expect(state.meals, isNotNull);
      // Settings are local preferences, not athlete data.
      await state.setUseMetricUnits(false);
      expect(state.useMetricUnits, isFalse);
      // Onboarding happens before the paywall.
      await state.startFreshCamp(startingWeightKg: 70, weeklyTrainingDays: 4);
      expect(state.latestWeight, 70);
    });
  });
}
