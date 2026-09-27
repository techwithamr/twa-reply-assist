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
assert.ok(root, "panel root should mount on LinkedIn URL");
assert.equal(root.classList.contains("is-open"), false);
assert.equal(root.classList.contains("has-composer"), true, "FAB should show on LinkedIn");

const keyEvent = new window.KeyboardEvent("keydown", {
  key: "R",
  code: "KeyR",
  altKey: true,
  shiftKey: true,
  bubbles: true,
  cancelable: true,
});
document.dispatchEvent(keyEvent);

assert.equal(root.classList.contains("is-open"), true, "Alt+Shift+R should open the panel");
assert.match(root.querySelector("h2")?.textContent || "", /صياغة رد/);

const toast = document.getElementById("twa-toast");
assert.ok(toast, "toast should exist");
assert.match(toast.textContent, /TWA جاهز|بيصيغ|اتكتب|خطأ|فشل/);

const box = document.querySelector(".ql-editor");
box.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
await new Promise((r) => setTimeout(r, 400));
console.log("after-click", { box: box.textContent, toast: toast.textContent, kind: toast.dataset.kind });
assert.match(box.textContent, /one/, "clicking the comment box should insert the first draft");
assert.equal(toast.dataset.kind, "ok");

console.log("dom-shortcut-test OK", {
  open: root.classList.contains("is-open"),
  fab: root.classList.contains("has-composer"),
  title: root.querySelector("h2")?.textContent,
  filled: box.textContent,
  toast: toast.textContent,
});
process.exit(0);
