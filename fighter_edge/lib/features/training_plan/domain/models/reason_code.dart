/// Why the generator decided something. The plan reveal turns each code into
/// one l10n sentence; the domain only emits the code.
enum ReasonCode {
  // Week shape.
  weekdaysChosen,
  noWeekdaysChosen,
  midWeekStart,
  noFightGeneralPlan,

  // Disciplines.
  firstDisciplinePriority,
  disciplineShared,

  // Goal.
  extraConditioningForCompetition,
  skillOnlyForTechnique,
  conditioningAndStrengthForFitness,
  strengthDaysForMuscle,

  // Level and sparring.
  noSparringForBeginner,
  sparringIncluded,
  noSparringInFightWeek,

  // Gym classes.
  gymClassDay,
  gymClassCountsAsSkill,

  // Spacing.
  recoveryAfterHardDays,

  // Fight phase.
  generalPhase,
  buildPhase,
  peakPhase,
  taperFightWeek,
  weighInLight,
  refuelDayRest,
  fightDayRest,
  postFightRecovery,

  // Templates and length.
  templateRotation,
  templateFallback,
  sparringFallbackToSkill,
  noTemplateAvailable,
  sessionMinutesOverride,
}
