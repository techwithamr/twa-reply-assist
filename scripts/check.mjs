import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  BRAND_IDENTITY_VOICE,
  CONTEXT_SPLIT,
  DEFAULT_MODEL,
  buildMessages,
  combineContext,
  parseDrafts,
  sanitizeContext,
  splitContext,
} from "../lib/voice.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(readFileSync(join(root, "manifest.json"), "utf8"));
const hosts = manifest.content_scripts[0].matches.join(" ");

assert.equal(manifest.manifest_version, 3);
assert.equal(DEFAULT_MODEL, "gpt-4.1-mini");
assert.match(hosts, /linkedin\.com/);
assert.match(hosts, /facebook\.com/);
assert.match(hosts, /youtube\.com/);
assert.match(hosts, /x\.com/);
assert.match(hosts, /instagram\.com/);
assert.equal(manifest.commands["toggle-reply-panel"].suggested_key.default, "Alt+Shift+R");
assert.equal(manifest.background.service_worker, "background.js");
assert.deepEqual(manifest.content_scripts[0].js, ["content/alive.js", "content/content.js"]);
assert.match(readFileSync(join(root, "content", "alive.js"), "utf8"), /twa-alive-bar/);
assert.ok(manifest.permissions.includes("scripting"));
assert.equal(manifest.content_scripts[0].type, undefined);
assert.doesNotMatch(readFileSync(join(root, "content", "content.js"), "utf8"), /^import /m);
assert.match(BRAND_IDENTITY_VOICE, /وضوح تقني/);
assert.match(BRAND_IDENTITY_VOICE, /techwithamr\.com\/contact/);

const cleaned = sanitizeContext("hello   world\n\n\nnext");
assert.equal(cleaned, "hello world\n\nnext");

const combined = combineContext("البوست", "التعليق");
assert.equal(combined, `البوست${CONTEXT_SPLIT}التعليق`);
assert.deepEqual(splitContext(combined), { postText: "البوست", commentText: "التعليق" });

const messages = buildMessages({
  platform: "linkedin",
  postText: "Scaling AI in Egypt roundtable",
  commentText: "Great having your perspective",
  author: "Mostafa",
  tone: "agree",
  language: "ar",
  extraVoice: "",
});
assert.equal(messages.length, 2);
assert.match(messages[0].content, /Tech With Amr/);
assert.match(messages[0].content, /وضوح تقني/);
assert.match(messages[1].content, /Scaling AI in Egypt/);
assert.doesNotMatch(messages[0].content, /انشر تلقائي|auto-post the comment/i);

const drafts = parseDrafts('{"drafts":["مسودة أولى","مسودة ثانية"]}');
assert.deepEqual(drafts, ["مسودة أولى", "مسودة ثانية"]);

const panel = readFileSync(join(root, "content", "content.js"), "utf8");
assert.match(panel, /id="twa-context"/);
assert.doesNotMatch(panel, /id="twa-post"/);
assert.match(panel, /has-composer/);
assert.match(panel, /toggle-reply-panel|TWA_TOGGLE|KeyR/);
assert.match(panel, /fillComposerDirect/);
assert.match(panel, /twa-toast/);
assert.match(panel, /__twaReplyAssistVersion !== "1.4.3"/);
assert.match(panel, /__twaReplyAssistVersion/);
assert.match(panel, /mountYapOnBox/);
assert.match(panel, /YAP_TONES/);
assert.match(readFileSync(join(root, "lib", "voice.js"), "utf8"), /id: "agree"/);
assert.match(readFileSync(join(root, "background.js"), "utf8"), /injectMatchingTabs/);

console.log("check.mjs OK", {
  model: DEFAULT_MODEL,
  platforms: 5,
  shortcut: "Alt+Shift+R",
  brandVoice: BRAND_IDENTITY_VOICE.includes("وضوح تقني"),
  drafts: drafts.length,
});
