import '../calendar.dart';
import '../camp_screening.dart';
import '../fight_camp.dart';
import '../weight_cut_policy.dart';
import '../weight_path.dart';

/// Warning signs asked at every cut entry (Fuel V2 rule 5; combat research
/// §5.2). The app keeps only whether a sign was reported, never a
/// description.
enum CutWarningSign {
  /// Fainted recently.
  fainting,

  /// Dark urine for days.
  darkUrine,

  dizziness,
  chestPainOrPalpitations,
  repeatedVomiting,

  /// Periods stopped or became irregular.
  missedPeriods,

  stressFracture,

  /// Heat exhaustion or heat stroke at any time.
  heatIllnessHistory,

  /// Taking diuretics, laxatives or prescribed stimulants now.
  diureticLaxativeOrStimulantUse,
}

/// Eating-disorder signals from the screen. A signal, not a diagnosis.
enum EatingDisorderSignal {
  /// Eating-disorder history or current symptoms, as in the Fuel setup.
  historyOrSymptoms,

  /// Binge eating or purging.
  bingeOrPurge,

  /// Fear of eating, or of losing control around food.
  fearOfEating,

  /// Distress about body shape or weight.
  bodyImageDistress,
}

/// A cut the fighter made for an earlier weigh-in.
class PastCut {
  const PastCut({required this.weighInDate, required this.lossFraction});

  final DateTime weighInDate;

  /// Body mass lost for that weigh-in, as a share of the weight the cut
  /// started from (0.05 is 5%).
  final double lossFraction;
}

/// What the fighter told the safety screen. Booleans and enums only.
class CutSafetyAnswers {
  const CutSafetyAnswers({
    this.ageYears,
    this.clinicalFlag = false,
    this.eatingDisorderSignals = const {},
    this.warningSigns = const {},
    this.pastCuts = const [],
  });

  /// Null when the fighter has not given an age.
  final int? ageYears;

  /// Any Fuel clinical flag: pregnancy or breastfeeding, medicated
  /// diabetes, kidney or serious liver disease, eating-disorder history, or
  /// another clinician-managed diet.
  final bool clinicalFlag;

  final Set<EatingDisorderSignal> eatingDisorderSignals;
  final Set<CutWarningSign> warningSigns;
  final List<PastCut> pastCuts;
}

enum CutSafetyOutcome {
  /// Under 18 or no valid age (rule 4). No cut tools at all.
  noCutTools,

  /// Show the "talk to a professional" card instead of cut tools (rule 5).
  talkToProfessional,

  /// Cut tools may show.
  cleared,
}

enum CutSafetyReason {
  underAge,
  ageUnknown,
  clinicalFlag,
  eatingDisorderSignal,

  /// Any [CutWarningSign], such as fainting or dark urine.
  warningSign,

  /// Another significant cut, or several cuts, within
  /// [CutSafetyScreen.repeatedCutWindowDays].
  repeatedCuts,

  /// More than [CutSafetyScreen.overLimitFraction] over the limit within
  /// [CutSafetyScreen.overLimitWindowDays] of the weigh-in.
  overLimitNearWeighIn,

  /// The weight path needs a supervised water cut or is not safe.
  pathNeedsSupervision,
}

class CutSafetyDecision {
  const CutSafetyDecision._(this.outcome, this.reasons);

  final CutSafetyOutcome outcome;

  /// Why: the age reason alone for [CutSafetyOutcome.noCutTools], every
  /// referral reason for [CutSafetyOutcome.talkToProfessional], empty when
  /// cleared.
  final Set<CutSafetyReason> reasons;

  bool get showCutTools => outcome == CutSafetyOutcome.cleared;

  bool get showTalkToProfessional =>
      outcome == CutSafetyOutcome.talkToProfessional;

  /// The existing camp screening state this decision maps to. Missing age
  /// fails closed as [CampScreening.pending].
  CampScreening get campScreening => switch (outcome) {
        CutSafetyOutcome.noCutTools => CampScreening.pending,
        CutSafetyOutcome.talkToProfessional =>
          CampScreening.needsProfessionalReview,
        CutSafetyOutcome.cleared => CampScreening.cleared,
      };
}

/// Decides, on every cut entry, whether cut tools may show, or the
/// "talk to a professional" card shows instead (Fuel V2 rules 4 and 5).
///
/// Pure Dart: no clock, no platform, no network. Callers pass [today].
// dietitian sign-off pending: the referral triggers and thresholds below
// (5% significant cut, 8-week window, 2% over the limit within 3 days) are
// from the combat research §5.2 and need a sports dietitian's review.
class CutSafetyScreen {
  const CutSafetyScreen._();

  /// A cut of at least this share of body mass counts as significant.
  static const double significantCutFraction = 0.05;

  /// Cuts inside this many days count toward weight cycling (8 weeks).
  static const int repeatedCutWindowDays = 56;

  /// This many past cuts of any size in the window also count.
  static const int repeatedCutCount = 2;

  /// "More than 2% over the limit within about 3 days" (rule 5).
  static const double overLimitFraction = 0.02;
  static const int overLimitWindowDays = 3;

  /// Rule 4: under-18 or unknown age gets no cut tools.
  static bool cutToolsAllowedForAge(int? ageYears) =>
      ageYears != null &&
      ageYears >= WeightCutPolicy.minimumAgeYears &&
      ageYears <= 120;

  /// [currentWeightKg] should be the trend weight. [camp] and
  /// [currentWeightKg] are optional: without them the weight checks are
  /// skipped, the screen answers still apply. [pathStatus] is the weight
  /// path's status, when there is one.
  static CutSafetyDecision evaluate({
    required CutSafetyAnswers answers,
    required DateTime today,
    FightCamp? camp,
    double? currentWeightKg,
    WeightPathStatus? pathStatus,
  }) {
    final age = answers.ageYears;
    if (!cutToolsAllowedForAge(age)) {
      final reason =
          age != null && age > 0 && age < WeightCutPolicy.minimumAgeYears
              ? CutSafetyReason.underAge
              : CutSafetyReason.ageUnknown;
      return CutSafetyDecision._(CutSafetyOutcome.noCutTools, {reason});
    }

    final reasons = <CutSafetyReason>{
      if (answers.clinicalFlag) CutSafetyReason.clinicalFlag,
      if (answers.eatingDisorderSignals.isNotEmpty)
        CutSafetyReason.eatingDisorderSignal,
      if (answers.warningSigns.isNotEmpty) CutSafetyReason.warningSign,
      if (_repeatedCuts(answers.pastCuts, today)) CutSafetyReason.repeatedCuts,
      if (camp != null && _overLimitNearWeighIn(camp, currentWeightKg, today))
        CutSafetyReason.overLimitNearWeighIn,
      if (pathStatus == WeightPathStatus.needsSupervision ||
          pathStatus == WeightPathStatus.notSafe ||
          pathStatus == WeightPathStatus.needsProfessionalReview)
        CutSafetyReason.pathNeedsSupervision,
    };
    return reasons.isEmpty
        ? const CutSafetyDecision._(CutSafetyOutcome.cleared, {})
        : CutSafetyDecision._(CutSafetyOutcome.talkToProfessional, reasons);
  }

  static bool _repeatedCuts(List<PastCut> cuts, DateTime today) {
    final recent = cuts.where((cut) {
      final ago = daysBetween(cut.weighInDate, today);
      return ago >= 0 &&
          ago <= repeatedCutWindowDays &&
          cut.lossFraction.isFinite &&
          cut.lossFraction > 0;
    }).toList();
    return recent.length >= repeatedCutCount ||
        recent.any((cut) => cut.lossFraction >= significantCutFraction);
  }

  static bool _overLimitNearWeighIn(
    FightCamp camp,
    double? currentWeightKg,
    DateTime today,
  ) {
    final current = currentWeightKg;
    if (current == null || !current.isFinite || current <= 0) return false;
    final days = camp.daysToWeighIn(today);
    if (days < 0 || days > overLimitWindowDays) return false;
    return current > camp.weightLimitKg * (1 + overLimitFraction) + 1e-9;
  }
}
