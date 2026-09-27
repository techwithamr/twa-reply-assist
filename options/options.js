const form = document.getElementById("form");
const status = document.getElementById("status");

chrome.storage.local.get(["apiKey", "model", "language", "extraVoice"], (stored) => {
  form.apiKey.value = stored.apiKey || "";
  form.model.value = stored.model || "gpt-4.1-mini";
  form.language.value = stored.language || "auto";
  form.extraVoice.value = stored.extraVoice || "";
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  chrome.storage.local.set(
    {
      apiKey: form.apiKey.value.trim(),
      model: form.model.value.trim() || "gpt-4.1-mini",
      language: form.language.value,
      extraVoice: form.extraVoice.value.trim(),
    },
    () => {
      status.hidden = false;
      status.textContent = "اتحفظ. افتح خانة تعليق ثم Alt+Shift+R أو زر رد.";
    }
  );
});
