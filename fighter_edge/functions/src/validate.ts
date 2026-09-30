import {
  AiAction,
  AiActionType,
  AiTaskType,
  CornerLine,
  CornerTopic,
  ModelResponse,
} from "./types";

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

const CORNER_TOPICS: readonly CornerTopic[] = [
  "training",
  "fuel",
  "weight",
  "camp",
  "recovery",
];

/** A corner's instructions between rounds: three, never a list. */
export const CORNER_LINE_COUNT = 3;

const MAX_SUMMARY_CHARS = 800;
const MAX_ACTIONS = 6;
const MAX_ACTION_TITLE_CHARS = 80;
const MAX_ACTION_REASON_CHARS = 200;
const MAX_CORNER_LINE_CHARS = 200;

export interface ValidationResult {
  ok: boolean;
  reason?: string;
}

/** Safely parses model output. Never throws — a parse failure is just a rejection. */
/**
 * Parses the model's reply. JSON mode is a request, not a guarantee — some
 * models still wrap the object in a ```json fence or a sentence of preamble.
 * Falls back to the outermost {...} span before giving up; anything that is
 * still not valid JSON is rejected, never repaired.
 */
export function parseModelJson(raw: string): unknown | null {
  try {
    return JSON.parse(raw);
  } catch {
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");
    if (start === -1 || end <= start) return null;
    try {
      return JSON.parse(raw.slice(start, end + 1));
    } catch {
      return null;
    }
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

function isValidCornerLine(value: unknown): value is CornerLine {
  if (typeof value !== "object" || value === null) return false;
  const line = value as Record<string, unknown>;
  return (
    typeof line.topic === "string" &&
    CORNER_TOPICS.includes(line.topic as CornerTopic) &&
    typeof line.text === "string" &&
    line.text.trim().length > 0 &&
    line.text.length <= MAX_CORNER_LINE_CHARS
  );
}

/** Exactly three lines, each on a different topic. */
function isValidCornerLines(value: unknown): value is CornerLine[] {
  if (!Array.isArray(value) || value.length !== CORNER_LINE_COUNT) return false;
  if (!value.every(isValidCornerLine)) return false;
  // Three different things to do, not one thing said three ways.
  return new Set(value.map((line: CornerLine) => line.topic)).size === CORNER_LINE_COUNT;
}

/** Structural shape check — matches master prompt §13.3's schema exactly. */
export function isWellFormedResponse(
  value: unknown,
  task: AiTaskType = "chat",
): value is ModelResponse {
  if (typeof value !== "object" || value === null) return false;
  const response = value as Record<string, unknown>;

  if (task === "cornerBrief") {
    if (response.schemaVersion !== 3 || !isValidCornerLines(response.lines)) {
      return false;
    }
  } else {
    if (response.schemaVersion !== 1) return false;
    if (typeof response.summary !== "string" || response.summary.length === 0) return false;
    if (response.summary.length > MAX_SUMMARY_CHARS) return false;
    if (!Array.isArray(response.actions) || response.actions.length > MAX_ACTIONS) return false;
    if (!response.actions.every(isValidAction)) return false;
  }
  if (!isStringArray(response.warnings)) return false;
  if (typeof response.requiresProfessionalReview !== "boolean") return false;
  if (!isStringArray(response.factsUsed)) return false;
  if (typeof response.contentVersion !== "string") return false;

  return true;
}

/** Everything the athlete can read in [response]. */
export function athleteVisibleText(response: ModelResponse): string[] {
  if (response.schemaVersion === 3) {
    return [...response.lines.map((line) => line.text), ...response.warnings];
  }
  return [
    response.summary,
    ...response.warnings,
    ...response.actions.flatMap((a) => [a.title, a.reason]),
  ];
}

function containsProhibitedContent(response: ModelResponse): boolean {
  const text = athleteVisibleText(response).join(" \n ");
  return PROHIBITED_PATTERNS.some((pattern) => pattern.test(text));
}

/**
 * Every 3+ digit number in the text, with thousands separators removed first.
 * Without that, "2,500 kcal" reads as "500" — a number no fact contains — and
 * an honest answer is rejected as fabricated.
 */
function numbersIn(text: string): number[] {
  const normalised = text.replace(/(\d)[,  '](?=\d{3}\b)/g, "$1");
  return (normalised.match(/\d{3,}/g) ?? []).map(Number);
}

/**
 * Loose defense against fabricated numbers: every 3+ digit number quoted in
 * the response must be a supplied fact, or the difference between two
 * supplied facts. The difference is allowed because "1,080 kcal left today"
 * (target minus consumed) is the single most useful thing a coach can say, and
 * it is arithmetic on the facts, not invention. Anything else — a plausible
 * calorie figure from nowhere — is still rejected.
 *
 * Chat checks its answer; the Corner Brief checks every line and warning,
 * since all of it sits on the Home screen as fact.
 */
function containsFabricatedNumbers(
  response: ModelResponse,
  suppliedFacts: string,
): boolean {
  const facts = [...new Set(numbersIn(suppliedFacts))];
  const allowed = new Set(facts);
  for (const a of facts) {
    for (const b of facts) {
      if (a > b) allowed.add(a - b);
    }
  }
  const content =
    response.schemaVersion === 3
      ? athleteVisibleText(response).join(" ")
      : response.summary;
  return numbersIn(content).some((n) => !allowed.has(n));
}

export function validateResponse(
  parsed: unknown,
  suppliedFactsJson: string,
  task: AiTaskType = "chat",
): ValidationResult {
  if (!isWellFormedResponse(parsed, task)) {
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

/**
 * Only the schema's own fields, for the app. A model can add fields of its
 * own (a stray "summary" on a Corner Brief, say); nothing the checks above
 * did not read ever reaches the athlete.
 */
export function toClientResponse(response: ModelResponse): ModelResponse {
  const common = {
    warnings: response.warnings,
    requiresProfessionalReview: response.requiresProfessionalReview,
    factsUsed: response.factsUsed,
    contentVersion: response.contentVersion,
  };
  if (response.schemaVersion === 3) {
    return {
      schemaVersion: 3,
      lines: response.lines.map(({ topic, text }) => ({ topic, text })),
      ...common,
    };
  }
  return {
    schemaVersion: 1,
    summary: response.summary,
    actions: response.actions.map(({ type, title, reason, recipeIds, mealSlot }) => ({
      type,
      title,
      reason,
      recipeIds,
      ...(mealSlot === undefined ? {} : { mealSlot }),
    })),
    ...common,
  };
}
