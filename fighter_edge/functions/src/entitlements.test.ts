import assert from "node:assert/strict";
import { test } from "node:test";

import { FetchLike, fetchRevenueCatEntitlement, usableApiKey } from "./entitlements";

test("only RevenueCat secret keys count as configured", () => {
  assert.equal(usableApiKey("sk_live_abc"), "sk_live_abc");
  assert.equal(usableApiKey("  sk_x  "), "sk_x");
  for (const raw of ["unset", "", "   ", null, undefined, "appl_public", "goog_public"]) {
    assert.equal(usableApiKey(raw), null);
  }
});

test("the RevenueCat client sends the key and encodes the account id", async () => {
  let seenUrl = "";
  let seenAuth = "";
  const fetchImpl: FetchLike = async (url, init) => {
    seenUrl = url;
    seenAuth = init.headers.Authorization;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        subscriber: { entitlements: { pro: { expires_date: null, product_identifier: "lifetime" } } },
      }),
    };
  };
  const ent = await fetchRevenueCatEntitlement("uid/with space", {
    apiKey: "sk_test",
    nowMs: 0,
    fetchImpl,
  });
  assert.equal(seenUrl, "https://api.revenuecat.com/v1/subscribers/uid%2Fwith%20space");
  assert.equal(seenAuth, "Bearer sk_test");
  assert.equal(ent.plan, "pro");
});

test("the RevenueCat client refuses without a key and surfaces HTTP errors", async () => {
  await assert.rejects(fetchRevenueCatEntitlement("u", { apiKey: null, nowMs: 0 }));
  const failing: FetchLike = async () => ({ ok: false, status: 429, json: async () => ({}) });
  await assert.rejects(
    fetchRevenueCatEntitlement("u", { apiKey: "sk_test", nowMs: 0, fetchImpl: failing }),
    /429/,
  );
});
