#!/usr/bin/env node
/**
 * App Store screenshots, second design (TabForge 1.1.1).
 *
 * One plain background, a large centered headline and subtitle, and one large
 * genuine capture per image: a native capture inside the installed Simulator's
 * own chrome, or a crop of the captured keyboard. No app UI is redrawn.
 *
 *   node release-prep/design/render-store-screenshots.mjs --output-root artifacts/screens-1.1.1/out
 *   node release-prep/design/render-store-screenshots.mjs --output-root … --family iphone-large --slide 3 --preview
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { deviceCutout } from './device-cutout.mjs';

const argument = (flag, fallback) => { const i = process.argv.indexOf(flag); return i < 0 ? fallback : process.argv[i + 1]; };
const root = process.cwd();
const outputRoot = path.resolve(argument('--output-root', 'artifacts/screens-1.1.1/out'));
const modules = process.env.TABFORGE_NODE_MODULES || path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require = createRequire(import.meta.url);
try { require.resolve('playwright'); require.resolve('sharp'); } catch { require = createRequire(path.join(modules, '_tabforge-store.cjs')); }
if (process.env.TABFORGE_NODE_MODULES) require = createRequire(path.join(modules, '_tabforge-store.cjs'));
const { chromium } = require('playwright');
const sharp = require('sharp');

const raw = JSON.parse(await fs.readFile(path.join(outputRoot, 'raw/manifest.json'), 'utf8'));
const work = path.join(outputRoot, 'framed-work');
await fs.mkdir(work, { recursive: true });
const dataURL = async file => `data:image/png;base64,${(await fs.readFile(file)).toString('base64')}`;
const sha256 = async file => crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');
const esc = t => String(t).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const chromiumPath = argument('--chromium', process.env.TABFORGE_CHROMIUM);
const browser = await chromium.launch({ headless: true, ...(chromiumPath ? { executablePath: chromiumPath } : {}) });

// Installed Simulator chrome around a native capture (same method as
// render-framed-screenshots.mjs; the capture itself is not retouched).
const pdfCache = new Map();
async function pdfPNG(file, scale = 3) {
  const key = file + '@' + scale;
  if (pdfCache.has(key)) return pdfCache.get(key);
  const out = path.join(work, crypto.createHash('sha256').update(key).digest('hex').slice(0, 16));
  try { await fs.access(out + '.png'); } catch { execFileSync('pdftocairo', ['-png', '-transp', '-singlefile', '-r', String(scale * 72), file, out]); }
  const result = { file: out + '.png', url: await dataURL(out + '.png'), ...(await sharp(out + '.png').metadata()) };
  pdfCache.set(key, result);
  return result;
}
const frameCache = new Map();
async function framed(sourceFamily, state) {
  const key = sourceFamily + '/' + state;
  if (frameCache.has(key)) return frameCache.get(key);
  const entry = raw.families[sourceFamily]?.[state];
  if (!entry) throw new Error(`Missing native ${key}`);
  const file = path.resolve(outputRoot, 'raw', entry.file);
  const out = path.join(work, `${sourceFamily}-${state}-store-framed.png`);
  const tablet = sourceFamily.startsWith('ipad');
  const scale = tablet ? 2 : 3;
  const model = tablet ? 'iPad Pro 11-inch (M5)' : 'iPhone 18 Pro';
  const profileDir = path.join(argument('--device-types', '/Library/Developer/CoreSimulator/Profiles/DeviceTypes'), model + '.simdevicetype/Contents/Resources');
  const profile = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', path.join(profileDir, 'profile.plist')], { encoding: 'utf8' }));
  const chromeDir = path.join(argument('--chrome-root', '/Library/Developer/DeviceKit/Chrome'), (tablet ? 'tablet5' : 'phone11') + '.devicechrome/Contents/Resources');
  const chrome = JSON.parse(await fs.readFile(path.join(chromeDir, 'chrome.json'), 'utf8'));
  const sides = chrome.images.sizing;
  const p = entry.provenance.pointGeometry.appBounds;
  const landscape = p.width > p.height;
  const sw = (landscape ? p.height : p.width) * scale, sh = (landscape ? p.width : p.height) * scale;
  const left = sides.leftWidth * scale, right = sides.rightWidth * scale, top = sides.topHeight * scale, bottom = sides.bottomHeight * scale;
  const width = sw + left + right, height = sh + top + bottom;
  const pieces = [];
  for (const position of ['topLeft', 'top', 'topRight', 'left', 'right', 'bottomLeft', 'bottom', 'bottomRight']) {
    const asset = await pdfPNG(path.join(chromeDir, chrome.images[position] + '.pdf'), scale);
    const aw = asset.width, ah = asset.height;
    let style = '';
    if (position === 'topLeft') style = `left:0;top:0;width:${aw}px;height:${ah}px`;
    if (position === 'topRight') style = `right:0;top:0;width:${aw}px;height:${ah}px`;
    if (position === 'bottomLeft') style = `left:0;bottom:0;width:${aw}px;height:${ah}px`;
    if (position === 'bottomRight') style = `right:0;bottom:0;width:${aw}px;height:${ah}px`;
    if (position === 'top' || position === 'bottom') style = `left:${aw === 3 ? 330 : 96 * scale}px;${position}:0;width:${width - 2 * (aw === 3 ? 330 : 96 * scale)}px;height:${ah}px`;
    if (position === 'left' || position === 'right') style = `${position}:0;top:${tablet ? 96 * scale : 110 * scale}px;width:${aw}px;height:${height - 2 * (tablet ? 96 * scale : 110 * scale)}px`;
    pieces.push(`<img src="${asset.url}" style="position:absolute;${style}">`);
  }
  const mask = await pdfPNG(path.join(profileDir, profile.framebufferMask + '.pdf'), 1);
  let sensor = '';
  if (!tablet) {
    // The legacy profile sensor PDF is empty. Keep the real island pixels from
    // a native Device Hub capture, isolated from its plain background.
    const cameraSource = path.join(outputRoot, 'framed-captures/iphone-light-clean-window.png');
    const camera = await sharp(cameraSource).extract({ left: 951, top: 190, width: 163, height: 65 }).ensureAlpha().raw().toBuffer();
    for (let i = 0; i < camera.length; i += 4) { const shade = Math.max(camera[i], camera[i + 1], camera[i + 2]); camera[i] = camera[i + 1] = camera[i + 2] = 0; camera[i + 3] = shade < 160 ? 255 - shade : 0; }
    const cameraPNG = await sharp(camera, { raw: { width: 163, height: 65, channels: 4 } }).png().toBuffer();
    sensor = `<img src="data:image/png;base64,${cameraPNG.toString('base64')}" style="position:absolute;left:458px;top:39px;width:288px;height:115px">`;
  }
  const source = await dataURL(file);
  const image = landscape
    ? `<img src="${source}" style="position:absolute;width:${sh}px;height:${sw}px;transform-origin:0 0;transform:translateX(${sw}px) rotate(90deg)">`
    : `<img src="${source}" style="width:100%;height:100%;display:block">`;
  const html = `<html><head><style>*{box-sizing:border-box}html,body{margin:0;background:transparent}.device{position:absolute;width:${width}px;height:${height}px}.screen{position:absolute;left:${left}px;top:${top}px;width:${sw}px;height:${sh}px;overflow:hidden;mask-image:url('${mask.url}');mask-size:100% 100%;mask-mode:alpha;background:#000}</style></head><body><div class="device" style="${landscape ? `transform-origin:0 0;transform:translateY(${width}px) rotate(-90deg)` : ''}">${pieces.join('')}<div class="screen">${image}${sensor}</div></div></body></html>`;
  const outWidth = landscape ? height : width, outHeight = landscape ? width : height;
  const page = await browser.newPage({ viewport: { width: outWidth, height: outHeight }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.screenshot({ path: out, omitBackground: true });
  await page.close();
  const result = { url: await dataURL(out), width: outWidth, height: outHeight, provenance: { kind: 'Native app capture in installed Apple Simulator chrome', sourceFile: path.relative(root, file), sourceSHA256: await sha256(file), state, orientation: landscape ? 'landscape' : 'portrait' } };
  frameCache.set(key, result);
  return result;
}

// The captured keyboard, cropped above the home-indicator margin so the
// content behind the system material (the tab bar) is not shown.
const keyboardTrim = { 'iphone-medium': 118, 'ipad-11': 18, 'duo-closed': 120 };
async function keyboardCard(sourceFamily, state) {
  const entry = raw.families[sourceFamily]?.[state];
  if (!entry?.keyboard) throw new Error(`Missing keyboard crop for ${sourceFamily}/${state}`);
  const file = path.resolve(outputRoot, 'raw', entry.file);
  const k = entry.keyboard;
  const crop = { left: k.x, top: k.y, width: k.width, height: k.height - keyboardTrim[sourceFamily] };
  const buffer = await sharp(file).extract(crop).png().toBuffer();
  return { url: `data:image/png;base64,${buffer.toString('base64')}`, width: crop.width, height: crop.height, provenance: { kind: 'Genuine captured keyboard crop', sourceFile: path.relative(root, file), sourceSHA256: await sha256(file), crop } };
}

// Actual Device Hub chassis captures for Duo poses the simulator cannot
// reach from a test (open and tabletop). Only the white window matte outside
// the chassis is removed; the UI inside is the 1.1.0 capture.
async function hubDevice(name, crop, pose) {
  const file = path.join(outputRoot, 'framed-captures', name);
  const cut = await deviceCutout(sharp, file, crop);
  return { url: `data:image/png;base64,${cut.buffer.toString('base64')}`, width: crop.width, height: crop.height, provenance: { kind: 'Actual Device Hub window capture (TabForge 1.1.0 UI)', sourceFile: path.relative(root, file), sourceSHA256: await sha256(file), crop, pose } };
}
const hub = {
  open: () => hubDevice('duo-open-light-clean-window.png', { x: 88, y: 226, width: 1900, height: 1365 }, 'Open'),
  tabletop: () => hubDevice('duo-tabletop-light-clean-window.png', { x: 478, y: 184, width: 1112, height: 1458 }, 'Tabletop'),
};

// A new closed-Duo capture placed in the actual closed Device Hub chassis.
// The display outline is measured row by row from the native frame (dark
// bezel to lit display); the real camera pixels are kept on top.
async function closedDuoDevice(state) {
  const key = 'duo-closed/' + state;
  if (frameCache.has(key)) return frameCache.get(key);
  const entry = raw.families['duo-closed']?.[state];
  if (!entry) throw new Error(`Missing native ${key}`);
  const capture = path.resolve(outputRoot, 'raw', entry.file);
  const chassisFile = path.join(outputRoot, 'framed-captures/duo-closed-light-clean-window.png');
  const crop = { x: 546, y: 224, width: 990, height: 1368 };
  const cut = await deviceCutout(sharp, chassisFile, crop);
  const { data: chassis, info } = await sharp(cut.buffer).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const W = info.width, H = info.height;
  const shade = (x, y) => { const i = (y * W + x) * 4; return Math.min(chassis[i], chassis[i + 1], chassis[i + 2]); };
  const rows = [];
  for (let y = 0; y < H; y++) {
    let left = -1, right = -1, hit = false;
    for (let x = 0; x < W / 2; x++) { const v = shade(x, y); if (v < 100) hit = true; if (hit && v > 180) { left = x; break; } }
    hit = false;
    for (let x = W - 1; x > W / 2; x--) { const v = shade(x, y); if (v < 100) hit = true; if (hit && v > 180) { right = x; break; } }
    if (left >= 0 && right - left > W * 0.6) rows.push({ y, left, right });
  }
  if (rows.length < H * 0.8) throw new Error('Closed Duo display outline not found');
  const top = rows[0].y, bottom = rows.at(-1).y;
  // Straight edges from the middle rows; a stray bright pixel beside the
  // chassis must not widen the display.
  const middle = rows.slice(Math.floor(rows.length * 0.2), Math.ceil(rows.length * 0.8));
  const median = values => values.sort((a, b) => a - b)[Math.floor(values.length / 2)];
  const minX = median(middle.map(r => r.left)), maxX = median(middle.map(r => r.right));
  for (const r of rows) { r.left = Math.max(r.left, minX); r.right = Math.min(r.right, maxX); }
  const dw = maxX - minX + 1, dh = bottom - top + 1;
  if (Math.abs(dw / dh - entry.sourcePixels.width / entry.sourcePixels.height) > 0.03) throw new Error(`Closed Duo display ${dw}x${dh} does not match the capture aspect ratio`);
  const screen = await sharp(capture).resize(dw, dh, { fit: 'fill' }).ensureAlpha().raw().toBuffer();
  const out = Buffer.from(chassis);
  for (const r of rows) {
    for (let x = r.left; x <= r.right; x++) {
      const o = (r.y * W + x) * 4, s = ((r.y - top) * dw + (x - minX)) * 4;
      // Keep the real camera: dark chassis pixels in the top-right corner.
      const camera = r.y - top < dh * 0.12 && x - minX > dw * 0.75 && shade(x, r.y) < 70;
      if (camera) continue;
      out[o] = screen[s]; out[o + 1] = screen[s + 1]; out[o + 2] = screen[s + 2]; out[o + 3] = 255;
    }
  }
  const png = await sharp(out, { raw: { width: W, height: H, channels: 4 } }).png().toBuffer();
  await fs.writeFile(path.join(work, `duo-closed-${state}-store-framed.png`), png);
  const result = { url: `data:image/png;base64,${png.toString('base64')}`, width: W, height: H, provenance: { kind: 'Native closed-Duo capture in the actual closed Device Hub chassis', sourceFile: path.relative(root, capture), sourceSHA256: await sha256(capture), chassis: path.relative(root, chassisFile), display: { x: minX, y: top, width: dw, height: dh }, pixelChanges: 'Proportional resize into the measured display outline; camera pixels kept from the chassis' } };
  frameCache.set(key, result);
  return result;
}

const families = [
  { id: 'iphone-medium', slot: 'APP_IPHONE_61', width: 1206, height: 2622, kind: 'phone', source: 'iphone-medium' },
  { id: 'iphone-large', slot: 'APP_IPHONE_69', width: 1320, height: 2868, kind: 'phone', source: 'iphone-medium' },
  { id: 'ipad-11', slot: 'APP_IPAD_PRO_3GEN_11', width: 1668, height: 2420, kind: 'tablet', source: 'ipad-11' },
  { id: 'ipad-13', slot: 'APP_IPAD_PRO_3GEN_129', width: 2064, height: 2752, kind: 'tablet', source: 'ipad-11' },
  // One shared Duo slot: files are numbered in upload order across the poses.
  { id: 'duo-closed', slot: 'APP_IPHONE_DUO', width: 1398, height: 2034, kind: 'duo', source: 'duo-closed', slides: [
    { id: 1, file: '01', title: 'A keyboard for\nwriting code', sub: 'Braces, brackets and Tab sit right beside the letters.', visual: 'closed', state: 'standard' },
    { id: 4, file: '04', title: 'Keep terminal\ncontrols close', sub: 'Escape, Control and the arrow keys sit above the letters.', visual: 'closed', state: 'terminal' },
    { id: 5, file: '05', title: 'At home in\nlight and dark', sub: 'The iOS theme uses the system keyboard’s glass. Or pick a code theme.', visual: 'cards', states: ['standard', 'dark'] },
    { id: 6, file: '06', title: 'Open source\nand private', sub: 'MIT licensed. No Full Access. No data collected.', visual: 'closed', state: 'settings' },
  ] },
  { id: 'duo-open', slot: 'APP_IPHONE_DUO', width: 2853, height: 2007, kind: 'duo-wide', slides: [
    { id: 2, file: '02', title: 'Open it up for more keys', sub: 'Unfold the Duo for a wider layout with more controls.', visual: 'hub', pose: 'open' },
  ] },
  { id: 'duo-tabletop', slot: 'APP_IPHONE_DUO', width: 1398, height: 2034, kind: 'duo', slides: [
    { id: 3, file: '03', title: 'A keyboard on\nthe lower display', sub: 'The keyboard adapts when you fold the Duo into tabletop.', visual: 'hub', pose: 'tabletop' },
  ] },
];
const slides = [
  { id: 1, title: 'A keyboard for\nwriting code', sub: 'Braces, brackets and Tab sit right beside the letters.', visual: 'device', state: 'standard' },
  { id: 2, title: 'Keep terminal\ncontrols close', sub: 'Escape, Control and the arrow keys sit above the letters.', visual: 'device', state: 'terminal' },
  { id: 3, title: 'At home in\nlight and dark', sub: 'The iOS theme uses the system keyboard’s glass. Or pick a code theme.', visual: 'cards', states: ['standard', 'dark'] },
  { id: 4, title: 'Indent without\nleaving the keys', sub: 'Indent or outdent a line, right from the keyboard.', visual: 'device', state: 'dark' },
  { id: 5, title: 'Make room\nfor your work', sub: { phone: 'In landscape, a compact layout keeps more of your app in view.', tablet: 'A compact layout keeps more of your document in view.' }, visual: 'device', state: 'compact' },
  { id: 6, title: 'Open source\nand private', sub: 'MIT licensed. No Full Access. No data collected.', visual: 'device', state: 'settings' },
];

const css = `
*{box-sizing:border-box;margin:0}
html,body{background:#F2F2F4}
body{-webkit-font-smoothing:antialiased;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Helvetica Neue',sans-serif}
main{position:relative;width:var(--w);height:var(--h);overflow:hidden;display:flex;flex-direction:column;align-items:center;padding:var(--top) var(--side) var(--bottom)}
header{text-align:center;flex:none}
h1{font-size:var(--h1);font-weight:700;line-height:1.06;letter-spacing:-0.025em;color:#1D1D1F;text-wrap:balance}
p{font-size:var(--sub);font-weight:500;line-height:1.3;letter-spacing:-0.01em;color:#6E6E73;margin-top:var(--gap);max-width:var(--measure);margin-left:auto;margin-right:auto;text-wrap:balance}
.visual{flex:1;min-height:0;width:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:var(--card-gap);margin-top:var(--visual-gap)}
.wide .visual{width:calc(100% + var(--side) * 1.4)}
.device{display:block;max-width:100%;max-height:100%;width:auto;height:auto;filter:drop-shadow(0 calc(var(--s)*18px) calc(var(--s)*36px) rgba(0,0,0,.14))}
.card{display:block;width:100%;height:auto;max-height:calc((100% - var(--card-gap)) / 2);object-fit:contain;border-radius:calc(var(--s)*34px);box-shadow:0 calc(var(--s)*14px) calc(var(--s)*40px) rgba(0,0,0,.14),0 0 0 1px rgba(0,0,0,.06)}
`;

const familyFilter = argument('--family', 'all').split(',');
const slideFilter = argument('--slide', 'all').split(',');
const preview = process.argv.includes('--preview');
const receipts = [];
try {
  for (const family of families.filter(f => familyFilter.includes('all') || familyFilter.includes(f.id))) {
    const s = Math.min(family.width, family.height) / 1000;
    // Layout tokens in thousandths of the canvas's shorter side.
    const tokens = {
      phone: { top: 150, side: 70, bottom: 90, h1: 100, sub: 42, gap: 26, measure: 840, visualGap: 90, cardGap: 60 },
      tablet: { top: 100, side: 90, bottom: 50, h1: 70, sub: 31, gap: 20, measure: 760, visualGap: 50, cardGap: 50 },
      duo: { top: 110, side: 80, bottom: 70, h1: 84, sub: 36, gap: 22, measure: 820, visualGap: 70, cardGap: 50 },
      'duo-wide': { top: 90, side: 120, bottom: 60, h1: 72, sub: 30, gap: 18, measure: 1300, visualGap: 50, cardGap: 50 },
    }[family.kind];
    const vars = {
      '--w': family.width + 'px', '--h': family.height + 'px', '--s': s,
      '--top': tokens.top * s + 'px', '--side': tokens.side * s + 'px', '--bottom': tokens.bottom * s + 'px',
      '--h1': tokens.h1 * s + 'px', '--sub': tokens.sub * s + 'px', '--gap': tokens.gap * s + 'px',
      '--measure': tokens.measure * s + 'px', '--visual-gap': tokens.visualGap * s + 'px', '--card-gap': tokens.cardGap * s + 'px',
    };
    for (const slide of (family.slides || slides).filter(x => slideFilter.includes('all') || slideFilter.includes(String(x.id)))) {
      let content;
      if (slide.visual === 'cards') {
        const cards = await Promise.all(slide.states.map(state => keyboardCard(family.source, state)));
        content = cards.map(c => `<img class="card" src="${c.url}" data-source="${esc(JSON.stringify(c.provenance))}">`).join('');
      } else {
        const d = slide.visual === 'hub' ? await hub[slide.pose]() : slide.visual === 'closed' ? await closedDuoDevice(slide.state) : await framed(family.source, slide.state);
        content = `<img class="device" src="${d.url}" width="${d.width}" height="${d.height}" data-source="${esc(JSON.stringify(d.provenance))}">`;
      }
      const sub = typeof slide.sub === 'string' ? slide.sub : slide.sub[family.kind];
      const style = Object.entries(vars).map(([k, v]) => `${k}:${v}`).join(';');
      const html = `<html><head><meta charset="utf-8"><style>${css}</style></head><body><main class="${slide.state === 'compact' ? 'wide' : ''}" style="${style}"><header><h1>${esc(slide.title).replaceAll('\n', '<br>')}</h1><p>${esc(sub)}</p></header><section class="visual">${content}</section></main></body></html>`;
      const dir = path.join(outputRoot, preview ? 'previews/store/' + family.id : 'store/en-US/' + family.slot);
      await fs.mkdir(dir, { recursive: true });
      const out = path.join(dir, `${slide.file || String(slide.id).padStart(2, '0')}.png`);
      const page = await browser.newPage({ viewport: { width: family.width, height: family.height }, deviceScaleFactor: 1 });
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      const issues = await page.evaluate(() => {
        const found = [];
        const lines = [...document.querySelectorAll('h1')].map(h => Math.round(h.getBoundingClientRect().height / parseFloat(getComputedStyle(h).lineHeight)));
        if (lines.some(n => n > 2)) found.push('headline wraps past two lines');
        for (const e of document.querySelectorAll('header,.device,.card')) {
          const r = e.getBoundingClientRect();
          if (r.x < -0.5 || r.y < -0.5 || r.right > innerWidth + 0.5 || r.bottom > innerHeight + 0.5) found.push(e.className + ' outside canvas');
        }
        return found;
      });
      if (issues.length) throw new Error(`${family.id}/${slide.id}: ${issues.join(', ')}`);
      await page.screenshot({ path: out, type: 'png', omitBackground: false });
      const sources = await page.evaluate(() => [...document.querySelectorAll('[data-source]')].map(e => JSON.parse(e.dataset.source)));
      await page.close();
      receipts.push({ family: family.id, slot: family.slot, slide: slide.id, title: slide.title.replace('\n', ' '), file: path.relative(root, out), width: family.width, height: family.height, sha256: await sha256(out), sources });
      console.log(`Rendered ${family.id}/${path.basename(out)}`);
    }
  }
} finally {
  await browser.close();
}
const receiptFile = path.join(outputRoot, preview ? 'previews/store-render-receipt.json' : 'store/render-receipt.json');
let previous = [];
try { previous = JSON.parse(await fs.readFile(receiptFile, 'utf8')).receipts || []; } catch (e) { if (e.code !== 'ENOENT') throw e; }
await fs.writeFile(receiptFile, JSON.stringify({ generatedAt: new Date().toISOString(), renderer: 'release-prep/design/render-store-screenshots.mjs', receipts: [...new Map([...previous, ...receipts].map(r => [`${r.family}/${r.slide}`, r])).values()] }, null, 2) + '\n');
