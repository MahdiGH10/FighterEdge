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

// --- Expiry-aware entitlement (audit M-4) ---------------------------------

import {
  ENTITLEMENT_LEEWAY_MS,
  entitlementFromSubscriber,
  hasActivePro,
  transferParties,
} from "./billing";

const HOUR = 3_600_000;

test("hasActivePro requires the pro plan", () => {
  assert.equal(hasActivePro({ plan: "free" }, NOW), false);
  assert.equal(hasActivePro(undefined, NOW), false);
  assert.equal(hasActivePro(null, NOW), false);
  assert.equal(hasActivePro({ plan: "PRO" }, NOW), false);
});

test("hasActivePro honours the recorded expiry, with leeway for late renewals", () => {
  const until = (expiresAtMs: number) => ({ plan: "pro", billing: { expiresAtMs } });
  assert.equal(hasActivePro(until(NOW_MS + HOUR), NOW_MS), true);
  // Just expired: still inside the renewal-lag leeway.
  assert.equal(hasActivePro(until(NOW_MS - 1), NOW_MS), true);
  assert.equal(hasActivePro(until(NOW_MS - ENTITLEMENT_LEEWAY_MS + 1), NOW_MS), true);
  // Past the leeway: a missed EXPIRATION webhook no longer keeps Pro on.
  assert.equal(hasActivePro(until(NOW_MS - ENTITLEMENT_LEEWAY_MS), NOW_MS), false);
  assert.equal(hasActivePro(until(NOW_MS - 30 * 24 * HOUR), NOW_MS), false);
});

test("hasActivePro keeps lifetime purchases and manual grants", () => {
  assert.equal(hasActivePro({ plan: "pro" }, NOW), true);
  assert.equal(hasActivePro({ plan: "pro", billing: { expiresAtMs: null } }, NOW), true);
  assert.equal(hasActivePro({ plan: "pro", billing: "garbage" }, NOW), true);
});

test("a billing-issue grace period extends access past the paid-through date", () => {
  const mutation = mapRevenueCatEvent(
    event({
      type: "BILLING_ISSUE",
      expiration_at_ms: NOW - 1,
      grace_period_expiration_at_ms: NOW + 3 * 86_400_000,
    }),
    NOW,
  );
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.expiresAtMs, NOW + 3 * 86_400_000);
});

// --- RevenueCat subscriber parsing ------------------------------------------

const iso = (ms: number) => new Date(ms).toISOString();
const NOW_MS = Date.parse("2026-09-24T12:00:00Z");

function subscriber(pro: Record<string, unknown> | null, subscription: Record<string, unknown> = {}) {
  return {
    subscriber: {
      entitlements: pro ? { pro } : {},
      subscriptions: {
        fighter_edge_pro_annual: { store: "app_store", ...subscription },
      },
    },
  };
}

test("an active, renewing subscription reads as Pro", () => {
  const ent = entitlementFromSubscriber(
    subscriber({ expires_date: iso(NOW_MS + 86_400_000), product_identifier: "fighter_edge_pro_annual" }),
    NOW_MS,
  );
  assert.deepEqual(ent, {
    plan: "pro",
    expiresAtMs: NOW_MS + 86_400_000,
    willRenew: true,
    productId: "fighter_edge_pro_annual",
    store: "app_store",
  });
});

test("a cancelled subscription is Pro until expiry but will not renew", () => {
  const ent = entitlementFromSubscriber(
    subscriber(
      { expires_date: iso(NOW_MS + 86_400_000), product_identifier: "fighter_edge_pro_annual" },
      { unsubscribe_detected_at: iso(NOW_MS - 1000) },
    ),
    NOW_MS,
  );
  assert.equal(ent.plan, "pro");
  assert.equal(ent.willRenew, false);
});

test("an expired entitlement reads as free, keeping its last expiry", () => {
  const ent = entitlementFromSubscriber(
    subscriber({ expires_date: iso(NOW_MS - 1000), product_identifier: "fighter_edge_pro_annual" }),
    NOW_MS,
  );
  assert.equal(ent.plan, "free");
  assert.equal(ent.expiresAtMs, NOW_MS - 1000);
  assert.equal(ent.willRenew, false);
});

test("a grace period keeps an expired subscription Pro", () => {
  const ent = entitlementFromSubscriber(
    subscriber({
      expires_date: iso(NOW_MS - 1000),
      grace_period_expires_date: iso(NOW_MS + 86_400_000),
      product_identifier: "fighter_edge_pro_annual",
    }, { billing_issues_detected_at: iso(NOW_MS - 2000) }),
    NOW_MS,
  );
  assert.equal(ent.plan, "pro");
  assert.equal(ent.expiresAtMs, NOW_MS + 86_400_000);
  assert.equal(ent.willRenew, false);
});

test("a lifetime entitlement has no expiry", () => {
  const ent = entitlementFromSubscriber(
    subscriber({ expires_date: null, product_identifier: "fighter_edge_pro_lifetime" }),
    NOW_MS,
  );
  assert.equal(ent.plan, "pro");
  assert.equal(ent.expiresAtMs, null);
});

test("no entitlement, or a malformed body, reads as free", () => {
  for (const body of [subscriber(null), {}, null, "x", { subscriber: { entitlements: { pro: 3 } } }]) {
    assert.equal(entitlementFromSubscriber(body, NOW_MS).plan, "free");
  }
});

// --- TRANSFER (audit M-5) ----------------------------------------------------

test("a transfer names both sides and drops anonymous RevenueCat ids", () => {
  const parties = transferParties({
    type: "TRANSFER",
    id: "evt-t",
    event_timestamp_ms: NOW,
    transferred_from: ["old-uid", "$RCAnonymousID:abc"],
    transferred_to: ["new-uid"],
  });
  assert.deepEqual(parties, {
    eventId: "evt-t",
    eventTimestampMs: NOW,
    from: ["old-uid"],
    to: ["new-uid"],
  });
});

test("non-transfer or empty transfer events have no parties", () => {
  assert.equal(transferParties(event()), null);
  assert.equal(transferParties({ type: "TRANSFER", id: "e", transferred_from: [], transferred_to: [] }), null);
  assert.equal(transferParties({ type: "TRANSFER", transferred_to: ["x"] }), null);
});
