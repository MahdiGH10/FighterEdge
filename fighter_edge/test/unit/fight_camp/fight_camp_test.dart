import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendar', () {
    test('counts calendar days, ignoring the time of day', () {
      expect(
        daysBetween(DateTime(2026, 1, 1, 23, 59), DateTime(2026, 1, 2, 0, 1)),
        1,
      );
      expect(daysBetween(DateTime(2026, 1, 2), DateTime(2026, 1, 1)), -1);
    });

    test('a daylight-saving weekend is still two days', () {
      // Europe and the US both change clocks in March.
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
    });

    test('weeks start on Monday', () {
      expect(weekStart(DateTime(2026, 9, 27)), DateTime.utc(2026, 9, 21));
      expect(weekStart(DateTime(2026, 9, 28)), DateTime.utc(2026, 9, 28));
      expect(weekStart(DateTime(2026, 10, 1)), DateTime.utc(2026, 9, 28));
    });

    test('adding days rolls over months', () {
      expect(addDays(DateTime(2026, 1, 31), 1), DateTime.utc(2026, 2, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime.utc(2026, 2, 28));
    });
  });

  group('WeightCutPolicy', () {
    test('the acute limit shrinks as the weigh-in gets closer (point 7)', () {
      expect(WeightCutPolicy.maxAcuteFraction(7), 0.067);
      expect(WeightCutPolicy.maxAcuteFraction(3), 0.067);
      expect(WeightCutPolicy.maxAcuteFraction(2), 0.057);
      expect(WeightCutPolicy.maxAcuteFraction(1), 0.044);
      expect(WeightCutPolicy.maxAcuteFraction(0), 0.044);
    });

    test('food plus the sweat allowance never exceeds point 7', () {
      expect(
        WeightCutPolicy.supervisedAcuteFraction(
            CompetitionCategory.professional, 5),
        0.067,
      );
      expect(
        WeightCutPolicy.supervisedAcuteFraction(
            CompetitionCategory.grappling, 5),
        closeTo(0.05, 1e-12),
      );
      expect(
        WeightCutPolicy.supervisedAcuteFraction(
            CompetitionCategory.amateurStriking, 1),
        0.044,
      );
    });
  });

  group('FightCamp', () {
    FightCamp camp({
      DateTime? fight,
      DateTime? weighIn,
      double limit = 70.3,
      int weeks = 8,
    }) =>
        FightCamp.tryCreate(
          fightDate: fight ?? DateTime(2026, 12, 12),
          weighInDate: weighIn,
          weightLimitKg: limit,
          category: CompetitionCategory.professional,
          campWeeks: weeks,
        )!;

    test('rejects dates and limits that cannot be a real fight', () {
      FightCamp? create({
        DateTime? weighIn,
        double limit = 70.3,
        int weeks = 8,
      }) =>
          FightCamp.tryCreate(
            fightDate: DateTime(2026, 12, 12),
            weighInDate: weighIn,
            weightLimitKg: limit,
            category: CompetitionCategory.professional,
            campWeeks: weeks,
          );
      expect(create(weighIn: DateTime(2026, 12, 13)), isNull);
      expect(create(weighIn: DateTime(2026, 12, 9)), isNull);
      expect(create(limit: 30), isNull);
      expect(create(limit: 221), isNull);
      expect(create(limit: double.nan), isNull);
      expect(create(weeks: 3), isNull);
      expect(create(weeks: 17), isNull);
      expect(create(weighIn: DateTime(2026, 12, 10)), isNotNull);
    });

    test('a missing weigh-in date means a same-day weigh-in', () {
      final sameDay = camp();
      expect(sameDay.weighInDate, sameDay.fightDate);
      expect(sameDay.fightWeekStart, DateTime.utc(2026, 12, 5));
    });

    test('phases follow the weigh-in and the fight', () {
      final dayBefore = camp(weighIn: DateTime(2026, 12, 11));
      final weighIn = DateTime(2026, 12, 11);
      CampPhase on(DateTime day) => dayBefore.phaseOn(day);

      expect(on(addDays(weighIn, -57)), CampPhase.offCamp);
      expect(on(addDays(weighIn, -56)), CampPhase.camp);
      expect(on(addDays(weighIn, -8)), CampPhase.camp);
      expect(on(addDays(weighIn, -7)), CampPhase.fightWeek);
      expect(on(weighIn), CampPhase.fightWeek);
      expect(on(DateTime(2026, 12, 12)), CampPhase.refuel);
      expect(on(DateTime(2026, 12, 13)), CampPhase.postFight);
      expect(on(DateTime(2026, 12, 19)), CampPhase.postFight);
      expect(on(DateTime(2026, 12, 20)), CampPhase.offCamp);
    });

    test('with a same-day weigh-in, fight day is still fight week', () {
      expect(camp().phaseOn(DateTime(2026, 12, 12)), CampPhase.fightWeek);
    });

    test('a longer camp starts earlier', () {
      final long = camp(weeks: 12);
      expect(
          long.phaseOn(addDays(DateTime(2026, 12, 12), -84)), CampPhase.camp);
      expect(long.phaseOn(addDays(DateTime(2026, 12, 12), -85)),
          CampPhase.offCamp);
    });

    test('counts days to the weigh-in and the fight', () {
      final dayBefore = camp(weighIn: DateTime(2026, 12, 11));
      final today = DateTime(2026, 12, 1, 18, 30);
      expect(dayBefore.daysToWeighIn(today), 10);
      expect(dayBefore.daysToFight(today), 11);
    });
  });

  group('FightCamp storage and calendar', () {
    FightCamp camp() => FightCamp.tryCreate(
          fightDate: DateTime(2026, 12, 12),
          weighInDate: DateTime(2026, 12, 11),
          weightLimitKg: 70.3,
          category: CompetitionCategory.olympic,
          campWeeks: 10,
        )!;

    test('round-trips through JSON', () {
      final json = camp().toJson();
      expect(json, {
        'fightDate': '2026-12-12',
        'weighInDate': '2026-12-11',
        'weightLimitKg': 70.3,
        'category': 'olympic',
        'campWeeks': 10,
      });
      expect(FightCamp.fromJson(json), camp());
    });

    test('reads a corrupt document as no fight', () {
      final good = camp().toJson();
      Map<String, dynamic> edited(String key, Object? value) =>
          {...good, key: value};
      expect(FightCamp.fromJson(edited('fightDate', '2026-02-31')), isNull);
      expect(FightCamp.fromJson(edited('fightDate', 'soon')), isNull);
      expect(FightCamp.fromJson(edited('fightDate', null)), isNull);
      expect(FightCamp.fromJson(edited('category', 'street')), isNull);
      expect(FightCamp.fromJson(edited('weightLimitKg', '70')), isNull);
      expect(FightCamp.fromJson(edited('weightLimitKg', 400)), isNull);
      expect(FightCamp.fromJson(edited('weighInDate', '2026-12-13')), isNull);
      expect(FightCamp.fromJson(edited('campWeeks', 40)), isNull);
    });

    test('an older document without optional fields still loads', () {
      final json = camp().toJson()
        ..remove('weighInDate')
        ..remove('campWeeks');
      final loaded = FightCamp.fromJson(json)!;
      expect(loaded.weighInDate, loaded.fightDate);
      expect(loaded.campWeeks, FightCamp.defaultCampWeeks);
    });

    test('counts camp weeks from the start of camp', () {
      final c = camp(); // 10 weeks, weigh-in 11 Dec
      final weighIn = DateTime(2026, 12, 11);
      expect(c.campWeekOn(addDays(weighIn, -71)), isNull);
      expect(c.campWeekOn(addDays(weighIn, -70)), 1);
      expect(c.campWeekOn(addDays(weighIn, -64)), 1);
      expect(c.campWeekOn(addDays(weighIn, -63)), 2);
      expect(c.campWeekOn(addDays(weighIn, -8)), 9);
      expect(c.campWeekOn(addDays(weighIn, -7)), isNull);
    });

    test('numbers fight-week days up to the weigh-in', () {
      final c = camp();
      final weighIn = DateTime(2026, 12, 11);
      expect(c.fightWeekDayOn(addDays(weighIn, -8)), isNull);
      expect(c.fightWeekDayOn(addDays(weighIn, -7)), 1);
      expect(c.fightWeekDayOn(addDays(weighIn, -1)), 7);
      expect(c.fightWeekDayOn(weighIn), 8);
      expect(c.fightWeekDayOn(DateTime(2026, 12, 12)), isNull);
    });
  });
}
