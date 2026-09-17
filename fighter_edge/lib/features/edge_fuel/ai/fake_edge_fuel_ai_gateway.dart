import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_target.dart';
import 'edge_fuel_ai_gateway.dart';
import 'edge_fuel_ai_models.dart';

/// Deterministic fake used in tests and as the offline fallback — no
/// network call, no provider key, same interface the real gateway
/// satisfies. Master prompt §13: "the first release can use a fake or
/// deterministic gateway until backend budget and provider are approved."
class FakeEdgeFuelAiGateway implements EdgeFuelAiGateway {
  final EdgeFuelAiResult Function()? nextResult;

  const FakeEdgeFuelAiGateway({this.nextResult});

  @override
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (nextResult != null) return nextResult!();
    if (!target.isSuccess) return const EdgeFuelAiResult.unavailable();

    return EdgeFuelAiResult.success(EdgeFuelAiResponse(
      summary:
          'Your target is ${target.targetCalories} kcal with ${target.proteinGrams}g '
          'protein, ${target.carbGrams}g carbs, and ${target.fatGrams}g fat. This is a '
          'deterministic estimate, not a diagnosis.',
      warnings: target.warnings,
      factsUsed: const [
        'targetCalories',
        'proteinGrams',
        'carbGrams',
        'fatGrams'
      ],
      contentVersion: 'fake',
    ));
  }

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (nextResult != null) return nextResult!();
    if (!target.isSuccess) return const EdgeFuelAiResult.unavailable();

    return const EdgeFuelAiResult.success(EdgeFuelAiResponse(
      summary: 'Your Fighter Brief is ready for today.',
      brief: FighterBriefSections(
        nextAction: 'Log your next meal so the brief can stay specific.',
        mealSuggestion:
            'Anchor the next meal around a reliable protein source.',
        trainingTiming:
            'Keep your usual training schedule and fuel consistently.',
        weeklyAdjustment:
            'Keep this target steady until you have a full week of data.',
      ),
      factsUsed: [
        'targetCalories',
        'proteinGrams',
        'carbGrams',
        'fatGrams',
      ],
      contentVersion: 'fake-brief',
    ));
  }
}
