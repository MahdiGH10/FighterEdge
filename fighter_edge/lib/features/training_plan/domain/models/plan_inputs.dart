import '../../../fight_camp/domain/calendar.dart';
import 'date_key.dart';
import 'discipline.dart';
import 'experience_level.dart';
import 'fight_context.dart';
import 'training_goal.dart';

/// Everything the generator reads. Same inputs + same template set give the
/// same week, byte for byte.
class PlanInputs {
  /// Weekdays are `DateTime.monday`..`DateTime.sunday` (1-7); anything else is
  /// dropped. Duplicate disciplines are dropped, keeping the first. A
  /// [sessionMinutes] outside [minSessionMinutes]..[maxSessionMinutes] is
  /// ignored.
  PlanInputs({
    required Iterable<Discipline> disciplines,
    required this.goal,
    required this.level,
    required Iterable<int> weekdays,
    Iterable<int> gymClassWeekdays = const [],
    int? sessionMinutes,
    required DateTime startDate,
    this.fight,
  })  : disciplines = List.unmodifiable(<Discipline>{...disciplines}),
        gymClassWeekdays = Set.unmodifiable(_validWeekdays(gymClassWeekdays)),
        trainingWeekdays = Set.unmodifiable({
          ..._validWeekdays(weekdays),
          ..._validWeekdays(gymClassWeekdays),
        }),
        sessionMinutes = sessionMinutes != null &&
                sessionMinutes >= minSessionMinutes &&
                sessionMinutes <= maxSessionMinutes
            ? sessionMinutes
            : null,
        startDate = calendarDay(startDate);

  static const int minSessionMinutes = 15;
  static const int maxSessionMinutes = 180;

  /// In priority order: the first gets about half the skill sessions.
  final List<Discipline> disciplines;
  final TrainingGoal goal;
  final ExperienceLevel level;

  /// Every day the athlete trains: the chosen weekdays plus the gym-class
  /// weekdays (a gym-class day is a training day even if not listed).
  final Set<int> trainingWeekdays;

  /// Weekdays that are a class at the athlete's gym (proposal decision 3).
  final Set<int> gymClassWeekdays;

  /// The athlete's own session length, or null to use the template's.
  final int? sessionMinutes;

  /// Nothing before this date is planned or counts against the athlete.
  final DateTime startDate;

  /// Optional. Without it the plan is a general one.
  final FightContext? fight;

  static Iterable<int> _validWeekdays(Iterable<int> days) =>
      days.where((d) => d >= DateTime.monday && d <= DateTime.sunday);

  /// A stable text form of every field, used for [hash].
  String get canonical {
    final days = trainingWeekdays.toList()..sort();
    final gym = gymClassWeekdays.toList()..sort();
    final camp = fight?.camp;
    final fightKey = camp == null
        ? ''
        : '${dateKey(camp.fightDate)}/${dateKey(camp.weighInDate)}/'
            '${camp.campWeeks}';
    return [
      'd=${disciplines.map((d) => d.name).join(',')}',
      'g=${goal.name}',
      'l=${level.name}',
      'w=${days.join(',')}',
      'c=${gym.join(',')}',
      'm=${sessionMinutes ?? ''}',
      's=${dateKey(startDate)}',
      'f=$fightKey',
    ].join(';');
  }

  /// An 8-digit hex fingerprint (FNV-1a) of [canonical].
  String get hash {
    var h = 0x811c9dc5;
    for (final unit in canonical.codeUnits) {
      h ^= unit;
      h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) &
          0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
