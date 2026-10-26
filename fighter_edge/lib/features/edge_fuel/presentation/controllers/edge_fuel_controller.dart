import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/data_repository.dart';
import '../../../../data/read_state.dart';
import '../../../../observability/error_reporter.dart';
import '../../../../observability/telemetry.dart';
import '../../data/edge_fuel_repository.dart';
import '../../domain/models/food_log_entry.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_enums.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_target.dart';
import '../../../../state/sync_tracker.dart';
import 'food_memory.dart';

/// Read-side access to a user's EdgeFuel profile/target, for screens outside
/// the setup wizard (the Plan screen now; Today/Insights in later sprints).
/// Mirrors `AppState.setUser`'s stream-subscription lifecycle so the two
/// controllers behave the same way when auth state changes.
class EdgeFuelController extends ChangeNotifier {
  EdgeFuelController({
    required EdgeFuelRepository repository,
    Telemetry telemetry = const NoopTelemetry(),
    ErrorReporter errorReporter = const NoopErrorReporter(),
    SyncTracker? sync,
  })  : _repository = repository,
        _telemetry = telemetry,
        _errorReporter = errorReporter,
        _sync = sync;

  final EdgeFuelRepository _repository;
  final Telemetry _telemetry;
  final ErrorReporter _errorReporter;

  /// Shared "not saved" state behind the notice on Home and Fuel. Optional
  /// so the controller still works on its own in tests.
  final SyncTracker? _sync;
  bool _lastSaveFailed = false;
  final Map<String, _FoodMutation> _unconfirmed = {};
  final Map<String, int> _writeVersions = {};
  final Set<String> _failedKeys = {};

  /// True when the most recent change could not be stored. Any later
  /// successful save clears it. The change stays on screen either way.
  bool get lastSaveFailed => _lastSaveFailed;
  StreamSubscription<ReadState<NutritionSetupDraft?>>? _draftSub;
  StreamSubscription<ReadState<NutritionTarget?>>? _targetSub;
  StreamSubscription<ReadState<NutritionDay>>? _daySub;
  String? _userId;
  NutritionSetupDraft? _draft;
  NutritionTarget? _target;
  NutritionDay? _day;
  DateTime _selectedDate = DateTime.now();
  FoodMemory? _memory;
  bool _disposed = false;
  ReadState<NutritionSetupDraft?> _draftRead = const ReadState(ReadPhase.empty);
  ReadState<NutritionTarget?> _targetRead = const ReadState(ReadPhase.empty);
  ReadState<NutritionDay> _dayRead = const ReadState(ReadPhase.empty);

  ReadState<NutritionSetupDraft?> get draftRead => _draftRead;
  ReadState<NutritionTarget?> get targetRead => _targetRead;
  ReadState<NutritionDay> get dayRead => _dayRead;
  bool get readsLoading =>
      _draftRead.isLoading || _targetRead.isLoading || _dayRead.isLoading;
  bool get readsUnavailable =>
      _draftRead.isFailed ||
      _targetRead.isFailed ||
      _dayRead.isFailed ||
      _draftRead.isStale ||
      _targetRead.isStale ||
      _dayRead.isStale;

  NutritionSetupDraft? get draft => _draft;
  NutritionTarget? get target => hasCompletedSetup ? _target : null;
  NutritionDay? get day => _day;
  bool get dayLoaded => _day != null && _dayRead.isUsable;
  bool get hasCompletedSetup =>
      _draft?.confirmed == true &&
      _draft?.screeningStatus == NutritionScreeningStatus.completed &&
      _draft?.safetyFlags.any == false;
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
    _draftRead =
        ReadState(userId == null ? ReadPhase.empty : ReadPhase.loading);
    _targetRead =
        ReadState(userId == null ? ReadPhase.empty : ReadPhase.loading);
    _dayRead = ReadState(userId == null ? ReadPhase.empty : ReadPhase.loading);
    _memory = null;
    _unconfirmed.clear();
    _writeVersions.clear();
    _failedKeys.clear();
    _lastSaveFailed = false;

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

    _subscribeReads(userId);
  }

  /// Re-subscribes after a failed or stale read. A new first snapshot must
  /// arrive before Fuel offers entry actions again.
  void retryReads() {
    final userId = _userId;
    if (userId == null) return;
    _draftSub?.cancel();
    _targetSub?.cancel();
    _daySub?.cancel();
    _draft = null;
    _target = null;
    _day = null;
    _draftRead = const ReadState(ReadPhase.loading);
    _targetRead = const ReadState(ReadPhase.loading);
    _dayRead = const ReadState(ReadPhase.loading);
    notifyListeners();
    _subscribeReads(userId);
  }

  void _subscribeReads(String userId) {
    _draftSub = _repository.watchProfileDraftRead(userId).listen((read) {
      if (_disposed || _userId != userId) return;
      _draftRead = read;
      if (read.isUsable) _draft = read.value;
      notifyListeners();
    });
    _targetSub = _repository.watchTargetRead(userId).listen((read) {
      if (_disposed || _userId != userId) return;
      _targetRead = read;
      if (read.isUsable) {
        _target = read.value;
        _watchSelectedDay();
      }
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

  /// Resets the selected day back to today, if it was moved. Home reads
  /// [isToday]/[day] for the Corner Brief, so leaving Fuel on a past or
  /// future day must not leave Home showing that day too.
  void showToday() {
    if (isToday) return;
    _selectedDate = DateTime.now();
    _day = null;
    _watchSelectedDay();
    notifyListeners();
  }

  /// Applies the entry at once. The returned future completes only when
  /// storage confirms the write, which Firestore never does while offline,
  /// so UI flows should not wait on it (audit A-4). It never throws: a
  /// failed write is reported and surfaces as [lastSaveFailed].
  Future<void> addEntry(FoodLogEntry entry) async {
    final day = _day;
    if (day == null || _userId == null || !writeGate()) return;
    final firstToday = day.entries.isEmpty;
    final saved = await _applyMutation(_FoodMutation(
      userId: _userId!,
      localDate: day.localDate,
      entryId: entry.id,
      entry: entry,
    ));
    if (!saved) return;
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
    final day = _day;
    if (day == null || _userId == null || !writeGate()) return;
    if (!day.entries.any((existing) => existing.id == entry.id)) return;
    await _applyMutation(_FoodMutation(
      userId: _userId!,
      localDate: day.localDate,
      entryId: entry.id,
      entry: entry,
    ));
  }

  Future<void> toggleEntry(FoodLogEntry entry) {
    return updateEntry(entry.copyWith(consumed: !entry.consumed));
  }

  Future<void> deleteEntry(FoodLogEntry entry) async {
    final day = _day;
    if (day == null || _userId == null || !writeGate()) return;
    if (!day.entries.any((existing) => existing.id == entry.id)) return;
    await _applyMutation(_FoodMutation(
      userId: _userId!,
      localDate: day.localDate,
      entryId: entry.id,
    ));
  }

  /// This calendar week's days, Monday through [now]'s date, oldest first.
  /// Days with nothing stored come back empty rather than missing, so the
  /// caller always gets one entry per elapsed day.
  Future<List<NutritionDay>> loadThisWeek({DateTime? now}) async {
    final userId = _userId;
    if (userId == null) return const [];
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final dates = [
      for (var i = today.weekday - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    return Future.wait(dates.map((date) async {
      final loaded = _day;
      if (dayLoaded &&
          loaded != null &&
          loaded.localDate == mealDateKey(date)) {
        return loaded;
      }
      return _repository
          .watchNutritionDay(userId, date,
              targetSnapshot: hasUsableTarget ? _target : null)
          .first
          .timeout(const Duration(seconds: 10));
    }));
  }

  /// Logs a remembered food again, as a fresh entry on the selected day.
  Future<FoodLogEntry> logAgain(FoodLogEntry template) async {
    final entry = entryForLogAgain(template);
    await addEntry(entry);
    return entry;
  }

  /// The fresh entry [logAgain] would add, without adding it. UI flows use
  /// this to add in the background and move on without waiting on storage.
  FoodLogEntry entryForLogAgain(FoodLogEntry template) {
    return template.copyWith(
      id: _manualId(),
      source: isSavedFood(template)
          ? FoodLogSource.savedMeal
          : FoodLogSource.recent,
      consumed: true,
      saved: isSavedFood(template),
      loggedAt: DateTime.now(),
    );
  }

  /// Stars or un-stars a food everywhere: in the cross-day memory, and on
  /// any of today's entries with the same name so the star reads the same.
  Future<void> toggleSavedFood(FoodLogEntry entry) async {
    final memory = _memory;
    final day = _day;
    if (memory == null || day == null || !writeGate()) return;
    final saved = memory.toggleSaved(entry);
    final key = FoodMemory.keyOf(entry);
    notifyListeners();
    await Future.wait([
      for (final e in day.entries)
        if (FoodMemory.keyOf(e) == key) updateEntry(e.copyWith(saved: saved)),
    ]);
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
    _day = null;
    _dayRead = const ReadState(ReadPhase.loading);
    final dateKey = mealDateKey(_selectedDate);
    _daySub = _repository
        .watchNutritionDayRead(
      userId,
      _selectedDate,
      targetSnapshot: hasUsableTarget ? _target : null,
    )
        .listen(
      (read) {
        if (_disposed ||
            _userId != userId ||
            mealDateKey(_selectedDate) != dateKey) {
          return;
        }
        _dayRead = read;
        if (read.isUsable) {
          var visible = read.value!;
          for (final mutation in _unconfirmed.values) {
            if (mutation.userId == userId && mutation.localDate == dateKey) {
              visible = _withMutation(visible, mutation);
            }
          }
          _day = visible;
        }
        notifyListeners();
      },
    );
  }

  /// Shows [day] immediately, then stores it. Returns whether storage
  /// confirmed the write. Never throws: callers include fire-and-forget
  /// taps, where an escaped error would become an uncaught crash report.
  /// Asked before any food-log write; the app points it at
  /// `AppState.requireWrite` so a read-only account cannot log food.
  bool Function() writeGate = _openGate;

  static bool _openGate() => true;

  Future<bool> _applyMutation(_FoodMutation mutation) async {
    if (_userId != mutation.userId || !writeGate()) return false;
    final day = _day;
    if (day == null || day.localDate != mutation.localDate) return false;
    _day = _withMutation(day, mutation);
    _unconfirmed[mutation.key] = mutation;
    notifyListeners();
    return _writeMutation(mutation);
  }

  NutritionDay _withMutation(NutritionDay day, _FoodMutation mutation) =>
      day.copyWith(
        entries: [
          for (final entry in day.entries)
            if (entry.id != mutation.entryId) entry,
          if (mutation.entry != null) mutation.entry!,
        ],
        updatedAt: DateTime.now(),
      );

  Future<bool> _writeMutation(_FoodMutation mutation) async {
    if (_disposed || _userId != mutation.userId) return true;
    final key = mutation.key;
    final version = (_writeVersions[key] ?? 0) + 1;
    _writeVersions[key] = version;
    try {
      if (mutation.entry == null) {
        await _repository.deleteFoodEntry(
          mutation.userId,
          mutation.localDate,
          mutation.entryId,
        );
      } else {
        await _repository.upsertFoodEntry(
          mutation.userId,
          mutation.localDate,
          mutation.entry!,
        );
      }
      if (!_disposed &&
          _userId == mutation.userId &&
          _writeVersions[key] == version) {
        _unconfirmed.remove(key);
        _failedKeys.remove(key);
        _lastSaveFailed = _failedKeys.isNotEmpty;
        _sync?.markSaved(key);
        notifyListeners();
      }
      return true;
    } catch (error, stack) {
      _errorReporter.report(error, stack, reason: 'nutrition_day_save_failed');
      if (!_disposed &&
          _userId == mutation.userId &&
          _writeVersions[key] == version) {
        _failedKeys.add(key);
        _lastSaveFailed = true;
        // This closure keeps the account, date and exact entry operation.
        // A newer edit of this entry replaces it under the same key.
        _sync?.markFailed(key, () => _writeMutation(mutation));
        notifyListeners();
      }
      return false;
    }
  }

  String _manualId() => 'food-${DateTime.now().microsecondsSinceEpoch}';
}

class _FoodMutation {
  const _FoodMutation({
    required this.userId,
    required this.localDate,
    required this.entryId,
    this.entry,
  });

  final String userId;
  final String localDate;
  final String entryId;
  final FoodLogEntry? entry;

  String get key => 'nutrition-day:$userId:$localDate:$entryId';
}
