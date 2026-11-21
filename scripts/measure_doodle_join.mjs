import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_DIR || "playwright");

const url = process.argv[2] || "https://glorifiednotepad.net/";
const runs = Number(process.argv[3] || 10);

const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

const browser = await chromium.launch();
const results = [];
let failures = 0;

try {
  for (let i = 0; i < runs; i++) {
    const context = await browser.newContext({ viewport: { width: 1365, height: 768 } });
    const page = await context.newPage();
    const cdp = await context.newCDPSession(page);
    const socketIds = new Set();
    let extensions = null;
    const marks = [];

    page.on("console", (m) => {
      if (m.text().includes("first full render complete")) marks.push(m.text());
    });
    await cdp.send("Network.enable");
    cdp.on("Network.webSocketCreated", (e) => {
      if (e.url.includes("/live/websocket")) socketIds.add(e.requestId);
    });
    cdp.on("Network.webSocketHandshakeResponseReceived", (e) => {
      if (!socketIds.has(e.requestId)) return;
      const entry = Object.entries(e.response.headers).find(
        ([k]) => k.toLowerCase() === "sec-websocket-extensions"
      );
      extensions = entry ? entry[1] : null;
    });

    await page.addInitScript(() => {
      const Native = window.WebSocket;
      window.WebSocket = class extends Native {
        constructor(...args) {
          super(...args);
          if (!new URL(this.url).pathname.includes("/live/websocket")) return;
          this.addEventListener("open", () => performance.mark("ws-open"));
          this.addEventListener("message", (e) => {
            if (typeof e.data === "string" && e.data.includes("load-pixels")) {
              performance.mark("join-receive");
              window.__joinBytes = e.data.length;
            }
          });
        }
        send(data) {
          if (typeof data === "string" && data.includes('"phx_join"') && !performance.getEntriesByName("join-send").length) {
            performance.mark("join-send");
          }
          return super.send(data);
        }
      };
    });

    const res = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });
    try {
      await page.waitForFunction(() => window.__joinBytes > 0, null, { timeout: 15000 });
      await page.waitForFunction(() => document.querySelector("#doodle-canvas")?.width > 300);
      const out = await page.evaluate(async () => {
        await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
        const c = document.querySelector("#doodle-canvas");
        const data = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
        const digest = await crypto.subtle.digest("SHA-256", data);
        const hash = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
        const t = (n) => performance.getEntriesByName(n)[0]?.startTime;
        return {
          joinMs: Math.round(t("join-receive") - t("join-send")),
          joinReplyChars: window.__joinBytes,
          fcpMs: Math.round(performance.getEntriesByName("first-contentful-paint")[0]?.startTime),
          hash,
        };
      });
      results.push({ status: res.status(), extensions, ...out });
    } catch (err) {
      failures++;
      console.error(`run ${i + 1} failed: ${err.message}`);
    }
    await context.close();
  }
} finally {
  await browser.close();
}

for (const r of results) console.log(JSON.stringify(r));
const joins = results.map((r) => r.joinMs);
console.log(
  JSON.stringify({
    runs,
    failures,
    joinMedianMs: joins.length ? median(joins) : null,
    joinMinMs: Math.min(...joins),
    joinMaxMs: Math.max(...joins),
    extensions: [...new Set(results.map((r) => r.extensions))],
    distinctCanvasHashes: new Set(results.map((r) => r.hash)).size,
  })
);
if (failures) process.exitCode = 1;
