import { timingSafeEqual } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {
  createRewardToken,
  fetchVerifierKeys,
  grantReward,
  hasUnusedReward,
  refundReward,
  REWARD_CUSTOM_DATA,
  rewardState,
  useReward,
  verifyRewardCallback,
} from "./adRewards";
import { buildAiFacts } from "./aiFacts";
import { hasActivePro, RevenueCatEvent } from "./billing";
import { ENFORCE_APP_CHECK } from "./config";
import { hasConsent } from "./consents";
import {
  processRevenueCatEvent,
  reconcileExpiredEntitlements,
  syncEntitlement as syncEntitlementFor,
  usableApiKey,
} from "./entitlements";
import {
  AiProvider,
  aiProvider,
  callOpenRouter,
  isUsableKey,
  modelChain,
  OpenRouterError,
} from "./openrouter";
import { buildUserContent } from "./prompt";
import { consumeQuota, readAiConfig, refundQuota } from "./quota";
import { REVENUECAT_API_KEY } from "./secrets";
import { SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } from "./systemPrompt";
import { AiRequest, ChatTurn, AiTaskType, ModelResponse } from "./types";
import { addUsage, dailyBudgetReached, NO_USAGE, recordUsage } from "./usage";
import { parseModelJson, toClientResponse, validateResponse } from "./validate";

initializeApp();

export { deleteAccount } from "./accountDeletion";

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
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
  "chat",
  "cornerBrief",
  "summarizeTrend",
];

/** A phone chat bubble, not a wall of text — also bounds cost per turn. */
const MAX_CHAT_MESSAGE_CHARS = 600;
/** 4 user/assistant pairs. Cost and prompt-injection surface both grow with
 * unbounded history, and a coach that forgets after a few turns is still far
 * better than the one-shot button it replaces. */
const MAX_HISTORY_TURNS = 8;
const MAX_HISTORY_TURN_CHARS = 600;

function isValidHistory(value: unknown): value is ChatTurn[] {
  if (!Array.isArray(value) || value.length > MAX_HISTORY_TURNS) return false;
  return value.every(
    (turn) =>
      typeof turn === "object" &&
      turn !== null &&
      ((turn as ChatTurn).role === "user" ||
        (turn as ChatTurn).role === "assistant") &&
      typeof (turn as ChatTurn).content === "string" &&
      (turn as ChatTurn).content.length <= MAX_HISTORY_TURN_CHARS,
  );
}

/**
 * The one and only backend boundary the Flutter app depends on
 * (`EdgeFuelAiGateway` client-side). Pipeline matches master prompt §13:
 * auth -> quota -> request validation -> minimum-necessary context -> model
 * -> strict schema + safety validation -> typed result.
 *
 * Budget protection (audit S-4, D-8): App Check once `ENFORCE_APP_CHECK`
 * is on, bounded request facts (aiFacts.ts), per-task daily limits
 * (quota.ts), and a daily token budget across all accounts (usage.ts).
 * Entitlement and consent are checked against the stored profile before
 * quota is consumed.
 */
export const edgeFuelAiExplain = onCall(
  {
    secrets: [OPENROUTER_API_KEY, GROQ_API_KEY],
    cors: true,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
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

    const aiConfig = await readAiConfig(db);
    if (!aiConfig.enabled) {
      return { status: "unavailable" as const };
    }

    const data = request.data as Partial<AiRequest> | undefined;
    if (!data || !data.task || !ALLOWED_TASKS.includes(data.task)) {
      throw new HttpsError("invalid-argument", "Unsupported or missing task.");
    }
    const task: AiTaskType = data.task;
    if (data.task === "chat") {
      if (
        typeof data.userMessage !== "string" ||
        data.userMessage.trim().length === 0 ||
        data.userMessage.length > MAX_CHAT_MESSAGE_CHARS
      ) {
        throw new HttpsError("invalid-argument", "Invalid chat message.");
      }
      if (data.history !== undefined && !isValidHistory(data.history)) {
        throw new HttpsError("invalid-argument", "Invalid conversation history.");
      }
    }
    // Only the fields the model needs, bounded in size (audit S-4, S-5).
    const factsResult = buildAiFacts(data);
    if (!factsResult.ok) {
      logger.info("ai_request_blocked", { task, reason: factsResult.reason });
      throw new HttpsError("invalid-argument", "Invalid plan facts.");
    }

    // Client-side gates are only a UX optimization. Every task is authorized
    // against the stored profile before quota is consumed or anything leaves
    // our servers.
    const profile = (await db.collection("users").doc(uid).get()).data();
    // Health data goes to a third party (OpenRouter, USA) only with the
    // account's explicit consent (Art. 9(2)(a) GDPR; Privacy Policy 2.3).
    if (!hasConsent(profile, "aiCoach")) {
      logger.info("ai_request_blocked", {
        task: data.task,
        reason: "consent_required",
      });
      return { status: "consentRequired" as const };
    }
    // Expiry-aware (audit M-4): `plan` alone let a missed EXPIRATION
    // webhook keep paid AI on forever. A free account may write one Corner
    // Brief a day after a rewarded video that AdMob confirmed to us
    // (adRewards.ts); the app cannot grant that itself.
    let usesReward = false;
    if (data.task !== "summarizeTrend" && !hasActivePro(profile, Date.now())) {
      if (data.task === "cornerBrief" && (await hasUnusedReward(db, uid, new Date()))) {
        usesReward = true;
      } else {
        return { status: "entitlementRequired" as const };
      }
    }

    // Across all accounts: pauses the AI for the rest of the UTC day if
    // something spends far more than expected.
    if (await dailyBudgetReached(db, new Date(), aiConfig.dailyTokenBudget)) {
      logger.warn("ai_daily_budget_reached", { task });
      return { status: "unavailable" as const };
    }

    // Taken before quota so two parallel calls can't share one video.
    if (usesReward && !(await useReward(db, uid, new Date()))) {
      return { status: "entitlementRequired" as const };
    }
    const giveRewardBack = async (reason: string) => {
      if (!usesReward) return;
      usesReward = false;
      try {
        await refundReward(db, uid, new Date());
      } catch (error) {
        logger.error("ad_reward_refund_failed", { reason, error: String(error) });
      }
    };

    const quota = await consumeQuota(db, uid, new Date(), task);
    if (!quota.allowed) {
      await giveRewardBack("quota_reached");
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

    // Quota is reserved before an external provider call so parallel requests
    // cannot spend past the daily cap. If we fail to return a validated answer,
    // release that reservation: athletes should never lose a turn because our
    // provider or schema gate failed.
    let quotaReserved = true;
    let usage = NO_USAGE;
    let modelCalls = 0;
    // Every model call costs tokens, answered or not.
    const recordUsageSafely = async (answered: boolean) => {
      if (modelCalls === 0) return;
      try {
        await recordUsage(db, new Date(), { task, modelCalls, usage, answered });
      } catch (error) {
        logger.error("ai_usage_record_failed", { task, error: String(error) });
      }
    };
    const unavailableAfterRefund = async (reason: string) => {
      await recordUsageSafely(false);
      await giveRewardBack(reason);
      if (quotaReserved) {
        quotaReserved = false;
        try {
          const refunded = await refundQuota(db, uid, new Date(), task);
          logger.info("ai_quota_refunded", {
            task: data.task,
            reason,
            remainingQuota: refunded.remaining,
          });
        } catch (error) {
          // Never turn an already-safe unavailable response into a raw server
          // error. The reservation has a conservative cost impact if Firestore
          // itself is down, but the user never sees internals.
          logger.error("ai_quota_refund_failed", {
            task: data.task,
            reason,
            error: String(error),
          });
        }
      }
      return { status: "unavailable" as const };
    };

    // Deliberately excludes userMessage/history: the fabricated-number check
    // below only allows numbers that appear here, so a number the athlete
    // typed (unverified, possibly wrong) can never be laundered into
    // something the model is allowed to repeat as if it were calculated.
    const suppliedFacts = { task, ...factsResult.facts };
    const suppliedFactsJson = JSON.stringify(suppliedFacts);

    const userContent = buildUserContent({
      task,
      suppliedFactsJson,
      history: data.history,
      userMessage: data.userMessage,
    });

    // One retry, only for an answer the validator rejected, and only while
    // there is still time for a second attempt inside the client's wait.
    // Measured on the free model: ~75% of first answers pass, so a second
    // independent try lifts the success rate to ~94% at the cost of latency
    // only for the unlucky quarter. A provider error or timeout is not
    // retried — a slow provider will not get faster on the second call.
    // Groq only when it is configured AND its key is real; otherwise the
    // coach keeps working on OpenRouter rather than failing on a 401.
    const provider: AiProvider =
      aiProvider() === "groq" && isUsableKey(GROQ_API_KEY.value())
        ? "groq"
        : "openrouter";
    const models = modelChain({ ...process.env, AI_PROVIDER: provider });
    const startedAt = Date.now();
    let parsed: unknown = null;
    let validation: { ok: boolean; reason?: string } = { ok: false };
    let modelIndex = 0;
    for (let attempt = 1; attempt <= MAX_MODEL_ATTEMPTS; attempt++) {
      let rawContent: string | null = null;
      // A model that is gone or throttled hands over to the next one in the
      // chain; this does not consume a validation attempt.
      while (modelIndex < models.length && rawContent === null) {
        try {
          const result = await callOpenRouter({
            provider,
            apiKey:
              provider === "groq"
                ? GROQ_API_KEY.value()
                : OPENROUTER_API_KEY.value(),
            model: models[modelIndex],
            systemPrompt: SYSTEM_PROMPT,
            userContent,
          });
          rawContent = result.content;
          usage = addUsage(usage, result.usage);
          modelCalls++;
        } catch (error) {
          // Never expose raw provider errors to the client (master prompt
          // §13.3) — and never log the model's own text either.
          const openRouterError =
            error instanceof OpenRouterError ? error : null;
          logger.error("openrouter_call_failed", {
            provider,
            task: data.task,
            attempt,
            modelIndex,
            error: openRouterError?.message ?? "unknown",
          });
          if (!openRouterError?.isModelFault) {
            return unavailableAfterRefund("provider_unavailable");
          }
          modelIndex++;
          if (Date.now() - startedAt > RETRY_CUTOFF_MS) {
            return unavailableAfterRefund("provider_retry_cutoff");
          }
        }
      }
      if (rawContent === null) {
        // Every model in the chain refused.
        return unavailableAfterRefund("all_models_unavailable");
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
      return unavailableAfterRefund("response_rejected");
    }

    // validateResponse accepted it, so it has this shape.
    const answer = parsed as ModelResponse;
    await recordUsageSafely(true);
    logger.info("ai_request_completed", {
      task: data.task,
      status: "success",
      modelCalls,
      promptTokens: usage.promptTokens,
      completionTokens: usage.completionTokens,
      requiresProfessionalReview: answer.requiresProfessionalReview,
    });
    quotaReserved = false;
    if (usesReward) logger.info("ad_reward_used", { task });
    return {
      status: "success" as const,
      response: {
        ...toClientResponse(answer),
        contentVersion: `sp${SYSTEM_PROMPT_VERSION}`,
      },
    };
  },
);

/**
 * Before a free account watches a rewarded video: says whether one can still
 * earn today's Corner Brief and, if so, hands out the one-time token the app
 * passes to AdMob. Checks the same gates as the brief itself, so nobody
 * watches a video that could not pay off.
 */
export const startRewardedBrief = onCall(
  { cors: true, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (request.auth.token.email_verified !== true) {
      return { status: "notEligible" as const };
    }
    const uid = request.auth.uid;
    const db = getFirestore();
    if (!(await readAiConfig(db)).enabled) {
      return { status: "unavailable" as const };
    }
    const profile = (await db.collection("users").doc(uid).get()).data();
    if (hasActivePro(profile, Date.now())) {
      return { status: "notEligible" as const };
    }
    if (!hasConsent(profile, "aiCoach")) {
      return { status: "consentRequired" as const };
    }
    const now = new Date();
    const state = await rewardState(db, uid, now);
    if (state === "unused") return { status: "unused" as const };
    if (state === "usedToday") return { status: "usedToday" as const };
    return {
      status: "ready" as const,
      token: await createRewardToken(db, uid, now),
    };
  },
);

/**
 * AdMob's server-side verification callback for rewarded videos. Google calls
 * this URL (set per ad unit in the AdMob console) after a video is watched to
 * the end, signed with its own keys. Only then does the account get its free
 * Corner Brief. Always answers 200 to a correctly signed call, so AdMob does
 * not retry a reward we chose not to grant; nothing identifying is logged.
 */
export const admobRewardCallback = onRequest(
  { cors: false },
  async (request, response) => {
    if (request.method !== "GET") {
      response.status(405).send("Method not allowed");
      return;
    }
    const url = request.originalUrl ?? request.url ?? "";
    const rawQuery = url.includes("?") ? url.slice(url.indexOf("?") + 1) : "";

    let reward;
    try {
      reward = verifyRewardCallback(rawQuery, await fetchVerifierKeys());
    } catch (error) {
      logger.error("ad_reward_keys_failed", { error: String(error) });
      response.status(503).send("Try again");
      return;
    }
    if (!reward) {
      logger.warn("ad_reward_rejected", { reason: "bad_signature" });
      response.status(403).send("Invalid signature");
      return;
    }

    // AdMob's "verify URL" check sends a signed call with no user.
    const expectedUnit = (process.env.ADMOB_REWARDED_AD_UNIT ?? "").trim();
    if (
      !reward.userId ||
      !reward.transactionId ||
      reward.customData !== REWARD_CUSTOM_DATA ||
      (expectedUnit.length > 0 && reward.adUnit !== expectedUnit)
    ) {
      logger.info("ad_reward_ignored", { reason: "not_a_brief_reward" });
      response.status(200).send("ok");
      return;
    }

    // user_id is our one-time token, never the account ID.
    const result = await grantReward(
      getFirestore(),
      reward.userId,
      reward.transactionId,
      new Date(),
    );
    logger.info("ad_reward_callback", { result });
    response.status(200).send("ok");
  },
);

/** Constant-time comparison of the webhook Authorization header. */
function authorizationMatches(received: string, expected: string): boolean {
  const a = Buffer.from(received);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * RevenueCat server-to-server subscription lifecycle endpoint.
 *
 * RevenueCat authenticates this endpoint with the configured Authorization
 * header. Events are idempotent and ordered per user by event timestamp, so
 * a delayed cancellation cannot overwrite a newer renewal. TRANSFER re-reads
 * both accounts from RevenueCat (see entitlements.ts).
 */
export const revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_AUTH, REVENUECAT_API_KEY], cors: false },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }

    const expected = REVENUECAT_WEBHOOK_AUTH.value();
    const received = request.get("authorization") ?? "";
    if (!expected || !authorizationMatches(received, expected)) {
      response.status(401).send("Unauthorized");
      return;
    }

    const raw = request.body as { event?: RevenueCatEvent } | undefined;
    if (!raw?.event) {
      response.status(400).send("Missing event");
      return;
    }

    try {
      const result = await processRevenueCatEvent(getFirestore(), raw.event, {
        apiKey: usableApiKey(REVENUECAT_API_KEY.value()),
        nowMs: Date.now(),
      });
      logger.info("revenuecat_webhook_result", {
        eventType: typeof raw.event.type === "string" ? raw.event.type : "unknown",
        status: result.status,
      });
      response.status(200).json({ status: result.status });
    } catch (error) {
      // Non-2xx makes RevenueCat retry; the ledger keeps a retry idempotent.
      logger.error("revenuecat_webhook_failed", { error: String(error) });
      response.status(500).send("Retry later");
    }
  },
);

/**
 * Pulls the caller's entitlement from RevenueCat right now. The app calls
 * this after a purchase or restore, so Pro activates in seconds and a
 * restore onto a different account works (audit M-3, M-5).
 */
export const syncEntitlement = onCall(
  { secrets: [REVENUECAT_API_KEY], cors: true, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    return syncEntitlementFor(getFirestore(), request.auth.uid, {
      apiKey: usableApiKey(REVENUECAT_API_KEY.value()),
      nowMs: Date.now(),
    });
  },
);

/**
 * Every six hours, settles Pro profiles whose expiry has passed: a renewal
 * whose webhook never arrived is recovered, and a lapsed plan is set back to
 * free (audit M-4).
 */
export const reconcileEntitlements = onSchedule(
  { schedule: "every 6 hours", secrets: [REVENUECAT_API_KEY], timeoutSeconds: 300 },
  async () => {
    const counts = await reconcileExpiredEntitlements(getFirestore(), {
      apiKey: usableApiKey(REVENUECAT_API_KEY.value()),
      nowMs: Date.now(),
    });
    logger.info("entitlements_reconciled", counts);
  },
);
