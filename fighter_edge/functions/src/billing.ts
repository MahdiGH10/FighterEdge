/**
 * RevenueCat webhook domain rules.
 *
 * This file deliberately contains no Firebase or HTTP code so subscription
 * lifecycle decisions can be tested without an emulator. RevenueCat sends a
 * cancellation when auto-renew is disabled, but access remains valid until
 * expiration; only EXPIRATION revokes the entitlement.
 */

export type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "PRODUCT_CHANGE"
  | "UNCANCELLATION"
  | "NON_RENEWING_PURCHASE"
  | "SUBSCRIPTION_EXTENDED"
  | "SUBSCRIPTION_PAUSED"
  | "CANCELLATION"
  | "BILLING_ISSUE"
  | "EXPIRATION"
  | "REFUND_REVERSED"
  | "TRANSFER"
  | "TEST";

export interface RevenueCatEvent {
  id?: unknown;
  type?: unknown;
  app_user_id?: unknown;
  original_app_user_id?: unknown;
  aliases?: unknown;
  entitlement_ids?: unknown;
  product_id?: unknown;
  store?: unknown;
  environment?: unknown;
  purchased_at_ms?: unknown;
  expiration_at_ms?: unknown;
  event_timestamp_ms?: unknown;
  cancel_reason?: unknown;
  expiration_reason?: unknown;
}

export interface EntitlementMutation {
  userId: string;
  plan: "free" | "pro";
  expiresAtMs: number | null;
  willRenew: boolean;
  eventTimestampMs: number;
  provider: "revenuecat";
  providerEventType: RevenueCatEventType;
  providerEventId: string;
  productId: string | null;
  store: string | null;
  environment: string | null;
  cancelReason: string | null;
  expirationReason: string | null;
}

const PRO_GRANT_EVENTS = new Set<RevenueCatEventType>([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "REFUND_REVERSED",
]);

const KEEP_UNTIL_EXPIRY_EVENTS = new Set<RevenueCatEventType>([
  "CANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
]);

const REVOKE_EVENTS = new Set<RevenueCatEventType>(["EXPIRATION"]);

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function finiteNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? value
    : null;
}

function eventType(value: unknown): RevenueCatEventType | null {
  const known: RevenueCatEventType[] = [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "PRODUCT_CHANGE",
    "UNCANCELLATION",
    "NON_RENEWING_PURCHASE",
    "SUBSCRIPTION_EXTENDED",
    "SUBSCRIPTION_PAUSED",
    "CANCELLATION",
    "BILLING_ISSUE",
    "EXPIRATION",
    "REFUND_REVERSED",
    "TRANSFER",
    "TEST",
  ];
  return typeof value === "string" && known.includes(value as RevenueCatEventType)
    ? (value as RevenueCatEventType)
    : null;
}

/** Returns the safe server mutation for a valid lifecycle event. */
export function mapRevenueCatEvent(
  event: RevenueCatEvent,
  nowMs = Date.now(),
): EntitlementMutation | null {
  const type = eventType(event.type);
  const providerEventId = stringValue(event.id);
  const userId = stringValue(event.app_user_id);
  if (!type || !providerEventId || !userId) return null;

  // TEST events validate the integration but must never grant a real account.
  if (type === "TEST" || type === "TRANSFER") return null;

  const eventTimestampMs = finiteNumber(event.event_timestamp_ms) ?? nowMs;
  const expiresAtMs = finiteNumber(event.expiration_at_ms);
  const hasFutureAccess = expiresAtMs == null || expiresAtMs > nowMs;

  let plan: "free" | "pro";
  if (REVOKE_EVENTS.has(type)) {
    plan = "free";
  } else if (KEEP_UNTIL_EXPIRY_EVENTS.has(type)) {
    plan = hasFutureAccess ? "pro" : "free";
  } else if (PRO_GRANT_EVENTS.has(type)) {
    plan = hasFutureAccess ? "pro" : "free";
  } else {
    return null;
  }

  return {
    userId,
    plan,
    expiresAtMs,
    willRenew: type !== "CANCELLATION" && type !== "SUBSCRIPTION_PAUSED",
    eventTimestampMs,
    provider: "revenuecat",
    providerEventType: type,
    providerEventId,
    productId: stringValue(event.product_id),
    store: stringValue(event.store),
    environment: stringValue(event.environment),
    cancelReason: stringValue(event.cancel_reason),
    expirationReason: stringValue(event.expiration_reason),
  };
}
