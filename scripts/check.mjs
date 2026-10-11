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
  detectReplyLanguage,
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
const alive = readFileSync(join(root, "content", "alive.js"), "utf8");
assert.match(alive, /twa-alive-bar/);
assert.match(alive, /twa-alive-launch/);
assert.match(alive, /width:32px/);
assert.doesNotMatch(alive, /min-width:280px/);
assert.match(alive, /function detectPlatform/);
assert.match(alive, /facebook\.com/);
assert.doesNotMatch(alive, /platform: "linkedin"/);
assert.match(alive, /"right:0"/);
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
assert.equal(detectReplyLanguage("Scaling AI in Egypt roundtable"), "en");
assert.equal(detectReplyLanguage("القرار في مشاريع الشبكات المصرية"), "ar");
const autoEn = buildMessages({
  platform: "linkedin",
  postText: "Scaling AI in Egypt roundtable",
  commentText: "",
  author: "",
  tone: "agree",
  language: "auto",
  extraVoice: "",
});
assert.match(autoEn[0].content, /English only/);

const drafts = parseDrafts('{"drafts":["مسودة أولى","مسودة ثانية"]}');
assert.deepEqual(drafts, ["مسودة أولى", "مسودة ثانية"]);

const panel = readFileSync(join(root, "content", "content.js"), "utf8");
assert.match(panel, /id="twa-context"/);
assert.doesNotMatch(panel, /id="twa-post"/);
assert.match(panel, /has-composer/);
assert.match(panel, /toggle-reply-panel|TWA_TOGGLE|KeyR/);
assert.match(panel, /fillComposerDirect/);
assert.match(panel, /twa-toast/);
assert.match(panel, /__twaReplyAssistVersion !== "1.4.8"/);
assert.match(readFileSync(join(root, "background.js"), "utf8"), /model: DEFAULT_MODEL/);
assert.match(panel, /__twaReplyAssistVersion/);
assert.match(panel, /mountYapOnBox/);
assert.match(panel, /YAP_TONES/);
assert.match(readFileSync(join(root, "lib", "voice.js"), "utf8"), /id: "agree"/);
assert.match(readFileSync(join(root, "background.js"), "utf8"), /injectMatchingTabs/);
assert.match(readFileSync(join(root, "android", "app", "src", "main", "java", "com", "techwithamr", "replyassist", "Voice.kt"), "utf8"), /gpt-4.1-mini/);
assert.match(readFileSync(join(root, "android", "app", "src", "main", "AndroidManifest.xml"), "utf8"), /TwaA11yService/);
assert.match(readFileSync(join(root, "shared", "twa-voice.json"), "utf8"), /وضوح تقني/);
assert.match(readFileSync(join(root, "download", "index.html"), "utf8"), /إعداد سريع بضغطة واحدة/);
assert.match(readFileSync(join(root, "scripts", "package-release.mjs"), "utf8"), /twa-reply-assist-chrome/);
assert.match(readFileSync(join(root, "scripts", "package-release.mjs"), "utf8"), /twa-reply-assist-setup-/);
assert.match(readFileSync(join(root, "scripts", "serve-download.mjs"), "utf8"), /\/api\/setup/);
assert.match(readFileSync(join(root, "scripts", "build-web.mjs"), "utf8"), /outputDirectory|public/);
assert.match(readFileSync(join(root, "vercel.json"), "utf8"), /build-web/);
assert.match(readFileSync(join(root, "package.json"), "utf8"), /"download"/);
assert.match(readFileSync(join(root, "package.json"), "utf8"), /"build:web"/);

console.log("check.mjs OK", {
  model: DEFAULT_MODEL,
  platforms: 5,
  shortcut: "Alt+Shift+R",
  brandVoice: BRAND_IDENTITY_VOICE.includes("وضوح تقني"),
  drafts: drafts.length,
});
