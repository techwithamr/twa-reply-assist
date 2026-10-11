import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { crc32, deflateRawSync } from "node:zlib";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const releaseDir = join(root, "release");
const staging = join(releaseDir, ".staging");
const manifestPath = join(root, "manifest.json");
const version = JSON.parse(readFileSync(manifestPath, "utf8")).version;

const chromeOut = join(releaseDir, `twa-reply-assist-chrome-${version}.zip`);
const androidZipOut = join(releaseDir, `twa-reply-assist-android-${version}.zip`);
const androidApkCandidates = [
  join(root, "android", "app", "build", "outputs", "apk", "debug", "app-debug.apk"),
  join(root, "android", "app", "build", "outputs", "apk", "release", "app-release.apk"),
  join(releaseDir, "twa-reply-assist.apk"),
];

const chromeInclude = [
  "manifest.json",
  "background.js",
  "content",
  "lib",
  "popup",
  "options",
  "icons",
  "shared",
];

const skipDir = new Set([
  ".git",
  "node_modules",
  ".chrome-profile",
  "release",
  ".gradle",
  "build",
  ".idea",
]);

function walk(dir, base = dir, files = []) {
  for (const name of readdirSync(dir)) {
    if (skipDir.has(name)) continue;
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, base, files);
    else files.push(relative(base, full).replaceAll("\\", "/"));
  }
  return files;
}

function copyTree(from, to) {
  mkdirSync(to, { recursive: true });
  for (const rel of walk(from)) {
    const src = join(from, rel);
    const dest = join(to, rel);
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(src, dest);
  }
}

function u16(n) {
  const b = Buffer.alloc(2);
  b.writeUInt16LE(n, 0);
  return b;
}

function u32(n) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(n >>> 0, 0);
  return b;
}

/** Cross-platform ZIP (no PowerShell) for local Windows + Vercel Linux. */
function zipFolder(folder, outZip) {
  if (existsSync(outZip)) rmSync(outZip);
  const files = walk(folder).sort();
  const locals = [];
  const centrals = [];
  let offset = 0;

  for (const rel of files) {
    const data = readFileSync(join(folder, rel));
    const name = Buffer.from(rel, "utf8");
    const compressed = deflateRawSync(data);
    const crc = crc32(data);
    const local = Buffer.concat([
      u32(0x04034b50),
      u16(20),
      u16(0),
      u16(8),
      u16(0),
      u16(0),
      u32(crc),
      u32(compressed.length),
      u32(data.length),
      u16(name.length),
      u16(0),
      name,
      compressed,
    ]);
    centrals.push(
      Buffer.concat([
        u32(0x02014b50),
        u16(20),
        u16(20),
        u16(0),
        u16(8),
        u16(0),
        u16(0),
        u32(crc),
        u32(compressed.length),
        u32(data.length),
        u16(name.length),
        u16(0),
        u16(0),
        u16(0),
        u16(0),
        u32(0),
        u32(offset),
        name,
      ])
    );
    locals.push(local);
    offset += local.length;
  }

  const central = Buffer.concat(centrals);
  const end = Buffer.concat([
    u32(0x06054b50),
    u16(0),
    u16(0),
    u16(files.length),
    u16(files.length),
    u32(central.length),
    u32(offset),
    u16(0),
  ]);
  writeFileSync(outZip, Buffer.concat([...locals, central, end]));
}

mkdirSync(releaseDir, { recursive: true });
rmSync(staging, { recursive: true, force: true });
mkdirSync(staging, { recursive: true });

const chromeStage = join(staging, "chrome");
mkdirSync(chromeStage, { recursive: true });
for (const item of chromeInclude) {
  const src = join(root, item);
  if (!existsSync(src)) continue;
  const dest = join(chromeStage, item);
  if (statSync(src).isDirectory()) copyTree(src, dest);
  else {
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(src, dest);
  }
}
zipFolder(chromeStage, chromeOut);

const androidStage = join(staging, "android");
copyTree(join(root, "android"), androidStage);
if (existsSync(join(root, "shared", "twa-voice.json"))) {
  mkdirSync(join(androidStage, "app", "src", "main", "assets"), { recursive: true });
  copyFileSync(
    join(root, "shared", "twa-voice.json"),
    join(androidStage, "app", "src", "main", "assets", "twa-voice.json")
  );
}
zipFolder(androidStage, androidZipOut);

let apkPath = "";
let apkName = "";
for (const candidate of androidApkCandidates) {
  if (existsSync(candidate)) {
    apkName = `twa-reply-assist-${version}.apk`;
    apkPath = join(releaseDir, apkName);
    copyFileSync(candidate, apkPath);
    break;
  }
}

copyFileSync(join(root, "scripts", "one-click-setup.ps1"), join(releaseDir, "one-click-setup.ps1"));
writeFileSync(
  join(releaseDir, "twa-setup.cmd"),
  [
    "@echo off",
    "setlocal",
    "title TWA Reply Assist Setup",
    'cd /d "%~dp0"',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0one-click-setup.ps1" -ReleaseDir "%~dp0"',
    "if errorlevel 1 (",
    "  echo.",
    "  echo Setup failed. Press any key to close.",
    "  pause >nul",
    "  exit /b 1",
    ")",
    "echo.",
    "echo Setup finished. Press any key to close.",
    "pause >nul",
    "",
  ].join("\r\n")
);

const setupBundleDir = join(staging, "setup-bundle");
mkdirSync(setupBundleDir, { recursive: true });
copyFileSync(chromeOut, join(setupBundleDir, relative(releaseDir, chromeOut).replaceAll("\\", "/").split("/").pop()));
copyFileSync(join(releaseDir, "one-click-setup.ps1"), join(setupBundleDir, "one-click-setup.ps1"));
copyFileSync(join(releaseDir, "twa-setup.cmd"), join(setupBundleDir, "twa-setup.cmd"));
const setupZipOut = join(releaseDir, `twa-reply-assist-setup-${version}.zip`);
zipFolder(setupBundleDir, setupZipOut);

const catalog = {
  version,
  builtAt: new Date().toISOString(),
  chrome: {
    file: relative(releaseDir, chromeOut).replaceAll("\\", "/"),
    label: "إضافة كروم",
  },
  android: {
    zip: relative(releaseDir, androidZipOut).replaceAll("\\", "/"),
    apk: apkName || null,
    label: apkName ? "تطبيق أندرويد (APK)" : "مشروع أندرويد (ابنِ APK من Android Studio)",
  },
  setup: {
    windows: "twa-setup.cmd",
    bundle: relative(releaseDir, setupZipOut).replaceAll("\\", "/"),
    note: "إعداد سريع على ويندوز: فك الضغط وشغّل twa-setup.cmd",
  },
};

writeFileSync(join(releaseDir, "catalog.json"), `${JSON.stringify(catalog, null, 2)}\n`);
rmSync(staging, { recursive: true, force: true });

console.log("package-release OK", catalog);
