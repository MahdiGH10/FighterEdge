import assert from "node:assert/strict";
import { test } from "node:test";

import { parseModelJson, validateResponse } from "./validate";

const suppliedFacts = JSON.stringify({
  target: { targetCalories: 2500, proteinGrams: 150, carbGrams: 260, fatGrams: 80 },
});

function goodResponse(overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: 1,
    summary: "You're on track. Your target is 2500 kcal with 150g protein.",
    actions: [],
    warnings: [],
    requiresProfessionalReview: false,
    factsUsed: ["targetCalories"],
    contentVersion: "sp1",
    ...overrides,
  };
}

function goodBriefResponse(overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: 2,
    summary: "Your Fighter Brief is ready for today.",
    brief: {
      nextAction: "Log your next meal so the plan stays specific.",
      mealSuggestion: "Anchor your next meal around a reliable protein source.",
      trainingTiming: "Keep your usual training schedule and fuel consistently.",
      weeklyAdjustment: "Keep this target steady until you have a full week of data.",
    },
    actions: [],
    warnings: [],
    requiresProfessionalReview: false,
    factsUsed: ["targetCalories", "proteinGrams"],
    contentVersion: "sp2",
    ...overrides,
  };
}

test("parseModelJson returns null for invalid JSON instead of throwing", () => {
  assert.equal(parseModelJson("not json"), null);
});

test("parseModelJson parses valid JSON", () => {
  assert.deepEqual(parseModelJson('{"a":1}'), { a: 1 });
});

test("accepts a well-formed, clean response", () => {
  const result = validateResponse(goodResponse(), suppliedFacts);
  assert.equal(result.ok, true);
});

test("rejects a response missing required fields", () => {
  const broken = goodResponse();
  delete (broken as Record<string, unknown>).summary;
  const result = validateResponse(broken, suppliedFacts);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "malformed_schema");
});

test("rejects wrong schemaVersion", () => {
  const result = validateResponse(goodResponse({ schemaVersion: 2 }), suppliedFacts);
  assert.equal(result.ok, false);
});

test("rejects prohibited weight-cut language in the summary", () => {
  const response = goodResponse({
    summary: "Try a sauna session and dehydrate before your weigh-in.",
  });
  const result = validateResponse(response, suppliedFacts);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "prohibited_content");
});

test("rejects prohibited language hidden in an action reason", () => {
  const response = goodResponse({
    actions: [
      {
        type: "recovery",
        title: "Cut weight",
        reason: "Use a laxative to drop water weight fast.",
        recipeIds: [],
      },
    ],
  });
  const result = validateResponse(response, suppliedFacts);
  assert.equal(result.ok, false);
});

test("rejects an action that references a recipe (no catalog exists yet)", () => {
  const response = goodResponse({
    actions: [
      {
        type: "recipe",
        title: "Try this recipe",
        reason: "Fits your macros",
        recipeIds: ["some-recipe-id"],
      },
    ],
  });
  const result = validateResponse(response, suppliedFacts);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "malformed_schema");
});

test("rejects a fabricated number not present in the supplied facts", () => {
  const response = goodResponse({
    summary: "Your target is actually 4200 kcal today.",
  });
  const result = validateResponse(response, suppliedFacts);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "fabricated_numbers");
});

test("allows numbers that are present in the supplied facts", () => {
  const response = goodResponse({
    summary: "Your 2500 kcal target includes 150g of protein.",
  });
  const result = validateResponse(response, suppliedFacts);
  assert.equal(result.ok, true);
});

test("accepts a complete version-2 Fighter Brief", () => {
  const result = validateResponse(goodBriefResponse(), suppliedFacts, "fighterBrief");
  assert.equal(result.ok, true);
});

test("rejects a Fighter Brief missing a required section", () => {
  const response = goodBriefResponse();
  delete (response.brief as Record<string, unknown>).trainingTiming;
  const result = validateResponse(response, suppliedFacts, "fighterBrief");
  assert.equal(result.ok, false);
  assert.equal(result.reason, "malformed_schema");
});

test("rejects prohibited language inside a Fighter Brief section", () => {
  const result = validateResponse(
    goodBriefResponse({
      brief: {
        ...goodBriefResponse().brief,
        mealSuggestion: "Dehydrate before training to make weight.",
      },
    }),
    suppliedFacts,
    "fighterBrief",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "prohibited_content");
});

test("rejects fabricated numbers inside a Fighter Brief section", () => {
  const result = validateResponse(
    goodBriefResponse({
      brief: {
        ...goodBriefResponse().brief,
        weeklyAdjustment: "Raise tomorrow's target to 4200 kcal.",
      },
    }),
    suppliedFacts,
    "fighterBrief",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "fabricated_numbers");
});
