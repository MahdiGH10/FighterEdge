import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/data_repository.dart';
import '../../data/edge_fuel_repository.dart';
import '../../domain/models/food_log_entry.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_day.dart';
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
  StreamSubscription<NutritionDay>? _daySub;
  String? _userId;
  NutritionSetupDraft? _draft;
  NutritionTarget? _target;
  NutritionDay? _day;
  DateTime _selectedDate = DateTime.now();

  NutritionSetupDraft? get draft => _draft;
  NutritionTarget? get target => _target;
  NutritionDay? get day => _day;
  bool get hasCompletedSetup => _draft?.confirmed == true;
  DateTime get selectedDate => _selectedDate;
  bool get isToday => mealDateKey(_selectedDate) == mealDateKey(DateTime.now());
  List<FoodLogEntry> get entries =>
      List.unmodifiable(_day?.entries ?? const []);
  int get consumedCalories => _day?.totals.calories ?? 0;
  int get consumedProtein => _day?.totals.proteinGrams ?? 0;
  int get consumedCarbs => _day?.totals.carbGrams ?? 0;
  int get consumedFats => _day?.totals.fatGrams ?? 0;
  int get targetCalories => target?.targetCalories ?? 0;
  int get targetProtein => target?.proteinGrams ?? 0;
  int get targetCarbs => target?.carbGrams ?? 0;
  int get targetFats => target?.fatGrams ?? 0;
  bool get hasUsableTarget => target?.isSuccess == true;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _draftSub?.cancel();
    _targetSub?.cancel();
    _daySub?.cancel();
    _draft = null;
    _target = null;
    _day = null;

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
      _watchSelectedDay();
      notifyListeners();
    });
    _watchSelectedDay();
  }

  void shiftDate(int days) {
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).add(Duration(days: days));
    _day = null;
    _watchSelectedDay();
    notifyListeners();
  }

  Future<void> addEntry(FoodLogEntry entry) async {
    final day = _activeDay();
    await _saveDay(
      day.copyWith(entries: [...day.entries, entry], updatedAt: DateTime.now()),
    );
  }

  Future<void> updateEntry(FoodLogEntry entry) async {
    final day = _activeDay();
    await _saveDay(
      day.copyWith(
        entries: [
          for (final existing in day.entries)
            if (existing.id == entry.id) entry else existing,
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleEntry(FoodLogEntry entry) {
    return updateEntry(entry.copyWith(consumed: !entry.consumed));
  }

  Future<void> deleteEntry(FoodLogEntry entry) async {
    final day = _activeDay();
    await _saveDay(
      day.copyWith(
        entries: [
          for (final existing in day.entries)
            if (existing.id != entry.id) existing,
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  List<FoodLogEntry> recentEntries({int limit = 5}) {
    final seen = <String>{};
    final recent = <FoodLogEntry>[];
    for (final entry in entries.reversed) {
      final key = entry.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      recent.add(entry.copyWith(
        id: _manualId(),
        source: FoodLogSource.recent,
        loggedAt: DateTime.now(),
        consumed: true,
      ));
      if (recent.length == limit) break;
    }
    return recent;
  }

  @override
  void dispose() {
    _draftSub?.cancel();
    _targetSub?.cancel();
    _daySub?.cancel();
    super.dispose();
  }

  void _watchSelectedDay() {
    final userId = _userId;
    if (userId == null) return;
    _daySub?.cancel();
    _daySub = _repository
        .watchNutritionDay(
      userId,
      _selectedDate,
      targetSnapshot: hasUsableTarget ? _target : null,
    )
        .listen((day) {
      _day = day;
      notifyListeners();
    });
  }

  NutritionDay _activeDay() {
    return _day ??
        NutritionDay.empty(
          localDate: mealDateKey(_selectedDate),
          timeZone: _selectedDate.timeZoneName,
          now: DateTime.now(),
          targetSnapshot: hasUsableTarget ? _target : null,
        );
  }

  Future<void> _saveDay(NutritionDay day) async {
    final userId = _userId;
    if (userId == null) return;
    _day = day;
    notifyListeners();
    await _repository.saveNutritionDay(userId, day);
  }

  String _manualId() => 'food-${DateTime.now().microsecondsSinceEpoch}';
}
