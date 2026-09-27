import { DEFAULT_MODEL, parseDrafts } from "./voice.js";

export async function createDrafts({ apiKey, model, messages }) {
  const chosen = String(model || DEFAULT_MODEL).trim() || DEFAULT_MODEL;
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: chosen,
      messages,
      temperature: 0.7,
      max_tokens: 400,
      response_format: { type: "json_object" },
    }),
  });

  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = body?.error?.message || `HTTP ${res.status}`;
    throw new Error(detail);
  }

  const raw = body?.choices?.[0]?.message?.content || "";
  const drafts = parseDrafts(raw);
  if (!drafts.length) {
    throw new Error("النموذج رجع ردًا فاضيًا. جرّب تاني أو راجع السياق.");
  }
  return drafts;
}
