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
  /** Set on BILLING_ISSUE when the store grants a grace period. */
  grace_period_expiration_at_ms?: unknown;
  event_timestamp_ms?: unknown;
  /** TRANSFER only: the App User IDs the purchases moved from and to. */
  transferred_from?: unknown;
  transferred_to?: unknown;
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

function laterOf(a: number | null, b: number | null): number | null {
  if (a == null) return b;
  if (b == null) return a;
  return Math.max(a, b);
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
  // A billing-issue grace period extends access past the paid-through date.
  const expiresAtMs = laterOf(
    finiteNumber(event.expiration_at_ms),
    finiteNumber(event.grace_period_expiration_at_ms),
  );
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

/**
 * How long past a recorded expiry Pro still counts. Stores report renewals to
 * RevenueCat with some delay, and a paying athlete must not lose Pro at every
 * period boundary while that lands. The scheduled reconciliation settles
 * anything still expired after this window.
 */
export const ENTITLEMENT_LEEWAY_MS = 60 * 60 * 1000;

/**
 * The one server-side answer to "is this profile Pro right now?" (audit
 * M-4). `plan` alone is not enough: a missed EXPIRATION webhook used to leave
 * Pro on forever. A Pro plan with no recorded expiry (a lifetime purchase or
 * a manual grant) stays Pro.
 */
export function hasActivePro(profile: unknown, nowMs: number): boolean {
  if (typeof profile !== "object" || profile === null) return false;
  const data = profile as { plan?: unknown; billing?: unknown };
  if (data.plan !== "pro") return false;
  const billing =
    typeof data.billing === "object" && data.billing !== null
      ? (data.billing as { expiresAtMs?: unknown })
      : {};
  const expiresAtMs = finiteNumber(billing.expiresAtMs);
  return expiresAtMs == null || expiresAtMs + ENTITLEMENT_LEEWAY_MS > nowMs;
}

/** Entitlement state as RevenueCat reports it right now. */
export interface RevenueCatEntitlement {
  plan: "free" | "pro";
  expiresAtMs: number | null;
  willRenew: boolean;
  productId: string | null;
  store: string | null;
}

function isoMs(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * Reads the `pro` entitlement from a RevenueCat v1 `GET /subscribers/{id}`
 * response. Pure, so the REST client stays a thin I/O shell.
 */
export function entitlementFromSubscriber(
  body: unknown,
  nowMs: number,
  entitlementId = "pro",
): RevenueCatEntitlement {
  const none: RevenueCatEntitlement = {
    plan: "free",
    expiresAtMs: null,
    willRenew: false,
    productId: null,
    store: null,
  };
  const subscriber = (body as { subscriber?: unknown } | null)?.subscriber;
  if (typeof subscriber !== "object" || subscriber === null) return none;
  const sub = subscriber as { entitlements?: unknown; subscriptions?: unknown };
  const entitlements =
    typeof sub.entitlements === "object" && sub.entitlements !== null
      ? (sub.entitlements as Record<string, unknown>)
      : {};
  const raw = entitlements[entitlementId];
  if (typeof raw !== "object" || raw === null) return none;
  const ent = raw as {
    expires_date?: unknown;
    grace_period_expires_date?: unknown;
    product_identifier?: unknown;
  };
  const productId = stringValue(ent.product_identifier);
  const expiresAtMs = laterOf(
    isoMs(ent.expires_date),
    isoMs(ent.grace_period_expires_date),
  );
  // A null expires_date is a lifetime (non-expiring) entitlement.
  const lifetime = ent.expires_date === null || ent.expires_date === undefined;
  const active = lifetime || (expiresAtMs != null && expiresAtMs > nowMs);

  const subscriptions =
    typeof sub.subscriptions === "object" && sub.subscriptions !== null
      ? (sub.subscriptions as Record<string, unknown>)
      : {};
  const subscription = (productId ? subscriptions[productId] : undefined) as
    | {
        unsubscribe_detected_at?: unknown;
        billing_issues_detected_at?: unknown;
        store?: unknown;
      }
    | undefined;
  const willRenew =
    active &&
    !lifetime &&
    subscription !== undefined &&
    subscription.unsubscribe_detected_at == null &&
    subscription.billing_issues_detected_at == null;

  return {
    plan: active ? "pro" : "free",
    expiresAtMs: lifetime ? null : expiresAtMs,
    willRenew,
    productId,
    store: stringValue(subscription?.store),
  };
}

function appUserIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map(stringValue)
    .filter((id): id is string => id !== null)
    // Anonymous RevenueCat IDs never correspond to a Firebase account.
    .filter((id) => !id.startsWith("$RCAnonymousID:"));
}

/**
 * The accounts a TRANSFER event touches (audit M-5). RevenueCat moves the
 * purchases from `transferred_from` to `transferred_to` when a restore happens
 * on a different account, and the event carries no entitlement data. Both
 * sides must therefore be re-read from RevenueCat.
 */
export function transferParties(
  event: RevenueCatEvent,
): { eventId: string; eventTimestampMs: number | null; from: string[]; to: string[] } | null {
  if (event.type !== "TRANSFER") return null;
  const eventId = stringValue(event.id);
  if (!eventId) return null;
  const from = appUserIds(event.transferred_from);
  const to = appUserIds(event.transferred_to).filter((id) => !from.includes(id));
  if (from.length === 0 && to.length === 0) return null;
  return {
    eventId,
    eventTimestampMs: finiteNumber(event.event_timestamp_ms),
    from,
    to,
  };
}
