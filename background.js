import { buildMessages } from "./lib/voice.js";
import { createDrafts } from "./lib/openai.js";

async function togglePanelOnTab(tabId) {
  const ping = () => chrome.tabs.sendMessage(tabId, { type: "TWA_TOGGLE" });
  try {
    await ping();
    return { ok: true };
  } catch {
    // content script missing or old module import failed
  }
  try {
    await chrome.scripting.insertCSS({ target: { tabId }, files: ["content/panel.css"] });
  } catch {
    // css may already be there
  }
  await chrome.scripting.executeScript({ target: { tabId }, files: ["content/content.js"] });
  await new Promise((resolve) => setTimeout(resolve, 200));
  await ping();
  return { ok: true };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "TWA_ENSURE_TOGGLE") {
    const tabId = message.tabId;
    if (!tabId) {
      sendResponse({ ok: false, error: "no tab" });
      return false;
    }
    togglePanelOnTab(tabId)
      .then(sendResponse)
      .catch((err) => sendResponse({ ok: false, error: err?.message || String(err) }));
    return true;
  }

  if (message?.type !== "TWA_GENERATE") return undefined;

  (async () => {
    const stored = await chrome.storage.local.get([
      "apiKey",
      "model",
      "language",
      "extraVoice",
    ]);
    if (!stored.apiKey) {
      throw new Error("حط مفتاح OpenAI من إعدادات الإضافة أولًا.");
    }

    const messages = buildMessages({
      platform: message.platform,
      postText: message.postText,
      commentText: message.commentText,
      author: message.author,
      tone: message.tone,
      language: stored.language || "auto",
      extraVoice: stored.extraVoice || "",
    });

    const drafts = await createDrafts({
      apiKey: stored.apiKey,
      model: stored.model,
      messages,
    });
    return { ok: true, drafts };
  })()
    .then(sendResponse)
    .catch((err) => {
      sendResponse({ ok: false, error: err?.message || String(err) });
    });

  return true;
});

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "toggle-reply-panel") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) return;
  try {
    await togglePanelOnTab(tab.id);
  } catch (err) {
    console.error("TWA toggle failed", err);
  }
});
