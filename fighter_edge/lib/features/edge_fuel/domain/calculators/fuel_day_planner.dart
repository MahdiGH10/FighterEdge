import 'dart:math' as math;

import '../models/fuel_day_plan.dart';
import '../models/fuel_guidance.dart';
import '../policies/fuel_day_policy.dart';
import '../policies/session_energy_table.dart';
import '../models/planned_fuel_session.dart';

/// Day-type fuel guidance as a pure function of the dated training plan.
///
/// ```text
/// rest        no planned training
/// easy        training, none of it hard, not a double day
/// hard        a hard session, or session energy >= 6 kcal/kg
/// doubleDay   two or more counted sessions, at least one beyond light
/// fightWeek   inside the fight window (wins over the others)
/// ```
///
/// There is no clock and no I/O: the caller passes the date. Calendar days are
/// compared by year, month and day only, so a time of day or a time zone never
/// moves a session to another day.
///
/// DIETITIAN SIGN-OFF PENDING: see [FuelDayPolicy]. Nothing here sets or
/// changes a target. Under-18 or unknown age gets no amounts: [guidance]
/// returns null and [hints] gives reason codes only.
class FuelDayPlanner {
  const FuelDayPlanner._();

  /// Classifies [date]. Sessions on other days, and sessions with no
  /// duration, are ignored.
  static FuelDayPlan planDay({
    required DateTime date,
    required Iterable<FuelDatedSession> plan,
    FuelFightWindow? fight,
  }) {
    final sessions = _sessionsOn(date, plan);
    final kcalPerKg = sessions.fold<double>(
      0,
      (sum, s) =>
          sum + SessionEnergyTable.sessionKcal(s.toPlannedFuelSession(0), 1),
    );
    final load = _loadOf(sessions, kcalPerKg);
    final inFight = fight?.contains(date) ?? false;
    return FuelDayPlan(
      date: DateTime(date.year, date.month, date.day),
      type: inFight ? FuelDayType.fightWeek : load,
      load: load,
      carbTier: _carbTierOf(load, sessions),
      sessions: List.unmodifiable(sessions),
      sessionKcalPerKg: kcalPerKg,
    );
  }

  /// [days] consecutive days from [start], in date order.
  static List<FuelDayPlan> planWeek({
    required DateTime start,
    required Iterable<FuelDatedSession> plan,
    FuelFightWindow? fight,
    int days = 7,
  }) {
    final dated = plan.toList(growable: false);
    return List.unmodifiable([
      for (var i = 0; i < days; i++)
        planDay(
          // DateTime's day overflow handles month ends. 12:00 keeps a DST
          // change from moving the calendar day.
          date: DateTime(start.year, start.month, start.day + i, 12),
          plan: dated,
          fight: fight,
        ),
    ]);
  }

  /// Macro guidance in grams for [day].
  ///
  /// Null when the athlete is not a confirmed adult (rule 4: under-18 or
  /// unknown age gets no targets) or the weight is not usable. The floors are
  /// always given. The ranges are given only when [amountsEnabled] is true and
  /// the day is not in fight week.
  static FuelMacroGuidance? guidance(
    FuelDayPlan day, {
    required double weightKg,
    required bool adultConfirmed,
    bool amountsEnabled = FuelDayPolicy.amountsEnabledByDefault,
  }) {
    if (!adultConfirmed) return null;
    if (!weightKg.isFinite || weightKg <= 0) return null;
    final status = day.isFightWeek
        ? FuelRangeStatus.fightWeek
        : (amountsEnabled
            ? FuelRangeStatus.shown
            : FuelRangeStatus.awaitingSignOff);
    final show = status == FuelRangeStatus.shown;
    final carbFloorPerKg = day.load == FuelDayType.doubleDay
        ? FuelDayPolicy.carbFloorDoubleDayGPerKg
        : FuelDayPolicy.carbFloorGPerKg;
    return FuelMacroGuidance(
      dayType: day.type,
      carbTier: day.carbTier,
      weightKg: weightKg,
      rangeStatus: status,
      carbs: show ? carbRangeFor(day.carbTier).forWeight(weightKg) : null,
      protein: show
          ? const PerKgRange(
              FuelDayPolicy.proteinLowGPerKg,
              FuelDayPolicy.proteinHighGPerKg,
            ).forWeight(weightKg)
          : null,
      fat: show
          ? const PerKgRange(
              FuelDayPolicy.fatLowGPerKg,
              FuelDayPolicy.fatHighGPerKg,
            ).forWeight(weightKg)
          : null,
      carbFloorGrams: (carbFloorPerKg * weightKg).ceil(),
      proteinFloorGrams: (FuelDayPolicy.proteinFloorGPerKg * weightKg).ceil(),
      fatFloorGrams: (FuelDayPolicy.fatFloorGPerKg * weightKg).ceil(),
    );
  }

  /// The g/kg carbohydrate range of a tier.
  // dietitian sign-off pending
  static PerKgRange carbRangeFor(CarbTier tier) => switch (tier) {
        CarbTier.light => const PerKgRange(
            FuelDayPolicy.carbLightLow,
            FuelDayPolicy.carbLightHigh,
          ),
        CarbTier.moderate => const PerKgRange(
            FuelDayPolicy.carbModerateLow,
            FuelDayPolicy.carbModerateHigh,
          ),
        CarbTier.heavy => const PerKgRange(
            FuelDayPolicy.carbHeavyLow,
            FuelDayPolicy.carbHeavyHigh,
          ),
      };

  /// Pre- and post-session hints for each of the day's sessions, in time
  /// order. Empty on a rest day.
  ///
  /// The reason codes always come through. The g/kg amounts come through only
  /// for a confirmed adult with [amountsEnabled] on. No hint is about fluid,
  /// sodium or skipping food.
  static List<SessionFuelHint> hints(
    FuelDayPlan day, {
    required bool adultConfirmed,
    bool amountsEnabled = FuelDayPolicy.amountsEnabledByDefault,
  }) {
    final amounts = adultConfirmed && amountsEnabled;
    final sessions = day.sessions;
    return List.unmodifiable([
      for (var i = 0; i < sessions.length; i++)
        SessionFuelHint(
          sessionIndex: i,
          session: sessions[i],
          pre: _pre(sessions[i], amounts: amounts),
          post: _post(
            sessions[i],
            next: i + 1 < sessions.length ? sessions[i + 1] : null,
            amounts: amounts,
          ),
        ),
    ]);
  }

  // ---- classification ----

  static List<FuelDatedSession> _sessionsOn(
    DateTime date,
    Iterable<FuelDatedSession> plan,
  ) {
    final indexed = <(int, FuelDatedSession)>[];
    var index = 0;
    for (final s in plan) {
      final i = index++;
      if (s.durationMinutes <= 0) continue;
      if (!FuelCalendar.sameDay(s.date, date)) continue;
      indexed.add((i, s));
    }
    // Time order. A session with no known start sorts after those with one,
    // and ties fall back to the caller's order, so the result is stable.
    indexed.sort((a, b) {
      final aStart = a.$2.startMinuteOfDay ?? 24 * 60;
      final bStart = b.$2.startMinuteOfDay ?? 24 * 60;
      final byStart = aStart.compareTo(bStart);
      return byStart != 0 ? byStart : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  static FuelDayType _loadOf(
    List<FuelDatedSession> sessions,
    double sessionKcalPerKg,
  ) {
    if (sessions.isEmpty) return FuelDayType.rest;
    final counted = sessions
        .where((s) =>
            s.durationMinutes >= FuelDayPolicy.minimumCountedSessionMinutes)
        .toList(growable: false);
    final countedBeyondLight =
        counted.any((s) => s.intensity != FuelIntensity.light);
    if (counted.length >= 2 && countedBeyondLight) return FuelDayType.doubleDay;
    final hard = sessions.any((s) => s.intensity == FuelIntensity.hard) ||
        sessionKcalPerKg >= FuelDayPolicy.hardDaySessionKcalPerKg;
    return hard ? FuelDayType.hard : FuelDayType.easy;
  }

  static CarbTier _carbTierOf(
    FuelDayType load,
    List<FuelDatedSession> sessions,
  ) =>
      switch (load) {
        FuelDayType.easy
            when sessions.any((s) => s.intensity != FuelIntensity.light) =>
          CarbTier.moderate,
        FuelDayType.hard || FuelDayType.doubleDay => CarbTier.heavy,
        // Rest, light-only training, and fight week (never a load).
        _ => CarbTier.light,
      };

  // ---- hints ----

  static bool _highIntensityOrLong(FuelDatedSession s) =>
      s.intensity == FuelIntensity.hard ||
      s.durationMinutes > FuelDayPolicy.longSessionMinutes;

  static PreSessionFuel _pre(FuelDatedSession s, {required bool amounts}) {
    if (_highIntensityOrLong(s)) {
      return PreSessionFuel(
        need: FuelHintNeed.recommended,
        carbs: amounts
            ? const PerKgRange(
                FuelDayPolicy.preCarbLowGPerKg,
                FuelDayPolicy.preCarbHighGPerKg,
              )
            : null,
        mealLeadHoursMin: FuelDayPolicy.preMealLeadHoursMin,
        mealLeadHoursMax: FuelDayPolicy.preMealLeadHoursMax,
        reasons: const [
          FuelHintReason.highIntensityOrLong,
          FuelHintReason.lowFatBeforeSession,
          FuelHintReason.lowFibreBeforeSession,
        ],
      );
    }
    if (s.intensity == FuelIntensity.moderate) {
      return const PreSessionFuel(
        need: FuelHintNeed.optional,
        reasons: [FuelHintReason.moderateSessionOptional],
      );
    }
    return const PreSessionFuel(
      need: FuelHintNeed.none,
      reasons: [FuelHintReason.lightSession],
    );
  }

  static PostSessionFuel _post(
    FuelDatedSession s, {
    required FuelDatedSession? next,
    required bool amounts,
  }) {
    final wantsCarbs = _highIntensityOrLong(s);
    if (s.intensity == FuelIntensity.light && !wantsCarbs) {
      return const PostSessionFuel(
        need: FuelHintNeed.none,
        reasons: [FuelHintReason.lightSession],
      );
    }
    final protein = amounts
        ? const PerKgRange(
            FuelDayPolicy.postProteinLowGPerKg,
            FuelDayPolicy.postProteinHighGPerKg,
          )
        : null;
    final reasons = <FuelHintReason>[FuelHintReason.proteinDoseAfter];
    final gapHours = next == null ? null : _gapHours(s, next);
    final soon =
        gapHours != null && gapHours < FuelDayPolicy.quickTurnaroundHours;
    if (next != null) {
      reasons.add(soon
          ? FuelHintReason.nextSessionSoon
          : FuelHintReason.nextSessionSameDay);
    }
    if (!wantsCarbs) {
      // Moderate session: a protein dose only. The day's carbohydrate tier
      // covers the rest.
      return PostSessionFuel(
        need: FuelHintNeed.recommended,
        protein: protein,
        proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
        reasons: List.unmodifiable(reasons),
      );
    }
    reasons.add(FuelHintReason.carbRefillAfter);
    if (soon) {
      return PostSessionFuel(
        need: FuelHintNeed.recommended,
        protein: protein,
        proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
        carbsPerHour: amounts
            ? const PerKgRange(
                FuelDayPolicy.quickCarbLowGPerKgPerHour,
                FuelDayPolicy.quickCarbHighGPerKgPerHour,
              )
            : null,
        carbsPerHourForHours: math.min(
          FuelDayPolicy.quickTurnaroundHours,
          math.max(1, gapHours.ceil()),
        ),
        reasons: List.unmodifiable(reasons),
      );
    }
    return PostSessionFuel(
      need: FuelHintNeed.recommended,
      protein: protein,
      proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
      carbs: amounts
          ? const PerKgRange(
              FuelDayPolicy.postCarbLowGPerKg,
              FuelDayPolicy.postCarbHighGPerKg,
            )
          : null,
      carbWithinMinutes: FuelDayPolicy.postCarbWithinMinutes,
      reasons: List.unmodifiable(reasons),
    );
  }

  /// Hours from the end of [a] to the start of [b], or null when either start
  /// is unknown. Never negative.
  static double? _gapHours(FuelDatedSession a, FuelDatedSession b) {
    final aStart = a.startMinuteOfDay;
    final bStart = b.startMinuteOfDay;
    if (aStart == null || bStart == null) return null;
    final minutes = bStart - (aStart + a.durationMinutes);
    return (minutes < 0 ? 0 : minutes) / 60;
  }
}
