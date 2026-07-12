class Fighter {
  final String name;
  final String tagline;
  final String division;
  final int heightCm;
  final double weightKg;
  final int trainingDays;
  final int totalWorkouts;
  final int wins;
  final int losses;
  final int currentStreak;
  final List<Goal> goals;

  const Fighter({
    required this.name,
    required this.tagline,
    required this.division,
    required this.heightCm,
    required this.weightKg,
    required this.trainingDays,
    required this.totalWorkouts,
    required this.wins,
    required this.losses,
    required this.currentStreak,
    required this.goals,
  });
}

class Goal {
  final String label;
  final double progress; // 0..1
  const Goal(this.label, this.progress);
}
