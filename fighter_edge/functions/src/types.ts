/**
 * Request/response shapes for the EdgeFuel AI gateway (master prompt §13.3).
 * Mirrors the Dart models in
 * lib/features/edge_fuel/ai/edge_fuel_ai_models.dart — keep both in sync.
 */

export type AiTaskType = "explainPlan" | "fighterBrief" | "summarizeTrend";

/** Minimum-necessary context sent from Flutter — never raw user PII beyond this. */
export interface AiRequest {
  task: AiTaskType;
  target: Record<string, unknown>;
  day?: Record<string, unknown> | null;
  foodPreferences?: {
    dietType?: string | null;
    allergens?: string[];
    dislikedFoods?: string[];
  } | null;
}

export type AiActionType =
  | "meal"
  | "recipe"
  | "timing"
  | "shopping"
  | "logging"
  | "recovery";

export interface AiAction {
  type: AiActionType;
  title: string;
  reason: string;
  recipeIds: string[];
  mealSlot?: string;
}

export interface AiResponse {
  schemaVersion: 1 | 2;
  summary: string;
  actions: AiAction[];
  warnings: string[];
  requiresProfessionalReview: boolean;
  factsUsed: string[];
  contentVersion: string;
  brief?: FighterBriefSections;
}

export interface FighterBriefSections {
  nextAction: string;
  mealSuggestion: string;
  trainingTiming: string;
  weeklyAdjustment: string;
}
