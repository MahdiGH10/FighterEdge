// Lists the chat models a Groq key can use, so the fallback chain can be
// picked from what exists today rather than from memory.
//
// From functions/:
//   npm run groq:models
//
// Needs GROQ_API_KEY in the environment. The key is only sent to Groq, never
// printed or written. Output is model names and sizes only.
//
// Groq's free tier is per-model rate limits (requests and tokens per minute
// and per day), so every model listed here is usable for free within its
// limits. Check the current limits at console.groq.com/settings/limits.

const apiKey = process.env.GROQ_API_KEY;
if (!apiKey) {
  console.error(
    "GROQ_API_KEY is not set. Set it in this shell (it is never printed).",
  );
  process.exit(2);
}

const response = await fetch("https://api.groq.com/openai/v1/models", {
  headers: { Authorization: `Bearer ${apiKey}` },
});
if (!response.ok) {
  console.error(`Groq responded ${response.status}. Is the key valid?`);
  process.exit(1);
}

const { data = [] } = await response.json();

// Speech, safety and routing models cannot write a Corner Brief.
const NOT_CHAT = /whisper|tts|orpheus|playai|guard|embed|compound/i;
const chat = data
  .filter((m) => m.active !== false && !NOT_CHAT.test(m.id))
  .sort((a, b) => a.id.localeCompare(b.id));

console.log(`${chat.length} chat model(s) available:\n`);
for (const m of chat) {
  const context = m.context_window ? `${Math.round(m.context_window / 1000)}k context` : "?";
  console.log(`${m.id}  (${m.owned_by ?? "?"}, ${context})`);
}
console.log(
  "\nNext: pick a few and score them with\n" +
    "  AI_PROVIDER=groq npm run eval:ai -- --models id1,id2,id3 --runs 2\n" +
    "then put the winners, best first, in GROQ_MODELS.",
);
