import { createServer } from "node:http";
import { execFile, spawn } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { pathToFileURL } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const port = Number(process.env.TWA_DOWNLOAD_PORT || 8787);

async function ensureRelease() {
  await import(pathToFileURL(join(root, "scripts", "package-release.mjs")).href);
}

const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".zip": "application/zip",
  ".apk": "application/vnd.android.package-archive",
  ".cmd": "application/octet-stream",
  ".ps1": "text/plain; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

function send(res, code, body, type = "text/plain; charset=utf-8") {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" });
  res.end(body);
}

function fileResponse(res, filePath) {
  if (!existsSync(filePath) || !statSync(filePath).isFile()) {
    send(res, 404, "not found");
    return;
  }
  const type = types[extname(filePath).toLowerCase()] || "application/octet-stream";
  const data = readFileSync(filePath);
  res.writeHead(200, {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "Content-Length": data.length,
    "Content-Disposition": extname(filePath).match(/\.(zip|apk|cmd)$/i)
      ? `attachment; filename="${filePath.split(/[/\\]/).pop()}"`
      : "inline",
  });
  res.end(data);
}

await ensureRelease();

const server = createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://127.0.0.1:${port}`);
  const path = url.pathname;

  if (path === "/api/catalog") {
    const catalog = join(root, "release", "catalog.json");
    return fileResponse(res, catalog);
  }

  if (path === "/api/setup" && req.method === "POST") {
    const releaseDir = join(root, "release");
    const script = join(root, "scripts", "one-click-setup.ps1");
    const child = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, "-ReleaseDir", releaseDir],
      { windowsHide: false, stdio: ["ignore", "pipe", "pipe"] }
    );
    let out = "";
    child.stdout.on("data", (d) => {
      out += d.toString();
    });
    child.stderr.on("data", (d) => {
      out += d.toString();
    });
    child.on("close", (code) => {
      send(
        res,
        code === 0 ? 200 : 500,
        JSON.stringify({ ok: code === 0, code, log: out }, null, 2),
        "application/json; charset=utf-8"
      );
    });
    return;
  }

  if (path === "/" || path === "/index.html") {
    return fileResponse(res, join(root, "download", "index.html"));
  }
  if (path === "/download.css") {
    return fileResponse(res, join(root, "download", "download.css"));
  }
  if (path.startsWith("/release/")) {
    return fileResponse(res, join(root, "release", path.slice("/release/".length)));
  }
  if (path === "/twa-setup.cmd") {
    return fileResponse(res, join(root, "release", "twa-setup.cmd"));
  }

  send(res, 404, "not found");
});

server.listen(port, "127.0.0.1", () => {
  const url = `http://127.0.0.1:${port}/`;
  console.log("TWA download UI", url);
  execFile("cmd", ["/c", "start", "", url], { windowsHide: true }, () => {});
});
