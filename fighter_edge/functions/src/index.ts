import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { callOpenRouter, DEFAULT_MODEL, OpenRouterError } from "./openrouter";
import { consumeQuota, isAiEnabled } from "./quota";
import { SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } from "./systemPrompt";
import { AiRequest, AiTaskType } from "./types";
import { parseModelJson, validateResponse } from "./validate";

initializeApp();

export { deleteAccount } from "./accountDeletion";

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const ALLOWED_TASKS: readonly AiTaskType[] = ["explainPlan", "summarizeTrend"];

/**
 * The one and only backend boundary the Flutter app depends on
 * (`EdgeFuelAiGateway` client-side). Pipeline matches master prompt §13:
 * auth -> quota -> request validation -> minimum-necessary context -> model
 * -> strict schema + safety validation -> typed result.
 *
 * Fast-MVP scope (explicit, user-approved deviation from the full spec):
 * no App Check, no server-owned Pro entitlement gate yet — every signed-in
 * user shares one generous daily quota. Both are flagged as follow-up
 * hardening work, not silently skipped.
 */
export const edgeFuelAiExplain = onCall(
  { secrets: [OPENROUTER_API_KEY], cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
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

    const quota = await consumeQuota(db, uid, new Date());
    if (!quota.allowed) {
      return { status: "quotaReached" as const };
    }

    const suppliedFacts = {
      task: data.task,
      target: data.target,
      day: data.day ?? null,
      foodPreferences: data.foodPreferences ?? null,
    };
    const suppliedFactsJson = JSON.stringify(suppliedFacts);

    const userContent = [
      "Task:", data.task,
      "\nSupplied facts (JSON):", suppliedFactsJson,
      "\nRespond with exactly one JSON object matching this shape:",
      JSON.stringify({
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
      }),
      "\nThis deployment has no recipe catalog yet — recipeIds must always be an empty array.",
    ].join(" ");

    let rawContent: string;
    try {
      rawContent = await callOpenRouter({
        apiKey: OPENROUTER_API_KEY.value(),
        model: process.env.OPENROUTER_MODEL ?? DEFAULT_MODEL,
        systemPrompt: SYSTEM_PROMPT,
        userContent,
      });
    } catch (error) {
      // Never expose raw provider errors to the client (master prompt §13.3).
      logger.error("openrouter_call_failed", {
        uid,
        task: data.task,
        error: error instanceof OpenRouterError ? error.message : "unknown",
      });
      return { status: "unavailable" as const };
    }

    const parsed = parseModelJson(rawContent);
    const validation = validateResponse(parsed, suppliedFactsJson);
    if (!validation.ok) {
      logger.warn("ai_response_rejected", {
        uid,
        task: data.task,
        reason: validation.reason,
      });
      return { status: "unavailable" as const };
    }

    return {
      status: "success" as const,
      response: {
        ...(parsed as object),
        contentVersion: `sp${SYSTEM_PROMPT_VERSION}`,
      },
    };
  },
);
