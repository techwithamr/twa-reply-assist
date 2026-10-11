import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(root, "public");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

await import(pathToFileURL(join(root, "scripts", "package-release.mjs")).href);

cpSync(join(root, "download", "index.html"), join(out, "index.html"));
cpSync(join(root, "download", "download.css"), join(out, "download.css"));
cpSync(join(root, "release"), join(out, "release"), { recursive: true });

writeFileSync(
  join(out, "_headers"),
  `/*
  X-Content-Type-Options: nosniff
/release/*
  Content-Disposition: attachment
`
);

console.log("build-web OK", out, "files ready for Vercel");
