import { getAuth } from "firebase-admin/auth";
import { Firestore, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import {
  deleteRevenueCatSubscriber,
  forgetBillingLedger,
  RevenueCatDeps,
  RevenueCatUnavailable,
  usableApiKey,
} from "./entitlements";
import { REVENUECAT_API_KEY } from "./secrets";

export interface AccountDataDeletion {
  revenueCat: "deleted" | "not_found" | "skipped_no_key";
  ledgerEntriesUnlinked: number;
}

/**
 * Deletes everything the service holds about [uid] except the Auth user:
 *
 * 1. The RevenueCat customer and its purchase history (audit D-9). First, so
 *    that if RevenueCat is unreachable nothing has been deleted yet and the
 *    athlete can simply try again. A customer RevenueCat doesn't know counts
 *    as deleted, which keeps a retry working.
 * 2. The account link in the `billingEvents` ledger. The event IDs, types
 *    and times stay for idempotency.
 * 3. Every Firestore document under `users/{uid}`: profile, consents,
 *    weights, meals, sessions, training log, nutrition data and AI usage.
 *
 * Throws [RevenueCatUnavailable] when step 1 fails, before any deletion.
 */
export async function deleteAccountData(
  db: Firestore,
  uid: string,
  deps: RevenueCatDeps,
): Promise<AccountDataDeletion> {
  const revenueCat = deps.apiKey
    ? await deleteRevenueCatSubscriber(uid, deps)
    : ("skipped_no_key" as const);
  const ledgerEntriesUnlinked = await forgetBillingLedger(db, uid);
  await db.recursiveDelete(db.collection("users").doc(uid));
  return { revenueCat, ledgerEntriesUnlinked };
}

/**
 * Permanently deletes the caller's account (see [deleteAccountData]), then
 * the Firebase Auth user itself. Irreversible.
 *
 * Runs as a Cloud Function rather than client-side because
 * `firestore.rules` deliberately blocks `delete` on the `users/{uid}`
 * document from the client (billing/entitlement state is server-owned, and a
 * client-side delete-then-recreate would be a way around that) — only the
 * Admin SDK, which bypasses security rules, can remove it. This also avoids
 * Firebase's "requires a recent sign-in" client-side constraint entirely: an
 * authenticated callable request is enough, no re-auth prompt needed.
 *
 * Data is wiped before the Auth user, so a failure partway through leaves a
 * signed-in account the athlete can retry deleting, rather than a
 * signed-out account with data still on the server.
 *
 * Logs never carry the account ID (repository rule): only outcomes and
 * counts.
 */
export const deleteAccount = onCall(
  { cors: true, secrets: [REVENUECAT_API_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;

    let outcome: AccountDataDeletion;
    try {
      outcome = await deleteAccountData(getFirestore(), uid, {
        apiKey: usableApiKey(REVENUECAT_API_KEY.value()),
        nowMs: Date.now(),
      });
    } catch (error) {
      if (error instanceof RevenueCatUnavailable) {
        logger.warn("account_deletion_billing_unavailable", { error: String(error) });
        throw new HttpsError(
          "unavailable",
          "We couldn't reach the billing service, so nothing was deleted yet. " +
            "Please try again in a few minutes.",
        );
      }
      logger.error("account_deletion_firestore_failed", { error: String(error) });
      throw new HttpsError(
        "internal",
        "Could not delete your data. Please try again.",
      );
    }

    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      // The data is already gone; log loudly so the orphaned Auth record can
      // be found by time and cleaned up, rather than silently leaving an
      // account that looks alive but has no data.
      logger.error("account_deletion_auth_failed", { error: String(error) });
      throw new HttpsError(
        "internal",
        "Your data was deleted but sign-out could not complete. Contact support.",
      );
    }

    logger.info("account_deleted", outcome);
    return { status: "deleted" as const };
  },
);
