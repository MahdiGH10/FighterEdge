import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/weight_entry.dart';
import '../../../observability/error_reporter.dart';
import '../data/fight_camp_repository.dart';
import '../domain/fight_camp.dart';
import '../domain/camp_screening.dart';
import '../domain/weight_path.dart';
import '../domain/weight_trend.dart';

/// The signed-in athlete's next fight, kept in sync with the repository.
///
/// Writes are optimistic: the screen updates at once and the write goes out
/// behind it, like every other log in the app. No UI waits on a Firestore
/// acknowledgement, so a save made offline never hangs.
class FightCampController extends ChangeNotifier {
  FightCampController({
    required FightCampRepository repository,
    ErrorReporter errorReporter = const NoopErrorReporter(),
    bool? refuelGuidance,
  })  : _repository = repository,
        _errorReporter = errorReporter,
        refuelGuidance =
            refuelGuidance ?? const bool.fromEnvironment('FIGHT_WEEK_REFUEL');

  final FightCampRepository _repository;
  final ErrorReporter _errorReporter;

  /// Whether fight week shows refuel steps and targets (and the AI coach is
  /// told about them). Off unless a build sets
  /// `--dart-define=FIGHT_WEEK_REFUEL=true`: the refuel numbers have not been
  /// reviewed by a qualified sports dietitian yet (launch audit SAFE-2/3), so
  /// no build that reaches testers shows them. Every surface reads this one
  /// value, so the screens and the AI never disagree.
  final bool refuelGuidance;
  StreamSubscription<FightCamp?>? _sub;
  String? _userId;
  FightCamp? _camp;
  bool _loaded = false;
  bool _disposed = false;

  FightCamp? get camp => _camp;

  /// False until the first snapshot for the current account arrives.
  bool get loaded => _loaded;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _camp = null;
    _loaded = false;
    if (userId == null) {
      notifyListeners();
      return;
    }
    _sub = _repository.watchFight(userId).listen(
      (camp) {
        _camp = camp;
        _loaded = true;
        notifyListeners();
      },
      onError: (Object error) {
        // Keep whatever is on screen; Firestore retries the listener itself.
        if (kDebugMode) debugPrint('[fight_camp] fight stream error: $error');
      },
    );
    notifyListeners();
  }

  void save(FightCamp camp) {
    final userId = _userId;
    if (userId == null) return;
    _camp = camp;
    notifyListeners();
    _write(() => _repository.saveFight(userId, camp), 'fight_save_failed');
  }

  void clear() {
    final userId = _userId;
    if (userId == null) return;
    _camp = null;
    notifyListeners();
    _write(() => _repository.deleteFight(userId), 'fight_delete_failed');
  }

  void _write(Future<void> Function() write, String reason) {
    unawaited(Future.sync(write).catchError((Object error, StackTrace stack) {
      _errorReporter.report(error, stack, reason: reason);
    }));
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// Everything a fight-camp surface shows for [camp] on [today].
class FightCampStatus {
  const FightCampStatus._({
    required this.camp,
    required this.phase,
    required this.daysToFight,
    required this.daysToWeighIn,
    required this.trend,
    required this.path,
  });

  final FightCamp camp;
  final CampPhase phase;
  final int daysToFight;
  final int daysToWeighIn;
  final WeightTrend trend;
  final WeightPath path;

  factory FightCampStatus.of(
    FightCamp camp, {
    required List<WeightEntry> weights,
    required DateTime today,
    int? ageYears,
    CampScreening screening = CampScreening.pending,
  }) {
    final trend = WeightTrend.from(
      [for (final w in weights) WeightPoint(w.date, w.kg)],
      today: today,
    );
    return FightCampStatus._(
      camp: camp,
      phase: camp.phaseOn(today),
      daysToFight: camp.daysToFight(today),
      daysToWeighIn: camp.daysToWeighIn(today),
      trend: trend,
      path: WeightPathCalculator.calculate(
        currentWeightKg: trend.trendKg,
        camp: camp,
        today: today,
        ageYears: ageYears,
        screening: screening,
      ),
    );
  }
}
