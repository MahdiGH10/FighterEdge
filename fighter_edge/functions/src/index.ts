import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { mapRevenueCatEvent, RevenueCatEvent } from "./billing";
import { callOpenRouter, DEFAULT_MODEL, OpenRouterError } from "./openrouter";
import { consumeQuota, isAiEnabled } from "./quota";
import { SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } from "./systemPrompt";
import { AiRequest, AiTaskType } from "./types";
import { parseModelJson, validateResponse } from "./validate";

initializeApp();

export { deleteAccount } from "./accountDeletion";

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const REVENUECAT_WEBHOOK_AUTH = defineSecret("REVENUECAT_WEBHOOK_AUTH");
/** First attempt plus at most one retry of a rejected answer. */
const MAX_MODEL_ATTEMPTS = 2;

/**
 * Retry only if the first answer came back within this long. The provider
 * call itself is capped at 25 s, so a retry started here finishes inside the
 * Flutter client's 45 s wait.
 */
const RETRY_CUTOFF_MS = 18_000;

const ALLOWED_TASKS: readonly AiTaskType[] = [
  "explainPlan",
  "fighterBrief",
  "summarizeTrend",
];

/**
 * The one and only backend boundary the Flutter app depends on
 * (`EdgeFuelAiGateway` client-side). Pipeline matches master prompt §13:
 * auth -> quota -> request validation -> minimum-necessary context -> model
 * -> strict schema + safety validation -> typed result.
 *
 * Fast-MVP scope (explicit, user-approved deviation from the full spec):
 * App Check is still a deployment follow-up. Entitlement checks and the
 * server-owned Pro gate are enforced here before quota is consumed.
 */
export const edgeFuelAiExplain = onCall(
  { secrets: [OPENROUTER_API_KEY], cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    // Unverified accounts are the cheap way to farm paid inference: sign up
    // with an address you do not own, spend our quota, repeat. The client
    // refuses first for a readable message, but that is UX — this is the
    // boundary. Checked before the profile read and before quota is consumed,
    // so a refused caller costs us nothing. Federated sign-in (Google, Apple)
    // arrives with email_verified already true.
    if (request.auth.token.email_verified !== true) {
      logger.info("ai_request_blocked", { reason: "email_not_verified" });
      throw new HttpsError(
        "permission-denied",
        "Verify your email address to use the AI coach."
      );
    }
    const uid = request.auth.uid;
    const db = getFirestore();

    if (!(await isAiEnabled(db))) {
      return { status: "unavailable" as const };
    }

    const data = request.data as Partial<AiRequest> | undefined;
    if (!data || !data.task || !ALLOWED_TASKS.includes(data.task)) {
      throw new HttpsError("invalid-argument", "Unsupported or missing task.");
    }
    if (!data.target || typeof data.target !== "object") {
      throw new HttpsError("invalid-argument", "Missing target facts.");
    }

    // Client-side gates are only a UX optimization. Premium tasks must be
    // authorized against the server-owned profile before consuming quota.
    if (data.task !== "summarizeTrend") {
      const profile = await db.collection("users").doc(uid).get();
      if (profile.data()?.plan !== "pro") {
        return { status: "entitlementRequired" as const };
      }
    }

    const quota = await consumeQuota(db, uid, new Date());
    if (!quota.allowed) {
      logger.info("ai_request_blocked", {
        task: data.task,
        reason: "quota_reached",
      });
      return { status: "quotaReached" as const };
    }
    logger.info("ai_request_started", {
      task: data.task,
      remainingQuota: quota.remaining,
    });

    const suppliedFacts = {
      task: data.task,
      target: data.target,
      day: data.day ?? null,
      foodPreferences: data.foodPreferences ?? null,
    };
    const suppliedFactsJson = JSON.stringify(suppliedFacts);

    const responseShape =
      data.task === "fighterBrief"
        ? {
            schemaVersion: 2,
            summary: "string",
            brief: {
              nextAction: "string",
              mealSuggestion: "string",
              trainingTiming: "string",
              weeklyAdjustment: "string",
            },
            actions: [],
            warnings: ["string"],
            requiresProfessionalReview: false,
            factsUsed: ["fact-name-from-supplied-facts"],
            contentVersion: "string",
          }
        : {
            schemaVersion: 1,
            summary: "string",
            actions: [
              {
                type: "meal|recipe|timing|shopping|logging|recovery",
                title: "string",
                reason: "string",
                recipeIds: [],
                mealSlot: "optional string",
              },
            ],
            warnings: ["string"],
            requiresProfessionalReview: false,
            factsUsed: ["fact-name-from-supplied-facts"],
            contentVersion: "string",
          };

    const userContent = [
      "Task:", data.task,
      "\nSupplied facts (JSON):", suppliedFactsJson,
      "\nRespond with exactly one JSON object matching this shape:",
      JSON.stringify(responseShape),
      data.task === "fighterBrief"
        ? "For Fighter Brief, make each brief section specific, concise, and grounded only in the supplied facts."
        : "",
      "\nThis deployment has no recipe catalog yet — recipeIds must always be an empty array.",
    ].join(" ");

    // One retry, only for an answer the validator rejected, and only while
    // there is still time for a second attempt inside the client's wait.
    // Measured on the free model: ~75% of first answers pass, so a second
    // independent try lifts the success rate to ~94% at the cost of latency
    // only for the unlucky quarter. A provider error or timeout is not
    // retried — a slow provider will not get faster on the second call.
    const model = process.env.OPENROUTER_MODEL ?? DEFAULT_MODEL;
    const startedAt = Date.now();
    let parsed: unknown = null;
    let validation: { ok: boolean; reason?: string } = { ok: false };
    for (let attempt = 1; attempt <= MAX_MODEL_ATTEMPTS; attempt++) {
      let rawContent: string;
      try {
        rawContent = await callOpenRouter({
          apiKey: OPENROUTER_API_KEY.value(),
          model,
          systemPrompt: SYSTEM_PROMPT,
          userContent,
        });
      } catch (error) {
        // Never expose raw provider errors to the client (master prompt §13.3).
        logger.error("openrouter_call_failed", {
          task: data.task,
          attempt,
          error: error instanceof OpenRouterError ? error.message : "unknown",
        });
        return { status: "unavailable" as const };
      }

      parsed = parseModelJson(rawContent);
      validation = validateResponse(parsed, suppliedFactsJson, data.task);
      if (validation.ok) break;
      logger.warn("ai_response_rejected", {
        task: data.task,
        attempt,
        reason: validation.reason,
      });
      if (Date.now() - startedAt > RETRY_CUTOFF_MS) break;
    }
    if (!validation.ok) {
      return { status: "unavailable" as const };
    }

    logger.info("ai_request_completed", {
      task: data.task,
      status: "success",
      requiresProfessionalReview:
        (parsed as { requiresProfessionalReview?: unknown })
          .requiresProfessionalReview === true,
    });
    return {
      status: "success" as const,
      response: {
        ...(parsed as object),
        contentVersion: `sp${SYSTEM_PROMPT_VERSION}`,
      },
    };
  },
);

/**
 * RevenueCat server-to-server subscription lifecycle endpoint.
 *
 * RevenueCat authenticates this endpoint with the configured Authorization
 * header. Events are idempotent and ordered per user by event timestamp so a
 * delayed cancellation cannot overwrite a newer renewal.
 */
export const revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_AUTH], cors: false },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }

    const expected = REVENUECAT_WEBHOOK_AUTH.value();
    const received = request.get("authorization") ?? "";
    if (!expected || received !== expected) {
      response.status(401).send("Unauthorized");
      return;
    }

    const raw = request.body as { event?: RevenueCatEvent } | undefined;
    const event = raw?.event;
    if (!event) {
      response.status(400).send("Missing event");
      return;
    }

    const mutation = mapRevenueCatEvent(event);
    // TEST, TRANSFER, and unknown events are acknowledged but do not mutate
    // entitlements. RevenueCat retries any non-2xx response.
    if (!mutation) {
      logger.info("revenuecat_webhook_ignored", {
        reason: "unsupported_or_test_event",
      });
      response.status(200).json({ status: "ignored" });
      return;
    }

    const db = getFirestore();
    const eventRef = db.collection("billingEvents").doc(mutation.providerEventId);
    const userRef = db.collection("users").doc(mutation.userId);

    try {
      await db.runTransaction(async (tx) => {
        const eventSnap = await tx.get(eventRef);
        if (eventSnap.exists) return;
        const userSnap = await tx.get(userRef);

        // Never create an entitlement profile from an external identifier.
        // The Firebase account must already exist and be owned by this app.
        if (!userSnap.exists) {
          tx.create(eventRef, {
            provider: mutation.provider,
            type: mutation.providerEventType,
            userId: mutation.userId,
            eventTimestampMs: mutation.eventTimestampMs,
            receivedAt: new Date().toISOString(),
            applied: false,
            ignored: "unknown_user",
          });
          return;
        }

        const existing = userSnap.data()?.billing as
          | { lastEventTimestampMs?: number }
          | undefined;
        const previousTimestamp = existing?.lastEventTimestampMs ?? 0;
        const isNewer = mutation.eventTimestampMs >= previousTimestamp;
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
                updatedAt: new Date().toISOString(),
              },
            },
            { merge: true },
          );
        }
        tx.create(eventRef, {
          provider: mutation.provider,
          type: mutation.providerEventType,
          userId: mutation.userId,
          eventTimestampMs: mutation.eventTimestampMs,
          receivedAt: new Date().toISOString(),
          applied: isNewer,
        });
      });
    } catch (error) {
      logger.error("revenuecat_webhook_failed", {
        eventId: mutation.providerEventId,
        error: String(error),
      });
      response.status(500).send("Retry later");
      return;
    }

    logger.info("revenuecat_webhook_processed", {
      eventType: mutation.providerEventType,
      store: mutation.store ?? "unknown",
      environment: mutation.environment ?? "unknown",
      plan: mutation.plan,
    });
    response.status(200).json({ status: "processed" });
  },
);
