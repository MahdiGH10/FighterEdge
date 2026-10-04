import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/models/weight_entry.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_harness.dart';

const _notSaved = "Some changes weren't saved to your account.";

/// Stands in for a server that refuses writes (rules, quota), then recovers.
class _RefusingDataRepository extends InMemoryDataRepository {
  bool refuse = true;

  @override
  Future<void> addWeight(String userId, WeightEntry entry) async {
    if (refuse) throw StateError('permission-denied');
    return super.addWeight(userId, entry);
  }
}

class _RefusingFuelRepository extends InMemoryEdgeFuelRepository {
  bool refuse = true;

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) async {
    if (refuse) throw StateError('permission-denied');
    return super.saveNutritionDay(userId, day);
  }
}

void main() {
  testWidgets('Home says a refused save was not stored, and Retry clears it',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final sync = SyncTracker();
    final data = _RefusingDataRepository();
    final state = AppState(dataRepository: data, sync: sync)..setUser('u1');

    await tester.pumpWidget(wrapApp(DashboardScreen(onNavigate: (_) {}),
        repo: repo, state: state, sync: sync));
    await tester.pumpAndSettle();
    expect(find.text(_notSaved), findsNothing);

    state.addWeight(DateTime(2026, 10, 4), 78.5);
    await tester.pumpAndSettle();
    expect(find.text(_notSaved), findsOneWidget);

    data.refuse = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_notSaved), findsNothing);
  });

  testWidgets('Fuel shows the same notice when a meal is refused',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final sync = SyncTracker();
    final fuelRepo = _RefusingFuelRepository();

    await tester.pumpWidget(wrapApp(const NutritionScreen(),
        repo: repo, edgeFuelRepo: fuelRepo, sync: sync));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NutritionScreen));
    await context.read<EdgeFuelController>().addEntry(FoodLogEntry(
          id: 'oats',
          name: 'Oats',
          notes: '',
          calories: 300,
          proteinGrams: 10,
          carbGrams: 50,
          fatGrams: 6,
          loggedAt: DateTime(2026, 10, 4, 8),
        ));
    await tester.pumpAndSettle();
    expect(find.text(_notSaved), findsOneWidget);

    fuelRepo.refuse = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_notSaved), findsNothing);
  });
}
