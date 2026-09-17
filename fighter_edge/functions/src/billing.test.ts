import assert from "node:assert/strict";
import { test } from "node:test";

import { mapRevenueCatEvent } from "./billing";

const NOW = 2_000_000;

function event(overrides: Record<string, unknown> = {}) {
  return {
    id: "evt-1",
    type: "INITIAL_PURCHASE",
    app_user_id: "firebase-user-1",
    event_timestamp_ms: NOW,
    expiration_at_ms: NOW + 86_400_000,
    product_id: "fighter_edge_pro_monthly",
    store: "PLAY_STORE",
    environment: "SANDBOX",
    ...overrides,
  };
}

test("initial purchase grants Pro with an expiry and provider metadata", () => {
  const mutation = mapRevenueCatEvent(event(), NOW);
  assert.deepEqual(mutation, {
    userId: "firebase-user-1",
    plan: "pro",
    expiresAtMs: NOW + 86_400_000,
    willRenew: true,
    eventTimestampMs: NOW,
    provider: "revenuecat",
    providerEventType: "INITIAL_PURCHASE",
    providerEventId: "evt-1",
    productId: "fighter_edge_pro_monthly",
    store: "PLAY_STORE",
    environment: "SANDBOX",
    cancelReason: null,
    expirationReason: null,
  });
});

test("cancellation keeps access until the recorded expiry", () => {
  const mutation = mapRevenueCatEvent(
    event({ type: "CANCELLATION", cancel_reason: "UNSUBSCRIBE" }),
    NOW,
  );
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.willRenew, false);
  assert.equal(mutation?.cancelReason, "UNSUBSCRIBE");
});

test("expiration revokes Pro even when the payload contains the old expiry", () => {
  const mutation = mapRevenueCatEvent(
    event({ type: "EXPIRATION", expiration_reason: "UNSUBSCRIBE" }),
    NOW,
  );
  assert.equal(mutation?.plan, "free");
  assert.equal(mutation?.expirationReason, "UNSUBSCRIBE");
});

test("stale cancellation after expiry is still safe when access has ended", () => {
  const mutation = mapRevenueCatEvent(
    event({
      type: "CANCELLATION",
      expiration_at_ms: NOW - 1,
    }),
    NOW,
  );
  assert.equal(mutation?.plan, "free");
});

test("test, transfer, malformed, and unknown events never mutate entitlements", () => {
  assert.equal(mapRevenueCatEvent(event({ type: "TEST" }), NOW), null);
  assert.equal(mapRevenueCatEvent(event({ type: "TRANSFER" }), NOW), null);
  assert.equal(mapRevenueCatEvent(event({ app_user_id: null }), NOW), null);
  assert.equal(mapRevenueCatEvent(event({ type: "MADE_UP" }), NOW), null);
});
