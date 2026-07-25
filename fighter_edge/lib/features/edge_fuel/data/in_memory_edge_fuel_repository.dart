import 'dart:async';

import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_target.dart';
import 'edge_fuel_repository.dart';

/// In-process fake used for tests and as the offline/unauthenticated
/// fallback. No disk or network I/O — state lives only as long as the
/// instance does.
class InMemoryEdgeFuelRepository implements EdgeFuelRepository {
  final Map<String, NutritionSetupDraft> _drafts = {};
  final Map<String, NutritionTarget> _targets = {};
  final Map<String, StreamController<NutritionSetupDraft?>> _draftControllers =
      {};
  final Map<String, StreamController<NutritionTarget?>> _targetControllers =
      {};

  @override
  Stream<NutritionSetupDraft?> watchProfileDraft(String userId) {
    final controller = _draftControllers.putIfAbsent(
      userId,
      () => StreamController<NutritionSetupDraft?>.broadcast(
        onListen: () {},
      ),
    );
    scheduleMicrotask(() => controller.add(_drafts[userId]));
    return controller.stream;
  }

  @override
  Future<void> saveProfileDraft(String userId, NutritionSetupDraft draft) async {
    _drafts[userId] = draft;
    _draftControllers[userId]?.add(draft);
  }

  @override
  Stream<NutritionTarget?> watchTarget(String userId) {
    final controller = _targetControllers.putIfAbsent(
      userId,
      () => StreamController<NutritionTarget?>.broadcast(onListen: () {}),
    );
    scheduleMicrotask(() => controller.add(_targets[userId]));
    return controller.stream;
  }

  @override
  Future<void> saveTarget(String userId, NutritionTarget target) async {
    _targets[userId] = target;
    _targetControllers[userId]?.add(target);
  }
}
