/// Pure-Dart response shapes for the EdgeFuel AI gateway (master prompt
/// §13.3). Mirrors `functions/src/types.ts` — keep both in sync. The backend
/// already validated this shape before it reached the client, but parsing
/// here stays defensive (never crash on an unexpected value).
library;

enum AiTaskType { chat, fighterBrief, summarizeTrend }

enum AiActionType { meal, recipe, timing, shopping, logging, recovery }

enum ChatRole { user, assistant }

/// One turn of a chat conversation, sent to the server as bounded context for
/// a follow-up message. Mirrors `functions/src/types.ts`'s `ChatTurn`.
class ChatTurn {
  final ChatRole role;
  final String content;

  const ChatTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};
}

/// Discriminates the gateway call's outcome so the UI can show the right
/// state (master prompt §14: "AI unavailable", "AI quota reached").
enum EdgeFuelAiStatus {
  success,
  quotaReached,
  entitlementRequired,
  unavailable,
}

class AiAction {
  final AiActionType type;
  final String title;
  final String reason;
  final List<String> recipeIds;
  final String? mealSlot;

  const AiAction({
    required this.type,
    required this.title,
    required this.reason,
    this.recipeIds = const [],
    this.mealSlot,
  });

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: AiActionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AiActionType.logging,
      ),
      title: json['title'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      recipeIds: List<String>.from(json['recipeIds'] as List? ?? const []),
      mealSlot: json['mealSlot'] as String?,
    );
  }
}

/// Version-2 sections returned only by the premium Fighter Brief task.
class FighterBriefSections {
  final String nextAction;
  final String mealSuggestion;
  final String trainingTiming;
  final String weeklyAdjustment;

  const FighterBriefSections({
    required this.nextAction,
    required this.mealSuggestion,
    required this.trainingTiming,
    required this.weeklyAdjustment,
  });

  factory FighterBriefSections.fromJson(Map<String, dynamic> json) {
    return FighterBriefSections(
      nextAction: json['nextAction'] as String? ?? '',
      mealSuggestion: json['mealSuggestion'] as String? ?? '',
      trainingTiming: json['trainingTiming'] as String? ?? '',
      weeklyAdjustment: json['weeklyAdjustment'] as String? ?? '',
    );
  }
}

class EdgeFuelAiResponse {
  final String summary;
  final List<AiAction> actions;
  final List<String> warnings;
  final bool requiresProfessionalReview;
  final List<String> factsUsed;
  final String contentVersion;
  final FighterBriefSections? brief;

  const EdgeFuelAiResponse({
    required this.summary,
    this.actions = const [],
    this.warnings = const [],
    this.requiresProfessionalReview = false,
    this.factsUsed = const [],
    this.contentVersion = '',
    this.brief,
  });

  factory EdgeFuelAiResponse.fromJson(Map<String, dynamic> json) {
    return EdgeFuelAiResponse(
      summary: json['summary'] as String? ?? '',
      actions: [
        for (final raw in json['actions'] as List? ?? const [])
          AiAction.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      warnings: List<String>.from(json['warnings'] as List? ?? const []),
      requiresProfessionalReview:
          json['requiresProfessionalReview'] as bool? ?? false,
      factsUsed: List<String>.from(json['factsUsed'] as List? ?? const []),
      contentVersion: json['contentVersion'] as String? ?? '',
      brief: json['brief'] is Map
          ? FighterBriefSections.fromJson(
              Map<String, dynamic>.from(json['brief'] as Map),
            )
          : null,
    );
  }
}

/// Typed result of a gateway call — the UI always has a definite state to
/// render, never a raw exception.
class EdgeFuelAiResult {
  final EdgeFuelAiStatus status;
  final EdgeFuelAiResponse? response;

  const EdgeFuelAiResult.success(EdgeFuelAiResponse this.response)
      : status = EdgeFuelAiStatus.success;

  const EdgeFuelAiResult.quotaReached()
      : status = EdgeFuelAiStatus.quotaReached,
        response = null;

  const EdgeFuelAiResult.entitlementRequired()
      : status = EdgeFuelAiStatus.entitlementRequired,
        response = null;

  const EdgeFuelAiResult.unavailable()
      : status = EdgeFuelAiStatus.unavailable,
        response = null;
}
