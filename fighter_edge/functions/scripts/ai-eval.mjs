// Evaluates the AI coach against fixed athlete scenarios, through the real
// facts builder, prompt and validator (src/aiEval.ts). Nothing is deployed.
//
// From functions/:
//   npm run eval:ai -- [--models a,b] [--runs 3] [--only id1,id2] [--dry-run]
//
// Needs OPENROUTER_API_KEY in the environment (except --dry-run). The key is
// only passed to OpenRouter, never printed or written. Without --models it
// tests the chain in .env.fighter-edge-app, i.e. what is deployed.
//
// The full report, with every answer, goes to eval-results/ (git-ignored).
// Scenarios are synthetic; no real athlete data is involved.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const { runEval, renderReport, summarise, passed } = require("../lib/aiEval.js");
const { SCENARIOS } = require("../lib/aiEvalScenarios.js");
const { SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } = require("../lib/systemPrompt.js");
const { callOpenRouter } = require("../lib/openrouter.js");

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? undefined : process.argv[index + 1];
}

function list(value) {
  return (value ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

function deployedModels() {
  try {
    const env = readFileSync(join(root, ".env.fighter-edge-app"), "utf8");
    const line = env.split(/\r?\n/).find((l) => /^OPENROUTER_MODELS=/.test(l));
    return list(line?.slice("OPENROUTER_MODELS=".length));
  } catch {
    return [];
  }
}

const dryRun = process.argv.includes("--dry-run");
const runs = Number(argValue("--runs") ?? 1);
const models = list(argValue("--models") ?? process.env.OPENROUTER_MODELS);
if (models.length === 0) models.push(...deployedModels());
const only = list(argValue("--only"));
const scenarios = only.length
  ? SCENARIOS.filter((s) => only.includes(s.id))
  : SCENARIOS;

if (models.length === 0 || scenarios.length === 0 || !(runs >= 1)) {
  console.error("Nothing to run: check --models, --only and --runs.");
  process.exit(2);
}

const apiKey = process.env.OPENROUTER_API_KEY;
if (!dryRun && !apiKey) {
  console.error(
    "OPENROUTER_API_KEY is not set. Set it in this shell (it is never " +
      "printed), or use --dry-run to check the harness without a model.",
  );
  process.exit(2);
}

// --dry-run: a canned, valid answer, to check the harness end to end.
const dryCall = async (_model, _system, userContent) => {
  const brief = userContent.startsWith("Task: fighterBrief");
  return {
    content: JSON.stringify({
      schemaVersion: brief ? 2 : 1,
      summary: "Log your next meal and lead with protein.",
      ...(brief
        ? {
            brief: {
              nextAction: "Log your next meal.",
              mealSuggestion: "Lead with protein.",
              trainingTiming: "Eat two to three hours before training.",
              weeklyAdjustment: "Hold the target this week.",
            },
          }
        : {}),
      actions: [],
      warnings: [],
      requiresProfessionalReview: false,
      factsUsed: ["targetCalories"],
      contentVersion: "dry-run",
    }),
    usage: { promptTokens: 0, completionTokens: 0, costUsd: 0 },
  };
};

const liveCall = (model, systemPrompt, userContent) =>
  callOpenRouter({ apiKey, model, systemPrompt, userContent });

const startedAt = new Date().toISOString();
const total = models.length * scenarios.length * runs;
console.log(
  `${dryRun ? "DRY RUN: " : ""}${scenarios.length} scenarios x ` +
    `${models.length} model(s) x ${runs} run(s) = ${total} calls, prompt v${SYSTEM_PROMPT_VERSION}`,
);

let done = 0;
const results = await runEval({
  scenarios,
  models: dryRun ? models.map((m) => `${m} (dry run)`) : models,
  runs,
  systemPrompt: SYSTEM_PROMPT,
  call: dryRun ? dryCall : liveCall,
  onResult: (r) => {
    done++;
    const outcome = r.error
      ? `error: ${r.error}`
      : !r.valid
        ? `rejected: ${r.rejectReason}`
        : passed(r)
          ? "pass"
          : "valid, weak";
    console.log(`[${done}/${total}] ${r.model} ${r.scenarioId} #${r.run}: ${outcome} (${r.latencyMs} ms)`);
  },
});

const outDir = join(root, "eval-results");
mkdirSync(outDir, { recursive: true });
const outFile = join(outDir, `ai-eval-${startedAt.replace(/[:.]/g, "-")}.md`);
writeFileSync(
  outFile,
  renderReport(results, scenarios, {
    startedAt,
    systemPromptVersion: SYSTEM_PROMPT_VERSION,
  }),
);

console.log("\nModel | replied | valid | passed | median latency | cost");
for (const s of summarise(results)) {
  console.log(
    `${s.model} | ${s.replied}/${s.total} | ${s.valid}/${s.total} | ` +
      `${s.passed}/${s.total} | ${(s.medianLatencyMs / 1000).toFixed(1)} s | $${s.costUsd.toFixed(4)}`,
  );
}
console.log(`\nFull report: ${outFile}`);
