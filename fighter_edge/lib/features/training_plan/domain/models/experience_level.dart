/// How experienced the athlete is. Picks template bands and gates sparring.
enum ExperienceLevel {
  beginner,
  intermediate,
  advanced,
  competitor;

  /// Session length in minutes when the athlete sets none (proposal
  /// decision 5). Needs owner confirmation.
  int get defaultSessionMinutes => switch (this) {
        ExperienceLevel.beginner => 45,
        ExperienceLevel.intermediate => 60,
        ExperienceLevel.advanced || ExperienceLevel.competitor => 75,
      };

  /// Beginners never get sparring (proposal decision 4).
  bool get allowsSparring => this != ExperienceLevel.beginner;
}
