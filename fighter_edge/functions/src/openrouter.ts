/**
 * Minimal chat-completions client for OpenRouter and Groq (both speak the
 * OpenAI chat-completions format). The API key is only ever read from a
 * server-side secret (see index.ts) — it never touches the Flutter app,
 * source control, or a request/response body sent to the client.
 *
 * OpenRouter is the default. `AI_PROVIDER=groq` switches to Groq. The names
 * below still say "OpenRouter" where they always did; they cover both.
 */

import { ModelUsage, parseUsage } from "./usage";

export type AiProvider = "openrouter" | "groq";

const PROVIDER_URLS: Record<AiProvider, string> = {
  openrouter: "https://openrouter.ai/api/v1/chat/completions",
  groq: "https://api.groq.com/openai/v1/chat/completions",
};

/**
 * Whether a secret holds a real key. "unset" is the placeholder the deploy
 * notes tell the owner to store until a provider is actually used.
 */
export function isUsableKey(key: string | undefined): key is string {
  const trimmed = (key ?? "").trim();
  return trimmed.length > 0 && trimmed.toLowerCase() !== "unset";
}

/** Which provider is configured; anything but "groq" means OpenRouter. */
export function aiProvider(env: NodeJS.ProcessEnv = process.env): AiProvider {
  return (env.AI_PROVIDER ?? "").trim().toLowerCase() === "groq"
    ? "groq"
    : "openrouter";
}

/** Cheap, JSON-mode-capable default. Override via the OPENROUTER_MODEL env var. */
export const DEFAULT_MODEL = "openai/gpt-4o-mini";

/**
 * Models to try, in order. Free models are the cheap way to run a beta, but
 * they are not contracts: on 2026-09-20 the model this deployment had been
 * using lost its free tier mid-day and every request started coming back
 * 404, while other free models were intermittently 429 from their upstream
 * provider's shared pool. One dead model must not take the feature down, so
 * the caller walks this list.
 *
 * Set OPENROUTER_MODELS (comma-separated) to override, or OPENROUTER_MODEL
 * for a single model. Both are non-secret runtime config.
 */
export function modelChain(env: NodeJS.ProcessEnv = process.env): string[] {
  const groq = aiProvider(env) === "groq";
  const raw = groq
    ? env.GROQ_MODELS
    : (env.OPENROUTER_MODELS ?? env.OPENROUTER_MODEL);
  const configured = (raw ?? "")
    .split(",")
    .map((model) => model.trim())
    .filter((model) => model.length > 0);
  if (configured.length > 0) return configured;
  return groq ? DEFAULT_GROQ_CHAIN : [DEFAULT_MODEL];
}

/**
 * Groq's free tier, best first (scored 2026-09-29 with `npm run eval:ai`:
 * qwen 23/29 passed, gpt-oss-120b 19/29, gpt-oss-20b 18/29). Groq retires
 * models, so re-run `npm run groq:models` now and then. Limits are per model, so a busy model
 * answering 429 hands over to the next one. This is a starting point:
 * `npm run groq:models` lists what the key can use and `npm run eval:ai`
 * scores them. Set GROQ_MODELS (comma-separated) to override.
 */
export const DEFAULT_GROQ_CHAIN = [
  "qwen/qwen3.8-27b",
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b",
];

/**
 * Under the client's 30 s budget with room for the Firestore round trips
 * either side. Measured on 2026-09-19: the free DeepSeek V4 Flash answers the
 * real Fighter Brief prompt in ~9-11 s with reasoning off, ~44 s with it on.
 */
const REQUEST_TIMEOUT_MS = 25_000;

/**
 * A Fighter Brief is four short sections plus a summary — well under 600
 * tokens of JSON. Without an explicit cap OpenRouter reserves the model's full
 * 16k output budget up front and refuses the call outright when the account
 * cannot cover that reservation, which is how every production request was
 * failing before this cap existed.
 */
const MAX_OUTPUT_TOKENS = 900;

export class OpenRouterError extends Error {
  /** HTTP status from the provider, when the failure came back as one. */
  readonly status?: number;
  readonly provider: AiProvider;

  constructor(
    message: string,
    status?: number,
    provider: AiProvider = "openrouter",
  ) {
    super(message);
    this.status = status;
    this.provider = provider;
  }

  /**
   * Whether another model is worth trying. 404 means the model (or its free
   * tier) is gone, 429 means the provider's shared pool is saturated, 5xx
   * means the provider is down — all of which a different model may not
   * have. A 401/403 is about our key, so trying more models just wastes the
   * user's wait.
   */
  get isModelFault(): boolean {
    const status = this.status;
    if (status === undefined) return false;
    // Groq answers 400 for a model it has retired or that lacks a feature we
    // ask for (e.g. JSON mode). Our request is the same for every model, so
    // trying the next one is right; OpenRouter's 400 is about our request.
    if (status === 400 && this.provider === "groq") return true;
    return status === 404 || status === 429 || status >= 500;
  }
}

export interface OpenRouterRequest {
  model: string;
  systemPrompt: string;
  userContent: string;
}

/**
 * The request body. Pure, so the privacy-relevant parts are testable:
 * - `usage.include` asks OpenRouter to report tokens and cost (usage.ts).
 * - With `OPENROUTER_DATA_COLLECTION=deny`, OpenRouter routes only to
 *   providers that don't store or train on prompts (audit S-5). Free models
 *   are mostly served by providers that do, so turn this on together with a
 *   paid model.
 */
export function buildRequestBody(
  request: OpenRouterRequest,
  env: NodeJS.ProcessEnv = process.env,
): Record<string, unknown> {
  if (aiProvider(env) === "groq") {
    return {
      model: request.model,
      response_format: { type: "json_object" },
      temperature: 0.2,
      max_tokens: MAX_OUTPUT_TOKENS,
      // Groq's reasoning models think before answering, and those tokens
      // count toward max_tokens; keep it short. Other models reject the
      // field, so only these get it.
      ...(request.model.startsWith("openai/gpt-oss")
        ? { reasoning_effort: "low" }
        : {}),
      messages: [
        { role: "system", content: request.systemPrompt },
        { role: "user", content: request.userContent },
      ],
    };
  }
  const denyDataCollection =
    (env.OPENROUTER_DATA_COLLECTION ?? "").trim().toLowerCase() === "deny";
  return {
    model: request.model,
    response_format: { type: "json_object" },
    temperature: 0.2,
    max_tokens: MAX_OUTPUT_TOKENS,
    // The model is filling in a fixed JSON shape from supplied facts, not
    // solving a problem — a hidden reasoning pass quadruples latency past
    // what a user will wait for and adds nothing the validator keeps.
    // Ignored by models that do not reason.
    reasoning: { enabled: false },
    usage: { include: true },
    ...(denyDataCollection ? { provider: { data_collection: "deny" } } : {}),
    messages: [
      { role: "system", content: request.systemPrompt },
      { role: "user", content: request.userContent },
    ],
  };
}

export interface OpenRouterResult {
  content: string;
  usage: ModelUsage;
}

export async function callOpenRouter(
  params: OpenRouterRequest & { apiKey: string; provider?: AiProvider },
): Promise<OpenRouterResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const provider = params.provider ?? aiProvider();
    const response = await fetch(PROVIDER_URLS[provider], {
      method: "POST",
      headers: {
        Authorization: `Bearer ${params.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(
        buildRequestBody(params, { ...process.env, AI_PROVIDER: provider }),
      ),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new OpenRouterError(
        `${provider} responded ${response.status}`,
        response.status,
        provider,
      );
    }

    const body = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const content = body.choices?.[0]?.message?.content;
    if (!content) {
      throw new OpenRouterError(
        `${provider} returned no content`,
        undefined,
        provider,
      );
    }
    return { content, usage: parseUsage(body) };
  } finally {
    clearTimeout(timeout);
  }
}
