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
    if (!bar.querySelector("#twa-alive-launch")) buildBar(bar);
    styleBar(bar);
    return bar;
  }

  function styleBar(bar) {
    if (document.querySelector(".twa-yap")) {
      bar.style.display = "none";
      bar.classList.remove("is-open");
      return;
    }
    const open = bar.classList.contains("is-open");
    bar.style.cssText = [
      "display:block",
      "position:fixed",
      "top:12px",
      "inset-inline-end:12px",
      "left:auto",
      "transform:none",
      "z-index:2147483647",
      "width:32px",
      "height:32px",
      "padding:0",
      "margin:0",
      "min-width:0",
      "max-width:none",
      "background:transparent",
      "box-shadow:none",
      "overflow:visible",
      "pointer-events:auto",
      "font:700 13px/1 Segoe UI,Tahoma,Arial,sans-serif",
    ].join(";");
    const launch = bar.querySelector("#twa-alive-launch");
    if (launch) {
      launch.style.cssText = [
        "width:32px",
        "height:32px",
        "border:0",
        "border-radius:999px",
        "background:#E85D3C",
        "color:#fff7f3",
        "font:800 13px/1 Segoe UI,Tahoma,Arial,sans-serif",
        "cursor:pointer",
        "box-shadow:0 2px 8px rgba(232,93,60,.4)",
        "padding:0",
      ].join(";");
    }
    const menu = bar.querySelector("#twa-alive-menu");
    if (menu) {
      menu.style.cssText = [
        "display:" + (open ? "flex" : "none"),
        "flex-direction:column",
        "gap:6px",
        "position:absolute",
        "top:40px",
        "right:0",
        "left:auto",
        "min-width:168px",
        "max-width:220px",
        "padding:8px",
        "border-radius:12px",
        "background:#E85D3C",
        "color:#fff7f3",
        "direction:rtl",
        "text-align:right",
        "box-shadow:0 8px 20px rgba(0,0,0,.28)",
      ].join(";");
    }
  }

  function buildBar(bar) {
    bar.innerHTML = "";
    const launch = document.createElement("button");
    launch.id = "twa-alive-launch";
    launch.type = "button";
    launch.textContent = "T";
    launch.title = "TWA شغال — اختَر نبرة";
    launch.setAttribute("aria-label", "TWA شغال — اختَر نبرة");
    launch.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      bar.classList.toggle("is-open");
      styleBar(bar);
    });
    const menu = document.createElement("div");
    menu.id = "twa-alive-menu";
    const status = document.createElement("div");
    status.id = "twa-alive-status";
    status.style.cssText = "font:600 11px/1.3 Segoe UI,Tahoma,Arial,sans-serif;opacity:.95";
    status.textContent = "جاهز";
    const row = document.createElement("div");
    row.style.cssText = "display:flex;flex-wrap:wrap;gap:4px;direction:ltr;justify-content:flex-start";
    TONES.forEach(([id, label]) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.dataset.tone = id;
      btn.textContent = label;
      btn.style.cssText =
        "border:0;border-radius:999px;padding:4px 7px;background:#fff7f3;color:#0B1220;font:700 10px Segoe UI,sans-serif;cursor:pointer";
      btn.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        runTone(id, label, status);
      });
      row.appendChild(btn);
    });
    menu.append(status, row);
    bar.append(launch, menu);
    if (!bar.dataset.twaOutside) {
      bar.dataset.twaOutside = "1";
      document.addEventListener(
        "click",
        (event) => {
          if (!bar.classList.contains("is-open")) return;
          if (bar.contains(event.target)) return;
          bar.classList.remove("is-open");
          styleBar(bar);
        },
        true
      );
    }
  }

  function setStatus(status, text, bad) {
    if (!status) return;
    status.textContent = text;
    status.style.color = bad ? "#ffe1dc" : "#fff7f3";
  }

  function detectPlatform(host) {
    const name = String(host || (typeof location !== "undefined" ? location.hostname : "") || "");
    if (name.includes("linkedin.com")) return "linkedin";
    if (name.includes("facebook.com")) return "facebook";
    if (name.includes("youtube.com")) return "youtube";
    if (name.includes("instagram.com")) return "instagram";
    if (name.includes("x.com") || name.includes("twitter.com")) return "x";
    return "unknown";
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
        platform: detectPlatform(),
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
        setStatus(status, `اتكتب · ${res.model || "gpt-4.1-mini"}`);
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
