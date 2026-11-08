#!/usr/bin/env node
/**
 * Product-page header (3840 × 1646, opaque) in the 1.1.1 screenshot style:
 * the listing's plain background and three genuine captured iPhone keyboards,
 * iOS Light in front with iOS Dark and Darcula behind. No text, because the
 * App Store places the app's icon and name below it and crops it per device.
 *
 *   node release-prep/design/render-store-header.mjs --output-root artifacts/screens-1.1.1/out
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const argument = (flag, fallback) => { const i = process.argv.indexOf(flag); return i < 0 ? fallback : process.argv[i + 1]; };
const root = process.cwd();
const outputRoot = path.resolve(argument('--output-root', 'artifacts/screens-1.1.1/out'));
const modules = process.env.TABFORGE_NODE_MODULES || path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require = createRequire(import.meta.url);
try { require.resolve('playwright'); require.resolve('sharp'); } catch { require = createRequire(path.join(modules, '_tabforge-header.cjs')); }
if (process.env.TABFORGE_NODE_MODULES) require = createRequire(path.join(modules, '_tabforge-header.cjs'));
const { chromium } = require('playwright');
const sharp = require('sharp');

const raw = JSON.parse(await fs.readFile(path.join(outputRoot, 'raw/manifest.json'), 'utf8'));
const sha256 = async file => crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');
const W = 3840, H = 1646;
// Above the home-indicator margin, as in the screenshot cards.
const TRIM = 118;
async function card(state) {
  const entry = raw.families['iphone-medium'][state];
  const file = path.resolve(outputRoot, 'raw', entry.file);
  const k = entry.keyboard;
  const crop = { left: k.x, top: k.y, width: k.width, height: k.height - TRIM };
  const buffer = await sharp(file).extract(crop).png().toBuffer();
  return { url: `data:image/png;base64,${buffer.toString('base64')}`, ratio: crop.height / crop.width, source: { file: path.relative(root, file), sha256: await sha256(file), crop, state } };
}
const [light, dark, darcula] = await Promise.all(['standard', 'dark', 'darcula'].map(card));
const front = 1180, side = 940, overlap = 230;
const cx = W / 2, cy = H * 0.47;
const place = (c, w, x, z, extra = '') => `<img src="${c.url}" style="position:absolute;left:${x}px;top:${cy - (w * c.ratio) / 2}px;width:${w}px;height:${w * c.ratio}px;border-radius:${w * 0.045}px;z-index:${z};box-shadow:0 28px 70px rgba(0,0,0,.18),0 0 0 2px rgba(0,0,0,.06);${extra}">`;
const html = `<html><head><style>html,body{margin:0;background:#F2F2F4}main{position:relative;width:${W}px;height:${H}px;overflow:hidden;background:#F2F2F4}</style></head><body><main>
${place(dark, side, cx - front / 2 - side + overlap, 1)}
${place(darcula, side, cx + front / 2 - overlap, 1)}
${place(light, front, cx - front / 2, 2)}
</main></body></html>`;
const browser = await chromium.launch({ headless: true, ...(process.env.TABFORGE_CHROMIUM ? { executablePath: process.env.TABFORGE_CHROMIUM } : {}) });
const dir = path.join(outputRoot, 'store/header');
await fs.mkdir(dir, { recursive: true });
const png = path.join(dir, 'header-render.png');
try {
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'load' });
  await page.screenshot({ path: png, type: 'png', omitBackground: false });
  await page.close();
} finally { await browser.close(); }
// Apple rejects alpha channels in header images.
const out = path.join(dir, 'tabforge-header-3840x1646.png');
await sharp(png).flatten({ background: '#F2F2F4' }).removeAlpha().png().toFile(out);
await fs.rm(png);
const meta = await sharp(out).metadata();
if (meta.width !== W || meta.height !== H || meta.hasAlpha) throw new Error('Header must be an opaque 3840 × 1646 image');
await fs.writeFile(path.join(dir, 'header-receipt.json'), JSON.stringify({ generatedAt: new Date().toISOString(), renderer: 'release-prep/design/render-store-header.mjs', file: path.relative(root, out), width: W, height: H, sha256: await sha256(out), sources: [light.source, dark.source, darcula.source] }, null, 2) + '\n');
console.log(`Rendered ${path.relative(root, out)}`);
