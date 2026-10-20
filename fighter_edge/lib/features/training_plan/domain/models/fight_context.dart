import '../../../fight_camp/domain/calendar.dart';
import '../../../fight_camp/domain/fight_camp.dart';
import 'training_phase.dart';

/// The athlete's booked fight, as the training plan needs it. Optional: with
/// no [FightContext] the plan is a general one.
///
/// Wraps the existing [FightCamp] so the dates, weigh-in rules and
/// [CampPhase] are not duplicated here.
class FightContext {
  const FightContext(this.camp);

  final FightCamp camp;

  DateTime get fightDate => camp.fightDate;
  DateTime get weighInDate => camp.weighInDate;

  /// Days between the weigh-in and the fight (0 for a same-day weigh-in).
  int get weighInOffsetDays => daysBetween(camp.weighInDate, camp.fightDate);

  /// Days before the fight at which each phase begins. App defaults taken
  /// from the proposal (general >8 wk, build 8-3, peak 3-1.5, taper last ~10
  /// days); they need coach review.
  static const int buildStartsDaysBeforeFight = 56;
  static const int peakStartsDaysBeforeFight = 21;
  static const int taperStartsDaysBeforeFight = 10;

  /// The training phase [date] falls in.
  TrainingPhase phaseOn(DateTime date) {
    final toFight = camp.daysToFight(date);
    if (toFight == 0) return TrainingPhase.fightDay;
    switch (camp.phaseOn(date)) {
      case CampPhase.postFight:
        return TrainingPhase.postFight;
      case CampPhase.refuel:
        return TrainingPhase.refuel;
      case CampPhase.offCamp:
        return TrainingPhase.general;
      case CampPhase.camp:
      case CampPhase.fightWeek:
        if (camp.daysToWeighIn(date) == 0) return TrainingPhase.weighIn;
        if (toFight <= taperStartsDaysBeforeFight) return TrainingPhase.taper;
        if (toFight <= peakStartsDaysBeforeFight) return TrainingPhase.peak;
        if (toFight <= buildStartsDaysBeforeFight) return TrainingPhase.build;
        return TrainingPhase.general;
    }
  }

  @override
  bool operator ==(Object other) => other is FightContext && other.camp == camp;

  @override
  int get hashCode => camp.hashCode;
}
