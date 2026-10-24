import assert from "node:assert/strict";
import { test } from "node:test";

import { mapRevenueCatEvent, parseProPeriod } from "./billing";

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
    proPeriod: null,
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
    proPeriod: null,
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

// --- Store free trial (V2 lane C) ------------------------------------------------

const DAY = 86_400_000;

test("a store trial start grants Pro until the trial end and records TRIAL", () => {
  const mutation = mapRevenueCatEvent(
    event({ period_type: "TRIAL", expiration_at_ms: NOW + 7 * DAY }),
    NOW,
  );
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.proPeriod, "TRIAL");
  assert.equal(mutation?.expiresAtMs, NOW + 7 * DAY);
  assert.equal(mutation?.willRenew, true);
  // The same rule the app and rules use must treat the stored profile as Pro.
  assert.equal(
    hasActivePro({ plan: mutation?.plan, billing: { expiresAtMs: mutation?.expiresAtMs } }, NOW),
    true,
  );
});

test("cancelling during the trial keeps access until the trial expires", () => {
  const mutation = mapRevenueCatEvent(
    event({
      type: "CANCELLATION",
      period_type: "TRIAL",
      cancel_reason: "UNSUBSCRIBE",
      expiration_at_ms: NOW + 3 * DAY,
    }),
    NOW,
  );
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.proPeriod, "TRIAL");
  assert.equal(mutation?.willRenew, false);
  assert.equal(mutation?.expiresAtMs, NOW + 3 * DAY);
});

test("a cancelled trial that has run out is free, not Pro", () => {
  const mutation = mapRevenueCatEvent(
    event({ type: "CANCELLATION", period_type: "TRIAL", expiration_at_ms: NOW - 1 }),
    NOW,
  );
  assert.equal(mutation?.plan, "free");
  assert.equal(mutation?.proPeriod, "TRIAL");
});

test("trial conversion moves the period from TRIAL to NORMAL", () => {
  const start = mapRevenueCatEvent(
    event({ period_type: "TRIAL", expiration_at_ms: NOW + 7 * DAY }),
    NOW,
  );
  const renewal = mapRevenueCatEvent(
    event({
      id: "evt-2",
      type: "RENEWAL",
      period_type: "NORMAL",
      event_timestamp_ms: NOW + 7 * DAY,
      expiration_at_ms: NOW + 37 * DAY,
    }),
    NOW + 7 * DAY,
  );
  assert.equal(start?.proPeriod, "TRIAL");
  assert.equal(renewal?.plan, "pro");
  assert.equal(renewal?.proPeriod, "NORMAL");
  assert.equal(renewal?.expiresAtMs, NOW + 37 * DAY);
});

test("a product change out of the trial records the new period", () => {
  const mutation = mapRevenueCatEvent(
    event({
      type: "PRODUCT_CHANGE",
      period_type: "NORMAL",
      product_id: "fighter_edge_pro_yearly",
      expiration_at_ms: NOW + 365 * DAY,
    }),
    NOW,
  );
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.proPeriod, "NORMAL");
  assert.equal(mutation?.productId, "fighter_edge_pro_yearly");
});

test("an introductory price period is recorded as INTRO and still grants Pro", () => {
  const mutation = mapRevenueCatEvent(event({ period_type: "INTRO" }), NOW);
  assert.equal(mutation?.plan, "pro");
  assert.equal(mutation?.proPeriod, "INTRO");
});

test("trial expiry revokes Pro and keeps the period for the record", () => {
  const mutation = mapRevenueCatEvent(
    event({
      type: "EXPIRATION",
      period_type: "TRIAL",
      expiration_reason: "UNSUBSCRIBE",
      expiration_at_ms: NOW + DAY, // a late payload must not keep access
    }),
    NOW,
  );
  assert.equal(mutation?.plan, "free");
  assert.equal(mutation?.proPeriod, "TRIAL");
});

test("a missing or unknown period_type is stored as null and never as a trial", () => {
  assert.equal(mapRevenueCatEvent(event(), NOW)?.proPeriod, null);
  for (const value of ["PROMOTIONAL", "PREPAID", "trial", "", 7, {}, undefined, null]) {
    const mutation = mapRevenueCatEvent(event({ period_type: value }), NOW);
    assert.equal(mutation?.proPeriod, null, `period_type ${String(value)}`);
    // The entitlement decision itself does not depend on the period.
    assert.equal(mutation?.plan, "pro");
  }
  assert.equal(parseProPeriod("TRIAL"), "TRIAL");
  assert.equal(parseProPeriod("nope"), null);
});

test("subscriber sync reads the period from the REST subscription", () => {
  const trial = entitlementFromSubscriber(
    {
      subscriber: {
        entitlements: {
          pro: { expires_date: iso(NOW_MS + 7 * DAY), product_identifier: "fighter_edge_pro_annual" },
        },
        subscriptions: {
          fighter_edge_pro_annual: { store: "play_store", period_type: "trial" },
        },
      },
    },
    NOW_MS,
  );
  assert.equal(trial.plan, "pro");
  assert.equal(trial.proPeriod, "TRIAL");
  assert.equal(
    entitlementFromSubscriber(
      subscriber(
        { expires_date: iso(NOW_MS + DAY), product_identifier: "fighter_edge_pro_annual" },
        { period_type: "something_new" },
      ),
      NOW_MS,
    ).proPeriod,
    null,
  );
});
