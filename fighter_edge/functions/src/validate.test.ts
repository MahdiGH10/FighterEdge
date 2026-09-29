import assert from "node:assert/strict";
import { test } from "node:test";

import { parseModelJson, toClientResponse, validateResponse } from "./validate";

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

function goodCornerBrief(overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: 3,
    lines: [
      { topic: "fuel", text: "Anchor your next meal around a reliable protein source." },
      { topic: "training", text: "Keep your usual session today and fuel before it." },
      { topic: "recovery", text: "Log tonight's sleep-friendly dinner so tomorrow stays specific." },
    ],
    warnings: [],
    requiresProfessionalReview: false,
    factsUsed: ["targetCalories", "proteinGrams"],
    contentVersion: "sp8",
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

test("accepts a Corner Brief of three lines on three topics", () => {
  const result = validateResponse(goodCornerBrief(), suppliedFacts, "cornerBrief");
  assert.equal(result.ok, true);
});

test("rejects a Corner Brief that is not exactly three lines", () => {
  const lines = goodCornerBrief().lines;
  for (const wrong of [lines.slice(0, 2), [...lines, { topic: "weight", text: "Weigh in tomorrow." }]]) {
    const result = validateResponse(goodCornerBrief({ lines: wrong }), suppliedFacts, "cornerBrief");
    assert.equal(result.ok, false);
    assert.equal(result.reason, "malformed_schema");
  }
});

test("rejects a Corner Brief that repeats a topic", () => {
  const [first, second] = goodCornerBrief().lines;
  const result = validateResponse(
    goodCornerBrief({ lines: [first, second, { ...first, text: "More protein at dinner." }] }),
    suppliedFacts,
    "cornerBrief",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "malformed_schema");
});

test("rejects a Corner Brief line with an unknown topic, no text, or too much text", () => {
  const [, second, third] = goodCornerBrief().lines;
  for (const bad of [
    { topic: "mindset", text: "Stay sharp." },
    { topic: "fuel", text: "   " },
    { topic: "fuel", text: "x".repeat(201) },
    { topic: "fuel" },
  ]) {
    const result = validateResponse(
      goodCornerBrief({ lines: [bad, second, third] }),
      suppliedFacts,
      "cornerBrief",
    );
    assert.equal(result.ok, false, JSON.stringify(bad));
    assert.equal(result.reason, "malformed_schema");
  }
});

test("rejects the old Fighter Brief shape for the Corner Brief task", () => {
  const result = validateResponse(
    goodResponse({ schemaVersion: 2, brief: { nextAction: "Log dinner." } }),
    suppliedFacts,
    "cornerBrief",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "malformed_schema");
});

test("rejects prohibited language inside a Corner Brief line", () => {
  const [first, second] = goodCornerBrief().lines;
  const result = validateResponse(
    goodCornerBrief({
      lines: [first, second, { topic: "weight", text: "Sit in the sauna tonight to drop the last kilo." }],
    }),
    suppliedFacts,
    "cornerBrief",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "prohibited_content");
});

test("rejects fabricated numbers in a Corner Brief line or warning", () => {
  const [first, second] = goodCornerBrief().lines;
  const inLine = validateResponse(
    goodCornerBrief({
      lines: [first, second, { topic: "weight", text: "Raise tomorrow's target to 4200 kcal." }],
    }),
    suppliedFacts,
    "cornerBrief",
  );
  assert.equal(inLine.ok, false);
  assert.equal(inLine.reason, "fabricated_numbers");

  const inWarning = validateResponse(
    goodCornerBrief({ warnings: ["Never drop below 1200 kcal."] }),
    suppliedFacts,
    "cornerBrief",
  );
  assert.equal(inWarning.ok, false);
  assert.equal(inWarning.reason, "fabricated_numbers");
});

test("parseModelJson recovers an object wrapped in a code fence", () => {
  assert.deepEqual(parseModelJson('```json\n{"a":1}\n```'), { a: 1 });
});

test("parseModelJson recovers an object after a sentence of preamble", () => {
  assert.deepEqual(parseModelJson('Here you go: {"a":1}'), { a: 1 });
});

test("parseModelJson still rejects text with no valid object", () => {
  assert.equal(parseModelJson("{ not really json }"), null);
});

// A real day: target 2500, 1420 eaten. Mirrors what the Flutter client sends.
const dayFacts = JSON.stringify({
  target: { targetCalories: 2500, proteinGrams: 150 },
  day: { consumedCalories: 1420 },
});

test("accepts supplied numbers written with a thousands separator", () => {
  // Regression: "2,500" used to be read as "500" and rejected as fabricated.
  const result = validateResponse(
    goodResponse({ summary: "You're at 1,420 of your 2,500 kcal target." }),
    dayFacts,
  );
  assert.equal(result.ok, true);
});

test("accepts the difference between two supplied numbers", () => {
  // 2500 - 1420: arithmetic on the facts, not invention.
  const result = validateResponse(
    goodResponse({ summary: "About 1,080 kcal left today." }),
    dayFacts,
  );
  assert.equal(result.ok, true);
});

test("still rejects a number that is neither supplied nor derived", () => {
  const result = validateResponse(
    goodResponse({ summary: "Aim for 3,150 kcal today." }),
    dayFacts,
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "fabricated_numbers");
});

test("accepts a chat reply using the same schema as before", () => {
  const result = validateResponse(goodResponse(), suppliedFacts, "chat");
  assert.equal(result.ok, true);
});

test("rejects a fabricated number in a chat reply", () => {
  const result = validateResponse(
    goodResponse({ summary: "You should actually eat 4200 kcal today." }),
    suppliedFacts,
    "chat",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "fabricated_numbers");
});

test("rejects prohibited content smuggled into a chat reply", () => {
  const result = validateResponse(
    goodResponse({ summary: "Try a water fast before your weigh-in." }),
    suppliedFacts,
    "chat",
  );
  assert.equal(result.ok, false);
  assert.equal(result.reason, "prohibited_content");
});

test("checks Corner Brief lines with the same number rules", () => {
  const result = validateResponse(
    goodCornerBrief({
      lines: [
        { topic: "fuel", text: "About 1,080 kcal left — make dinner protein-first." },
        { topic: "training", text: "Wrestling today: eat a carb-based meal a few hours before." },
        { topic: "weight", text: "Hold 2,500 kcal this week while your trend settles." },
      ],
    }),
    dayFacts,
    "cornerBrief",
  );
  assert.equal(result.ok, true);
});

test("the app only receives the schema's own fields", () => {
  const brief = toClientResponse({
    ...goodCornerBrief(),
    summary: "An unchecked extra the model added.",
    lines: goodCornerBrief().lines.map((line) => ({ ...line, emoji: "🥊" })),
  } as never);
  assert.deepEqual(Object.keys(brief).sort(), [
    "contentVersion",
    "factsUsed",
    "lines",
    "requiresProfessionalReview",
    "schemaVersion",
    "warnings",
  ]);
  assert.deepEqual(Object.keys((brief as { lines: object[] }).lines[0]).sort(), ["text", "topic"]);

  const chat = toClientResponse({
    ...goodResponse(),
    brief: { nextAction: "An old field." },
    actions: [{ type: "logging", title: "Log dinner", reason: "Keeps it specific.", recipeIds: [], extra: 1 }],
  } as never);
  assert.equal("brief" in chat, false);
  assert.deepEqual(Object.keys((chat as { actions: object[] }).actions[0]).sort(), [
    "reason",
    "recipeIds",
    "title",
    "type",
  ]);
});
