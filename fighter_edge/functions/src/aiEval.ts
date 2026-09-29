/**
 * Offline evaluation of the AI coach: runs fixed athlete scenarios through
 * the same facts builder, prompt, and validator as the deployed function, and
 * scores what an athlete would actually see. Run by scripts/ai-eval.mjs;
 * never deployed behaviour.
 *
 * Two questions, answered separately:
 * - Would the athlete see an answer at all? (`valid`: the production
 *   validator accepts it. A rejected answer reaches the athlete as
 *   "unavailable".)
 * - Is the answer any use? (`checks`: per-scenario expectations such as
 *   quoting the right remaining amount, refusing an unsafe cut, or saying it
 *   does not know something the facts do not contain.)
 *
 * Expectation checks are keyword heuristics, not judgement. The report
 * prints every answer so a person can read them.
 */

import { buildAiFacts } from "./aiFacts";
import { buildUserContent } from "./prompt";
import { AiTaskType, ChatTurn } from "./types";
import { ModelUsage, NO_USAGE } from "./usage";
import { parseModelJson, validateResponse } from "./validate";

/** Summary limit the system prompt asks for (the validator allows 800). */
export const PROMPT_SUMMARY_CHARS = 300;
/** Corner Brief line limit the system prompt asks for (the validator allows 200). */
export const PROMPT_LINE_CHARS = 120;

export interface ScenarioExpectation {
  /** Each inner list needs at least one of its terms, case-insensitive. */
  mentionsAnyOf?: string[][];
  /** None of these may match the visible text. */
  mentionsNone?: RegExp[];
  /** requiresProfessionalReview must equal this. */
  professionalReview?: boolean;
  /** Corner Brief: each of these topics has a line. */
  topics?: string[];
  /** Corner Brief: none of these topics has a line. */
  topicsNone?: string[];
  /** Corner Brief: the first (most important) line's topic. */
  firstTopic?: string;
}

export interface EvalScenario {
  id: string;
  task: AiTaskType;
  /** What this scenario measures, for the report. */
  purpose: string;
  request: {
    target: Record<string, unknown>;
    day?: Record<string, unknown> | null;
    foodPreferences?: Record<string, unknown> | null;
    today?: Record<string, unknown> | null;
    userMessage?: string;
    history?: ChatTurn[];
  };
  expect: ScenarioExpectation;
}

export interface ModelCall {
  (model: string, systemPrompt: string, userContent: string): Promise<{
    content: string;
    usage: ModelUsage;
  }>;
}

export interface CheckResult {
  name: string;
  ok: boolean;
}

export interface EvalResult {
  scenarioId: string;
  model: string;
  run: number;
  latencyMs: number;
  usage: ModelUsage;
  /** Provider error, when there was no reply at all. */
  error?: string;
  parsed: boolean;
  /** The production validator accepted it, so the athlete would see it. */
  valid: boolean;
  rejectReason?: string;
  /** Within the length the system prompt asks for. */
  concise: boolean;
  checks: CheckResult[];
  /** Everything the athlete would read, for the report. */
  visibleText: string;
}

/** Valid, concise, and every expectation met. */
export function passed(result: EvalResult): boolean {
  return result.valid && result.concise && result.checks.every((c) => c.ok);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? (value as Record<string, unknown>)
    : null;
}

/** The Corner Brief's line texts; empty for any other answer. */
function lineTexts(response: Record<string, unknown>): unknown[] {
  if (!Array.isArray(response.lines)) return [];
  return response.lines.map((line) =>
    line && typeof line === "object" ? (line as { text?: unknown }).text : undefined,
  );
}

/** The Corner Brief's topics, in order; empty for any other answer. */
function lineTopics(value: unknown): unknown[] {
  const response = asRecord(value);
  if (!response || !Array.isArray(response.lines)) return [];
  return response.lines.map((line) =>
    line && typeof line === "object" ? (line as { topic?: unknown }).topic : undefined,
  );
}

/** The athlete-visible text: summary or Corner Brief lines, warnings, actions. */
export function visibleText(value: unknown): string {
  const response = asRecord(value);
  if (!response) return "";
  const parts: unknown[] = [response.summary, ...lineTexts(response)];
  if (Array.isArray(response.warnings)) parts.push(...response.warnings);
  if (Array.isArray(response.actions)) {
    for (const action of response.actions) {
      if (action && typeof action === "object") {
        parts.push(action.title, action.reason);
      }
    }
  }
  return parts.filter((p): p is string => typeof p === "string").join("\n");
}

/** Thousands separators dropped, so "1,080" matches "1080". */
function normalise(text: string): string {
  return text.replace(/(\d)[,  '](?=\d{3}\b)/g, "$1").toLowerCase();
}

export function isConcise(value: unknown): boolean {
  const response = asRecord(value);
  if (!response) return false;
  if (Array.isArray(response.lines)) {
    return lineTexts(response).every(
      (text) => typeof text === "string" && text.length <= PROMPT_LINE_CHARS,
    );
  }
  return (
    typeof response.summary === "string" &&
    response.summary.length <= PROMPT_SUMMARY_CHARS
  );
}

export function scoreExpectations(
  value: unknown,
  expect: ScenarioExpectation,
): CheckResult[] {
  const text = normalise(visibleText(value));
  const checks: CheckResult[] = [];
  for (const group of expect.mentionsAnyOf ?? []) {
    checks.push({
      name: `mentions ${group.join(" | ")}`,
      ok: group.some((term) => text.includes(term.toLowerCase())),
    });
  }
  for (const pattern of expect.mentionsNone ?? []) {
    checks.push({ name: `avoids ${pattern}`, ok: !pattern.test(text) });
  }
  if (expect.professionalReview !== undefined) {
    const flag = asRecord(value)?.requiresProfessionalReview;
    checks.push({
      name: `professionalReview=${expect.professionalReview}`,
      ok: flag === expect.professionalReview,
    });
  }
  const topics = lineTopics(value);
  for (const topic of expect.topics ?? []) {
    checks.push({ name: `has a ${topic} line`, ok: topics.includes(topic) });
  }
  for (const topic of expect.topicsNone ?? []) {
    checks.push({ name: `no ${topic} line`, ok: !topics.includes(topic) });
  }
  if (expect.firstTopic !== undefined) {
    checks.push({
      name: `leads with ${expect.firstTopic}`,
      ok: topics[0] === expect.firstTopic,
    });
  }
  return checks;
}

/** Facts and prompt exactly as the deployed function builds them. */
export function preparePrompt(scenario: EvalScenario): {
  suppliedFactsJson: string;
  userContent: string;
} {
  const facts = buildAiFacts(scenario.request);
  if (!facts.ok) {
    throw new Error(`Scenario ${scenario.id} has invalid facts: ${facts.reason}`);
  }
  const suppliedFactsJson = JSON.stringify({
    task: scenario.task,
    ...facts.facts,
  });
  const userContent = buildUserContent({
    task: scenario.task,
    suppliedFactsJson,
    history: scenario.request.history,
    userMessage: scenario.request.userMessage,
  });
  return { suppliedFactsJson, userContent };
}

export async function evaluateOnce(
  scenario: EvalScenario,
  model: string,
  run: number,
  systemPrompt: string,
  call: ModelCall,
  now: () => number = Date.now,
): Promise<EvalResult> {
  const { suppliedFactsJson, userContent } = preparePrompt(scenario);
  const started = now();
  const base = {
    scenarioId: scenario.id,
    model,
    run,
  };
  let content: string;
  let usage: ModelUsage;
  try {
    ({ content, usage } = await call(model, systemPrompt, userContent));
  } catch (error) {
    return {
      ...base,
      latencyMs: now() - started,
      usage: NO_USAGE,
      error: error instanceof Error ? error.message : String(error),
      parsed: false,
      valid: false,
      concise: false,
      checks: [],
      visibleText: "",
    };
  }
  const latencyMs = now() - started;
  const parsed = parseModelJson(content);
  const verdict = validateResponse(parsed, suppliedFactsJson, scenario.task);
  return {
    ...base,
    latencyMs,
    usage,
    parsed: parsed !== null,
    valid: verdict.ok,
    rejectReason: verdict.ok ? undefined : verdict.reason,
    concise: isConcise(parsed),
    checks: scoreExpectations(parsed, scenario.expect),
    visibleText: visibleText(parsed),
  };
}

/** Sequential on purpose: free models rate-limit bursts. */
export async function runEval(options: {
  scenarios: EvalScenario[];
  models: string[];
  runs: number;
  systemPrompt: string;
  call: ModelCall;
  onResult?: (result: EvalResult) => void;
}): Promise<EvalResult[]> {
  const results: EvalResult[] = [];
  for (const model of options.models) {
    for (const scenario of options.scenarios) {
      for (let run = 1; run <= options.runs; run++) {
        const result = await evaluateOnce(
          scenario,
          model,
          run,
          options.systemPrompt,
          options.call,
        );
        results.push(result);
        options.onResult?.(result);
      }
    }
  }
  return results;
}

export interface ModelSummary {
  model: string;
  total: number;
  replied: number;
  valid: number;
  passed: number;
  medianLatencyMs: number;
  costUsd: number;
  tokens: number;
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? sorted[mid]
    : Math.round((sorted[mid - 1] + sorted[mid]) / 2);
}

export function summarise(results: EvalResult[]): ModelSummary[] {
  const models = [...new Set(results.map((r) => r.model))];
  return models.map((model) => {
    const mine = results.filter((r) => r.model === model);
    return {
      model,
      total: mine.length,
      replied: mine.filter((r) => r.error === undefined).length,
      valid: mine.filter((r) => r.valid).length,
      passed: mine.filter(passed).length,
      medianLatencyMs: median(
        mine.filter((r) => r.error === undefined).map((r) => r.latencyMs),
      ),
      costUsd: mine.reduce((sum, r) => sum + r.usage.costUsd, 0),
      tokens: mine.reduce(
        (sum, r) => sum + r.usage.promptTokens + r.usage.completionTokens,
        0,
      ),
    };
  });
}

function percent(part: number, whole: number): string {
  return whole === 0 ? "-" : `${Math.round((part / whole) * 100)}%`;
}

function cell(text: string): string {
  return text.replace(/\|/g, "\\|").replace(/\n/g, "<br>");
}

export function renderReport(
  results: EvalResult[],
  scenarios: EvalScenario[],
  meta: { startedAt: string; systemPromptVersion: number },
): string {
  const lines: string[] = [
    `# AI coach evaluation, ${meta.startedAt}`,
    "",
    `System prompt v${meta.systemPromptVersion}. One attempt per run; ` +
      "production retries a rejected answer once, so its success rate is " +
      "somewhat higher than `valid` here.",
    "",
    "**valid**: the production validator accepts it, so the athlete sees it. " +
      "**passed**: valid, within the prompt's length limit, and every " +
      "scenario expectation met (keyword heuristics; read the answers below).",
    "",
    "## Models",
    "",
    "| Model | Replied | Valid | Passed | Median latency | Tokens | Cost |",
    "|---|---|---|---|---|---|---|",
  ];
  for (const s of summarise(results)) {
    lines.push(
      `| ${s.model} | ${percent(s.replied, s.total)} | ` +
        `${percent(s.valid, s.total)} | ${s.passed}/${s.total} ` +
        `(${percent(s.passed, s.total)}) | ${(s.medianLatencyMs / 1000).toFixed(1)} s | ` +
        `${s.tokens} | $${s.costUsd.toFixed(4)} |`,
    );
  }
  lines.push("", "## Scenarios", "");
  for (const scenario of scenarios) {
    lines.push(`### ${scenario.id} (${scenario.task})`, "", scenario.purpose, "");
    if (scenario.request.userMessage) {
      lines.push(`Athlete: "${scenario.request.userMessage}"`, "");
    }
    lines.push("| Model | Run | Result | Failed checks | Answer |", "|---|---|---|---|---|");
    for (const r of results.filter((x) => x.scenarioId === scenario.id)) {
      const outcome = r.error
        ? `error: ${r.error}`
        : !r.valid
          ? `rejected (${r.rejectReason})`
          : passed(r)
            ? "pass"
            : r.concise
              ? "valid, weak"
              : "valid, too long";
      const failed = r.checks.filter((c) => !c.ok).map((c) => c.name).join("; ");
      lines.push(
        `| ${r.model} | ${r.run} | ${cell(outcome)} | ${cell(failed || "-")} | ` +
          `${cell(r.visibleText.slice(0, 700) || "-")} |`,
      );
    }
    lines.push("");
  }
  return lines.join("\n");
}
