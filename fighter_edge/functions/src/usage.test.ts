import assert from "node:assert/strict";
import { test } from "node:test";

import { addUsage, NO_USAGE, parseUsage } from "./usage";

test("reads OpenRouter's usage block", () => {
  assert.deepEqual(
    parseUsage({
      choices: [],
      usage: { prompt_tokens: 1200, completion_tokens: 180, total_tokens: 1380, cost: 0.00042 },
    }),
    { promptTokens: 1200, completionTokens: 180, costUsd: 0.00042 },
  );
});

test("treats a missing or malformed usage block as zero", () => {
  assert.deepEqual(parseUsage({}), NO_USAGE);
  assert.deepEqual(parseUsage(null), NO_USAGE);
  assert.deepEqual(
    parseUsage({ usage: { prompt_tokens: "many", completion_tokens: -3, cost: Number.NaN } }),
    NO_USAGE,
  );
});

test("adds usage across a retry", () => {
  const first = { promptTokens: 1000, completionTokens: 100, costUsd: 0.001 };
  const second = { promptTokens: 1000, completionTokens: 150, costUsd: 0.002 };
  const total = addUsage(first, second);
  assert.equal(total.promptTokens, 2000);
  assert.equal(total.completionTokens, 250);
  assert.ok(Math.abs(total.costUsd - 0.003) < 1e-12);
});
