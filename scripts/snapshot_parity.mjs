import { createRequire } from "node:module";
import { readFileSync } from "node:fs";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_DIR || "playwright");

const dir = process.argv[2];
const board = JSON.parse(readFileSync(`${dir}/board.json`, "utf8"));
const pngBase64 = readFileSync(`${dir}/board.png`).toString("base64");
const sizes = [[1366, 768], [1365, 768], [1365, 767], [1920, 1080], [390, 844]];

const imgHtml = `<!doctype html><style>
body{background-color:#df9390;margin:0}
#snap{position:fixed;left:50%;top:50%;width:7680px;height:4320px;margin:-2160px 0 0 -3840px;image-rendering:pixelated}
</style><img id="snap" src="data:image/png;base64,${pngBase64}">`;

const canvasHtml = `<!doctype html><style>
body{background-color:#df9390;margin:0}
canvas{position:fixed;top:0;left:0;width:100%;height:100%}
</style><canvas id="c"></canvas>`;

async function drawBoard(page, data) {
  await page.evaluate((data) => {
    const W = 1920, H = 1080, PIXEL = 2, scale = 2;
    const c = document.getElementById("c");
    c.width = innerWidth;
    c.height = innerHeight;
    const ctx = c.getContext("2d");
    const off = new OffscreenCanvas(W, H);
    const image = new ImageData(W, H);
    const u32 = new Uint32Array(image.data.buffer);
    const put = (p) => {
      if (p.x < 0 || p.x >= W || p.y < 0 || p.y >= H) return;
      const r = parseInt(p.color.slice(1, 3), 16), g = parseInt(p.color.slice(3, 5), 16), b = parseInt(p.color.slice(5, 7), 16);
      u32[p.y * W + p.x] = ((255 << 24) | (b << 16) | (g << 8) | r) >>> 0;
    };
    data.pixels.forEach(put);
    data.animations.forEach((a) => (a.frames["0"] || []).forEach(put));
    off.getContext("2d").putImageData(image, 0, 0);
    ctx.clearRect(0, 0, c.width, c.height);
    ctx.save();
    ctx.translate(innerWidth / 2 - (W * PIXEL * scale) / 2, innerHeight / 2 - (H * PIXEL * scale) / 2);
    ctx.scale(scale, scale);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(off, 0, 0, W * PIXEL, H * PIXEL);
    ctx.restore();
  }, data);
}

const browser = await chromium.launch();
try {
  const diffPage = await browser.newPage();
  for (const [w, h] of sizes) {
    const context = await browser.newContext({ viewport: { width: w, height: h } });
    const a = await context.newPage();
    await a.setContent(canvasHtml);
    await drawBoard(a, board);
    const shotCanvas = await a.screenshot();
    const b = await context.newPage();
    await b.setContent(imgHtml);
    await b.waitForFunction(() => document.getElementById("snap").complete);
    const shotImg = await b.screenshot();

    const diff = await diffPage.evaluate(
      async ([x, y]) => {
        const load = async (b64) => {
          const bmp = await createImageBitmap(await (await fetch(`data:image/png;base64,${b64}`)).blob());
          const cv = new OffscreenCanvas(bmp.width, bmp.height);
          const cx = cv.getContext("2d");
          cx.drawImage(bmp, 0, 0);
          return cx.getImageData(0, 0, bmp.width, bmp.height).data;
        };
        const [p, q] = await Promise.all([load(x), load(y)]);
        let different = 0, max = 0;
        for (let i = 0; i < p.length; i += 4) {
          const d = Math.max(Math.abs(p[i] - q[i]), Math.abs(p[i + 1] - q[i + 1]), Math.abs(p[i + 2] - q[i + 2]));
          if (d) different++;
          if (d > max) max = d;
        }
        return { different, max, total: p.length / 4 };
      },
      [shotCanvas.toString("base64"), shotImg.toString("base64")]
    );
    console.log(JSON.stringify({ viewport: `${w}x${h}`, identical: shotCanvas.equals(shotImg), ...diff }));
    await context.close();
  }
} finally {
  await browser.close();
}
