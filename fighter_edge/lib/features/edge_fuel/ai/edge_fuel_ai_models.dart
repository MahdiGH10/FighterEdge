/// Pure-Dart response shapes for the EdgeFuel AI gateway (master prompt
/// §13.3). Mirrors `functions/src/types.ts` — keep both in sync. The backend
/// already validated this shape before it reached the client, but parsing
/// here stays defensive (never crash on an unexpected value).
library;

enum AiTaskType { chat, cornerBrief, summarizeTrend }

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

  /// The account hasn't agreed to AI data sharing (the server checks).
  consentRequired,
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

/// What a Corner Brief line is about. Mirrors `functions/src/types.ts`.
enum CornerTopic { training, fuel, weight, camp, recovery }

/// One of the three lines of the daily Corner Brief.
class CornerBriefLine {
  final CornerTopic topic;
  final String text;

  const CornerBriefLine({required this.topic, required this.text});

  /// Null for a line the server would never send: an unknown topic or no
  /// text. Dropping it is safer than guessing what it was about.
  static CornerBriefLine? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final topic =
        CornerTopic.values.where((t) => t.name == raw['topic']).firstOrNull;
    final text = raw['text'];
    if (topic == null || text is! String || text.trim().isEmpty) return null;
    return CornerBriefLine(topic: topic, text: text);
  }
}

class EdgeFuelAiResponse {
  final String summary;
  final List<AiAction> actions;
  final List<String> warnings;
  final bool requiresProfessionalReview;
  final List<String> factsUsed;
  final String contentVersion;

  /// The Corner Brief's lines, most important first. Empty for chat.
  final List<CornerBriefLine> lines;

  const EdgeFuelAiResponse({
    this.summary = '',
    this.actions = const [],
    this.warnings = const [],
    this.requiresProfessionalReview = false,
    this.factsUsed = const [],
    this.contentVersion = '',
    this.lines = const [],
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
      lines: [
        for (final raw in json['lines'] as List? ?? const [])
          if (CornerBriefLine.tryParse(raw) case final line?) line,
      ],
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

  const EdgeFuelAiResult.consentRequired()
      : status = EdgeFuelAiStatus.consentRequired,
        response = null;

  const EdgeFuelAiResult.unavailable()
      : status = EdgeFuelAiStatus.unavailable,
        response = null;
}
