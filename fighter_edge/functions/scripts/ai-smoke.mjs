// Smoke-tests a model against the real EdgeFuel prompt and validator, without
// deploying anything. Usage (from functions/, after `npm run build`):
//
//   OPENROUTER_API_KEY=... node scripts/ai-smoke.mjs <model> [runs]
//
// Reports, per run: latency, whether the reply parsed, and whether it passed
// the same validateResponse() the deployed function uses. A model is only fit
// to deploy if it passes consistently here — replying is not the bar.
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { SYSTEM_PROMPT } = require("../lib/systemPrompt.js");
const { parseModelJson, validateResponse } = require("../lib/validate.js");
const { callOpenRouter } = require("../lib/openrouter.js");

const model = process.argv[2];
const runs = Number(process.argv[3] ?? 3);
const apiKey = process.env.OPENROUTER_API_KEY;
if (!model || !apiKey) {
  console.error("usage: OPENROUTER_API_KEY=... node scripts/ai-smoke.mjs <model> [runs]");
  process.exit(2);
}

// Representative of what the Flutter client sends: a real target, a partly
// logged day, and food preferences.
const facts = {
  task: "fighterBrief",
  target: {
    targetCalories: 2500, proteinGrams: 150, carbGrams: 290, fatGrams: 78,
    maintenanceCalories: 2750, goal: "loseFat", weeklyTrainingDays: 4,
  },
  day: {
    consumedCalories: 1420, consumedProteinGrams: 88, consumedCarbGrams: 160,
    consumedFatGrams: 41, entryCount: 3,
  },
  foodPreferences: { dietType: null, allergens: ["peanuts"], dislikedFoods: [] },
};
const factsJson = JSON.stringify(facts);
const shape = {
  schemaVersion: 2, summary: "string",
  brief: { nextAction: "string", mealSuggestion: "string",
    trainingTiming: "string", weeklyAdjustment: "string" },
  actions: [], warnings: ["string"], requiresProfessionalReview: false,
  factsUsed: ["fact-name-from-supplied-facts"], contentVersion: "string",
};
const userContent = [
  "Task:", "fighterBrief",
  "\nSupplied facts (JSON):", factsJson,
  "\nRespond with exactly one JSON object matching this shape:",
  JSON.stringify(shape),
  "For Fighter Brief, make each brief section specific, concise, and grounded only in the supplied facts.",
  "\nThis deployment has no recipe catalog yet — recipeIds must always be an empty array.",
].join(" ");

let passed = 0;
for (let i = 1; i <= runs; i++) {
  const started = Date.now();
  try {
    const raw = await callOpenRouter({ apiKey, model, systemPrompt: SYSTEM_PROMPT, userContent });
    const ms = Date.now() - started;
    const parsed = parseModelJson(raw);
    const verdict = validateResponse(parsed, factsJson, "fighterBrief");
    if (verdict.ok) passed++;
    console.log(`run ${i}: ${ms}ms parsed=${parsed !== null} valid=${verdict.ok}` +
      (verdict.ok ? "" : ` reason=${verdict.reason}`));
    if (i === 1 && parsed) console.log(JSON.stringify(parsed, null, 2));
  } catch (error) {
    console.log(`run ${i}: ${Date.now() - started}ms ERROR ${error.message}`);
  }
}
console.log(`\n${model}: ${passed}/${runs} passed validation`);
