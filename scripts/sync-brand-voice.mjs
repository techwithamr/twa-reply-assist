import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const remotion = process.env.TWA_REMOTION_ROOT || "C:\\Github\\Remotion";
const signaturePath = join(remotion, "shared", "trends", "brand-signature.ts");
const socialPath = join(remotion, "web", "src", "lib", "brand-social-copy.ts");
const voicePath = join(root, "lib", "voice.js");

function quotedField(src, key) {
  const match = src.match(new RegExp(`${key}:\\s*"([\\s\\S]*?)"\\s*,`, "m"));
  return match?.[1]?.replace(/\\n/g, "\n").trim() || "";
}

const signature = readFileSync(signaturePath, "utf8");
const social = readFileSync(socialPath, "utf8");
const aboutLine =
  social.match(/أساعد مهندسي IT[\s\S]*?مش كورس\./)?.[0]?.replace(/\s+/g, " ") || "";

const lines = [
  `شعار: ${quotedField(signature, "sloganAr")} / ${quotedField(signature, "sloganEn")}`,
  `وعد: ${quotedField(signature, "taglineAr")}`,
  `نبرة: ${quotedField(signature, "toneCoreAr")}`,
  `مجال: ${quotedField(signature, "nicheAr")}`,
  `جمهور: ${quotedField(signature, "audienceAr")}`,
  aboutLine ? `ملخص المنصات: ${aboutLine}` : "",
  "CTA المسموح فقط عند نبرة CTA: https://techwithamr.com/contact",
].filter(Boolean);

const block = [
  "// <TWA_BRAND_VOICE>",
  "export const BRAND_IDENTITY_SOURCE =",
  `  ${JSON.stringify(`${signaturePath} + brand-social-copy.ts`)};`,
  "export const BRAND_IDENTITY_VOICE =",
  `  ${JSON.stringify(lines.join("\n"))};`,
  "// </TWA_BRAND_VOICE>",
].join("\n");

const current = readFileSync(voicePath, "utf8");
const next = current.replace(
  /\/\/ <TWA_BRAND_VOICE>[\s\S]*?\/\/ <\/TWA_BRAND_VOICE>/,
  block
);
if (next === current) {
  throw new Error("voice.js missing TWA_BRAND_VOICE markers");
}
writeFileSync(voicePath, next);
console.log("sync-brand-voice OK", { lines: lines.length, source: signaturePath });
