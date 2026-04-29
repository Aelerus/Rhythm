// Minimal static file server for the prototype. No dependencies.
// Run with `node serve.js` (or via start.bat).

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = Number(process.env.PORT) || 8000;
const ROOT = __dirname;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css":  "text/css; charset=utf-8",
  ".js":   "text/javascript; charset=utf-8",
  ".mjs":  "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg":  "image/svg+xml",
  ".png":  "image/png",
  ".jpg":  "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif":  "image/gif",
  ".ico":  "image/x-icon",
  ".wav":  "audio/wav",
  ".mp3":  "audio/mpeg",
  ".ogg":  "audio/ogg",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf":  "font/ttf",
};

const server = http.createServer((req, res) => {
  let urlPath;
  try { urlPath = decodeURIComponent(req.url.split("?")[0]); }
  catch { res.writeHead(400); return res.end("Bad URL"); }

  if (urlPath === "/") urlPath = "/index.html";

  const target = path.normalize(path.join(ROOT, urlPath));
  if (!target.startsWith(ROOT)) {
    res.writeHead(403); return res.end("Forbidden");
  }

  fs.stat(target, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      return res.end("404 Not Found: " + urlPath);
    }
    const ext = path.extname(target).toLowerCase();
    res.writeHead(200, {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Cache-Control": "no-store",
    });
    fs.createReadStream(target).pipe(res);
  });
});

server.listen(PORT, () => {
  console.log(`Rhythm Bullet Hell — serving at http://localhost:${PORT}`);
  console.log(`Press Ctrl+C to stop.`);
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use. Close the other server or set PORT=xxxx.`);
  } else {
    console.error("Server error:", err);
  }
  process.exit(1);
});
