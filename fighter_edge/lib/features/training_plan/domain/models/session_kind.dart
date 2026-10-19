/// What a planned session is for.
enum SessionKind {
  skill,
  sparring,
  conditioning,
  strength,
  recovery,

  /// A class the athlete attends at their gym. The app prescribes nothing and
  /// only logs it and plans around it (proposal decision 3).
  gymClass;

  /// The l10n key used when no template could be found for a slot. These are
  /// also the titles of the launch placeholder set.
  String get fallbackTitleKey => switch (this) {
        SessionKind.skill => 'tplGenericSkill',
        SessionKind.sparring => 'tplGenericSparring',
        SessionKind.conditioning => 'tplGenericConditioning',
        SessionKind.strength => 'tplGenericStrength',
        SessionKind.recovery => 'tplGenericRecovery',
        SessionKind.gymClass => 'tplGenericGymClass',
      };

  /// Skill and sparring sessions are split between the athlete's disciplines.
  bool get isDisciplineSpecific =>
      this == SessionKind.skill || this == SessionKind.sparring;
}
