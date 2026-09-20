/// A written technique drill: what to do, what to watch for, and how to put
/// reps on it. Pure data — no Flutter, no persistence.
class Drill {
  final String id;
  final DrillDiscipline discipline;

  /// Stable path in the coach-owned [TechniqueTaxonomy]. A discipline is a
  /// useful drill-card label; this key is the more specific curriculum path
  /// that powers Train's Striking/Grappling browser.
  final String categoryId;

  /// The sport the technique is taught in, shown as a small label
  /// ("BOXING", "MUAY THAI").
  final String sport;
  final String title;

  /// One sentence on why the technique matters.
  final String summary;
  final DrillLevel level;
  final List<String> keyPoints;
  final List<String> commonMistakes;

  /// How to put reps on it, in plain words: rounds, reps, solo or partner.
  final String prescription;
  final bool needsPartner;

  /// Starter drills are free; the rest of the library is Pro.
  final bool starter;

  const Drill({
    required this.id,
    required this.discipline,
    required this.categoryId,
    required this.sport,
    required this.title,
    required this.summary,
    required this.level,
    required this.keyPoints,
    required this.commonMistakes,
    required this.prescription,
    this.needsPartner = false,
    this.starter = false,
  });
}

enum DrillDiscipline { striking, wrestling, bjj, clinch }

enum DrillLevel { fundamentals, intermediate }

/// How far along the athlete says they are with a drill. Self-reported, in
/// the order a technique is actually learned.
enum DrillProgress { none, studied, drilled, sharp }

extension DrillDisciplineLabel on DrillDiscipline {
  String get label => switch (this) {
        DrillDiscipline.striking => 'Striking',
        DrillDiscipline.wrestling => 'Wrestling',
        DrillDiscipline.bjj => 'BJJ',
        DrillDiscipline.clinch => 'Clinch',
      };
}

extension DrillLevelLabel on DrillLevel {
  String get label => switch (this) {
        DrillLevel.fundamentals => 'Fundamentals',
        DrillLevel.intermediate => 'Intermediate',
      };
}

extension DrillProgressLabel on DrillProgress {
  String get label => switch (this) {
        DrillProgress.none => 'Not started',
        DrillProgress.studied => 'Studied',
        DrillProgress.drilled => 'Drilled',
        DrillProgress.sharp => 'Sharp',
      };
}
