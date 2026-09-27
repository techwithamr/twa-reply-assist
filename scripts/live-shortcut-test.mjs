import { spawn } from "node:child_process";
import { readFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const profile = join(root, ".chrome-profile");
const port = 9223;
const chrome =
  process.env.CHROME_PATH ||
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

mkdirSync(profile, { recursive: true });

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function json(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res.json();
}

function readExtensionId() {
  const files = [
    join(profile, "Default", "Secure Preferences"),
    join(profile, "Default", "Preferences"),
  ];
  for (const file of files) {
    if (!existsSync(file)) continue;
    const raw = readFileSync(file, "utf8");
    const data = JSON.parse(raw);
    const settings = data.extensions?.settings || {};
    for (const [id, value] of Object.entries(settings)) {
      if (String(value.path || "").replaceAll("/", "\\").toLowerCase().includes("twa-reply-assist")) {
        return id;
      }
    }
  }
  return "";
}

async function waitForId() {
  for (let i = 0; i < 20; i++) {
    const id = readExtensionId();
    if (id) return id;
    await sleep(500);
  }
  throw new Error("extension id not found in test profile");
}

async function cdp(wsUrl, method, params = {}) {
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", reject);
  });
  const id = Math.floor(Math.random() * 1e9);
  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`CDP timeout ${method}`)), 8000);
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id !== id) return;
      clearTimeout(timer);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    });
    ws.send(JSON.stringify({ id, method, params }));
  });
  ws.close();
  return result;
}

async function waitDevtools() {
  for (let i = 0; i < 30; i++) {
    try {
      return await json(`http://127.0.0.1:${port}/json/version`);
    } catch {
      await sleep(400);
    }
  }
  throw new Error("devtools not ready");
}

const child = spawn(
  chrome,
  [
    `--user-data-dir=${profile}`,
    `--load-extension=${root}`,
    "--disable-features=DisableLoadExtensionCommandLineSwitch",
    `--remote-debugging-port=${port}`,
    "--no-first-run",
    "--no-default-browser-check",
    "about:blank",
  ],
  { detached: true, stdio: "ignore" }
);
child.unref();

let passed = false;
try {
  await waitDevtools();
  const id = await waitForId();
  const harness = `chrome-extension://${id}/tests/harness.html`;
  const created = await json(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(harness)}`);
  await sleep(800);
  const targets = await json(`http://127.0.0.1:${port}/json`);
  const page = targets.find((t) => t.url.includes("harness.html")) || created;
  if (!page?.webSocketDebuggerUrl) throw new Error("no harness target");

  await sleep(700);
  const before = await cdp(page.webSocketDebuggerUrl, "Runtime.evaluate", {
    expression:
      "({root:!!document.getElementById('twa-reply-root'), open:document.getElementById('twa-reply-root')?.classList.contains('is-open')||false})",
    returnByValue: true,
  });

  await cdp(page.webSocketDebuggerUrl, "Input.dispatchKeyEvent", {
    type: "keyDown",
    key: "Alt",
    code: "AltLeft",
    windowsVirtualKeyCode: 18,
    modifiers: 1,
  });
  await cdp(page.webSocketDebuggerUrl, "Input.dispatchKeyEvent", {
    type: "keyDown",
    key: "Shift",
    code: "ShiftLeft",
    windowsVirtualKeyCode: 16,
    modifiers: 9,
  });
  await cdp(page.webSocketDebuggerUrl, "Input.dispatchKeyEvent", {
    type: "keyDown",
    key: "R",
    code: "KeyR",
    windowsVirtualKeyCode: 82,
    modifiers: 9,
  });
  await cdp(page.webSocketDebuggerUrl, "Input.dispatchKeyEvent", {
    type: "keyUp",
    key: "R",
    code: "KeyR",
    windowsVirtualKeyCode: 82,
    modifiers: 9,
  });
  await sleep(400);

  const after = await cdp(page.webSocketDebuggerUrl, "Runtime.evaluate", {
    expression:
      "({root:!!document.getElementById('twa-reply-root'), open:document.getElementById('twa-reply-root')?.classList.contains('is-open')||false, text:document.querySelector('#twa-reply-root h2')?.textContent||''})",
    returnByValue: true,
  });

  const beforeVal = before.result.value;
  const afterVal = after.result.value;
  if (!afterVal.root) throw new Error(`panel root missing ${JSON.stringify({ beforeVal, afterVal })}`);
  if (!afterVal.open) throw new Error(`panel did not open ${JSON.stringify({ beforeVal, afterVal })}`);
  if (afterVal.text !== "صياغة رد") throw new Error(`unexpected title ${afterVal.text}`);
  passed = true;
  console.log("live-shortcut-test OK", { id, beforeVal, afterVal });
} finally {
  try {
    child.kill();
  } catch {
    // ignore
  }
}

if (!passed) process.exit(1);
