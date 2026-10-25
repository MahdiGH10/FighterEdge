import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/data_repository.dart';
import '../../../models/training_log_entry.dart';
import '../../../state/app_state.dart';
import '../../../state/sync_tracker.dart';
import '../../fight_camp/domain/calendar.dart';
import '../../fight_camp/domain/fight_camp.dart';
import '../data/legacy_plan_migration.dart';
import '../data/onboarding_plan.dart';
import '../data/stored_training_plan.dart';
import '../../weekly_review/domain/weekly_review.dart';
import '../domain/consistency/weekly_adherence.dart';
import '../domain/consistency/weekly_streak.dart';
import '../domain/models/date_key.dart';
import '../domain/models/fight_context.dart';
import '../domain/models/plan_inputs.dart';
import '../domain/models/planned_session.dart';
import '../domain/models/planned_week.dart';
import '../domain/models/session_status.dart';
import '../domain/session_status_resolver.dart';
import '../domain/templates/generic_template_set.dart';
import '../domain/models/session_template.dart';
import '../domain/training_plan_generator.dart';

/// One calendar day of the week as the screens show it.
class PlanDayView {
  const PlanDayView({
    required this.date,
    required this.rows,
    required this.emptyStatus,
  });

  final DateTime date;

  /// Every session shown on [date], including the original-date row of a
  /// session that was moved away. Empty on a rest day.
  final List<ResolvedSession> rows;

  /// What a day without a session is: [SessionStatus.rest], or
  /// [SessionStatus.beforeStart] before the plan began. Neither ever counts
  /// against the athlete.
  final SessionStatus emptyStatus;

  bool get isRest => rows.isEmpty;
}

/// The athlete's dated training week.
///
/// It keeps the saved plan inputs in sync with the repository, generates the
/// dated weeks from them with [TrainingPlanGenerator] (nothing about a week
/// is stored, so the same inputs always give the same week after a reload),
/// resolves each session's status against the training log with
/// [SessionStatusResolver], and records done, skipped and moved.
///
/// Writes are optimistic, like every other log in the app: the screen
/// updates at once and a refused save is reported through [SyncTracker].
class PlanController extends ChangeNotifier {
  PlanController({
    required AppState log,
    DataRepository? repository,
    TemplateSet? templates,
    SyncTracker? sync,
    TrainingPlanGenerator generator = const TrainingPlanGenerator(),
    SessionStatusResolver resolver = const SessionStatusResolver(),
  })  : _log = log,
        _repository = repository,
        _templates = templates ?? GenericTemplateSet.instance,
        _sync = sync ?? SyncTracker(),
        _generator = generator,
        _resolver = resolver {
    // With no repository (demo, tests) there is nothing to wait for.
    _loaded = repository == null;
    _log.addListener(_onLogChanged);
  }

  /// A timer or free session shorter than this cannot stand in for a planned
  /// session (proposal decision 9). A Reaction drill never can.
  static const int minStandInSeconds = 20 * 60;

  /// How far back weeks are generated for the week list and the weekly
  /// consistency.
  static const int historyWeeks = 52;

  final AppState _log;
  final DataRepository? _repository;
  final TemplateSet _templates;
  final SyncTracker _sync;
  final TrainingPlanGenerator _generator;
  final SessionStatusResolver _resolver;

  StreamSubscription<StoredTrainingPlan?>? _sub;
  String? _userId;
  StoredTrainingPlan? _stored;
  bool _loaded = false;
  bool _disposed = false;
  FightCamp? _camp;
  String _profileGoal = '';
  String _profileLevel = '';
  String? _migrationTriedFor;
  int _generation = 0;

  PlanInputs? _inputs;
  String? _cacheHash;
  final Map<String, PlannedWeek> _weeks = {};
  List<ResolvedSession>? _rows;
  String? _rowsDay;

  /// Called from the provider whenever the signed-in account, the fight or
  /// the profile answers used to seed a migrated plan change.
  void configure({
    required String? userId,
    FightCamp? fight,
    String goal = '',
    String level = '',
  }) {
    _profileGoal = goal;
    _profileLevel = level;
    var changed = false;
    if (_camp != fight) {
      _camp = fight;
      _invalidate(inputs: true);
      changed = true;
    }
    if (_userId != userId) {
      _setUser(userId);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ---- Reading the plan ----

  /// False until the first snapshot for the current account arrives. With no
  /// repository (demo, tests) it is always true.
  bool get loaded => _loaded;

  bool get hasPlan => _stored != null;

  /// The saved inputs joined with the current fight, or null without a plan.
  PlanInputs? get inputs {
    final stored = _stored;
    if (stored == null) return null;
    return _inputs ??= stored.inputs.withFight(
      _camp == null ? null : FightContext(_camp!),
    );
  }

  /// Every weekday the athlete trains, for reminders.
  Set<int> get trainingWeekdays =>
      _stored?.inputs.trainingWeekdays ?? const <int>{};

  /// Today's calendar day, from the app clock.
  DateTime get today => calendarDay(_log.now);

  /// The Monday of this week.
  DateTime get thisWeekStart => weekStart(today);

  /// The generated week containing [date], or null without a plan.
  PlannedWeek? weekContaining(DateTime date) {
    final inputs = this.inputs;
    if (inputs == null) return null;
    return _weekAt(inputs, weekStart(date));
  }

  PlannedWeek? get currentWeek => weekContaining(today);

  PlannedWeek _weekAt(PlanInputs inputs, DateTime start) {
    if (_cacheHash != inputs.hash) {
      _weeks.clear();
      _cacheHash = inputs.hash;
    }
    return _weeks.putIfAbsent(
      dateKey(start),
      () => _generator.week(inputs, start, _templates),
    );
  }

  /// Every session in the window (see [historyWeeks]) up to next week, with
  /// its status for today, oldest first.
  List<ResolvedSession> get rows {
    final inputs = this.inputs;
    final stored = _stored;
    if (inputs == null || stored == null) return const [];
    final todayDay = today;
    final key = dateKey(todayDay);
    final cached = _rows;
    if (cached != null && _rowsDay == key) return cached;

    final earliest = addDays(todayDay, -7 * historyWeeks);
    final first = weekStart(
      inputs.startDate.isAfter(earliest) ? inputs.startDate : earliest,
    );
    final last = addDays(weekStart(todayDay), 7);
    final weeks = <PlannedWeek>[];
    for (var start = first; !start.isAfter(last); start = addDays(start, 7)) {
      weeks.add(_weekAt(inputs, start));
    }
    final resolved = List<ResolvedSession>.unmodifiable(_resolver.resolve(
      weeks: weeks,
      today: todayDay,
      completions: _completions(),
      adjustments: stored.adjustments.values,
    ));
    _rows = resolved;
    _rowsDay = key;
    return resolved;
  }

  static final _plannedId = RegExp(r'^\d{4}-\d{2}-\d{2}\.[A-Za-z]+$');

  /// The log reduced to what the plan needs. A Reaction drill and a timer or
  /// free session under [minStandInSeconds] are left out; an entry whose
  /// `planSlotId` is not a planned-session id (an old weekday slot) counts
  /// as an unnamed record for its day.
  Iterable<CompletionRecord> _completions() sync* {
    for (final entry in _log.trainingLog) {
      if (!entry.source.countsAsTrainingDay) continue;
      final seconds = entry.durationSeconds;
      if (entry.source != TrainingSource.planned &&
          seconds != null &&
          seconds < minStandInSeconds) {
        continue;
      }
      final slot = entry.planSlotId;
      yield CompletionRecord(
        plannedSessionId:
            slot != null && _plannedId.hasMatch(slot) ? slot : null,
        date: entry.completedAt,
      );
    }
  }

  /// The seven days of the week starting [start] (default this week).
  List<PlanDayView> weekDays({DateTime? start}) {
    final first = weekStart(start ?? today);
    final week = weekContaining(first);
    if (week == null) return const [];
    final all = rows;
    return [
      for (var i = 0; i < 7; i++)
        () {
          final date = addDays(first, i);
          return PlanDayView(
            date: date,
            rows: [
              for (final row in all)
                if (daysBetween(date, row.date) == 0) row,
            ],
            emptyStatus: _resolver.emptyDayStatus(week, week.days[i]),
          );
        }(),
    ];
  }

  /// The session to do today (status [SessionStatus.today]), if any.
  ResolvedSession? get todaySession => _firstWhere(
        (r) => r.status == SessionStatus.today && r.movedTo == null,
      );

  /// Today's session whether or not it is done; null on a rest day.
  ResolvedSession? get todayRow =>
      todaySession ??
      _firstWhere(
        (r) =>
            r.status == SessionStatus.completed &&
            r.movedTo == null &&
            daysBetween(today, r.date) == 0,
      );

  /// The next session after today that is still to do, which may be next
  /// week's. Null when nothing is left.
  ResolvedSession? get nextSession => _firstWhere(
        (r) =>
            r.status == SessionStatus.planned &&
            r.movedTo == null &&
            daysBetween(today, r.date) > 0,
      );

  ResolvedSession? _firstWhere(bool Function(ResolvedSession) test) {
    for (final row in rows) {
      if (test(row)) return row;
    }
    return null;
  }

  /// Planned versus done for this week. Rest days and recovery sessions are
  /// never counted.
  WeeklyAdherence get thisWeek => WeeklyAdherence.fromResolved(
        weekStart: thisWeekStart,
        resolved: rows,
        today: today,
      );

  /// Consecutive weeks that met their target, counting this one once it
  /// has. Rest days and rest-only weeks never break it, and nothing before
  /// the plan began is counted.
  WeeklyStreak get weeklyStreak {
    if (_stored == null) {
      return const WeeklyStreak(
          count: 0, currentWeekMet: false, currentWeekAlive: true);
    }
    final start = _stored!.inputs.startDate;
    final earliest = addDays(today, -7 * historyWeeks);
    final first = weekStart(start.isAfter(earliest) ? start : earliest);
    final all = rows;
    final weeks = <WeeklyAdherence>[];
    for (var ws = first; !ws.isAfter(thisWeekStart); ws = addDays(ws, 7)) {
      weeks.add(WeeklyAdherence.fromResolved(
          weekStart: ws, resolved: all, today: today));
    }
    return WeeklyStreak.of(weeks);
  }

  /// What the athlete decided at the review of the week starting
  /// [weekStart], or null when it has not been reviewed.
  ReviewDecision? reviewDecision(DateTime weekStart) =>
      _stored?.reviews[dateKey(calendarDay(weekStart))];

  /// The newest log entry that fulfils [sessionId].
  TrainingLogEntry? logEntryFor(String sessionId) {
    for (final entry in _log.trainingLog) {
      if (entry.planSlotId == sessionId) return entry;
    }
    return null;
  }

  /// A missed session can be moved to today while this week lasts and today
  /// has no session of its own.
  bool canMoveToToday(ResolvedSession row) =>
      row.status == SessionStatus.missed &&
      row.movedTo == null &&
      daysBetween(thisWeekStart, row.date) >= 0 &&
      todayRow == null;

  // ---- Changing the plan ----

  /// Makes the first plan at the end of onboarding, replacing any older one.
  void startFresh({
    required int weeklyTrainingDays,
    required String goal,
    required String level,
  }) {
    _adopt(OnboardingPlan.create(
      weeklyTrainingDays: weeklyTrainingDays,
      goal: goal,
      level: level,
      today: today,
    ));
  }

  /// Marks [session] done now, or updates the effort and note of the entry it
  /// already has. [title] is the localized name shown in History.
  void complete(
    PlannedSession session, {
    required String title,
    int rpe = 7,
    String note = '',
  }) {
    final existing = logEntryFor(session.id);
    final cleanNote = note.trim();
    final now = _log.now;
    _log.addTrainingLogEntry(
      existing?.copyWith(rpe: rpe.clamp(1, 10), note: cleanNote) ??
          TrainingLogEntry(
            id: TrainingLogEntry.plannedId(session.id, now),
            completedAt: now,
            source: TrainingSource.planned,
            title: title,
            planSlotId: session.id,
            rpe: rpe.clamp(1, 10),
            note: cleanNote,
            detail: {
              'kind': session.kind.name,
              if (session.discipline != null)
                'discipline': session.discipline!.name,
            },
          ),
    );
  }

  /// Takes back a completion. The session goes back to what its date says.
  void undoComplete(PlannedSession session) {
    if (!_log.requireWrite()) return;
    final entry = logEntryFor(session.id);
    if (entry != null) _log.removeTrainingLogEntry(entry.id);
  }

  /// The athlete chose not to do [session]. Neutral, not a failure.
  void skip(PlannedSession session) {
    if (!_log.requireWrite()) return;
    _adjust(SessionAdjustment.skipped(session.id));
  }

  /// Moves [session] to [to]. Nothing moves on its own.
  void move(PlannedSession session, DateTime to) {
    if (!_log.requireWrite()) return;
    _adjust(SessionAdjustment.moved(session.id, calendarDay(to)));
  }

  /// Puts a skipped or moved session back on its planned date.
  void clearAdjustment(PlannedSession session) {
    if (!_log.requireWrite()) return;
    final stored = _stored;
    if (stored == null || !stored.adjustments.containsKey(session.id)) return;
    _adopt(stored.withoutAdjustment(session.id));
  }

  /// Records the athlete's answer to the review of the week starting
  /// [weekStart]. The plan itself only changes through what they accepted.
  void recordReview(DateTime weekStart, ReviewDecision decision) {
    if (!_log.requireWrite()) return;
    final stored = _stored;
    if (stored == null) return;
    _adopt(stored.withReview(calendarDay(weekStart), decision));
  }

  /// Prepare a review decision for an atomic target + plan repository write.
  /// The live plan stays unchanged until [adoptCommittedReview] is called.
  StoredTrainingPlan? prepareAcceptedReview(DateTime weekStart) {
    if (!_log.canWrite) return null;
    return _stored
        ?.withReview(calendarDay(weekStart), ReviewDecision.accepted)
        .copyWith(
          generatorVersion: TrainingPlanGenerator.version,
          templateSetVersion: _templates.version,
        );
  }

  void adoptCommittedReview(String userId, DateTime weekStart) {
    if (_disposed || _userId != userId || _stored == null) return;
    _stored = _stored!.withReview(
      calendarDay(weekStart),
      ReviewDecision.accepted,
    );
    _loaded = true;
    _invalidate(inputs: true);
    notifyListeners();
  }

  void _adjust(SessionAdjustment adjustment) {
    final stored = _stored;
    if (stored == null) return;
    _adopt(stored.withAdjustment(adjustment));
  }

  /// Makes [plan] the current plan and saves it behind the screen.
  void _adopt(StoredTrainingPlan plan) {
    final stamped = plan.copyWith(
      generatorVersion: TrainingPlanGenerator.version,
      templateSetVersion: _templates.version,
    );
    _stored = stamped;
    _loaded = true;
    _invalidate(inputs: true);
    notifyListeners();
    final repo = _repository;
    final userId = _userId;
    if (repo == null || userId == null) return;
    unawaited(_sync.run('plan', 'plan_save_failed',
        () => repo.saveTrainingPlan(userId, stamped)));
  }

  // ---- Account, stream and migration ----

  void _setUser(String? userId) {
    _userId = userId;
    _sub?.cancel();
    _sub = null;
    _generation++;
    // With no repository the plan only lives here, so there is no account to
    // swap it for.
    if (_repository != null) _stored = null;
    _loaded = false;
    _migrationTriedFor = null;
    _invalidate(inputs: true);
    final repo = _repository;
    if (repo == null) {
      // No persistence (demo, tests): the plan lives in memory.
      _loaded = true;
      return;
    }
    if (userId == null) return;
    _sub = repo.watchTrainingPlan(userId).listen(
      (plan) {
        _stored = plan;
        _loaded = true;
        _invalidate(inputs: true);
        notifyListeners();
        if (plan == null) _migrateLegacySchedule();
      },
      onError: (Object error) {
        // The last known plan stays on screen; Firestore retries itself.
        if (kDebugMode) debugPrint('[plan] plan stream error: $error');
      },
    );
  }

  /// The one-time move from the weekday-string schedule. It runs only while
  /// no plan is saved, and saving one is what marks it done; the old
  /// documents are left in place. A failure leaves everything as it was and
  /// is tried again on the next launch.
  void _migrateLegacySchedule() {
    final repo = _repository;
    final userId = _userId;
    if (repo == null || userId == null || _migrationTriedFor == userId) return;
    _migrationTriedFor = userId;
    final generation = _generation;
    unawaited(() async {
      try {
        final slots = await repo
            .watchLegacySessions(userId)
            .first
            .timeout(const Duration(seconds: 10));
        if (_disposed || generation != _generation || _stored != null) return;
        final plan = LegacyPlanMigration.migrate(
          slots,
          today: today,
          goal: _profileGoal,
          level: _profileLevel,
        );
        if (plan != null) _adopt(plan);
      } catch (_) {
        // Nothing was changed; the next launch tries again.
      }
    }());
  }

  void _onLogChanged() {
    _invalidate();
    notifyListeners();
  }

  void _invalidate({bool inputs = false}) {
    _rows = null;
    _rowsDay = null;
    if (inputs) _inputs = null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _log.removeListener(_onLogChanged);
    super.dispose();
  }
}
