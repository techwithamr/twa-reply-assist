import assert from "node:assert/strict";
import { JSDOM } from "jsdom";

const html = `<!doctype html><html><body>
<article><p>Clear strategy aligned priorities at a conference.</p>
<div class="comments-comment-box"><div class="ql-editor" contenteditable="true">Add a comment</div></div>
</article></body></html>`;

const dom = new JSDOM(html, { url: "https://www.linkedin.com/feed/", pretendToBeVisual: true, runScripts: "outside-only" });
const { window } = dom;
globalThis.window = window;
globalThis.document = window.document;
globalThis.HTMLElement = window.HTMLElement;
const api = {
  runtime: {
    sendMessage(_payload, cb) {
      cb({ ok: true, drafts: ["Visible draft from TWA"] });
    },
    lastError: null,
  },
};
globalThis.chrome = api;
window.chrome = api;

const code = await (await import("node:fs/promises")).readFile(new URL("../content/alive.js", import.meta.url), "utf8");
window.eval(code);

const bar = document.getElementById("twa-alive-bar");
assert.ok(bar, "alive bar must exist");
assert.match(bar.textContent, /TWA شغال/);
const agree = [...bar.querySelectorAll("button")].find((b) => b.dataset.tone === "agree");
assert.ok(agree);
agree.click();
await new Promise((r) => setTimeout(r, 80));
console.log("status", document.getElementById("twa-alive-status")?.textContent);
console.log("box", document.querySelector(".ql-editor")?.textContent);
assert.match(document.querySelector(".ql-editor").textContent, /Visible draft from TWA/);
console.log("alive-bar-test OK", { bar: bar.textContent.slice(0, 40) });
process.exit(0);
