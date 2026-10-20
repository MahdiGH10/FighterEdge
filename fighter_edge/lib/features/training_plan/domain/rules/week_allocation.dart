import 'dart:math' as math;

import '../../../fight_camp/domain/calendar.dart';
import '../models/day_type.dart';
import '../models/discipline.dart';
import '../models/experience_level.dart';
import '../models/intensity.dart';
import '../models/plan_inputs.dart';
import '../models/reason_code.dart';
import '../models/session_kind.dart';
import '../models/training_goal.dart';
import '../models/training_phase.dart';
import 'phase_modifiers.dart';

/// What one calendar day of a week was allocated, before any template is
/// chosen. [kind] is null on a rest day.
class DaySlot {
  DaySlot({
    required this.date,
    required this.phase,
    required this.beforeStart,
  });

  final DateTime date;
  final TrainingPhase phase;

  /// The date is before the plan's start date.
  final bool beforeStart;

  DayType type = DayType.rest;
  SessionKind? kind;
  Discipline? discipline;
  Intensity intensity = Intensity.light;
  final List<ReasonCode> reasons = [];

  /// A third hard day in a row was turned into recovery.
  bool spacedRecovery = false;

  void addReason(ReasonCode reason) {
    if (!reasons.contains(reason)) reasons.add(reason);
  }
}

/// A week's allocation: one [DaySlot] per day, plus week-level reasons.
class WeekAllocation {
  const WeekAllocation({
    required this.days,
    required this.reasons,
    required this.weekIndex,
  });

  final List<DaySlot> days;
  final List<ReasonCode> reasons;

  /// Whole weeks from the plan start; 0 for the week containing it. Drives
  /// template rotation and the discipline split.
  final int weekIndex;
}

/// The week number of [weekStart] relative to the plan's [planStart]: 0 for
/// the week that contains the start date, 1 for the next, -1 for the one
/// before.
int weekIndexOf(DateTime planStart, DateTime weekStart) {
  final shifted = daysBetween(planStart, weekStart) + 6;
  return (shifted - shifted % 7) ~/ 7;
}

/// The slot counts of a week.
class SlotMix {
  const SlotMix({
    required this.skill,
    required this.conditioning,
    required this.strength,
  });

  final int skill;
  final int conditioning;
  final int strength;
}

/// How many skill, conditioning and strength sessions [total] sessions split
/// into for [goal]. Proposal section 4 defaults; need owner confirmation.
SlotMix slotMixFor(int total, TrainingGoal goal) {
  if (total <= 0) return const SlotMix(skill: 0, conditioning: 0, strength: 0);
  var conditioning = 0;
  var strength = 0;
  switch (goal) {
    case TrainingGoal.competitionPrep:
    case TrainingGoal.makeWeight:
      conditioning = total >= 4 ? 2 : (total >= 2 ? 1 : 0);
      strength = total >= 5 ? 1 : 0;
    case TrainingGoal.improveTechnique:
      break;
    case TrainingGoal.loseFat:
    case TrainingGoal.buildFitness:
      conditioning = total >= 4 ? 2 : (total >= 2 ? 1 : 0);
      strength = total >= 5 ? 2 : (total >= 3 ? 1 : 0);
    case TrainingGoal.buildMuscle:
      strength = total >= 3 ? 2 : (total >= 2 ? 1 : 0);
      conditioning = total >= 4 ? 1 : 0;
  }
  // Always keep one skill session.
  while (total - conditioning - strength < 1) {
    if (strength > 0) {
      strength--;
    } else {
      conditioning--;
    }
  }
  return SlotMix(
    skill: total - conditioning - strength,
    conditioning: conditioning,
    strength: strength,
  );
}

/// Allocates the seven days from [weekStart]: which days train, and with what
/// kind, discipline and intensity. Pure and deterministic.
WeekAllocation allocateWeek(PlanInputs inputs, DateTime weekStart) {
  final start = calendarDay(weekStart);
  final weekIndex = weekIndexOf(inputs.startDate, start);
  final fight = inputs.fight;
  final weekReasons = <ReasonCode>[];
  void weekReason(ReasonCode reason) {
    if (!weekReasons.contains(reason)) weekReasons.add(reason);
  }

  final slots = [
    for (var i = 0; i < 7; i++)
      DaySlot(
        date: addDays(start, i),
        phase: fight?.phaseOn(addDays(start, i)) ?? TrainingPhase.general,
        beforeStart: daysBetween(inputs.startDate, addDays(start, i)) < 0,
      ),
  ];

  if (fight == null) weekReason(ReasonCode.noFightGeneralPlan);
  weekReason(
    inputs.trainingWeekdays.isEmpty
        ? ReasonCode.noWeekdaysChosen
        : ReasonCode.weekdaysChosen,
  );
  if (slots.first.beforeStart && !slots.last.beforeStart) {
    weekReason(ReasonCode.midWeekStart);
  }

  // Pass 1: fixed days (fight, gym class, forced recovery) and free days.
  final free = <DaySlot>[];
  var gymCount = 0;
  for (final slot in slots) {
    if (slot.beforeStart) continue;
    final modifier = PhaseModifiers.forPhase(slot.phase);
    final chosen = inputs.trainingWeekdays.contains(slot.date.weekday);
    if (slot.phase == TrainingPhase.fightDay) {
      slot.addReason(ReasonCode.fightDayRest);
      continue;
    }
    if (!chosen) continue;
    if (!modifier.trainable) {
      slot.addReason(modifier.reason!);
      continue;
    }
    if (inputs.gymClassWeekdays.contains(slot.date.weekday)) {
      slot
        ..kind = SessionKind.gymClass
        ..intensity = Intensity.moderate.capAt(modifier.maxIntensity)
        ..addReason(ReasonCode.gymClassDay);
      gymCount++;
    } else if (modifier.forcesRecovery) {
      slot
        ..kind = SessionKind.recovery
        ..intensity = Intensity.light;
    } else {
      free.add(slot);
    }
  }

  // Pass 2: split the free days into kinds.
  final total = free.length + gymCount;
  final mix = slotMixFor(total, inputs.goal);
  var skill = mix.skill;
  var conditioning = mix.conditioning;
  var strength = mix.strength;
  if (gymCount > 0) {
    // A gym class is skill work the athlete already gets; fill the other days
    // with the rest of the mix.
    final removed = math.min(gymCount, skill);
    skill -= removed;
    var excess = gymCount - removed;
    while (excess > 0 && strength > 0) {
      strength--;
      excess--;
    }
    while (excess > 0 && conditioning > 0) {
      conditioning--;
      excess--;
    }
    weekReason(ReasonCode.gymClassCountsAsSkill);
  }

  var sparring = 0;
  final sparringDays = <DaySlot>[];
  const sparringGoals = {
    TrainingGoal.competitionPrep,
    TrainingGoal.makeWeight,
    TrainingGoal.improveTechnique,
  };
  if (sparringGoals.contains(inputs.goal) && total >= 3 && free.isNotEmpty) {
    if (!inputs.level.allowsSparring) {
      weekReason(ReasonCode.noSparringForBeginner);
    } else {
      final advanced = inputs.level == ExperienceLevel.advanced ||
          inputs.level == ExperienceLevel.competitor;
      final want = total >= 5 && advanced ? 2 : 1;
      final allowed = [
        for (final s in free)
          if (PhaseModifiers.forPhase(s.phase).allowsSparring) s,
      ];
      final cap = math.max(0, skill - 1);
      sparring = math.min(want, math.min(cap, allowed.length));
      if (cap > 0 && sparring < want && allowed.length < free.length) {
        weekReason(ReasonCode.noSparringInFightWeek);
      }
      // Spread sparring evenly over the days that allow it.
      for (var i = 0; i < sparring; i++) {
        sparringDays
            .add(allowed[((2 * i + 1) * allowed.length) ~/ (2 * sparring)]);
      }
      skill -= sparring;
    }
  }

  for (final slot in sparringDays) {
    slot.kind = SessionKind.sparring;
  }
  final remaining = [
    for (final s in free)
      if (!sparringDays.contains(s)) s,
  ];
  final order = _interleave(skill, conditioning, strength);
  for (var i = 0; i < remaining.length; i++) {
    remaining[i].kind = order[i];
  }

  // Intensity: the kind's default, capped by the day's phase.
  for (final slot in free) {
    final base = switch (slot.kind!) {
      SessionKind.skill => Intensity.moderate,
      _ => Intensity.hard,
    };
    slot.intensity =
        base.capAt(PhaseModifiers.forPhase(slot.phase).maxIntensity);
  }

  // Spacing: never three hard days in a row.
  var hardRun = 0;
  for (final slot in slots) {
    if (slot.kind == null || slot.intensity != Intensity.hard) {
      hardRun = 0;
      continue;
    }
    if (hardRun >= 2) {
      slot
        ..kind = SessionKind.recovery
        ..intensity = Intensity.light
        ..spacedRecovery = true;
      hardRun = 0;
    } else {
      hardRun++;
    }
  }

  // Disciplines: the first listed gets half of the skill-type sessions.
  final skillSlots = [
    for (final s in slots)
      if (s.kind?.isDisciplineSpecific ?? false) s,
  ];
  for (var j = 0; j < skillSlots.length; j++) {
    skillSlots[j].discipline = _disciplineFor(
      inputs.disciplines,
      weekIndex * skillSlots.length + j,
    );
  }

  _attachReasons(inputs, slots, weekReason, total);
  return WeekAllocation(
      days: slots, reasons: weekReasons, weekIndex: weekIndex);
}

/// Skill slots first, then alternating hard slots, so hard days are spread:
/// never two hard slots in a row while a skill slot is left.
List<SessionKind> _interleave(int skill, int conditioning, int strength) {
  final hard = <SessionKind>[];
  var c = conditioning;
  var s = strength;
  while (c > 0 || s > 0) {
    if (c > 0) {
      hard.add(SessionKind.conditioning);
      c--;
    }
    if (s > 0) {
      hard.add(SessionKind.strength);
      s--;
    }
  }
  final result = <SessionKind>[];
  var skillLeft = skill;
  var hardIndex = 0;
  var lastWasHard = true;
  while (skillLeft > 0 || hardIndex < hard.length) {
    final takeSkill =
        skillLeft > 0 && (lastWasHard || hardIndex >= hard.length);
    if (takeSkill) {
      result.add(SessionKind.skill);
      skillLeft--;
      lastWasHard = false;
    } else {
      result.add(hard[hardIndex++]);
      lastWasHard = true;
    }
  }
  return result;
}

/// Over many weeks the first discipline gets half of the slots; the others
/// take turns for the other half: d0 d1 d0 d2 d0 d1 ...
Discipline? _disciplineFor(List<Discipline> disciplines, int index) {
  if (disciplines.isEmpty) return null;
  if (disciplines.length == 1) return disciplines.first;
  final position = index % (2 * (disciplines.length - 1));
  return position.isEven ? disciplines.first : disciplines[1 + position ~/ 2];
}

void _attachReasons(
  PlanInputs inputs,
  List<DaySlot> slots,
  void Function(ReasonCode) weekReason,
  int total,
) {
  final fight = inputs.fight;
  final goal = inputs.goal;
  final multipleDisciplines = inputs.disciplines.length > 1;

  switch (goal) {
    case TrainingGoal.competitionPrep:
    case TrainingGoal.makeWeight:
      if (total >= 4) weekReason(ReasonCode.extraConditioningForCompetition);
    case TrainingGoal.improveTechnique:
      weekReason(ReasonCode.skillOnlyForTechnique);
    case TrainingGoal.loseFat:
    case TrainingGoal.buildFitness:
      weekReason(ReasonCode.conditioningAndStrengthForFitness);
    case TrainingGoal.buildMuscle:
      weekReason(ReasonCode.strengthDaysForMuscle);
  }

  for (final slot in slots) {
    final kind = slot.kind;
    if (kind == null) {
      slot.type = switch (slot.phase) {
        TrainingPhase.fightDay => DayType.fight,
        TrainingPhase.weighIn => DayType.weighIn,
        _ => DayType.rest,
      };
      continue;
    }
    if (slot.spacedRecovery) slot.addReason(ReasonCode.recoveryAfterHardDays);
    switch (kind) {
      case SessionKind.skill:
        if (goal == TrainingGoal.improveTechnique) {
          slot.addReason(ReasonCode.skillOnlyForTechnique);
        }
      case SessionKind.sparring:
        slot.addReason(ReasonCode.sparringIncluded);
      case SessionKind.conditioning:
        if ((goal == TrainingGoal.competitionPrep ||
                goal == TrainingGoal.makeWeight) &&
            total >= 4) {
          slot.addReason(ReasonCode.extraConditioningForCompetition);
        }
        if (goal == TrainingGoal.loseFat || goal == TrainingGoal.buildFitness) {
          slot.addReason(ReasonCode.conditioningAndStrengthForFitness);
        }
      case SessionKind.strength:
        if (goal == TrainingGoal.buildMuscle) {
          slot.addReason(ReasonCode.strengthDaysForMuscle);
        }
        if (goal == TrainingGoal.loseFat || goal == TrainingGoal.buildFitness) {
          slot.addReason(ReasonCode.conditioningAndStrengthForFitness);
        }
      case SessionKind.recovery:
      case SessionKind.gymClass:
        break;
    }
    if (kind.isDisciplineSpecific && multipleDisciplines) {
      slot.addReason(
        slot.discipline == inputs.disciplines.first
            ? ReasonCode.firstDisciplinePriority
            : ReasonCode.disciplineShared,
      );
    }
    final phaseReason = PhaseModifiers.forPhase(slot.phase).reason;
    if (fight != null && phaseReason != null) slot.addReason(phaseReason);

    slot.type = switch (slot.phase) {
      TrainingPhase.weighIn => DayType.weighIn,
      _ => kind == SessionKind.recovery ? DayType.recovery : DayType.training,
    };
  }
}
