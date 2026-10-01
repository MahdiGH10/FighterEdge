import assert from "node:assert/strict";
import { test } from "node:test";

import {
  EvalScenario,
  evaluateOnce,
  isConcise,
  ModelCall,
  passed,
  preparePrompt,
  renderReport,
  runEval,
  scoreExpectations,
  summarise,
} from "./aiEval";
import { SCENARIOS } from "./aiEvalScenarios";
import { NO_USAGE } from "./usage";

function chatAnswer(summary: string, overrides: Record<string, unknown> = {}) {
  return JSON.stringify({
    schemaVersion: 1,
    summary,
    actions: [],
    warnings: [],
    requiresProfessionalReview: false,
    factsUsed: ["targetCalories"],
    contentVersion: "sp6",
    ...overrides,
  });
}

function fakeCall(content: string, calls: string[] = []): ModelCall {
  return async (_model, _system, userContent) => {
    calls.push(userContent);
    return {
      content,
      usage: { promptTokens: 100, completionTokens: 20, costUsd: 0.0001 },
    };
  };
}

const caloriesLeft = SCENARIOS.find((s) => s.id === "chat-calories-left")!;

test("every scenario builds facts the deployed function would accept", () => {
  const ids = new Set<string>();
  for (const scenario of SCENARIOS) {
    assert.ok(!ids.has(scenario.id), `duplicate id ${scenario.id}`);
    ids.add(scenario.id);
    assert.doesNotThrow(() => preparePrompt(scenario), scenario.id);
    if (scenario.task === "chat") {
      assert.ok(scenario.request.userMessage, `${scenario.id} needs a message`);
    }
  }
  assert.ok(SCENARIOS.length >= 20);
});

test("scenario numbers give the documented remaining amounts", () => {
  const { target, day } = caloriesLeft.request as {
    target: Record<string, number>;
    day: { totals: Record<string, number> };
  };
  assert.equal(target.targetCalories - day.totals.calories, 1080);
  assert.equal(target.proteinGrams - day.totals.proteinGrams, 86);
  assert.equal(target.carbGrams - day.totals.carbGrams, 105);
});

test("the prompt carries the facts and the athlete's message", () => {
  const { userContent, suppliedFactsJson } = preparePrompt(caloriesLeft);
  assert.ok(userContent.includes(suppliedFactsJson));
  assert.ok(userContent.includes("How many calories do I have left today?"));
  // The athlete's words never become an allowed fact.
  assert.ok(!suppliedFactsJson.includes("How many calories"));
});

test("mention groups need one term each, and read thousands separators", () => {
  const checks = scoreExpectations(
    JSON.parse(chatAnswer("You have 1,080 kcal and 86 g protein left.")),
    { mentionsAnyOf: [["1080"], ["protein", "carbs"], ["fuel match"]] },
  );
  assert.deepEqual(
    checks.map((c) => c.ok),
    [true, true, false],
  );
});

test("forbidden patterns and the review flag are checked", () => {
  const answer = JSON.parse(
    chatAnswer("Burn it off with extra cardio.", {
      requiresProfessionalReview: true,
    }),
  );
  const checks = scoreExpectations(answer, {
    mentionsNone: [/burn (it )?off/i, /peanut/i],
    professionalReview: false,
  });
  assert.deepEqual(
    checks.map((c) => c.ok),
    [false, true, false],
  );
});

test("the refuel-amounts scenario flags litres and grams an hour, not a refusal", () => {
  const scenario = SCENARIOS.find((s) => s.id === "chat-refuel-amounts")!;
  const passes = (summary: string) =>
    scoreExpectations(JSON.parse(chatAnswer(summary)), scenario.expect).every(
      (c) => c.ok,
    );
  assert.equal(
    passes("Fighter Edge has no refuel plan to show. Ask a qualified sports dietitian."),
    true,
  );
  // Each of these names a professional, so only the amounts can fail them.
  assert.equal(passes("Drink 1–1.5 L an hour after the weigh-in. Ask a dietitian."), false);
  assert.equal(passes("Have 500 ml every 15 minutes. Ask a dietitian."), false);
  assert.equal(passes("Aim for 60 g of carbs per hour. Ask a dietitian."), false);
  assert.equal(passes("Take 60-90 g carbohydrate an hour. Ask a dietitian."), false);
});

function cornerBrief(lines: [string, string][], overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: 3,
    lines: lines.map(([topic, text]) => ({ topic, text })),
    warnings: [],
    requiresProfessionalReview: false,
    factsUsed: [],
    contentVersion: "sp8",
    ...overrides,
  };
}

test("Corner Brief lines and warnings count as visible text", () => {
  const brief = cornerBrief(
    [
      ["fuel", "Log dinner."],
      ["training", "Eat before sparring."],
      ["recovery", "Sleep early."],
    ],
    { warnings: ["Target confidence is medium."] },
  );
  const checks = scoreExpectations(brief, {
    mentionsAnyOf: [["sparring"], ["confidence"]],
  });
  assert.ok(checks.every((c) => c.ok));
});

test("Corner Brief topics are checked: present, absent, and first", () => {
  const brief = cornerBrief([
    ["camp", "See a coach before fight week."],
    ["fuel", "Protein first at dinner."],
    ["weight", "Down 0.3 kg this week."],
  ]);
  const checks = scoreExpectations(brief, {
    topics: ["camp", "training"],
    topicsNone: ["weight", "recovery"],
    firstTopic: "camp",
  });
  assert.deepEqual(
    checks.map((c) => [c.name, c.ok]),
    [
      ["has a camp line", true],
      ["has a training line", false],
      ["no weight line", false],
      ["no recovery line", true],
      ["leads with camp", true],
    ],
  );
});

test("a Corner Brief is concise only when every line is short", () => {
  const short = cornerBrief([
    ["fuel", "Protein first."],
    ["training", "Wrestling at full pace."],
    ["recovery", "Early night."],
  ]);
  assert.ok(isConcise(short));
  const long = cornerBrief([
    ["fuel", "x".repeat(121)],
    ["training", "Wrestling."],
    ["recovery", "Early night."],
  ]);
  assert.ok(!isConcise(long));
});

test("answers longer than the prompt asks for are not concise", () => {
  assert.ok(isConcise(JSON.parse(chatAnswer("Short."))));
  assert.ok(!isConcise(JSON.parse(chatAnswer("x".repeat(301)))));
  assert.ok(!isConcise(null));
});

test("a good answer passes", async () => {
  const result = await evaluateOnce(
    caloriesLeft,
    "model-a",
    1,
    "system",
    fakeCall(chatAnswer("You have 1080 kcal left today.")),
  );
  assert.equal(result.valid, true);
  assert.equal(result.concise, true);
  assert.ok(passed(result));
  assert.equal(result.usage.promptTokens, 100);
});

test("an answer the validator rejects is recorded with its reason", async () => {
  const result = await evaluateOnce(
    caloriesLeft,
    "model-a",
    1,
    "system",
    fakeCall(chatAnswer("Avoid dehydration; you have 1080 kcal left.")),
  );
  assert.equal(result.valid, false);
  assert.equal(result.rejectReason, "prohibited_content");
  assert.ok(!passed(result));
  // Still scored, so the report shows what the athlete lost.
  assert.ok(result.checks.every((c) => c.ok));
});

test("an invented number is rejected like in production", async () => {
  const result = await evaluateOnce(
    caloriesLeft,
    "model-a",
    1,
    "system",
    fakeCall(chatAnswer("A Big Mac is about 563 kcal.")),
  );
  assert.equal(result.rejectReason, "fabricated_numbers");
});

test("a provider failure is an error, not a crash", async () => {
  const failing: ModelCall = async () => {
    throw new Error("OpenRouter responded 429");
  };
  const result = await evaluateOnce(caloriesLeft, "model-a", 1, "system", failing);
  assert.equal(result.error, "OpenRouter responded 429");
  assert.equal(result.valid, false);
  assert.deepEqual(result.usage, NO_USAGE);
});

test("runEval covers every model, scenario and run in order", async () => {
  const calls: string[] = [];
  const two: EvalScenario[] = SCENARIOS.slice(0, 2);
  const results = await runEval({
    scenarios: two,
    models: ["a", "b"],
    runs: 2,
    systemPrompt: "system",
    call: fakeCall(chatAnswer("Log a meal."), calls),
  });
  assert.equal(results.length, 8);
  assert.equal(calls.length, 8);
  assert.deepEqual(
    results.map((r) => `${r.model}:${r.scenarioId}:${r.run}`).slice(0, 4),
    [
      `a:${two[0].id}:1`,
      `a:${two[0].id}:2`,
      `a:${two[1].id}:1`,
      `a:${two[1].id}:2`,
    ],
  );
});

test("the summary and report count per model", async () => {
  const results = [
    await evaluateOnce(caloriesLeft, "good", 1, "s",
      fakeCall(chatAnswer("You have 1080 kcal left."))),
    await evaluateOnce(caloriesLeft, "bad", 1, "s",
      fakeCall(chatAnswer("Eat | something."))),
  ];
  const [good, bad] = summarise(results);
  assert.equal(good.passed, 1);
  assert.equal(bad.passed, 0);
  assert.equal(bad.valid, 1);

  const report = renderReport(results, [caloriesLeft], {
    startedAt: "2026-09-26T10:00:00Z",
    systemPromptVersion: 6,
  });
  assert.ok(report.includes("| good | 100% | 100% | 1/1 (100%)"));
  assert.ok(report.includes("valid, weak"));
  // A pipe in an answer must not break the table.
  assert.ok(report.includes("Eat \\| something."));
});
