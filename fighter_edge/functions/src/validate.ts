import { AiAction, AiActionType, AiResponse } from "./types";

/**
 * Response validation gate (master prompt §13.3). The model's raw output is
 * never trusted — anything that fails here triggers the caller's
 * deterministic fallback instead of reaching the user. Whole-response
 * rejection only (no partial edits), so there is no way for a model to learn
 * "which half gets through."
 */

const PROHIBITED_PATTERNS: RegExp[] = [
  /dehydrat/i,
  /purg(e|ing)/i,
  /laxative/i,
  /diuretic/i,
  /sauna/i,
  /starv/i,
  /rapid\s+(weight\s+)?cut/i,
  /water\s*fast/i,
  /cut\s+water/i,
];

const ACTION_TYPES: readonly AiActionType[] = [
  "meal",
  "recipe",
  "timing",
  "shopping",
  "logging",
  "recovery",
];

const MAX_SUMMARY_CHARS = 800;
const MAX_ACTIONS = 6;
const MAX_ACTION_TITLE_CHARS = 80;
const MAX_ACTION_REASON_CHARS = 200;

export interface ValidationResult {
  ok: boolean;
  reason?: string;
}

/** Safely parses model output. Never throws — a parse failure is just a rejection. */
export function parseModelJson(raw: string): unknown | null {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((v) => typeof v === "string");
}

function isValidAction(value: unknown): value is AiAction {
  if (typeof value !== "object" || value === null) return false;
  const action = value as Record<string, unknown>;
  if (typeof action.type !== "string" || !ACTION_TYPES.includes(action.type as AiActionType)) {
    return false;
  }
  if (typeof action.title !== "string" || action.title.length === 0) return false;
  if (typeof action.title === "string" && action.title.length > MAX_ACTION_TITLE_CHARS) {
    return false;
  }
  if (typeof action.reason !== "string" || action.reason.length > MAX_ACTION_REASON_CHARS) {
    return false;
  }
  // No recipe catalog exists yet (EF-3) — any recipe reference is unverifiable,
  // so it's rejected outright rather than trusted.
  if (!isStringArray(action.recipeIds) || action.recipeIds.length > 0) return false;
  if (action.mealSlot !== undefined && typeof action.mealSlot !== "string") return false;
  return true;
}

/** Structural shape check — matches master prompt §13.3's schema exactly. */
export function isWellFormedResponse(value: unknown): value is AiResponse {
  if (typeof value !== "object" || value === null) return false;
  const response = value as Record<string, unknown>;

  if (response.schemaVersion !== 1) return false;
  if (typeof response.summary !== "string" || response.summary.length === 0) return false;
  if (response.summary.length > MAX_SUMMARY_CHARS) return false;
  if (!Array.isArray(response.actions) || response.actions.length > MAX_ACTIONS) return false;
  if (!response.actions.every(isValidAction)) return false;
  if (!isStringArray(response.warnings)) return false;
  if (typeof response.requiresProfessionalReview !== "boolean") return false;
  if (!isStringArray(response.factsUsed)) return false;
  if (typeof response.contentVersion !== "string") return false;

  return true;
}

function containsProhibitedContent(response: AiResponse): boolean {
  const text = [
    response.summary,
    ...response.warnings,
    ...response.actions.flatMap((a) => [a.title, a.reason]),
  ].join(" \n ");
  return PROHIBITED_PATTERNS.some((pattern) => pattern.test(text));
}

/**
 * Loose defense against fabricated numbers: every 3+ digit number quoted in
 * the summary must appear somewhere in the supplied facts. Not a perfect
 * guarantee, but it catches the common failure mode of a model inventing a
 * plausible-looking calorie/macro figure.
 */
function containsFabricatedNumbers(
  response: AiResponse,
  suppliedFacts: string,
): boolean {
  const suppliedNumbers = new Set(suppliedFacts.match(/\d{3,}/g) ?? []);
  const summaryNumbers = response.summary.match(/\d{3,}/g) ?? [];
  return summaryNumbers.some((n) => !suppliedNumbers.has(n));
}

export function validateResponse(
  parsed: unknown,
  suppliedFactsJson: string,
): ValidationResult {
  if (!isWellFormedResponse(parsed)) {
    return { ok: false, reason: "malformed_schema" };
  }
  if (containsProhibitedContent(parsed)) {
    return { ok: false, reason: "prohibited_content" };
  }
  if (containsFabricatedNumbers(parsed, suppliedFactsJson)) {
    return { ok: false, reason: "fabricated_numbers" };
  }
  return { ok: true };
}
