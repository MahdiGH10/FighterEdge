/**
 * Server-owned Pro entitlement: webhook processing, on-demand sync with
 * RevenueCat, and reconciliation (audit M-3, M-4, M-5).
 *
 * Every write goes through [writeEntitlement], which is ordered by
 * timestamp. A late or replayed event can therefore never overwrite newer
 * state, whether it came from a webhook, a sync, or the scheduled job. The
 * RevenueCat REST client takes an injectable fetch so all of this is tested
 * against the Firestore emulator without network access.
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

import {
  ENTITLEMENT_LEEWAY_MS,
  entitlementFromSubscriber,
  mapRevenueCatEvent,
  RevenueCatEntitlement,
  RevenueCatEvent,
  transferParties,
} from "./billing";

export type FetchLike = (
  url: string,
  init: {
    method: string;
    headers: Record<string, string>;
    signal?: AbortSignal;
  },
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export interface RevenueCatDeps {
  /** RevenueCat secret API key, or null when not configured. */
  apiKey: string | null;
  nowMs: number;
  fetchImpl?: FetchLike;
}

const REVENUECAT_SUBSCRIBERS = "https://api.revenuecat.com/v1/subscribers/";
const REVENUECAT_TIMEOUT_MS = 10_000;

/** Minimum gap between two syncs for one account (protects the RC quota). */
export const SYNC_THROTTLE_MS = 10_000;

/**
 * RevenueCat secret keys start with `sk_`. Anything else, including the
 * placeholder "unset" used to deploy before RevenueCat exists, counts as not
 * configured.
 */
export function usableApiKey(raw: string | null | undefined): string | null {
  const key = raw?.trim() ?? "";
  return key.startsWith("sk_") ? key : null;
}

export class RevenueCatUnavailable extends Error {}

/** One call to RevenueCat's v1 subscriber endpoint, with a timeout. */
async function revenueCatRequest(
  method: "GET" | "DELETE",
  appUserId: string,
  deps: RevenueCatDeps,
): Promise<Awaited<ReturnType<FetchLike>>> {
  if (!deps.apiKey) throw new RevenueCatUnavailable("RevenueCat API key not configured");
  const fetchImpl = deps.fetchImpl ?? (fetch as unknown as FetchLike);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REVENUECAT_TIMEOUT_MS);
  try {
    return await fetchImpl(REVENUECAT_SUBSCRIBERS + encodeURIComponent(appUserId), {
      method,
      headers: {
        Authorization: `Bearer ${deps.apiKey}`,
        "Content-Type": "application/json",
      },
      signal: controller.signal,
    });
  } catch (error) {
    throw new RevenueCatUnavailable(`RevenueCat unreachable: ${String(error)}`);
  } finally {
    clearTimeout(timeout);
  }
}

/** The account's `pro` entitlement as RevenueCat sees it right now. */
export async function fetchRevenueCatEntitlement(
  appUserId: string,
  deps: RevenueCatDeps,
): Promise<RevenueCatEntitlement> {
  const response = await revenueCatRequest("GET", appUserId, deps);
  if (!response.ok) {
    throw new RevenueCatUnavailable(`RevenueCat responded ${response.status}`);
  }
  return entitlementFromSubscriber(await response.json(), deps.nowMs);
}

/**
 * Deletes the RevenueCat customer and its purchase history (RevenueCat's
 * GDPR deletion). A customer RevenueCat doesn't know counts as deleted, so
 * a retried account deletion goes through. This does not cancel a store
 * subscription; the account-deletion page tells the athlete to do that.
 */
export async function deleteRevenueCatSubscriber(
  appUserId: string,
  deps: RevenueCatDeps,
): Promise<"deleted" | "not_found"> {
  const response = await revenueCatRequest("DELETE", appUserId, deps);
  if (response.status === 404) return "not_found";
  if (!response.ok) {
    throw new RevenueCatUnavailable(`RevenueCat responded ${response.status}`);
  }
  return "deleted";
}

/**
 * Unlinks the `billingEvents` ledger from a deleted account (audit D-9). The
 * entries stay, with their event ID, type and time, so a replayed webhook is
 * still recognised as a duplicate, but none of them points to the account
 * any more. Returns how many entries were unlinked.
 */
export async function forgetBillingLedger(db: Firestore, uid: string): Promise<number> {
  const ledger = db.collection("billingEvents");
  const [single, transfers] = await Promise.all([
    ledger.where("userId", "==", uid).get(),
    ledger.where("userIds", "array-contains", uid).get(),
  ]);
  const updates = [
    ...single.docs.map((doc) => ({
      ref: doc.ref,
      data: { userId: FieldValue.delete(), accountDeleted: true },
    })),
    ...transfers.docs.map((doc) => ({
      ref: doc.ref,
      data: { userIds: FieldValue.arrayRemove(uid), accountDeleted: true },
    })),
  ];
  // A batch holds at most 500 writes.
  for (let start = 0; start < updates.length; start += 400) {
    const batch = db.batch();
    for (const { ref, data } of updates.slice(start, start + 400)) {
      batch.update(ref, data);
    }
    await batch.commit();
  }
  return updates.length;
}

export type WriteOutcome = "applied" | "stale" | "unknown_user";

/**
 * Writes [entitlement] to `users/{uid}` unless the stored state is newer.
 * Never creates a profile: the Firebase account must already exist.
 */
export async function writeEntitlement(
  db: Firestore,
  uid: string,
  entitlement: RevenueCatEntitlement,
  source: { type: string; eventId: string | null; timestampMs: number },
  extraBilling: Record<string, unknown> = {},
): Promise<WriteOutcome> {
  const userRef = db.collection("users").doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) return "unknown_user";
    const previous =
      (snap.data()?.billing as { lastEventTimestampMs?: number } | undefined)
        ?.lastEventTimestampMs ?? 0;
    if (source.timestampMs < previous) return "stale";
    tx.set(
      userRef,
      {
        plan: entitlement.plan,
        entitlement: entitlement.plan === "pro" ? "pro" : null,
        billing: {
          provider: "revenuecat",
          productId: entitlement.productId,
          store: entitlement.store,
          expiresAtMs: entitlement.expiresAtMs,
          willRenew: entitlement.willRenew,
          lastEventId: source.eventId,
          lastEventType: source.type,
          lastEventTimestampMs: source.timestampMs,
          updatedAt: new Date(source.timestampMs).toISOString(),
          ...extraBilling,
        },
      },
      { merge: true },
    );
    return "applied";
  });
}

export type WebhookResult =
  | { status: "processed"; applied: number }
  | { status: "duplicate" }
  | { status: "ignored"; reason: string };

/**
 * Applies one RevenueCat webhook event. Idempotent per event id via the
 * `billingEvents` ledger. Throws only for a retryable failure (Firestore or
 * RevenueCat unavailable), which becomes a non-2xx so RevenueCat retries.
 */
export async function processRevenueCatEvent(
  db: Firestore,
  event: RevenueCatEvent | undefined,
  deps: RevenueCatDeps,
): Promise<WebhookResult> {
  if (!event) return { status: "ignored", reason: "missing_event" };

  const transfer = transferParties(event);
  if (transfer) return processTransfer(db, transfer, deps);

  const mutation = mapRevenueCatEvent(event, deps.nowMs);
  // TEST and unknown events are acknowledged but never mutate entitlements.
  if (!mutation) return { status: "ignored", reason: "unsupported_or_test_event" };

  const eventRef = db.collection("billingEvents").doc(mutation.providerEventId);
  const userRef = db.collection("users").doc(mutation.userId);
  return db.runTransaction(async (tx): Promise<WebhookResult> => {
    const eventSnap = await tx.get(eventRef);
    if (eventSnap.exists) return { status: "duplicate" };
    const userSnap = await tx.get(userRef);
    const ledger = {
      provider: mutation.provider,
      type: mutation.providerEventType,
      userId: mutation.userId,
      eventTimestampMs: mutation.eventTimestampMs,
      receivedAt: new Date(deps.nowMs).toISOString(),
    };

    // Never create an entitlement profile from an external identifier, and
    // don't record the identifier either: it may belong to a deleted account.
    if (!userSnap.exists) {
      const { userId: _unknown, ...anonymous } = ledger;
      tx.create(eventRef, { ...anonymous, applied: false, ignored: "unknown_user" });
      return { status: "processed", applied: 0 };
    }

    const previous =
      (userSnap.data()?.billing as { lastEventTimestampMs?: number } | undefined)
        ?.lastEventTimestampMs ?? 0;
    const isNewer = mutation.eventTimestampMs >= previous;
    if (isNewer) {
      tx.set(
        userRef,
        {
          plan: mutation.plan,
          entitlement: mutation.plan === "pro" ? "pro" : null,
          billing: {
            provider: mutation.provider,
            productId: mutation.productId,
            store: mutation.store,
            environment: mutation.environment,
            expiresAtMs: mutation.expiresAtMs,
            willRenew: mutation.willRenew,
            cancelReason: mutation.cancelReason,
            expirationReason: mutation.expirationReason,
            lastEventId: mutation.providerEventId,
            lastEventType: mutation.providerEventType,
            lastEventTimestampMs: mutation.eventTimestampMs,
            updatedAt: new Date(deps.nowMs).toISOString(),
          },
        },
        { merge: true },
      );
    }
    tx.create(eventRef, { ...ledger, applied: isNewer });
    return { status: "processed", applied: isNewer ? 1 : 0 };
  });
}

/**
 * TRANSFER carries no entitlement data, so both sides are re-read from
 * RevenueCat. Without an API key the losing side is still revoked (it no
 * longer owns the purchase), and the gaining side is picked up by its own
 * sync (a restore calls [syncEntitlement]) once a key is configured.
 */
async function processTransfer(
  db: Firestore,
  transfer: NonNullable<ReturnType<typeof transferParties>>,
  deps: RevenueCatDeps,
): Promise<WebhookResult> {
  const eventRef = db.collection("billingEvents").doc(transfer.eventId);
  if ((await eventRef.get()).exists) return { status: "duplicate" };

  const timestampMs = transfer.eventTimestampMs ?? deps.nowMs;
  const source = { type: "TRANSFER", eventId: transfer.eventId, timestampMs };
  let applied = 0;
  let pending = 0;

  for (const uid of [...transfer.from, ...transfer.to]) {
    let outcome: WriteOutcome;
    if (deps.apiKey) {
      // A RevenueCat failure throws: the event is retried as a whole, and
      // the timestamp ordering makes re-applying the finished part harmless.
      outcome = await writeEntitlement(
        db,
        uid,
        await fetchRevenueCatEntitlement(uid, deps),
        source,
      );
    } else if (transfer.from.includes(uid)) {
      outcome = await writeEntitlement(
        db,
        uid,
        { plan: "free", expiresAtMs: null, willRenew: false, productId: null, store: null },
        source,
      );
    } else {
      pending++;
      continue;
    }
    if (outcome === "applied") applied++;
  }

  await eventRef.create({
    provider: "revenuecat",
    type: "TRANSFER",
    userIds: [...transfer.from, ...transfer.to],
    eventTimestampMs: timestampMs,
    receivedAt: new Date(deps.nowMs).toISOString(),
    applied: applied > 0,
    ...(pending > 0 ? { pendingWithoutApiKey: pending } : {}),
  });
  if (pending > 0) {
    logger.warn("revenuecat_transfer_pending_api_key", { pending });
  }
  return { status: "processed", applied };
}

export type SyncResult =
  | { status: "updated"; isPro: boolean; expiresAtMs: number | null }
  | { status: "throttled" }
  | { status: "unavailable" };

/**
 * Pulls the caller's entitlement straight from RevenueCat. The app calls
 * this right after a purchase or restore, so Pro lands in seconds instead of
 * waiting for the webhook. It is also what makes a restore on a different
 * account work (M-5).
 */
export async function syncEntitlement(
  db: Firestore,
  uid: string,
  deps: RevenueCatDeps,
): Promise<SyncResult> {
  if (!deps.apiKey) return { status: "unavailable" };
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) return { status: "unavailable" };
  const lastSyncAtMs =
    (snap.data()?.billing as { lastSyncAtMs?: number } | undefined)?.lastSyncAtMs ?? 0;
  if (deps.nowMs - lastSyncAtMs < SYNC_THROTTLE_MS) return { status: "throttled" };

  let entitlement: RevenueCatEntitlement;
  try {
    entitlement = await fetchRevenueCatEntitlement(uid, deps);
  } catch (error) {
    logger.warn("entitlement_sync_unavailable", { error: String(error) });
    return { status: "unavailable" };
  }
  await writeEntitlement(
    db,
    uid,
    entitlement,
    { type: "SYNC", eventId: null, timestampMs: deps.nowMs },
    { lastSyncAtMs: deps.nowMs },
  );
  return {
    status: "updated",
    isPro: entitlement.plan === "pro",
    expiresAtMs: entitlement.expiresAtMs,
  };
}

/**
 * Settles Pro profiles whose recorded expiry is past the leeway: a renewal
 * webhook that never arrived is recovered from RevenueCat, and a genuinely
 * expired plan is set back to free. Manual grants with no recorded expiry
 * are never touched.
 */
export async function reconcileExpiredEntitlements(
  db: Firestore,
  deps: RevenueCatDeps,
  limit = 200,
): Promise<{ checked: number; stillPro: number; expired: number; failed: number }> {
  const cutoff = deps.nowMs - ENTITLEMENT_LEEWAY_MS;
  const expiredPro = await db
    .collection("users")
    .where("plan", "==", "pro")
    .where("billing.expiresAtMs", "<", cutoff)
    .limit(limit)
    .get();

  const counts = { checked: 0, stillPro: 0, expired: 0, failed: 0 };
  for (const doc of expiredPro.docs) {
    counts.checked++;
    let entitlement: RevenueCatEntitlement = {
      plan: "free",
      expiresAtMs: null,
      willRenew: false,
      productId: null,
      store: null,
    };
    if (deps.apiKey) {
      try {
        entitlement = await fetchRevenueCatEntitlement(doc.id, deps);
      } catch {
        counts.failed++;
        continue; // Try again next run; the leeway check already denies Pro.
      }
    } else {
      // Without RevenueCat, keep what the webhook last said about the store
      // and only flip the plan off.
      const billing = doc.data().billing as Record<string, unknown> | undefined;
      entitlement = {
        ...entitlement,
        expiresAtMs: (billing?.expiresAtMs as number | undefined) ?? null,
        productId: (billing?.productId as string | undefined) ?? null,
        store: (billing?.store as string | undefined) ?? null,
      };
    }
    await writeEntitlement(db, doc.id, entitlement, {
      type: "RECONCILE",
      eventId: null,
      timestampMs: deps.nowMs,
    });
    if (entitlement.plan === "pro") counts.stillPro++;
    else counts.expired++;
  }
  return counts;
}
