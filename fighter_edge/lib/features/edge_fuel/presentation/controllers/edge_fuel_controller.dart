import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/data_repository.dart';
import '../../../../observability/telemetry.dart';
import '../../data/edge_fuel_repository.dart';
import '../../domain/models/food_log_entry.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_target.dart';
import 'food_memory.dart';

/// Read-side access to a user's EdgeFuel profile/target, for screens outside
/// the setup wizard (the Plan screen now; Today/Insights in later sprints).
/// Mirrors `AppState.setUser`'s stream-subscription lifecycle so the two
/// controllers behave the same way when auth state changes.
class EdgeFuelController extends ChangeNotifier {
  EdgeFuelController({
    required EdgeFuelRepository repository,
    Telemetry telemetry = const NoopTelemetry(),
  })  : _repository = repository,
        _telemetry = telemetry;

  final EdgeFuelRepository _repository;
  final Telemetry _telemetry;
  StreamSubscription<NutritionSetupDraft?>? _draftSub;
  StreamSubscription<NutritionTarget?>? _targetSub;
  StreamSubscription<NutritionDay>? _daySub;
  String? _userId;
  NutritionSetupDraft? _draft;
  NutritionTarget? _target;
  NutritionDay? _day;
  DateTime _selectedDate = DateTime.now();
  FoodMemory? _memory;
  bool _disposed = false;

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

  /// Distinct foods logged most recently, across days — newest first.
  List<FoodLogEntry> get recentFoods => _memory?.recent ?? const [];

  /// Foods the athlete starred, across days.
  List<FoodLogEntry> get savedFoods => _memory?.saved ?? const [];

  bool isSavedFood(FoodLogEntry entry) => _memory?.isSaved(entry) ?? false;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _draftSub?.cancel();
    _targetSub?.cancel();
    _daySub?.cancel();
    _draft = null;
    _target = null;
    _day = null;
    _memory = null;

    if (userId == null) {
      notifyListeners();
      return;
    }

    final memory = FoodMemory(userId);
    memory.load().then((_) {
      // Ignore a load that finishes after the account changed or the
      // controller went away.
      if (_disposed || _userId != userId) return;
      _memory = memory;
      notifyListeners();
    });

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
    final firstToday = day.entries.isEmpty;
    await _saveDay(
      day.copyWith(entries: [...day.entries, entry], updatedAt: DateTime.now()),
    );
    _memory?.remember(entry);
    // Every way of logging food (quick add, search, a recipe) lands here, so
    // this is the one place the habit is counted. Only a 0/1 flag leaves the
    // device, and only after storage reports success.
    _telemetry.track(
      TelemetryEvent.mealLogged,
      parameters: {'first_today': firstToday ? 1 : 0},
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

  /// This calendar week's days, Monday through [now]'s date, oldest first.
  /// Days with nothing stored come back empty rather than missing, so the
  /// caller always gets one entry per elapsed day.
  Future<List<NutritionDay>> loadThisWeek({DateTime? now}) async {
    final userId = _userId;
    if (userId == null) return const [];
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final days = <NutritionDay>[];
    for (var i = today.weekday - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
      final loaded = _day;
      if (loaded != null && loaded.localDate == mealDateKey(date)) {
        days.add(loaded);
        continue;
      }
      days.add(await _repository
          .watchNutritionDay(userId, date,
              targetSnapshot: hasUsableTarget ? _target : null)
          .first);
    }
    return days;
  }

  /// Logs a remembered food again, as a fresh entry on the selected day.
  Future<FoodLogEntry> logAgain(FoodLogEntry template) async {
    final entry = template.copyWith(
      id: _manualId(),
      source: isSavedFood(template)
          ? FoodLogSource.savedMeal
          : FoodLogSource.recent,
      consumed: true,
      saved: isSavedFood(template),
      loggedAt: DateTime.now(),
    );
    await addEntry(entry);
    return entry;
  }

  /// Stars or un-stars a food everywhere: in the cross-day memory, and on
  /// any of today's entries with the same name so the star reads the same.
  Future<void> toggleSavedFood(FoodLogEntry entry) async {
    final memory = _memory;
    if (memory == null) return;
    final saved = memory.toggleSaved(entry);
    final key = FoodMemory.keyOf(entry);
    final day = _activeDay();
    if (!day.entries.any((e) => FoodMemory.keyOf(e) == key)) {
      notifyListeners();
      return;
    }
    await _saveDay(
      day.copyWith(
        entries: [
          for (final e in day.entries)
            if (FoodMemory.keyOf(e) == key) e.copyWith(saved: saved) else e,
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
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
