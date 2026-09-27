const state = document.getElementById("state");
const keyInput = document.getElementById("apiKey");

async function injectThisTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) return { ok: false, error: "مافيش تبويب نشط." };
  return chrome.runtime.sendMessage({ type: "TWA_ENSURE_TOGGLE", tabId: tab.id });
}

const readyLabel = (model) => `جاهز · ${model || "gpt-4.1-mini"}`;

chrome.storage.local.get(["apiKey", "model"], (stored) => {
  keyInput.value = stored.apiKey || "";
  if (!stored.apiKey) {
    state.textContent = "المفتاح فاضي — الصقه في الحقل تحت واضغط حفظ.";
    return;
  }
  state.textContent = readyLabel(stored.model);
  injectThisTab().then((res) => {
    if (res && !res.ok && res.error && res.error !== "no tab") {
      state.textContent = `حقن فشل: ${res.error}`;
    } else if (res?.warn) {
      state.textContent = `${readyLabel(stored.model)} · حقن تم`;
    }
  });
});

document.getElementById("saveKey").addEventListener("click", () => {
  const apiKey = keyInput.value.trim();
  chrome.storage.local.set({ apiKey }, () => {
    state.textContent = apiKey
      ? `اتحفظ · ${"gpt-4.1-mini"}`
      : "المفتاح فاضي — الصقه في الحقل تحت واضغط حفظ.";
  });
});

document.getElementById("openPanel").addEventListener("click", async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) {
    state.textContent = "مافيش تبويب نشط.";
    return;
  }
  const res = await chrome.runtime.sendMessage({ type: "TWA_ENSURE_TOGGLE", tabId: tab.id });
  if (!res?.ok) {
    state.textContent = res?.error || "حدّث الصفحة وبعدين اضغط تاني.";
    return;
  }
  window.close();
});

document.getElementById("options").addEventListener("click", () => {
  chrome.runtime.openOptionsPage();
});
