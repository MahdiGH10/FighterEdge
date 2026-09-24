/**
 * Builds the facts the model sees from the client's request (audit S-4,
 * S-5). The app sends whole domain objects (targets, the day's food log and
 * food preferences). The model needs only a few fields of each, so this keeps
 * those fields, drops the rest (IDs, timestamps, free-text notes, schema
 * metadata), and bounds every string and list.
 *
 * That does three jobs:
 * - Cost: a client can no longer send megabytes of "facts" to be turned into
 *   tokens on our account.
 * - Privacy: less personal data leaves our servers (data minimisation).
 * - Safety: user-typed text reaches the prompt only as short, bounded strings.
 *
 * The fabricated-number check (validate.ts) only accepts numbers that appear
 * in these facts, so everything the model may quote must survive here.
 */

/**
 * Hard ceiling on the serialized facts, after trimming: room for a heavy day
 * (40 entries with long names and full food preferences), about 3k tokens.
 */
export const MAX_FACTS_BYTES = 12 * 1024;

const MAX_ENTRIES = 40;
const MAX_ENTRY_NAME = 60;
const MAX_TARGET_NOTES = 10;
const MAX_TARGET_NOTE = 160;
const MAX_PREFERENCE_ITEMS = 20;
const MAX_PREFERENCE_ITEM = 40;
const MAX_SHORT_STRING = 40;

const TARGET_NUMBERS = [
  "policyVersion",
  "estimatedRmrKcal",
  "maintenanceRangeLowKcal",
  "maintenanceRangeHighKcal",
  "targetCalories",
  "proteinGrams",
  "fatGrams",
  "carbGrams",
  "fiberGramsLow",
  "fiberGramsHigh",
  "proteinReferenceWeightKg",
  "activityCoefficientUsed",
  "appliedGoalAdjustmentPercent",
] as const;
const TARGET_STRINGS = ["status", "equationProfileUsed", "confidence"] as const;
const MACROS = ["calories", "proteinGrams", "carbGrams", "fatGrams"] as const;

export interface AiFacts {
  target: Record<string, unknown>;
  day: Record<string, unknown> | null;
  foodPreferences: {
    dietType: string | null;
    allergens: string[];
    dislikedFoods: string[];
  } | null;
}

export type FactsResult =
  | { ok: true; facts: AiFacts; json: string }
  | { ok: false; reason: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function shortString(value: unknown, max: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed.slice(0, max);
}

function stringList(value: unknown, maxItems: number, maxLength: number): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  for (const item of value) {
    const text = shortString(item, maxLength);
    if (text !== undefined) out.push(text);
    if (out.length === maxItems) break;
  }
  return out;
}

function pickNumbers(source: Record<string, unknown>, keys: readonly string[]) {
  const out: Record<string, number> = {};
  for (const key of keys) {
    const value = finiteNumber(source[key]);
    if (value !== undefined) out[key] = value;
  }
  return out;
}

function trimTarget(raw: Record<string, unknown>): Record<string, unknown> {
  const target: Record<string, unknown> = pickNumbers(raw, TARGET_NUMBERS);
  for (const key of TARGET_STRINGS) {
    const value = shortString(raw[key], MAX_SHORT_STRING);
    if (value !== undefined) target[key] = value;
  }
  target.reasons = stringList(raw.reasons, MAX_TARGET_NOTES, MAX_TARGET_NOTE);
  target.warnings = stringList(raw.warnings, MAX_TARGET_NOTES, MAX_TARGET_NOTE);
  return target;
}

function trimDay(raw: Record<string, unknown>): Record<string, unknown> {
  const day: Record<string, unknown> = {};
  const localDate = shortString(raw.localDate, 10);
  if (localDate !== undefined) day.localDate = localDate;
  const coverage = shortString(raw.loggingCoverage, MAX_SHORT_STRING);
  if (coverage !== undefined) day.loggingCoverage = coverage;
  if (isRecord(raw.totals)) day.totals = pickNumbers(raw.totals, MACROS);

  const entries: Record<string, unknown>[] = [];
  if (Array.isArray(raw.entries)) {
    for (const item of raw.entries) {
      if (!isRecord(item)) continue;
      const entry: Record<string, unknown> = {
        name: shortString(item.name, MAX_ENTRY_NAME) ?? "Food",
        ...pickNumbers(item, MACROS),
      };
      if (typeof item.consumed === "boolean") entry.consumed = item.consumed;
      entries.push(entry);
      if (entries.length === MAX_ENTRIES) break;
    }
  }
  day.entries = entries;
  return day;
}

function trimPreferences(raw: unknown): AiFacts["foodPreferences"] {
  if (!isRecord(raw)) return null;
  return {
    dietType: shortString(raw.dietType, MAX_SHORT_STRING) ?? null,
    allergens: stringList(raw.allergens, MAX_PREFERENCE_ITEMS, MAX_PREFERENCE_ITEM),
    dislikedFoods: stringList(raw.dislikedFoods, MAX_PREFERENCE_ITEMS, MAX_PREFERENCE_ITEM),
  };
}

/**
 * Trims the client's target, day and preferences to what the model needs.
 * Fails only when the target is missing or has no calorie target, or when
 * the trimmed facts are still larger than [MAX_FACTS_BYTES].
 */
export function buildAiFacts(request: {
  target?: unknown;
  day?: unknown;
  foodPreferences?: unknown;
}): FactsResult {
  if (!isRecord(request.target)) return { ok: false, reason: "missing_target" };
  const target = trimTarget(request.target);
  if (target.targetCalories === undefined) {
    return { ok: false, reason: "target_without_calories" };
  }
  const facts: AiFacts = {
    target,
    day: isRecord(request.day) ? trimDay(request.day) : null,
    foodPreferences: trimPreferences(request.foodPreferences),
  };
  const json = JSON.stringify(facts);
  if (Buffer.byteLength(json, "utf8") > MAX_FACTS_BYTES) {
    return { ok: false, reason: "facts_too_large" };
  }
  return { ok: true, facts, json };
}
