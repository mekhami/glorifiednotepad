import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_DIR || "playwright");

const url = process.argv[2] || "https://glorifiednotepad.net/";
const out = process.argv[3] || "board.json";

const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  const board = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("no join reply")), 20000);
    page.on("websocket", (ws) => {
      if (!new URL(ws.url()).pathname.includes("/live/websocket")) return;
      ws.on("framereceived", ({ payload }) => {
        if (typeof payload !== "string" || !payload.includes("load-pixels")) return;
        const events = JSON.parse(payload)[4]?.response?.rendered?.e;
        const pixels = events?.find(([name]) => name === "load-pixels")?.[1].pixels;
        const animations = events?.find(([name]) => name === "load-animations")?.[1].animations;
        if (!pixels || !animations) return;
        clearTimeout(timer);
        resolve({ pixels, animations });
      });
    });
  });
  await page.goto(url, { waitUntil: "domcontentloaded" });
  const data = await board;
  writeFileSync(out, JSON.stringify(data));
  console.log(JSON.stringify({ out, pixels: data.pixels.length, animations: data.animations.length }));
} finally {
  await browser.close();
}
