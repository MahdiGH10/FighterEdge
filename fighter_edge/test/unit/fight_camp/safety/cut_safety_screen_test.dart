import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/cut_safety_screen.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

FightCamp campIn(int daysToWeighIn, {double limit = 70}) => FightCamp.tryCreate(
      fightDate: addDays(today, daysToWeighIn + 1),
      weighInDate: addDays(today, daysToWeighIn),
      weightLimitKg: limit,
      category: CompetitionCategory.amateurStriking,
    )!;

CutSafetyDecision decide(
  CutSafetyAnswers answers, {
  FightCamp? camp,
  double? weight,
  WeightPathStatus? status,
}) =>
    CutSafetyScreen.evaluate(
      answers: answers,
      today: today,
      camp: camp,
      currentWeightKg: weight,
      pathStatus: status,
    );

const adult = CutSafetyAnswers(ageYears: 25);

void main() {
  group('rule 4: under-18 or unknown age gets no cut tools', () {
    test('minors', () {
      for (final age in [10, 14, 17]) {
        final d = decide(CutSafetyAnswers(ageYears: age));
        expect(d.outcome, CutSafetyOutcome.noCutTools, reason: '$age');
        expect(d.reasons, {CutSafetyReason.underAge});
        expect(d.showCutTools, isFalse);
        expect(d.showTalkToProfessional, isFalse);
        expect(d.campScreening, CampScreening.pending);
      }
    });

    test('missing or impossible ages fail closed', () {
      for (final age in [null, 0, -3, 121, 400]) {
        final d = decide(CutSafetyAnswers(ageYears: age));
        expect(d.outcome, CutSafetyOutcome.noCutTools, reason: '$age');
        expect(d.reasons, {CutSafetyReason.ageUnknown});
      }
    });

    test('age wins over every other answer', () {
      final d = decide(
        const CutSafetyAnswers(
          ageYears: 16,
          clinicalFlag: true,
          warningSigns: {CutWarningSign.fainting},
        ),
      );
      expect(d.outcome, CutSafetyOutcome.noCutTools);
    });

    test('18 and 120 are allowed', () {
      expect(CutSafetyScreen.cutToolsAllowedForAge(18), isTrue);
      expect(CutSafetyScreen.cutToolsAllowedForAge(120), isTrue);
      expect(CutSafetyScreen.cutToolsAllowedForAge(17), isFalse);
      expect(CutSafetyScreen.cutToolsAllowedForAge(null), isFalse);
      expect(WeightCutPolicy.minimumAgeYears, 18);
    });
  });

  test('a healthy adult with no flags is cleared', () {
    final d = decide(adult);
    expect(d.outcome, CutSafetyOutcome.cleared);
    expect(d.reasons, isEmpty);
    expect(d.showCutTools, isTrue);
    expect(d.showTalkToProfessional, isFalse);
    expect(d.campScreening, CampScreening.cleared);
  });

  group('rule 5: talk to a professional', () {
    void expectReferral(CutSafetyDecision d, CutSafetyReason reason) {
      expect(d.outcome, CutSafetyOutcome.talkToProfessional);
      expect(d.reasons, contains(reason));
      expect(d.showTalkToProfessional, isTrue);
      expect(d.showCutTools, isFalse);
      expect(d.campScreening, CampScreening.needsProfessionalReview);
    }

    test('clinical flags', () {
      expectReferral(
        decide(const CutSafetyAnswers(ageYears: 30, clinicalFlag: true)),
        CutSafetyReason.clinicalFlag,
      );
    });

    test('each eating-disorder signal', () {
      for (final signal in EatingDisorderSignal.values) {
        expectReferral(
          decide(
              CutSafetyAnswers(ageYears: 30, eatingDisorderSignals: {signal})),
          CutSafetyReason.eatingDisorderSignal,
        );
      }
    });

    test('fainting, dark urine and every other warning sign', () {
      for (final sign in CutWarningSign.values) {
        expectReferral(
          decide(CutSafetyAnswers(ageYears: 30, warningSigns: {sign})),
          CutSafetyReason.warningSign,
        );
      }
    });

    test('a significant cut in the last 8 weeks', () {
      expectReferral(
        decide(CutSafetyAnswers(ageYears: 30, pastCuts: [
          PastCut(weighInDate: addDays(today, -56), lossFraction: 0.05),
        ])),
        CutSafetyReason.repeatedCuts,
      );
    });

    test('two smaller cuts in the last 8 weeks', () {
      expectReferral(
        decide(CutSafetyAnswers(ageYears: 30, pastCuts: [
          PastCut(weighInDate: addDays(today, -10), lossFraction: 0.02),
          PastCut(weighInDate: addDays(today, -40), lossFraction: 0.03),
        ])),
        CutSafetyReason.repeatedCuts,
      );
    });

    test('old, small, future or invalid past cuts do not count', () {
      final d = decide(CutSafetyAnswers(ageYears: 30, pastCuts: [
        PastCut(weighInDate: addDays(today, -57), lossFraction: 0.08),
        PastCut(weighInDate: addDays(today, -20), lossFraction: 0.03),
        PastCut(weighInDate: addDays(today, 5), lossFraction: 0.08),
        PastCut(weighInDate: addDays(today, -5), lossFraction: double.nan),
        PastCut(weighInDate: addDays(today, -5), lossFraction: 0),
      ]));
      expect(d.outcome, CutSafetyOutcome.cleared);
    });

    test('more than 2% over the limit within 3 days of the weigh-in', () {
      // 70 kg limit: 71.4 kg is exactly 2%.
      for (final days in [0, 1, 2, 3]) {
        expectReferral(
          decide(adult, camp: campIn(days), weight: 71.5),
          CutSafetyReason.overLimitNearWeighIn,
        );
      }
    });

    test('2% or less, or further out, is not a referral by itself', () {
      expect(decide(adult, camp: campIn(2), weight: 71.4).outcome,
          CutSafetyOutcome.cleared);
      expect(decide(adult, camp: campIn(4), weight: 75).outcome,
          CutSafetyOutcome.cleared);
      expect(decide(adult, camp: campIn(2)).outcome, CutSafetyOutcome.cleared);
      expect(decide(adult, camp: campIn(2), weight: double.nan).outcome,
          CutSafetyOutcome.cleared);
      // Weigh-in passed.
      expect(decide(adult, camp: campIn(-1), weight: 80).outcome,
          CutSafetyOutcome.cleared);
    });

    test('a path that needs supervision or is not safe', () {
      for (final status in [
        WeightPathStatus.needsSupervision,
        WeightPathStatus.notSafe,
        WeightPathStatus.needsProfessionalReview,
      ]) {
        expectReferral(decide(adult, status: status),
            CutSafetyReason.pathNeedsSupervision);
      }
      for (final status in [
        WeightPathStatus.onTrack,
        WeightPathStatus.atWeight,
        WeightPathStatus.needsMoreData,
      ]) {
        expect(decide(adult, status: status).outcome, CutSafetyOutcome.cleared);
      }
    });

    test('every reason is listed', () {
      final d = decide(
        CutSafetyAnswers(
          ageYears: 30,
          clinicalFlag: true,
          eatingDisorderSignals: const {EatingDisorderSignal.bingeOrPurge},
          warningSigns: const {CutWarningSign.darkUrine},
          pastCuts: [
            PastCut(weighInDate: addDays(today, -7), lossFraction: 0.06),
          ],
        ),
        camp: campIn(1),
        weight: 75,
        status: WeightPathStatus.notSafe,
      );
      expect(d.reasons, {
        CutSafetyReason.clinicalFlag,
        CutSafetyReason.eatingDisorderSignal,
        CutSafetyReason.warningSign,
        CutSafetyReason.repeatedCuts,
        CutSafetyReason.overLimitNearWeighIn,
        CutSafetyReason.pathNeedsSupervision,
      });
    });
  });
}
