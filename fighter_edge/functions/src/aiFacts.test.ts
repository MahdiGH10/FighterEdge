import assert from "node:assert/strict";
import { test } from "node:test";

import { buildAiFacts, MAX_FACTS_BYTES } from "./aiFacts";

/** Shaped like `NutritionTarget.toJson()` in the app. */
const target = {
  status: "success",
  policyVersion: 3,
  calculatedAt: "2026-09-24T08:00:00.000Z",
  reasons: ["Moderate activity"],
  warnings: [],
  estimatedRmrKcal: 1740,
  maintenanceRangeLowKcal: 2550,
  maintenanceRangeHighKcal: 2750,
  targetCalories: 2500,
  proteinGrams: 160,
  fatGrams: 75,
  carbGrams: 290,
  fiberGramsLow: 25,
  fiberGramsHigh: 38,
  proteinReferenceWeightKg: 77.2,
  equationProfileUsed: "male",
  activityCoefficientUsed: 1.55,
  appliedGoalAdjustmentPercent: -10,
  confidence: "high",
};

/** Shaped like `FoodLogEntry.toJson()`. */
const entry = (name: string, calories = 450) => ({
  schemaVersion: 1,
  id: "entry-7f3a",
  name,
  notes: "ate this after sparring with my coach",
  calories,
  proteinGrams: 35,
  carbGrams: 50,
  fatGrams: 12,
  consumed: true,
  saved: false,
  source: "catalog",
  loggedAt: "2026-09-24T12:31:00.000Z",
});

const day = {
  schemaVersion: 1,
  localDate: "2026-09-24",
  timeZone: "Europe/Berlin",
  targetSnapshot: target,
  entries: [entry("Chicken rice bowl"), entry("Greek yogurt", 180)],
  totals: { calories: 630, proteinGrams: 70, carbGrams: 100, fatGrams: 24 },
  hydrationCheckIns: [],
  activitySnapshot: null,
  loggingCoverage: "partial",
  migratedFromLegacyMeals: false,
  createdAt: "2026-09-24T07:00:00.000Z",
  updatedAt: "2026-09-24T12:31:00.000Z",
};

const preferences = {
  dietType: "omnivore",
  allergens: ["peanuts"],
  dislikedFoods: ["olives"],
};

test("keeps the facts the model may quote and drops the rest", () => {
  const result = buildAiFacts({ target, day, foodPreferences: preferences });
  assert.ok(result.ok);

  assert.equal(result.facts.target.targetCalories, 2500);
  assert.equal(result.facts.target.maintenanceRangeHighKcal, 2750);
  assert.equal(result.facts.target.calculatedAt, undefined);
  assert.deepEqual(result.facts.day?.totals, day.totals);
  assert.deepEqual(result.facts.day?.entries, [
    { name: "Chicken rice bowl", calories: 450, proteinGrams: 35, carbGrams: 50, fatGrams: 12, consumed: true },
    { name: "Greek yogurt", calories: 180, proteinGrams: 35, carbGrams: 50, fatGrams: 12, consumed: true },
  ]);
  assert.equal(result.facts.day?.targetSnapshot, undefined);
  assert.deepEqual(result.facts.foodPreferences, preferences);

  // IDs, timestamps and free-text notes never reach the prompt.
  for (const dropped of ["entry-7f3a", "2026-09-24T12:31", "sparring with my coach", "Europe/Berlin"]) {
    assert.equal(result.json.includes(dropped), false, dropped);
  }
});

test("bounds user text and list sizes", () => {
  const result = buildAiFacts({
    target,
    day: {
      ...day,
      entries: Array.from({ length: 200 }, (_, i) => entry(`Meal ${i} ${"x".repeat(500)}`)),
    },
    foodPreferences: {
      dietType: "d".repeat(300),
      allergens: Array.from({ length: 100 }, (_, i) => `allergen ${i}`),
      dislikedFoods: [42, "  ", "okra"],
    },
  });
  assert.ok(result.ok);
  const entries = result.facts.day?.entries as { name: string }[];
  assert.equal(entries.length, 40);
  assert.ok(entries.every((e) => e.name.length <= 60));
  assert.equal(result.facts.foodPreferences?.dietType?.length, 40);
  assert.equal(result.facts.foodPreferences?.allergens.length, 20);
  assert.deepEqual(result.facts.foodPreferences?.dislikedFoods, ["okra"]);
  assert.ok(Buffer.byteLength(result.json) <= MAX_FACTS_BYTES);
});

test("drops values of the wrong type instead of passing them on", () => {
  const result = buildAiFacts({
    target: { ...target, proteinGrams: "a lot", fatGrams: Number.POSITIVE_INFINITY, extra: { nested: true } },
    day: { totals: { calories: "630" }, entries: ["not an entry", null] },
  });
  assert.ok(result.ok);
  assert.equal(result.facts.target.proteinGrams, undefined);
  assert.equal(result.facts.target.fatGrams, undefined);
  assert.equal(result.facts.target.extra, undefined);
  assert.deepEqual(result.facts.day?.totals, {});
  assert.deepEqual(result.facts.day?.entries, []);
  assert.equal(result.facts.foodPreferences, null);
});

test("refuses a request without a usable target", () => {
  assert.deepEqual(buildAiFacts({}), { ok: false, reason: "missing_target" });
  assert.deepEqual(buildAiFacts({ target: [] }), { ok: false, reason: "missing_target" });
  assert.deepEqual(
    buildAiFacts({ target: { ...target, targetCalories: null } }),
    { ok: false, reason: "target_without_calories" },
  );
});

test("a day is optional", () => {
  const result = buildAiFacts({ target, day: "yesterday" });
  assert.ok(result.ok);
  assert.equal(result.facts.day, null);
});
