/**
 * Minimal OpenRouter chat-completions client. The API key is only ever read
 * from a server-side secret (see index.ts) — it never touches the Flutter
 * app, source control, or a request/response body sent to the client.
 */

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

/** Cheap, JSON-mode-capable default. Override via the OPENROUTER_MODEL env var. */
export const DEFAULT_MODEL = "openai/gpt-4o-mini";

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

export class OpenRouterError extends Error {}

export async function callOpenRouter(params: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  userContent: string;
}): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${params.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: params.model,
        response_format: { type: "json_object" },
        temperature: 0.2,
        max_tokens: MAX_OUTPUT_TOKENS,
        // The model is filling in a fixed JSON shape from supplied facts, not
        // solving a problem — a hidden reasoning pass quadruples latency past
        // what a user will wait for and adds nothing the validator keeps.
        // Ignored by models that do not reason.
        reasoning: { enabled: false },
        messages: [
          { role: "system", content: params.systemPrompt },
          { role: "user", content: params.userContent },
        ],
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new OpenRouterError(`OpenRouter responded ${response.status}`);
    }

    const body = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const content = body.choices?.[0]?.message?.content;
    if (!content) {
      throw new OpenRouterError("OpenRouter returned no content");
    }
    return content;
  } finally {
    clearTimeout(timeout);
  }
}
