import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_day_planner.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_guidance.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/fuel_day_policy.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy_v2.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Monday.
final _day = DateTime(2026, 10, 19);

FuelDatedSession _s({
  DateTime? date,
  FuelIntensity intensity = FuelIntensity.moderate,
  FuelDiscipline discipline = FuelDiscipline.boxing,
  int minutes = 60,
  int? start,
  String? id,
}) =>
    FuelDatedSession(
      date: date ?? _day,
      discipline: discipline,
      intensity: intensity,
      durationMinutes: minutes,
      startMinuteOfDay: start,
      sessionId: id,
    );

FuelDayPlan _plan(List<FuelDatedSession> sessions, {FuelFightWindow? fight}) =>
    FuelDayPlanner.planDay(date: _day, plan: sessions, fight: fight);

void main() {
  group('day type', () {
    test('no session is a rest day with the light carb tier', () {
      final day = _plan(const []);
      expect(day.type, FuelDayType.rest);
      expect(day.load, FuelDayType.rest);
      expect(day.carbTier, CarbTier.light);
      expect(day.hasTraining, isFalse);
      expect(day.sessionKcalPerKg, 0);
    });

    test('sessions on other days and with no duration are ignored', () {
      final day = _plan([
        _s(
            date: _day.add(const Duration(days: 1)),
            intensity: FuelIntensity.hard),
        _s(date: _day.subtract(const Duration(days: 1))),
        _s(minutes: 0, intensity: FuelIntensity.hard),
        _s(minutes: -10),
      ]);
      expect(day.type, FuelDayType.rest);
      expect(day.sessions, isEmpty);
    });

    test('the time of day never moves a session to another day', () {
      final late = DateTime(2026, 10, 19, 23, 59);
      final early = DateTime(2026, 10, 19, 0, 1);
      final day = _plan([_s(date: late), _s(date: early)]);
      expect(day.sessions, hasLength(2));
      expect(day.date, DateTime(2026, 10, 19));
    });

    test('a light session is an easy day on the light tier', () {
      final day = _plan([
        _s(intensity: FuelIntensity.light, discipline: FuelDiscipline.other),
      ]);
      expect(day.type, FuelDayType.easy);
      expect(day.carbTier, CarbTier.light);
      expect(day.hasTraining, isTrue);
    });

    test('a short moderate session is an easy day on the moderate tier', () {
      final day = _plan([
        _s(intensity: FuelIntensity.moderate, minutes: 30),
      ]);
      expect(day.type, FuelDayType.easy);
      expect(day.carbTier, CarbTier.moderate);
    });

    test('a hard session is a hard day on the heavy tier', () {
      final day = _plan([_s(intensity: FuelIntensity.hard, minutes: 30)]);
      expect(day.type, FuelDayType.hard);
      expect(day.carbTier, CarbTier.heavy);
    });

    test('heavy session energy makes a hard day with no hard session', () {
      // Muay Thai moderate: 6.5 net MET x 1 h = 6.5 kcal/kg, over the 6.0
      // threshold shared with policy v2.
      final day = _plan([
        _s(discipline: FuelDiscipline.muayThai, minutes: 60),
      ]);
      expect(day.sessionKcalPerKg, closeTo(6.5, 1e-9));
      expect(
        FuelDayPolicy.hardDaySessionKcalPerKg,
        NutritionPolicyV2.hardDaySessionKcalPerKg,
      );
      expect(day.type, FuelDayType.hard);
    });

    test('two counted sessions with one beyond light is a double day', () {
      final day = _plan([
        _s(intensity: FuelIntensity.light, minutes: 30),
        _s(intensity: FuelIntensity.moderate, minutes: 30),
      ]);
      expect(day.type, FuelDayType.doubleDay);
      expect(day.carbTier, CarbTier.heavy);
    });

    test('two light sessions are not a double day', () {
      final day = _plan([
        _s(intensity: FuelIntensity.light, minutes: 30),
        _s(intensity: FuelIntensity.light, minutes: 30),
      ]);
      expect(day.type, FuelDayType.easy);
    });

    test('a session under 20 minutes does not count toward a double day', () {
      final day = _plan([
        _s(intensity: FuelIntensity.light, minutes: 45),
        _s(intensity: FuelIntensity.moderate, minutes: 15),
      ]);
      expect(day.type, isNot(FuelDayType.doubleDay));
      expect(day.type, FuelDayType.easy);
      expect(day.carbTier, CarbTier.moderate);
    });

    test('a short hard session beside a light one is hard, not double', () {
      final day = _plan([
        _s(intensity: FuelIntensity.light, minutes: 45),
        _s(intensity: FuelIntensity.hard, minutes: 15),
      ]);
      expect(day.type, FuelDayType.hard);
    });

    test('fight week wins over the training load, which is kept', () {
      final fight = FuelFightWindow(
        weighInDate: DateTime(2026, 10, 24),
        fightDate: DateTime(2026, 10, 25),
      );
      final day = _plan([_s(intensity: FuelIntensity.hard)], fight: fight);
      expect(day.type, FuelDayType.fightWeek);
      expect(day.isFightWeek, isTrue);
      expect(day.load, FuelDayType.hard);
      expect(day.carbTier, CarbTier.heavy);
    });
  });

  group('fight window', () {
    final window = FuelFightWindow(
      weighInDate: DateTime(2026, 11, 7),
      fightDate: DateTime(2026, 11, 8),
    );

    test('runs from seven days before the weigh-in through fight day', () {
      expect(window.contains(DateTime(2026, 10, 30)), isFalse);
      expect(window.contains(DateTime(2026, 10, 31)), isTrue);
      expect(window.contains(DateTime(2026, 11, 7)), isTrue);
      expect(window.contains(DateTime(2026, 11, 8, 23)), isTrue);
      expect(window.contains(DateTime(2026, 11, 9)), isFalse);
    });

    test('counts calendar days across a month end and DST', () {
      // Europe DST ends on 2026-10-25; calendar days still count as one.
      expect(
        FuelCalendar.dayNumber(DateTime(2026, 10, 26)) -
            FuelCalendar.dayNumber(DateTime(2026, 10, 25)),
        1,
      );
      expect(
        FuelCalendar.sameDay(
          DateTime(2026, 10, 31, 0, 5),
          DateTime(2026, 10, 31, 23, 55),
        ),
        isTrue,
      );
    });
  });

  group('week', () {
    test('plans seven dated days in order across a month end', () {
      final start = DateTime(2026, 10, 28);
      final week = FuelDayPlanner.planWeek(
        start: start,
        plan: [
          _s(date: DateTime(2026, 10, 28), intensity: FuelIntensity.hard),
          _s(date: DateTime(2026, 11, 1), intensity: FuelIntensity.light),
        ],
      );
      expect(week, hasLength(7));
      expect(week.first.date, DateTime(2026, 10, 28));
      expect(week.last.date, DateTime(2026, 11, 3));
      expect(week[0].type, FuelDayType.hard);
      expect(week[1].type, FuelDayType.rest);
      expect(week[4].type, FuelDayType.easy);
    });

    test('is deterministic', () {
      List<FuelDayType> run() => FuelDayPlanner.planWeek(
            start: _day,
            plan: [
              _s(intensity: FuelIntensity.hard),
              _s(date: DateTime(2026, 10, 21)),
            ],
          ).map((d) => d.type).toList();
      expect(run(), run());
    });
  });

  group('guidance', () {
    test('gives nothing to anyone not confirmed as an adult', () {
      final day = _plan([_s(intensity: FuelIntensity.hard)]);
      expect(
        FuelDayPlanner.guidance(day, weightKg: 70, adultConfirmed: false),
        isNull,
      );
      expect(
        FuelDayPlanner.guidance(
          day,
          weightKg: 70,
          adultConfirmed: false,
          amountsEnabled: true,
        ),
        isNull,
      );
    });

    test('gives nothing for an unusable weight', () {
      final day = _plan(const []);
      for (final w in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          FuelDayPlanner.guidance(day, weightKg: w, adultConfirmed: true),
          isNull,
          reason: '$w',
        );
      }
    });

    test('keeps the ranges behind the default-off flag', () {
      expect(FuelDayPolicy.amountsEnabledByDefault, isFalse);
      expect(FuelDayPolicy.dietitianSignOffPending, isTrue);
      final g = FuelDayPlanner.guidance(
        _plan([_s(intensity: FuelIntensity.hard)]),
        weightKg: 70,
        adultConfirmed: true,
      )!;
      expect(g.rangeStatus, FuelRangeStatus.awaitingSignOff);
      expect(g.carbs, isNull);
      expect(g.protein, isNull);
      expect(g.fat, isNull);
      // The floors always come through.
      expect(g.carbFloorGrams, 210);
      expect(g.proteinFloorGrams, 84);
      expect(g.fatFloorGrams, 35);
    });

    test('scales the tier ranges by weight when the flag is on', () {
      FuelMacroGuidance g(List<FuelDatedSession> s) => FuelDayPlanner.guidance(
            _plan(s),
            weightKg: 70,
            adultConfirmed: true,
            amountsEnabled: true,
          )!;

      final rest = g(const []);
      expect(rest.rangeStatus, FuelRangeStatus.shown);
      expect(rest.dayType, FuelDayType.rest);
      expect(rest.carbs, const GramRange(210, 350));
      expect(rest.protein, const GramRange(112, 154));
      expect(rest.fat, const GramRange(49, 91));

      final moderate = g([_s(minutes: 30)]);
      expect(moderate.carbTier, CarbTier.moderate);
      expect(moderate.carbs, const GramRange(350, 490));

      final hard = g([_s(intensity: FuelIntensity.hard)]);
      expect(hard.carbs, const GramRange(420, 700));
      expect(hard.carbFloorGrams, 210);
    });

    test('raises the carbohydrate floor on a double day', () {
      final g = FuelDayPlanner.guidance(
        _plan([
          _s(intensity: FuelIntensity.hard, minutes: 30),
          _s(intensity: FuelIntensity.light, minutes: 30),
        ]),
        weightKg: 70,
        adultConfirmed: true,
      )!;
      expect(g.dayType, FuelDayType.doubleDay);
      expect(g.carbFloorGrams, 245);
    });

    test('never gives day ranges in fight week, even with the flag on', () {
      final fight = FuelFightWindow(
        weighInDate: DateTime(2026, 10, 20),
        fightDate: DateTime(2026, 10, 20),
      );
      final g = FuelDayPlanner.guidance(
        _plan([_s(intensity: FuelIntensity.hard)], fight: fight),
        weightKg: 70,
        adultConfirmed: true,
        amountsEnabled: true,
      )!;
      expect(g.rangeStatus, FuelRangeStatus.fightWeek);
      expect(g.carbs, isNull);
      expect(g.protein, isNull);
      expect(g.fat, isNull);
      expect(g.carbFloorGrams, 210);
    });

    test('the floors match policy v2 and sit inside the ranges', () {
      expect(FuelDayPolicy.carbFloorGPerKg, NutritionPolicyV2.carbFloorGPerKg);
      expect(
        FuelDayPolicy.proteinFloorGPerKg,
        NutritionPolicyV2.proteinFloorGPerKg,
      );
      expect(FuelDayPolicy.fatFloorGPerKg, NutritionPolicyV2.fatFloorGPerKg);
      for (final tier in CarbTier.values) {
        final r = FuelDayPlanner.carbRangeFor(tier);
        expect(r.low, greaterThanOrEqualTo(FuelDayPolicy.carbFloorGPerKg));
        expect(r.high, greaterThan(r.low));
      }
      expect(
        FuelDayPolicy.proteinLowGPerKg,
        greaterThan(FuelDayPolicy.proteinFloorGPerKg),
      );
      expect(FuelDayPolicy.fatLowGPerKg,
          greaterThan(FuelDayPolicy.fatFloorGPerKg));
    });
  });

  group('session hints', () {
    test('a rest day has none', () {
      expect(
        FuelDayPlanner.hints(_plan(const []), adultConfirmed: true),
        isEmpty,
      );
    });

    test('a hard session: pre-meal 2-3 h before, protein and carbs after', () {
      final hints = FuelDayPlanner.hints(
        _plan([_s(intensity: FuelIntensity.hard, id: 'plan-1')]),
        adultConfirmed: true,
        amountsEnabled: true,
      );
      expect(hints, hasLength(1));
      final h = hints.single;
      expect(h.sessionIndex, 0);
      expect(h.session.sessionId, 'plan-1');
      expect(h.pre.need, FuelHintNeed.recommended);
      expect(h.pre.carbs, const PerKgRange(1, 4));
      expect(h.pre.mealLeadHoursMin, 2);
      expect(h.pre.mealLeadHoursMax, 3);
      expect(h.pre.reasons, [
        FuelHintReason.highIntensityOrLong,
        FuelHintReason.lowFatBeforeSession,
        FuelHintReason.lowFibreBeforeSession,
      ]);
      expect(h.post.need, FuelHintNeed.recommended);
      expect(h.post.protein, const PerKgRange(0.25, 0.4));
      expect(h.post.proteinWithinHours, 2);
      expect(h.post.carbs, const PerKgRange(0.6, 1.0));
      expect(h.post.carbWithinMinutes, 30);
      expect(h.post.carbsPerHour, isNull);
      expect(h.post.reasons, [
        FuelHintReason.proteinDoseAfter,
        FuelHintReason.carbRefillAfter,
      ]);
    });

    test('amounts stay off by default and for anyone not a confirmed adult',
        () {
      final day = _plan([_s(intensity: FuelIntensity.hard)]);
      for (final h in [
        ...FuelDayPlanner.hints(day, adultConfirmed: true),
        ...FuelDayPlanner.hints(
          day,
          adultConfirmed: false,
          amountsEnabled: true,
        ),
      ]) {
        expect(h.pre.carbs, isNull);
        expect(h.post.protein, isNull);
        expect(h.post.carbs, isNull);
        expect(h.post.carbsPerHour, isNull);
        // The codes still come through.
        expect(h.pre.need, FuelHintNeed.recommended);
        expect(h.post.reasons, contains(FuelHintReason.carbRefillAfter));
      }
    });

    test('a moderate session: optional before, a protein dose after', () {
      final h = FuelDayPlanner.hints(
        _plan([_s(minutes: 30)]),
        adultConfirmed: true,
        amountsEnabled: true,
      ).single;
      expect(h.pre.need, FuelHintNeed.optional);
      expect(h.pre.carbs, isNull);
      expect(h.pre.reasons, [FuelHintReason.moderateSessionOptional]);
      expect(h.post.need, FuelHintNeed.recommended);
      expect(h.post.protein, isNotNull);
      expect(h.post.carbs, isNull);
      expect(h.post.reasons, [FuelHintReason.proteinDoseAfter]);
    });

    test('a light session needs nothing special', () {
      final h = FuelDayPlanner.hints(
        _plan([_s(intensity: FuelIntensity.light, minutes: 45)]),
        adultConfirmed: true,
        amountsEnabled: true,
      ).single;
      expect(h.pre.need, FuelHintNeed.none);
      expect(h.post.need, FuelHintNeed.none);
      expect(h.post.reasons, [FuelHintReason.lightSession]);
    });

    test('a light session over 90 minutes counts as long', () {
      final h = FuelDayPlanner.hints(
        _plan([_s(intensity: FuelIntensity.light, minutes: 100)]),
        adultConfirmed: true,
        amountsEnabled: true,
      ).single;
      expect(h.pre.need, FuelHintNeed.recommended);
      expect(h.post.carbs, isNotNull);
    });

    test('a quick turnaround gives an hourly carbohydrate rate', () {
      final hints = FuelDayPlanner.hints(
        _plan([
          // Listed out of order: the planner sorts by start time.
          _s(start: 13 * 60, minutes: 60, id: 'pm'),
          _s(intensity: FuelIntensity.hard, start: 9 * 60, id: 'am'),
        ]),
        adultConfirmed: true,
        amountsEnabled: true,
      );
      expect(hints.map((h) => h.session.sessionId), ['am', 'pm']);
      final first = hints.first.post;
      // 10:00 to 13:00 is a 3 h gap.
      expect(first.reasons, contains(FuelHintReason.nextSessionSoon));
      expect(first.carbsPerHour, const PerKgRange(1.0, 1.2));
      expect(first.carbsPerHourForHours, 3);
      expect(first.carbs, isNull);
      expect(hints.last.post.reasons,
          isNot(contains(FuelHintReason.nextSessionSoon)));
    });

    test('an overlapping next session still gives at least one hour', () {
      final first = FuelDayPlanner.hints(
        _plan([
          _s(intensity: FuelIntensity.hard, start: 9 * 60, minutes: 120),
          _s(start: 10 * 60, minutes: 30),
        ]),
        adultConfirmed: true,
        amountsEnabled: true,
      ).first.post;
      expect(first.carbsPerHourForHours, 1);
    });

    test('a later second session, or unknown times, is just same-day', () {
      final far = FuelDayPlanner.hints(
        _plan([
          _s(intensity: FuelIntensity.hard, start: 7 * 60),
          _s(start: 18 * 60),
        ]),
        adultConfirmed: true,
        amountsEnabled: true,
      ).first.post;
      expect(far.reasons, contains(FuelHintReason.nextSessionSameDay));
      expect(far.carbs, isNotNull);

      final unknown = FuelDayPlanner.hints(
        _plan([
          _s(intensity: FuelIntensity.hard),
          _s(),
        ]),
        adultConfirmed: true,
      ).first.post;
      expect(unknown.reasons, contains(FuelHintReason.nextSessionSameDay));

      final moderateThenMore = FuelDayPlanner.hints(
        _plan([_s(start: 8 * 60, minutes: 30), _s(start: 9 * 60, minutes: 30)]),
        adultConfirmed: true,
      ).first.post;
      expect(moderateThenMore.reasons, [
        FuelHintReason.proteinDoseAfter,
        FuelHintReason.nextSessionSoon,
      ]);
    });

    test('no hint code is about fluid, sodium, fasting or food labels', () {
      const banned = {
        'fluid', 'water', 'sodium', 'salt', 'fast', 'fasting', 'sauna', //
        'sweat', 'diuretic', 'laxative', 'good', 'bad', 'cheat', 'earn',
        'junk', 'clean', 'over', 'avoid', 'restrict', 'skip',
      };
      for (final reason in FuelHintReason.values) {
        final words = reason.name
            .split(RegExp(r'(?=[A-Z])'))
            .map((w) => w.toLowerCase())
            .toSet();
        expect(words.intersection(banned), isEmpty, reason: reason.name);
      }
    });
  });
}
