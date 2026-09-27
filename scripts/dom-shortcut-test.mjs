import assert from "node:assert/strict";
import { JSDOM } from "jsdom";

const html = `<!doctype html>
<html>
  <body>
    <article>
      <p class="update-components-text">Recording modes and CCTV reliability</p>
      <div class="comments-comment-box">
        <div class="ql-editor" contenteditable="true">Add a comment</div>
      </div>
    </article>
  </body>
</html>`;

const dom = new JSDOM(html, {
  url: "https://www.linkedin.com/feed/",
  pretendToBeVisual: true,
});

const { window } = dom;
globalThis.window = window;
globalThis.document = window.document;
globalThis.location = window.location;
globalThis.HTMLElement = window.HTMLElement;
globalThis.MutationObserver = window.MutationObserver;
globalThis.getComputedStyle = window.getComputedStyle;
globalThis.InputEvent = window.InputEvent;
globalThis.chrome = {
  runtime: {
    getURL: (p) => `https://extension.local/${p}`,
    sendMessage(_payload, cb) {
      if (typeof cb === "function") cb({ ok: true, drafts: ["one", "two"] });
    },
    onMessage: { addListener() {} },
    lastError: null,
  },
};

await import(`../content/content.js?t=${Date.now()}`);

const root = document.getElementById("twa-reply-root");
assert.ok(root, "toast host should mount on LinkedIn URL");
assert.equal(document.querySelector(".twa-fab"), null, "side FAB must stay off");
assert.equal(document.querySelector(".twa-panel"), null, "side panel must stay off");

const toast = document.getElementById("twa-toast");
assert.ok(toast, "toast should exist");
assert.match(toast.textContent, /TWA جاهز|بيصيغ|اتكتب|خطأ|فشل|الشريط/);

const commentBox = document.querySelector(".comments-comment-box");
const yapBtn = commentBox.querySelector(".twa-yap-btn");
assert.ok(yapBtn, "Yapzy-style T button should sit on the comment box");
yapBtn.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
assert.equal(commentBox.querySelector(".twa-yap").classList.contains("is-open"), true);
const agree = [...commentBox.querySelectorAll(".twa-yap-row")].find((n) => n.dataset.tone === "agree");
agree.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
await new Promise((r) => setTimeout(r, 400));
const box = document.querySelector(".ql-editor");
console.log("after-yap", { box: box.textContent, toast: toast.textContent, kind: toast.dataset.kind });
assert.match(box.textContent, /one/, "picking Agree should insert the first draft");
assert.equal(toast.dataset.kind, "ok");

console.log("dom-shortcut-test OK", {
  oneSurface: !document.querySelector(".twa-fab") && !document.querySelector(".twa-panel"),
  filled: box.textContent,
  toast: toast.textContent,
});
process.exit(0);
