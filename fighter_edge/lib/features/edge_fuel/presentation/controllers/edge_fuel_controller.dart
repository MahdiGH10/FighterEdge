import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/edge_fuel_repository.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';

/// Read-side access to a user's EdgeFuel profile/target, for screens outside
/// the setup wizard (the Plan screen now; Today/Insights in later sprints).
/// Mirrors `AppState.setUser`'s stream-subscription lifecycle so the two
/// controllers behave the same way when auth state changes.
class EdgeFuelController extends ChangeNotifier {
  EdgeFuelController({required EdgeFuelRepository repository})
      : _repository = repository;

  final EdgeFuelRepository _repository;
  StreamSubscription<NutritionSetupDraft?>? _draftSub;
  StreamSubscription<NutritionTarget?>? _targetSub;
  String? _userId;
  NutritionSetupDraft? _draft;
  NutritionTarget? _target;

  NutritionSetupDraft? get draft => _draft;
  NutritionTarget? get target => _target;
  bool get hasCompletedSetup => _draft?.confirmed == true;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _draftSub?.cancel();
    _targetSub?.cancel();
    _draft = null;
    _target = null;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _draftSub = _repository.watchProfileDraft(userId).listen((draft) {
      _draft = draft;
      notifyListeners();
    });
    _targetSub = _repository.watchTarget(userId).listen((target) {
      _target = target;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _draftSub?.cancel();
    _targetSub?.cancel();
    super.dispose();
  }
}
