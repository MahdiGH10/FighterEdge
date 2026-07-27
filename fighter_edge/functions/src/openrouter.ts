/**
 * Minimal OpenRouter chat-completions client. The API key is only ever read
 * from a server-side secret (see index.ts) — it never touches the Flutter
 * app, source control, or a request/response body sent to the client.
 */

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

/** Cheap, JSON-mode-capable default. Override via the OPENROUTER_MODEL env var. */
export const DEFAULT_MODEL = "openai/gpt-4o-mini";

const REQUEST_TIMEOUT_MS = 15_000;

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
