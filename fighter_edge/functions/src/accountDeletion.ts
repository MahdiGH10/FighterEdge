import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Permanently deletes the caller's account: every Firestore document under
 * `users/{uid}` (profile, weights, meals, sessions, nutritionProfile,
 * nutritionTargets, nutritionDays, aiUsage) and the Firebase Auth user
 * itself. Irreversible.
 *
 * Runs as a Cloud Function rather than client-side because
 * `firestore.rules` deliberately blocks `delete` on the `users/{uid}`
 * document from the client (billing/entitlement state is server-owned, and a
 * client-side delete-then-recreate would be a way around that) — only the
 * Admin SDK, which bypasses security rules, can remove it. This also avoids
 * Firebase's "requires a recent sign-in" client-side constraint entirely: an
 * authenticated callable request is enough, no re-auth prompt needed.
 *
 * Firestore is wiped before the Auth user, so a failure partway through
 * leaves an orphaned-but-still-signed-in-out account (recoverable by asking
 * the user to try again) rather than a signed-out account with data still on
 * the server.
 */
export const deleteAccount = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const db = getFirestore();

  try {
    await db.recursiveDelete(db.collection("users").doc(uid));
  } catch (error) {
    logger.error("account_deletion_firestore_failed", { uid, error: String(error) });
    throw new HttpsError(
      "internal",
      "Could not delete your data. Please try again.",
    );
  }

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    // Firestore data is already gone at this point; log loudly so this
    // orphaned Auth record can be cleaned up manually rather than silently
    // leaving an account that looks alive but has no data.
    logger.error("account_deletion_auth_failed", { uid, error: String(error) });
    throw new HttpsError(
      "internal",
      "Your data was deleted but sign-out could not complete. Contact support.",
    );
  }

  logger.info("account_deleted", { uid });
  return { status: "deleted" as const };
});
