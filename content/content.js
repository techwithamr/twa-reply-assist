/* Classic content script — no import. Split markers stay identical to lib/voice.js. */
if (window !== window.top) {
  document.getElementById("twa-reply-root")?.remove();
  document.getElementById("twa-alive-bar")?.remove();
  document.querySelectorAll(".twa-yap, .twa-fab, .twa-panel").forEach((n) => n.remove());
  window.__twaReplyAssistVersion = "1.4.3";
} else if (window.__twaReplyAssistVersion !== "1.4.3") {
  window.__twaReplyAssistVersion = "1.4.3";
  document.getElementById("twa-reply-root")?.remove();
  document.querySelectorAll(".twa-yap").forEach((n) => n.remove());
  document.querySelectorAll(".twa-fab, .twa-panel").forEach((n) => n.remove());
  window.__twaReplyAssistLoaded = true;

  const CONTEXT_SPLIT = "\n---\n";
  function combineContext(postText, commentText) {
    const post = String(postText || "").trim();
    const comment = String(commentText || "").trim();
    if (post && comment) return `${post}${CONTEXT_SPLIT}${comment}`;
    return post || comment;
  }
  function splitContext(combined) {
    const text = String(combined || "");
    const idx = text.indexOf(CONTEXT_SPLIT);
    if (idx === -1) return { postText: text.trim(), commentText: "" };
    return {
      postText: text.slice(0, idx).trim(),
      commentText: text.slice(idx + CONTEXT_SPLIT.length).trim(),
    };
  }

  const COMPOSERS = {
    linkedin: [
      ".comments-comment-box .ql-editor",
      ".comments-comment-texteditor .ql-editor",
      ".comments-comment-box-comment__text-editor",
      ".comments-comment-box [contenteditable='true']",
      "[aria-label*='Add a comment' i]",
      "[aria-label*='إضافة تعليق']",
    ],
    youtube: [
      "ytd-commentbox #contenteditable-root",
      "#contenteditable-root[contenteditable='true']",
    ],
    facebook: [
      "[role='textbox'][aria-label*='comment' i]",
      "[role='textbox'][aria-label*='Comment']",
      "[role='textbox'][aria-label*='تعليق']",
      "[role='textbox'][aria-label*='Write a comment' i]",
    ],
    x: [
      "[aria-modal='true'] [data-testid='tweetTextarea_0']",
      "[data-testid='tweetTextarea_0']",
    ],
    instagram: [
      "textarea[aria-label*='comment' i]",
      "textarea[placeholder*='comment' i]",
      "textarea[aria-label*='تعليق']",
      "form textarea",
    ],
  };

  function detectPlatform(host = location.hostname) {
    if (host.includes("linkedin.com")) return "linkedin";
    if (host.includes("facebook.com")) return "facebook";
    if (host.includes("youtube.com")) return "youtube";
    if (host.includes("instagram.com")) return "instagram";
    if (host.includes("x.com") || host.includes("twitter.com")) return "x";
    return "unknown";
  }

  function firstText(root, selectors, max = 4000) {
    if (!root) return "";
    for (const sel of selectors) {
      const el = root.querySelector(sel);
      const text = el?.innerText?.trim() || el?.textContent?.trim();
      if (text) return text.slice(0, max);
    }
    return "";
  }

  function closestCard(el) {
    return (
      el?.closest?.(
        "article, .feed-shared-update-v2, ytd-watch-flexy, ytd-comment-thread-renderer, [role='article'], [data-testid='tweet'], [role='dialog']"
      ) || document.body
    );
  }

  function isVisible(el) {
    if (!el) return false;
    const style = getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") {
      return false;
    }
    const box = el.getBoundingClientRect();
    return box.width > 8 && box.height > 8;
  }

  function extractLinkedIn(fromEl) {
    const card = closestCard(fromEl || document.activeElement) || document.querySelector("article");
    let postText = firstText(card, [
      ".update-components-text",
      ".feed-shared-update-v2__description",
      ".feed-shared-inline-show-more-text",
      ".break-words",
    ]);
    if (!postText && card) {
      postText = String(card.innerText || "")
        .replace(/Add a comment[\s\S]*$/i, "")
        .replace(/Like\s+Comment\s+Repost[\s\S]*$/i, "")
        .trim()
        .slice(0, 2500);
    }
    return {
      author: firstText(card, [
        ".update-components-actor__title",
        ".update-components-actor__name",
        "span.update-components-actor__name",
      ], 200),
      postText,
      commentText: firstText(card, [
        ".comments-comment-item__main-content",
        ".comments-comment-item .update-components-text",
        ".comments-comment-entity .break-words",
      ], 2000),
    };
  }

  function extractYouTube(fromEl) {
    const hovered = document.querySelector("ytd-comment-thread-renderer:hover #content-text");
    return {
      author: firstText(document, ["#channel-name a", "ytd-channel-name #text", "#owner #channel-name"], 200),
      postText: [
        firstText(document, ["h1.ytd-watch-metadata yt-formatted-string", "#title h1", "h1 yt-formatted-string"]),
        firstText(document, ["#description-inline-expander", "ytd-watch-metadata #description"]),
      ]
        .filter(Boolean)
        .join("\n\n"),
      commentText:
        hovered?.innerText?.trim() ||
        firstText(fromEl && closestCard(fromEl), ["#content-text"], 2000),
    };
  }

  function extractFacebook(fromEl) {
    const card = closestCard(fromEl || document.activeElement);
    return {
      author: firstText(card, ["strong a", "h2 a", "h3 a", "[role='link'] strong"], 200),
      postText:
        firstText(card, ["[data-ad-preview='message']", "[data-ad-comet-preview='message']", "div[dir='auto']"]) ||
        (card?.innerText || "").slice(0, 2500),
      commentText: "",
    };
  }

  function extractX(fromEl) {
    const card =
      fromEl?.closest?.("article[data-testid='tweet']") ||
      document.querySelector("article[data-testid='tweet']");
    return {
      author: firstText(card, ["[data-testid='User-Name']"], 200),
      postText: firstText(card, ["[data-testid='tweetText']"]),
      commentText: "",
    };
  }

  function extractInstagram(fromEl) {
    const rootEl =
      fromEl?.closest?.("[role='dialog']") ||
      document.querySelector("[role='dialog']") ||
      document.querySelector("article") ||
      document.body;
    return {
      author: firstText(rootEl, ["header a", "a[href*='/'] span"], 200),
      postText: firstText(rootEl, ["h1", "span[dir='auto']", "ul li span[dir='auto']"]),
      commentText: "",
    };
  }

  function selectedText() {
    return window.getSelection()?.toString()?.trim().slice(0, 4000) || "";
  }

  function extractContext(fromEl) {
    const platform = detectPlatform();
    const picked = selectedText();
    const readers = {
      linkedin: extractLinkedIn,
      youtube: extractYouTube,
      facebook: extractFacebook,
      x: extractX,
      instagram: extractInstagram,
    };
    const base = readers[platform] ? readers[platform](fromEl) : { author: "", postText: "", commentText: "" };

    if (picked && picked.length > 20) {
      if (!base.commentText) base.commentText = picked;
      else if (!base.postText) base.postText = picked;
      else base.postText = `${base.postText}\n\n[تحديد المستخدم]\n${picked}`;
    }
    return { platform, ...base };
  }

  function composerSelectors() {
    return COMPOSERS[detectPlatform()] || [];
  }

  function visibleCommentComposer() {
    const platform = detectPlatform();
    const sels = composerSelectors();
    for (const sel of sels) {
      for (const node of document.querySelectorAll(sel)) {
        if (!isVisible(node)) continue;
        if (platform === "x") {
          const onStatus = location.pathname.includes("/status/");
          const inModal = Boolean(node.closest("[aria-modal='true']"));
          if (!onStatus && !inModal) continue;
        }
        return node;
      }
    }
    return null;
  }

  function findComposer() {
    const active = document.activeElement;
    if (active && (active.isContentEditable || active.tagName === "TEXTAREA")) return active;
    return visibleCommentComposer();
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
        const ok = document.execCommand("insertText", false, text);
        if (!ok) el.textContent = text;
      } catch {
        el.textContent = text;
      }
      try {
        el.dispatchEvent(new InputEvent("input", { bubbles: true, data: text, inputType: "insertText" }));
      } catch {
        el.dispatchEvent(new Event("input", { bubbles: true }));
      }
      return true;
    }
    if ("value" in el) {
      el.value = text;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      return true;
    }
    el.textContent = text;
    return Boolean(el.textContent);
  }

  function insertDraft(text) {
    return insertInto(findComposer(), text);
  }

  function el(tag, attrs = {}, kids = []) {
    const node = document.createElement(tag);
    Object.entries(attrs).forEach(([k, v]) => {
      if (k === "className") node.className = v;
      else if (k === "text") node.textContent = v;
      else node.setAttribute(k, v);
    });
    kids.forEach((c) => node.appendChild(c));
    return node;
  }

  const root = el("div", { id: "twa-reply-root" });
  const toast = el("div", { className: "twa-toast", id: "twa-toast" });
  const panel = el("div", { className: "twa-panel" });
  const fab = el("button", { className: "twa-fab", type: "button", text: "رد" });
  fab.title = "صياغة رد · اضغط خانة التعليق";

  panel.innerHTML = `
    <h2>صياغة رد</h2>
    <p class="twa-meta" id="twa-platform"></p>
    <label for="twa-context">السياق</label>
    <textarea id="twa-context" placeholder="البوست. لو فيه تعليق، هيظهر بعد سطر ---"></textarea>
    <details class="twa-more">
      <summary>نبرة</summary>
      <select id="twa-tone">
        <option value="agree">Agree</option>
        <option value="supportive">Supportive</option>
        <option value="humor">Light humor</option>
        <option value="experience">From experience</option>
        <option value="question">Smart question</option>
        <option value="story">Quick story</option>
        <option value="bold">Bold take</option>
        <option value="custom">Custom</option>
      </select>
    </details>
    <div class="twa-row">
      <button type="button" class="twa-btn twa-primary" id="twa-generate">صِغ مسودتين</button>
      <button type="button" class="twa-btn twa-ghost" id="twa-refresh">حدّث</button>
    </div>
    <p class="twa-hint">اضغط خانة التعليق عشان يتكتب مباشرة · النشر يدوي</p>
    <p class="twa-error" id="twa-error" hidden></p>
    <div id="twa-drafts"></div>
  `;

  root.append(toast);
  document.documentElement.appendChild(root);

  const contextBox = panel.querySelector("#twa-context");
  const toneBox = panel.querySelector("#twa-tone");
  const platformLine = panel.querySelector("#twa-platform");
  const errorLine = panel.querySelector("#twa-error");
  const draftsBox = panel.querySelector("#twa-drafts");

  function showToast(msg, kind = "info") {
    toast.textContent = msg || "";
    toast.dataset.kind = kind;
    toast.classList.toggle("is-on", Boolean(msg));
    errorLine.hidden = kind !== "error" || !msg;
    errorLine.textContent = kind === "error" ? msg || "" : "";
  }

  function fillContext(fromEl) {
    const ctx = extractContext(fromEl);
    platformLine.textContent = `${ctx.platform}${ctx.author ? ` · ${ctx.author}` : ""}`;
    contextBox.value = combineContext(ctx.postText, ctx.commentText);
    return ctx;
  }

  function showError(msg) {
    showToast(msg || "", msg ? "error" : "info");
  }

  function renderDrafts(drafts) {
    draftsBox.innerHTML = "";
    drafts.forEach((draft) => {
      const card = el("div", { className: "twa-draft" });
      const p = el("p", { text: draft });
      const row = el("div", { className: "twa-row" });
      const copyBtn = el("button", { className: "twa-btn twa-ghost", type: "button", text: "نسخ" });
      const insertBtn = el("button", { className: "twa-btn twa-primary", type: "button", text: "إدراج" });
      copyBtn.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText(draft);
          copyBtn.textContent = "تم";
        } catch (err) {
          showToast(`النسخ فشل: ${err?.message || err}`, "error");
        }
        setTimeout(() => {
          copyBtn.textContent = "نسخ";
        }, 1200);
      });
      insertBtn.addEventListener("click", () => {
        const ok = insertDraft(draft);
        if (!ok) showToast("ما لقيتش خانة تعليق. انسخ المسودة يدوي.", "error");
        else showToast("اتكتب في الخانة. راجع وانشر بنفسك.", "ok");
      });
      row.append(copyBtn, insertBtn);
      card.append(p, row);
      draftsBox.appendChild(card);
    });
  }

  function togglePanel() {
    // One surface: the top #twa-alive-bar. Do not reopen the old side panel.
  }

  function syncFab() {
    const supported = detectPlatform() !== "unknown";
    const show =
      supported || Boolean(visibleCommentComposer()) || root.classList.contains("is-open");
    root.classList.toggle("has-composer", show);
  }

  function composerIsEmpty(node) {
    const text = String(node.innerText || node.value || "")
      .replace(/\u00a0/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    if (!text) return true;
    return /^(add a comment|write a comment|إضافة تعليق|أضف تعليق)/i.test(text);
  }

  function isStartPost(el) {
    return Boolean(
      el.closest?.(
        ".share-box, .share-creation-state, .share-box-feed-entry, [data-test-id='share-box']"
      )
    );
  }

  function isCommentSurface(el) {
    if (!el || el.nodeType !== 1 || el.closest("#twa-reply-root")) return false;
    if (isStartPost(el)) return false;
    if (el.closest(".comments-comment-box, .comments-comment-texteditor, .comments-comment-item")) {
      return true;
    }
    const label = `${el.getAttribute("aria-label") || ""} ${el.getAttribute("placeholder") || ""}`;
    if (/start a post|create a post|ابدأ منشور/i.test(label)) return false;
    return /add a comment|write a comment|تعليق|comment/i.test(label);
  }

  function resolveComposer(fromEl) {
    if (!fromEl) return null;
    if (fromEl.isContentEditable || fromEl.tagName === "TEXTAREA") return fromEl;
    return (
      fromEl.querySelector?.(".ql-editor, [contenteditable='true'], textarea") ||
      fromEl.closest?.(".comments-comment-box")?.querySelector(".ql-editor, [contenteditable='true'], textarea") ||
      null
    );
  }

  let filling = false;
  let lastFillAt = 0;

  function requestDrafts(payload) {
    return new Promise((resolve) => {
      const ext = globalThis.chrome;
      if (!ext?.runtime?.sendMessage) {
        resolve({ ok: false, error: "الإضافة مش متوصلة. اعمل Reload من chrome://extensions." });
        return;
      }
      ext.runtime.sendMessage(payload, (res) => {
        if (ext.runtime.lastError) {
          resolve({ ok: false, error: `خطأ اتصال: ${ext.runtime.lastError.message}` });
          return;
        }
        resolve(res || { ok: false, error: "رد فاضي من الإضافة." });
      });
    });
  }

  async function fillComposerDirect(composer, opts = {}) {
    if (!composer || filling) return;
    const now = Date.now();
    if (now - lastFillAt < 600) return;
    if (!opts.force) {
      if (composer.dataset.twaFilled === "1" && !composerIsEmpty(composer)) return;
      if (!composerIsEmpty(composer) && composer.dataset.twaFilled !== "1") return;
    }

    filling = true;
    lastFillAt = now;
    showToast("بيصيغ التعليق…", "info");
    const ctx = fillContext(composer);
    if (!ctx.postText || ctx.postText.length < 12) {
      filling = false;
      showToast("ماقدرتش أقرأ نص البوست. افتح البوست أو حدّد النص بالماوس.", "error");
      return;
    }

    const res = await requestDrafts({
      type: "TWA_GENERATE",
      platform: ctx.platform,
      author: ctx.author,
      postText: ctx.postText,
      commentText: ctx.commentText,
      tone: opts.tone || toneBox.value || "agree",
      customNote: opts.customNote || "",
    });
    filling = false;
    if (!res?.ok) {
      showToast(res?.error || "فشل توليد التعليق.", "error");
      return;
    }
    const draft = res.drafts?.[0];
    if (!draft) {
      showToast("النموذج ما رجّعش مسودة.", "error");
      return;
    }
    const ok = insertInto(composer, draft);
    if (!ok) {
      showToast(`التعليق جاهز بس ما اتنكتبش. انسخه: ${draft}`, "error");
      return;
    }
    composer.dataset.twaFilled = "1";
    showToast("اتكتب في الخانة. راجع وبعدين انشر بنفسك.", "ok");
  }

  const YAP_TONES = [
    { id: "agree", icon: "✓", label: "Agree" },
    { id: "supportive", icon: "🤝", label: "Supportive" },
    { id: "humor", icon: "🙂", label: "Light humor" },
    { id: "experience", icon: "💡", label: "From experience" },
    { id: "question", icon: "?", label: "Smart question" },
    { id: "story", icon: "📖", label: "Quick story" },
    { id: "bold", icon: "⚡", label: "Bold take" },
    { id: "custom", icon: "✎", label: "Custom" },
  ];

  async function ensureComposer(box) {
    let composer = resolveComposer(box) || box.querySelector(".ql-editor, [contenteditable='true'], textarea");
    if (composer) return composer;
    const trigger = [...box.querySelectorAll("div, span, button")].find((n) =>
      /add a comment|write a comment|إضافة تعليق/i.test((n.textContent || "").trim())
    );
    if (trigger) trigger.click();
    await new Promise((r) => setTimeout(r, 280));
    return (
      box.querySelector(".ql-editor, [contenteditable='true'], textarea") ||
      resolveComposer(document.activeElement)
    );
  }

  function closeAllYapMenus() {
    document.querySelectorAll(".twa-yap.is-open").forEach((n) => n.classList.remove("is-open"));
  }

  function mountYapOnBox(box) {
    if (!box || box.querySelector(":scope > .twa-yap")) return;
    const wrap = el("div", { className: "twa-yap" });
    const btn = el("button", { className: "twa-yap-btn", type: "button", text: "T" });
    btn.title = "TWA Reply — اختَر نبرة";
    btn.setAttribute("aria-label", "TWA Reply tones");
    const menu = el("div", { className: "twa-yap-menu" });
    YAP_TONES.forEach((tone) => {
      const row = el("button", { className: "twa-yap-row", type: "button" });
      row.dataset.tone = tone.id;
      row.innerHTML = `<span class="twa-yap-ico">${tone.icon}</span><span>${tone.label}</span>`;
      row.addEventListener("click", async (event) => {
        event.preventDefault();
        event.stopPropagation();
        let customNote = "";
        if (tone.id === "custom") {
          customNote = window.prompt("اكتب النبرة أو التعليمات:") || "";
          if (!customNote.trim()) {
            showToast("النبرة المخصصة فاضية.", "error");
            return;
          }
        }
        closeAllYapMenus();
        showToast(`بيصيغ (${tone.label})…`, "info");
        const composer = await ensureComposer(box);
        if (!composer) {
          showToast("ما فتحتش خانة التعليق. دوس Add a comment بعدين الأيقونة.", "error");
          return;
        }
        try {
          await fillComposerDirect(composer, { tone: tone.id, customNote, force: true });
        } catch (err) {
          filling = false;
          showToast(`خطأ غير متوقع: ${err?.message || err}`, "error");
        }
      });
      menu.appendChild(row);
    });
    btn.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const open = wrap.classList.contains("is-open");
      closeAllYapMenus();
      wrap.classList.toggle("is-open", !open);
    });
    wrap.append(btn, menu);
    box.insertBefore(wrap, box.firstChild);
  }

  function mountYapButtons() {
    const boxes = new Set(
      document.querySelectorAll(
        ".comments-comment-box, .comments-comment-texteditor, [class*='comments-comment-box']"
      )
    );
    for (const n of document.querySelectorAll("div, span, button")) {
      const t = (n.textContent || "").trim();
      if (/^Add a comment/i.test(t) && n.children.length <= 1) {
        const host = n.closest(".comments-comment-box, form, div");
        if (host && !host.closest("#twa-reply-root")) boxes.add(host);
      }
    }
    boxes.forEach(mountYapOnBox);
  }

  fab.addEventListener("click", () => togglePanel());
  panel.querySelector("#twa-refresh").addEventListener("click", () => fillContext());

  panel.querySelector("#twa-generate").addEventListener("click", async () => {
    showToast("بيصيغ المسودات…", "info");
    const ctx = extractContext();
    const split = splitContext(contextBox.value);
    const btn = panel.querySelector("#twa-generate");
    btn.disabled = true;
    btn.textContent = "بيصيغ…";
    const res = await requestDrafts({
      type: "TWA_GENERATE",
      platform: ctx.platform,
      author: ctx.author,
      postText: split.postText,
      commentText: split.commentText,
      tone: toneBox.value,
    });
    btn.disabled = false;
    btn.textContent = "صِغ مسودتين";
    if (!res?.ok) {
      showToast(res?.error || "فشل توليد الرد.", "error");
      return;
    }
    renderDrafts(res.drafts);
    showToast("مسودتان جاهزين. راجع قبل النشر.", "ok");
  });

  if (globalThis.chrome?.runtime?.onMessage?.addListener) {
    globalThis.chrome.runtime.onMessage.addListener((message) => {
      if (message?.type === "TWA_TOGGLE") togglePanel();
    });
  } else {
    showToast("الإضافة مش متوصلة. اعمل Reload من chrome://extensions ثم F5.", "error");
  }

  document.addEventListener(
    "keydown",
    (event) => {
      if (event.altKey && event.shiftKey && (event.code === "KeyR" || event.key === "R" || event.key === "r")) {
        event.preventDefault();
        event.stopPropagation();
        togglePanel();
      }
    },
    true
  );

  document.addEventListener("click", (event) => {
    const target = event.target;
    if (!target || target.nodeType !== 1) return;
    if (!target.closest(".twa-yap")) closeAllYapMenus();
  }, true);

  syncFab();
  mountYapButtons();
  showToast("TWA جاهز — اختَر نبرة من الشريط فوق الصفحة.", "info");
  const observer = new MutationObserver(() => {
    syncFab();
    mountYapButtons();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  setInterval(() => {
    syncFab();
    mountYapButtons();
  }, 1500);
}
