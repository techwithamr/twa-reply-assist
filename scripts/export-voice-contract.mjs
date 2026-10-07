import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  BRAND_IDENTITY_VOICE,
  DEFAULT_MODEL,
  PLATFORM_LIMITS,
  TONES,
  TONE_LINES,
  TWA_VOICE_CONTRACT,
} from "../lib/voice.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = {
  contract: TWA_VOICE_CONTRACT,
  model: DEFAULT_MODEL,
  brand: BRAND_IDENTITY_VOICE,
  tones: TONES.map((t) => ({ id: t.id, label: t.labelEn })),
  platforms: PLATFORM_LIMITS,
  toneLines: TONE_LINES,
};
const shared = join(root, "shared");
mkdirSync(shared, { recursive: true });
const jsonPath = join(shared, "twa-voice.json");
writeFileSync(jsonPath, `${JSON.stringify(out, null, 2)}\n`);
const androidAssets = join(root, "android", "app", "src", "main", "assets");
mkdirSync(androidAssets, { recursive: true });
writeFileSync(join(androidAssets, "twa-voice.json"), `${JSON.stringify(out, null, 2)}\n`);
console.log("export-voice-contract OK", jsonPath);
