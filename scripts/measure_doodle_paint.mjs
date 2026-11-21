import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_DIR || "playwright");

const url = process.argv[2] || "https://glorifiednotepad.net/";
const runs = Number(process.argv[3] || 10);
const viewport = { width: 1366, height: 768 };

const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
const stats = (xs) => (xs.length ? { median: median(xs), min: Math.min(...xs), max: Math.max(...xs) } : null);

const browser = await chromium.launch();

async function coldLoad() {
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  let canvasMs = null;
  const snapshotUrls = [];

  page.on("console", (m) => {
    const hit = m.text().match(/\+(\d+)ms from nav \| .* first full render complete/);
    if (hit) canvasMs = Number(hit[1]);
  });
  page.on("response", (r) => {
    if (new URL(r.url()).pathname.startsWith("/doodle/snapshot/")) {
      snapshotUrls.push({ path: new URL(r.url()).pathname, status: r.status() });
    }
  });
  await page.addInitScript(() => {
    window.__elementTimes = {};
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) window.__elementTimes[e.identifier] = e.renderTime || e.loadTime;
    }).observe({ type: "element", buffered: true });
  });

  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.waitForFunction(() => document.querySelector("#doodle-canvas")?.width > 300, null, { timeout: 15000 });
  await page.waitForFunction(() => !document.getElementById("doodle-snapshot"), null, { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(300);
  const elementTimes = await page.evaluate(() => window.__elementTimes);
  await context.close();
  return {
    snapshotMs: elementTimes["doodle-snapshot"] ? Math.round(elementTimes["doodle-snapshot"]) : null,
    canvasMs,
    snapshotRequests: snapshotUrls,
  };
}

async function screenshotWith(blockApp) {
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  if (blockApp) await page.route("**/assets/js/app-*.js*", (route) => route.abort());
  await page.goto(url, { waitUntil: "domcontentloaded" });
  const src = await page.evaluate(() => document.getElementById("doodle-snapshot-img")?.getAttribute("src") ?? null);
  if (blockApp) {
    await page.waitForFunction(() => {
      const img = document.getElementById("doodle-snapshot-img");
      return img && img.complete && img.naturalWidth > 0;
    }, null, { timeout: 15000 });
  } else {
    await page.waitForFunction(() => document.querySelector("#doodle-canvas")?.width > 300, null, { timeout: 15000 });
    await page.waitForFunction(() => !document.getElementById("doodle-snapshot"), null, { timeout: 15000 });
    await page.waitForTimeout(500);
  }
  const shot = await page.screenshot();
  await context.close();
  return { shot, src };
}

const results = [];
let failures = 0;
try {
  for (let i = 0; i < runs; i++) {
    try {
      results.push(await coldLoad());
    } catch (err) {
      failures++;
      console.error(`run ${i + 1} failed: ${err.message}`);
    }
  }

  for (const r of results) console.log(JSON.stringify(r));
  const summary = {
    runs,
    failures,
    snapshotMs: stats(results.map((r) => r.snapshotMs).filter((x) => x != null)),
    canvasMs: stats(results.map((r) => r.canvasMs).filter((x) => x != null)),
    snapshotRequestsNon200: results.flatMap((r) => r.snapshotRequests).filter((r) => r.status !== 200).length,
  };

  if (process.env.PARITY === "1") {
    const before = await screenshotWith(true);
    const after = await screenshotWith(false);
    summary.parity = {
      identical: before.shot.equals(after.shot),
      snapshotOnlySrc: before.src,
      canvasStageSrc: after.src,
    };
  }
  console.log(JSON.stringify(summary));
} finally {
  await browser.close();
}
if (failures) process.exitCode = 1;
