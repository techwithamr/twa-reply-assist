/* Always-on banner. Inline styles so it shows even if panel.css never loads. */
(function twaAlive() {
  if (window !== window.top) {
    document.getElementById("twa-alive-bar")?.remove();
    return;
  }
  const BAR_ID = "twa-alive-bar";
  const TONES = [
    ["agree", "Agree"],
    ["supportive", "Supportive"],
    ["humor", "Humor"],
    ["experience", "Experience"],
    ["question", "Question"],
    ["story", "Story"],
    ["bold", "Bold"],
  ];

  function ensureBar() {
    const host = document.body || document.documentElement;
    if (!host) return null;
    let bar = document.getElementById(BAR_ID);
    if (!bar) {
      bar = document.createElement("div");
      bar.id = BAR_ID;
      host.appendChild(bar);
      buildBar(bar);
    } else if (!host.contains(bar)) {
      host.appendChild(bar);
    }
    styleBar(bar);
    return bar;
  }

  function styleBar(bar) {
    bar.style.cssText = [
      "position:fixed",
      "top:12px",
      "left:50%",
      "transform:translateX(-50%)",
      "z-index:2147483647",
      "background:#E85D3C",
      "color:#fff7f3",
      "padding:12px 16px",
      "border-radius:14px",
      "font:700 15px/1.4 Segoe UI,Tahoma,Arial,sans-serif",
      "direction:rtl",
      "text-align:right",
      "min-width:280px",
      "max-width:520px",
      "box-shadow:0 8px 24px rgba(0,0,0,.45)",
      "pointer-events:auto",
    ].join(";");
  }

  function buildBar(bar) {
    bar.innerHTML = "";
    const title = document.createElement("div");
    title.textContent = "TWA شغال — اختَر نبرة";
    title.style.marginBottom = "8px";
    bar.appendChild(title);
    const status = document.createElement("div");
    status.id = "twa-alive-status";
    status.style.cssText = "font-weight:600;margin-bottom:8px;opacity:.95";
    status.textContent = "جاهز";
    bar.appendChild(status);
    const row = document.createElement("div");
    row.style.cssText = "display:flex;flex-wrap:wrap;gap:6px;direction:ltr;justify-content:flex-start";
    TONES.forEach(([id, label]) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.dataset.tone = id;
      btn.textContent = label;
      btn.style.cssText =
        "border:0;border-radius:999px;padding:5px 8px;background:#fff7f3;color:#0B1220;font:700 11px Segoe UI,sans-serif;cursor:pointer";
      btn.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        runTone(id, label, status);
      });
      row.appendChild(btn);
    });
    bar.appendChild(row);
  }

  function setStatus(status, text, bad) {
    if (!status) return;
    status.textContent = text;
    status.style.color = bad ? "#ffe1dc" : "#fff7f3";
  }

  function postText() {
    const article = document.querySelector("article") || document.querySelector("[role='article']");
    const raw = (
      article?.innerText ||
      article?.textContent ||
      document.body?.innerText ||
      document.body?.textContent ||
      ""
    ).replace(/Add a comment[\s\S]*$/i, "");
    return raw.trim().slice(0, 2500);
  }

  function openComposer() {
    const article =
      document.querySelector("article, [role='article'], .feed-shared-update-v2") || document;
    const actions = article.querySelectorAll(
      "button.comment-button, button[aria-label='Comment'], button[aria-label*='Comment on' i], button[aria-label*='تعليق']"
    );
    for (const btn of actions) {
      if (btn.closest(".comments-comment-box, .comments-comment-texteditor, .share-box, .share-creation-state")) {
        continue;
      }
      btn.click();
      break;
    }
    const trigger = [...article.querySelectorAll("div, span, p, button")].find((n) => {
      const t = (n.textContent || "").trim();
      return /^(Add a comment|إضافة تعليق|أضف تعليق)/i.test(t) && n.children.length <= 2;
    });
    trigger?.click();
  }

  function findComposer() {
    const boxes = document.querySelectorAll(
      ".comments-comment-box .ql-editor, .comments-comment-box [contenteditable='true'], [aria-label*='Add a comment' i], [contenteditable='true']"
    );
    for (const el of boxes) {
      if (el.closest(".share-box, .share-creation-state")) continue;
      return el;
    }
    return null;
  }

  function insertInto(el, text) {
    if (!el) return false;
    try {
      el.focus();
    } catch {
      // ignore
    }
    const editable = el.isContentEditable || el.getAttribute("contenteditable") === "true";
    if (editable) {
      try {
        document.execCommand("selectAll", false, null);
        document.execCommand("insertText", false, text);
      } catch {
        // fall through
      }
      const now = String(el.innerText || el.textContent || "");
      if (!now.includes(String(text).slice(0, 12))) el.textContent = text;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      return true;
    }
    if ("value" in el) {
      el.value = text;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      return true;
    }
    el.textContent = text;
    return true;
  }

  async function runTone(tone, label, status) {
    setStatus(status, `بيصيغ ${label}…`);
    const ext =
      (typeof chrome !== "undefined" && chrome && chrome.runtime && chrome) ||
      globalThis.chrome ||
      (typeof window !== "undefined" && window.chrome);
    if (!ext?.runtime?.sendMessage) {
      setStatus(status, "خطأ: الإضافة مش متوصلة. Reload من chrome://extensions", true);
      return;
    }
    const text = postText();
    if (text.length < 12) {
      setStatus(status, "خطأ: ماقرأتش البوست. افتح بوست واضح.", true);
      return;
    }
    let composer = findComposer();
    if (!composer) {
      openComposer();
      await new Promise((r) => setTimeout(r, 800));
      composer = findComposer();
    }
    ext.runtime.sendMessage(
      {
        type: "TWA_GENERATE",
        platform: "linkedin",
        author: "",
        postText: text,
        commentText: "",
        tone,
      },
      (res) => {
        if (ext.runtime.lastError) {
          setStatus(status, `خطأ اتصال: ${ext.runtime.lastError.message}`, true);
          return;
        }
        if (!res?.ok) {
          setStatus(status, res?.error || "فشل التوليد", true);
          return;
        }
        const draft = res.drafts?.[0];
        if (!draft) {
          setStatus(status, "خطأ: مفيش مسودة", true);
          return;
        }
        if (!insertInto(composer || findComposer(), draft)) {
          setStatus(status, `جاهز بس ما اتنكتبش: ${draft}`, true);
          return;
        }
        setStatus(status, "اتكتب. راجع وانشر بنفسك.");
      }
    );
  }

  function boot() {
    ensureBar();
  }
  if (document.body) boot();
  else document.addEventListener("DOMContentLoaded", boot);
  setInterval(ensureBar, 1200);
})();
