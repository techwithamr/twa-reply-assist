import { buildMessages, DEFAULT_MODEL } from "./lib/voice.js";
import { createDrafts } from "./lib/openai.js";

const HOST_GLOBS = [
  "https://www.linkedin.com/*",
  "https://linkedin.com/*",
  "https://www.facebook.com/*",
  "https://web.facebook.com/*",
  "https://www.youtube.com/*",
  "https://youtube.com/*",
  "https://x.com/*",
  "https://twitter.com/*",
  "https://www.instagram.com/*",
  "https://instagram.com/*",
  "http://127.0.0.1/*",
  "http://localhost/*",
];

async function injectIntoTab(tab) {
  if (!tab?.id || !tab.url || tab.url.startsWith("chrome")) return;
  try {
    await chrome.scripting.insertCSS({ target: { tabId: tab.id }, files: ["content/panel.css"] });
    await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      files: ["content/alive.js", "content/content.js"],
    });
  } catch (err) {
    console.warn("TWA inject failed", tab.url, err?.message || err);
  }
}

async function injectMatchingTabs() {
  const tabs = await chrome.tabs.query({ url: HOST_GLOBS });
  for (const tab of tabs) await injectIntoTab(tab);
}

async function pinDefaults() {
  await chrome.storage.local.set({ language: "auto", model: DEFAULT_MODEL });
}

chrome.runtime.onInstalled.addListener(() => {
  pinDefaults();
  injectMatchingTabs();
});
chrome.runtime.onStartup.addListener(() => {
  pinDefaults();
  injectMatchingTabs();
});
chrome.tabs.onUpdated.addListener((_tabId, info, tab) => {
  if (info.status === "complete") injectIntoTab(tab);
});

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
  await chrome.scripting.executeScript({
    target: { tabId, allFrames: true },
    files: ["content/alive.js", "content/content.js"],
  });
  await new Promise((resolve) => setTimeout(resolve, 200));
  try {
    await ping();
  } catch (err) {
    return { ok: true, injected: true, warn: err?.message || String(err) };
  }
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
      language: stored.language === "ar" || stored.language === "en" ? stored.language : "auto",
      extraVoice: [stored.extraVoice || "", message.customNote || ""].filter(Boolean).join("\n"),
    });

    const drafts = await createDrafts({
      apiKey: stored.apiKey,
      model: DEFAULT_MODEL,
      messages,
    });
    return { ok: true, drafts, model: DEFAULT_MODEL };
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
