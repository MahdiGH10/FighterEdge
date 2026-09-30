import '../../daily_snapshot/domain/daily_snapshot.dart';
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
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
    DailySnapshot? today,
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
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) async {
    if (nextResult != null) return nextResult!();
    if (!target.isSuccess) return const EdgeFuelAiResult.unavailable();

    return const EdgeFuelAiResult.success(EdgeFuelAiResponse(
      lines: [
        CornerBriefLine(
          topic: CornerTopic.fuel,
          text: 'Log your next meal so your corner can stay specific.',
        ),
        CornerBriefLine(
          topic: CornerTopic.training,
          text: 'Keep your usual session and eat a few hours before it.',
        ),
        CornerBriefLine(
          topic: CornerTopic.recovery,
          text: "Make tonight's dinner protein-first.",
        ),
      ],
      factsUsed: [
        'targetCalories',
        'proteinGrams',
      ],
      contentVersion: 'fake-corner-brief',
    ));
  }
}
