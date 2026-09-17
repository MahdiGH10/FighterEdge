enum FighterBriefStatus { ready, needsMoreData }

enum FighterBriefFocus {
  firstMeal,
  protein,
  carbohydrates,
  calories,
  onTrack,
}

/// The deterministic, free preview of the premium Fighter Brief.
///
/// This model deliberately contains no AI output. It is safe to calculate
/// locally, cheap to render offline, and keeps the nutrition target engine
/// authoritative while the paid brief adds explanations and adaptations.
class FighterBriefPreview {
  final FighterBriefStatus status;
  final FighterBriefFocus focus;
  final String summary;
  final String nextAction;
  final int? caloriesRemaining;
  final int? proteinRemaining;
  final int? carbohydratesRemaining;
  final int? fatsRemaining;

  const FighterBriefPreview({
    required this.status,
    required this.focus,
    required this.summary,
    required this.nextAction,
    this.caloriesRemaining,
    this.proteinRemaining,
    this.carbohydratesRemaining,
    this.fatsRemaining,
  });

  bool get isReady => status == FighterBriefStatus.ready;

  factory FighterBriefPreview.needsMoreData() {
    return const FighterBriefPreview(
      status: FighterBriefStatus.needsMoreData,
      focus: FighterBriefFocus.firstMeal,
      summary: 'Log a meal to see your first Fighter Brief.',
      nextAction: 'Log a meal to unlock your personalized next step.',
    );
  }
}
