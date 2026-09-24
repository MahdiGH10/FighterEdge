import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { buildRequestBody, DEFAULT_MODEL, modelChain, OpenRouterError } from "./openrouter";

describe("modelChain", () => {
  it("reads a comma-separated list in order", () => {
    assert.deepEqual(
      modelChain({ OPENROUTER_MODELS: "a/one:free, b/two:free ,c/three" }),
      ["a/one:free", "b/two:free", "c/three"],
    );
  });

  it("accepts a single model, and prefers the list when both are set", () => {
    assert.deepEqual(modelChain({ OPENROUTER_MODEL: "a/one" }), ["a/one"]);
    assert.deepEqual(
      modelChain({ OPENROUTER_MODELS: "a/one", OPENROUTER_MODEL: "b/two" }),
      ["a/one"],
    );
  });

  it("falls back to the paid default when nothing is configured", () => {
    assert.deepEqual(modelChain({}), [DEFAULT_MODEL]);
    assert.deepEqual(modelChain({ OPENROUTER_MODELS: " , ," }), [
      DEFAULT_MODEL,
    ]);
  });
});

describe("OpenRouterError.isModelFault", () => {
  it("hands over to the next model when this one is gone or throttled", () => {
    // 404 is what a model losing its free tier returns; 429 is the upstream
    // provider's shared pool; 5xx is the provider being down.
    for (const status of [404, 429, 500, 503]) {
      assert.equal(new OpenRouterError("x", status).isModelFault, true);
    }
  });

  it("does not walk the chain for our own key or request being wrong", () => {
    for (const status of [400, 401, 402, 403]) {
      assert.equal(new OpenRouterError("x", status).isModelFault, false);
    }
    // A timeout or abort carries no status: retrying other models only
    // burns the caller's remaining wait.
    assert.equal(new OpenRouterError("timeout").isModelFault, false);
  });
});

describe("buildRequestBody", () => {
  it("asks OpenRouter to report usage, and keeps data collection unset by default", () => {
    const body = buildRequestBody(
      { model: "m/one", systemPrompt: "sys", userContent: "facts" },
      {},
    );
    assert.deepEqual(body.usage, { include: true });
    assert.equal(body.provider, undefined);
    assert.equal(body.max_tokens, 900);
    assert.deepEqual(body.messages, [
      { role: "system", content: "sys" },
      { role: "user", content: "facts" },
    ]);
  });

  it("routes only to providers that don't keep prompts when configured", () => {
    for (const value of ["deny", " DENY "]) {
      const body = buildRequestBody(
        { model: "m/one", systemPrompt: "s", userContent: "u" },
        { OPENROUTER_DATA_COLLECTION: value },
      );
      assert.deepEqual(body.provider, { data_collection: "deny" });
    }
    const allow = buildRequestBody(
      { model: "m/one", systemPrompt: "s", userContent: "u" },
      { OPENROUTER_DATA_COLLECTION: "allow" },
    );
    assert.equal(allow.provider, undefined);
  });
});
