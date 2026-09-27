import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { extname, join } from "node:path";

const root = join(import.meta.dirname, "..");
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css" };
const server = createServer((req, res) => {
  const file = req.url === "/" ? "/tests/fake-linkedin.html" : req.url;
  const path = join(root, decodeURIComponent(file.split("?")[0]));
  if (!path.startsWith(root) || !existsSync(path)) {
    res.writeHead(404);
    res.end("not found");
    return;
  }
  res.writeHead(200, { "content-type": types[extname(path)] || "text/plain" });
  res.end(readFileSync(path));
});
server.listen(3847, "127.0.0.1", () => {
  console.log("PROOF_SERVER http://127.0.0.1:3847/tests/fake-linkedin.html");
});
