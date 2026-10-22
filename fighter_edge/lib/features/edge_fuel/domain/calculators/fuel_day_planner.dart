import 'dart:math' as math;

import '../models/fuel_day_plan.dart';
import '../models/fuel_guidance.dart';
import '../models/planned_fuel_session.dart';
import '../policies/fuel_day_policy.dart';
import '../policies/session_energy_table.dart';

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
/// changes a target. Under-18 or unknown age gets no guidance
/// ([guidance] requires `adultConfirmed`).
class FuelDayPlanner {
  const FuelDayPlanner._();

  /// Classifies [date]. Sessions on other days are ignored. A session with no
  /// duration is ignored.
  static FuelDayPlan planDay({
    required DateTime date,
    required Iterable<FuelDatedSession> plan,
    FuelFightWindow? fight,
  }) {
    final sessions = _sessionsOn(date, plan);
    final load = _loadOf(sessions);
    final tier = _carbTierOf(load, sessions);
    final kcalPerKg = sessions.fold<double>(
      0,
      (sum, s) =>
          sum +
          SessionEnergyTable.sessionKcal(s.toPlannedFuelSession(0), 1.0),
    );
    final inFight = fight?.contains(date) ?? false;
    return FuelDayPlan(
      date: DateTime(date.year, date.month, date.day),
      type: inFight ? FuelDayType.fightWeek : load,
      load: load,
      carbTier: tier,
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
    final first = DateTime(start.year, start.month, start.day);
    return List.unmodifiable([
      for (var i = 0; i < days; i++)
        planDay(
          // DateTime's day overflow handles month ends. 12:00 keeps a DST
          // change from moving the calendar day.
          date: DateTime(first.year, first.month, first.day + i, 12),
          plan: dated,
          fight: fight,
        ),
    ]);
  }

  /// Macro ranges in grams for [day]. Null when the athlete is not a
  /// confirmed adult (rule 4: under-18 or unknown age gets no targets) or the
  /// weight is not usable.
  static FuelMacroGuidance? guidance(
    FuelDayPlan day, {
    required double weightKg,
    required bool adultConfirmed,
  }) {
    if (!adultConfirmed) return null;
    if (!weightKg.isFinite || weightKg <= 0) return null;
    final (carbLow, carbHigh) = switch (day.carbTier) {
      CarbTier.light => (
          FuelDayPolicy.carbLightLow,
          FuelDayPolicy.carbLightHigh
        ),
      CarbTier.moderate => (
          FuelDayPolicy.carbModerateLow,
          FuelDayPolicy.carbModerateHigh
        ),
      CarbTier.heavy => (
          FuelDayPolicy.carbHeavyLow,
          FuelDayPolicy.carbHeavyHigh
        ),
    };
    final carbFloorPerKg = day.load == FuelDayType.doubleDay
        ? FuelDayPolicy.carbFloorDoubleDayGPerKg
        : FuelDayPolicy.carbFloorGPerKg;
    return FuelMacroGuidance(
      dayType: day.type,
      carbTier: day.carbTier,
      weightKg: weightKg,
      carbGramsLow: (carbLow * weightKg).round(),
      carbGramsHigh: (carbHigh * weightKg).round(),
      carbFloorGrams: (carbFloorPerKg * weightKg).ceil(),
      proteinGramsLow: (FuelDayPolicy.proteinLowGPerKg * weightKg).round(),
      proteinGramsHigh: (FuelDayPolicy.proteinHighGPerKg * weightKg).round(),
      proteinFloorGrams: (FuelDayPolicy.proteinFloorGPerKg * weightKg).ceil(),
      fatGramsLow: (FuelDayPolicy.fatLowGPerKg * weightKg).round(),
      fatGramsHigh: (FuelDayPolicy.fatHighGPerKg * weightKg).round(),
      fatFloorGrams: (FuelDayPolicy.fatFloorGPerKg * weightKg).ceil(),
    );
  }

  /// Pre- and post-session hints for each of the day's sessions, in time
  /// order. Empty on a rest day. Reason codes and g/kg ranges only.
  static List<SessionFuelHint> hints(FuelDayPlan day) {
    final sessions = day.sessions;
    return List.unmodifiable([
      for (var i = 0; i < sessions.length; i++)
        SessionFuelHint(
          sessionIndex: i,
          session: sessions[i],
          pre: _pre(sessions[i]),
          post: _post(
            sessions[i],
            next: i + 1 < sessions.length ? sessions[i + 1] : null,
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

  static FuelDayType _loadOf(List<FuelDatedSession> sessions) {
    if (sessions.isEmpty) return FuelDayType.rest;
    final counted = sessions
        .where(
            (s) => s.durationMinutes >= FuelDayPolicy.minimumCountedSessionMinutes)
        .toList();
    final anyBeyondLight = sessions.any((s) => s.intensity != FuelIntensity.light);
    if (counted.length >= 2 && anyBeyondLight) return FuelDayType.doubleDay;
    final kcalPerKg = sessions.fold<double>(
      0,
      (sum, s) =>
          sum +
          SessionEnergyTable.sessionKcal(s.toPlannedFuelSession(0), 1.0),
    );
    final hard = sessions.any((s) => s.intensity == FuelIntensity.hard) ||
        kcalPerKg >= FuelDayPolicy.hardDaySessionKcalPerKg;
    return hard ? FuelDayType.hard : FuelDayType.easy;
  }

  static CarbTier _carbTierOf(
    FuelDayType load,
    List<FuelDatedSession> sessions,
  ) {
    switch (load) {
      case FuelDayType.rest:
        return CarbTier.light;
      case FuelDayType.easy:
        final allLight =
            sessions.every((s) => s.intensity == FuelIntensity.light);
        return allLight ? CarbTier.light : CarbTier.moderate;
      case FuelDayType.hard:
      case FuelDayType.doubleDay:
        return CarbTier.heavy;
      case FuelDayType.fightWeek:
        // Never passed: [_loadOf] does not return it.
        return CarbTier.light;
    }
  }

  // ---- hints ----

  static bool _highIntensityOrLong(FuelDatedSession s) =>
      s.intensity == FuelIntensity.hard ||
      s.durationMinutes > FuelDayPolicy.longSessionMinutes;

  static PreSessionFuel _pre(FuelDatedSession s) {
    if (_highIntensityOrLong(s)) {
      return const PreSessionFuel(
        need: FuelHintNeed.recommended,
        carbs: PerKgRange(
          FuelDayPolicy.preCarbLowGPerKg,
          FuelDayPolicy.preCarbHighGPerKg,
        ),
        mealLeadHoursMin: FuelDayPolicy.preMealLeadHoursMin,
        mealLeadHoursMax: FuelDayPolicy.preMealLeadHoursMax,
        reasons: [
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

  static PostSessionFuel _post(FuelDatedSession s, {FuelDatedSession? next}) {
    if (s.intensity == FuelIntensity.light && !_highIntensityOrLong(s)) {
      return const PostSessionFuel(
        need: FuelHintNeed.none,
        reasons: [FuelHintReason.lightSession],
      );
    }
    const protein = PerKgRange(
      FuelDayPolicy.postProteinLowGPerKg,
      FuelDayPolicy.postProteinHighGPerKg,
    );
    final reasons = <FuelHintReason>[FuelHintReason.proteinDoseAfter];
    final wantsCarbs = _highIntensityOrLong(s);
    final gapHours = next == null ? null : _gapHours(s, next);
    final soon = gapHours != null &&
        gapHours < FuelDayPolicy.quickTurnaroundHours;
    if (next != null) {
      reasons.add(soon
          ? FuelHintReason.nextSessionSoon
          : FuelHintReason.nextSessionSameDay);
    }
    if (!wantsCarbs) {
      // Moderate session: protein dose only. The day's carbohydrate tier
      // covers the rest.
      return PostSessionFuel(
        need: FuelHintNeed.recommended,
        protein: protein,
        proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
        reasons: reasons,
      );
    }
    reasons.add(FuelHintReason.carbRefillAfter);
    if (soon) {
      return PostSessionFuel(
        need: FuelHintNeed.recommended,
        protein: protein,
        proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
        carbsPerHour: const PerKgRange(
          FuelDayPolicy.quickCarbLowGPerKgPerHour,
          FuelDayPolicy.quickCarbHighGPerKgPerHour,
        ),
        carbsPerHourForHours: math.min(
          FuelDayPolicy.quickTurnaroundHours,
          math.max(1, gapHours.ceil()),
        ),
        reasons: reasons,
      );
    }
    return PostSessionFuel(
      need: FuelHintNeed.recommended,
      protein: protein,
      proteinWithinHours: FuelDayPolicy.postProteinWithinHours,
      carbs: const PerKgRange(
        FuelDayPolicy.postCarbLowGPerKg,
        FuelDayPolicy.postCarbHighGPerKg,
      ),
      carbWithinMinutes: FuelDayPolicy.postCarbWithinMinutes,
      reasons: reasons,
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
