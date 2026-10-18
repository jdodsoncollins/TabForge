#!/usr/bin/env node
/** Deterministic layout only: the browser crops genuine captures; it never redraws the app. */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const root = process.cwd();
const args = new Set(process.argv.slice(2));
const argument = (flag, fallback) => {
  const index = process.argv.indexOf(flag);
  return index < 0 ? fallback : process.argv[index + 1];
};
const runtimeModules = process.env.TABFORGE_NODE_MODULES || path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require = createRequire(import.meta.url);
try { require.resolve('playwright'); require.resolve('sharp'); }
catch { require = createRequire(path.join(runtimeModules, '_tabforge-renderer.cjs')); }
if (process.env.TABFORGE_NODE_MODULES) require = createRequire(path.join(runtimeModules, '_tabforge-renderer.cjs'));
const { chromium } = require('playwright');
const sharp = require('sharp');
const outputRoot = path.resolve(argument('--output-root', 'artifacts/app-store-release-2026-10-18'));
const manifestPath = path.resolve(argument('--manifest', path.join(outputRoot, 'raw/manifest.json')));
const preview = args.has('--preview');
const placeholders = args.has('--placeholders');
if (placeholders && !preview) throw new Error('Placeholders are allowed only with --preview.');
const familyFilter = argument('--family', 'all');
const slideFilter = argument('--slide', 'all');
const families = [
  { id: 'iphone-medium', slot: 'APP_IPHONE_61', width: 1206, height: 2622, label: 'iPhone', kind: 'phone' },
  { id: 'iphone-large', slot: 'APP_IPHONE_69', width: 1320, height: 2868, label: 'iPhone', kind: 'phone' },
  { id: 'ipad-13', slot: 'APP_IPAD_PRO_3GEN_129', width: 2064, height: 2752, label: 'iPad', kind: 'wide' },
  { id: 'ipad-11', slot: 'APP_IPAD_PRO_3GEN_11', width: 1668, height: 2420, label: 'iPad', kind: 'wide' },
  { id: 'duo-closed', slot: 'APP_IPHONE_DUO', width: 1398, height: 2034, label: 'Duo closed', kind: 'short' },
  { id: 'duo-open', slot: 'APP_IPHONE_DUO', width: 2853, height: 2007, label: 'Duo open', kind: 'wide' },
];
const slides = [
  { id: 1, title: 'A keyboard for\nwriting code', caption: 'Keep braces, brackets and Tab within reach.', className: 'hero', label: 'Programming keyboard' },
  { id: 2, title: 'Indent without\nleaving the keys', caption: 'Indent or outdent a line and keep your place.', className: 'indent', label: 'Editing' },
  { id: 3, title: 'Keep terminal\ncontrols close', caption: 'Use Escape, arrows and modifiers from the keyboard.', className: 'escape dark', label: 'Navigation' },
  { id: 4, title: 'Choose your\nkeyboard theme', caption: 'Follow the iOS appearance or choose a code palette.', className: 'palette', label: 'Appearance' },
  { id: 5, title: 'Make room\nfor your work', caption: 'A compact landscape layout leaves more space for your app.', className: 'adaptive', label: 'Adaptive layout' },
  { id: 6, title: 'See how your\nkeyboard works', caption: 'Read the MIT licensed source, privacy policy and security guidance.', className: 'source dark', label: 'Open source' },
];
let manifest;
try { manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8')); }
catch (error) { if (!placeholders) throw error; manifest = { families: {} }; }
for (const family of families) {
  const slot = manifest.slots?.[family.id];
  if (slot) {
    if (!/^[A-Z0-9_]+$/.test(slot)) throw new Error(`Invalid screenshot slot: ${slot}`);
    family.slot = slot;
  }
}
const sourceCache = new Map();
const escape = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

async function source(family, name) {
  const entry = manifest.families?.[family.id]?.[name];
  if (!entry) {
    if (placeholders) return null;
    throw new Error(`Missing actual capture: ${family.id}/${name}`);
  }
  const asset = typeof entry === 'string' ? { file: entry } : entry;
  const file = path.resolve(path.dirname(manifestPath), asset.file);
  const allowed = path.resolve(outputRoot, 'raw') + path.sep;
  if (!file.startsWith(allowed)) throw new Error(`Capture must be within raw/: ${file}`);
  if (!sourceCache.has(file)) {
    const data = await fs.readFile(file);
    const metadata = await sharp(data).metadata();
    if (!metadata.width || !metadata.height) throw new Error(`Not an image: ${file}`);
    sourceCache.set(file, { file, width: metadata.width, height: metadata.height, dataURL: `data:image/${metadata.format === 'jpg' ? 'jpeg' : metadata.format};base64,${data.toString('base64')}` });
  }
  return { ...sourceCache.get(file), ...asset };
}

function crop(asset, kind, extraClass = '', label = '') {
  if (!asset) return `<div class="capture pending ${extraClass}"><span>Capture pending<br><small>Internal layout preview — no app UI represented</small></span></div>`;
  let rectangle = asset[kind];
  if (kind === 'working' && !rectangle && asset.keyboard) {
    const keyboard = asset.keyboard;
    const above = Math.min(keyboard.y, keyboard.height * .34);
    rectangle = { x: keyboard.x, y: keyboard.y - above, width: keyboard.width, height: keyboard.height + above };
  }
  if (!rectangle) throw new Error(`Missing ${kind} crop for ${asset.file}`);
  const { x, y, width, height } = rectangle;
  if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0 || x < 0 || y < 0 || x + width > asset.width + .1 || y + height > asset.height + .1) throw new Error(`Invalid ${kind} crop for ${asset.file}`);
  return `<div class="capture ${extraClass}" data-capture="${escape(path.relative(root, asset.file))}" data-crop="${escape(JSON.stringify(rectangle))}" style="aspect-ratio:${width}/${height}"><img alt="${escape(label)}" src="${asset.dataURL}" style="width:${asset.width / width * 100}%;left:${-x / width * 100}%;top:${-y / height * 100}%"></div>`;
}

async function compose(family, slide) {
  let title = slide.title;
  let caption = slide.caption;
  if (family.id === 'duo-open' && slide.id === 3) caption = 'Use Escape, arrows and modifiers. Terminal shortcuts depend on the client forwarding them.';
  if (slide.id === 5 && family.kind === 'wide') {
    title = 'Use the space\nyou have';
    caption = family.id === 'duo-open' ? 'The open display makes room for more code keys.' : 'A larger layout makes room for numbers, symbols and editing keys.';
  }
  const get = name => source(family, name);
  const workingCrop = family.id.startsWith('duo-') ? 'keyboard' : 'working';
  let content;
  if ([1, 2, 3].includes(slide.id)) {
    const capture = await get(slide.id === 3 ? 'terminal' : 'standard');
    content = `${family.kind === 'wide' && family.id !== 'duo-open' && capture?.code ? `<div class="code-detail">${crop(capture, 'code', '', 'Native playground code detail')}</div>` : ''}<div class="primary">${crop(capture, workingCrop, '', 'Real TabForge keyboard and playground')}<p class="capture-label">${slide.id === 3 ? 'Terminal profile in the playground' : 'TabForge playground'} · ${escape(family.label)}</p></div>`;
    if (slide.id === 2 && family.id !== 'duo-open') content += '<p class="note">Indent and outdent are one tap away.</p>';
    if (slide.id === 3 && family.id !== 'duo-open') content += '<p class="note">Terminal shortcuts depend on the client forwarding them.</p>';
  } else if (slide.id === 4) {
    const themeCaptures = await Promise.all(['standard', 'dark', 'darcula'].map(get));
    const labels = ['iOS Standard · Light', 'iOS Standard · Dark', 'Darcula'];
    content = '<div class="theme-grid">' + themeCaptures.map((asset, index) => `<figure class="theme theme-${index}"><figcaption>${labels[index]}</figcaption>${crop(asset, 'keyboard', '', labels[index])}</figure>`).join('') + '</div>';
  } else if (slide.id === 5) {
    if (family.kind === 'wide') {
      content = `<div class="primary">${crop(await get('standard'), workingCrop, '', 'Expanded TabForge keyboard')}<p class="capture-label">Expanded keyboard · ${escape(family.label)}</p></div>`;
    } else {
      const compact = await get('compact');
      const landscape = compact?.provenance?.windowOrientation === 'landscape';
      if (compact && !landscape) caption = family.id === 'duo-closed' ? 'Choose a compact height when your app needs more room.' : 'A compact layout leaves more space for your app.';
      const standardLabel = family.id === 'duo-closed' && !landscape ? 'Standard height' : 'Portrait';
      content = `<div class="adaptive-stack"><figure class="landscape"><figcaption>${landscape ? 'Compact landscape' : 'Compact height'}</figcaption>${crop(compact, 'keyboard', '', 'Actual compact keyboard')}</figure><figure class="portrait-detail"><figcaption>${standardLabel}</figcaption>${crop(await get('standard'), 'keyboard', '', 'Actual portrait keyboard')}</figure></div>`;
    }
  } else {
    content = `<div class="settings-detail">${crop(await get('settings'), 'detail', '', 'App Settings source, privacy and security links')}</div><p class="repo">github.com/jdodsoncollins/TabForge</p><p class="source-footnote">The keyboard has no analytics or typed-text logging.<br>Preferences, snippets and the playground draft stay on device.</p>`;
  }
  const geometry = family.height / family.width;
  return `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body><main class="page ${slide.className} ${family.kind} ${family.id} ${geometry < 1.6 ? 'short-canvas' : ''}" style="--scale:${family.width / 1000};--page-height:${family.height}px"><div class="brand">TabForge <span>/</span> ${escape(slide.label)}</div><header><h1>${escape(title).replaceAll('\n', '<br>')}</h1><p class="caption">${escape(caption)}</p></header><section class="visual">${content}</section><div class="bottom-mark">TabForge · Code Keyboard</div>${placeholders ? '<div class="preview-watermark">INTERNAL LAYOUT PREVIEW</div>' : ''}</main></body></html>`;
}

const css = `
*{box-sizing:border-box}html,body{margin:0;padding:0;background:#F2F0E9}body{-webkit-font-smoothing:antialiased}.page{width:100vw;height:var(--page-height);overflow:hidden;position:relative;background:#F2F0E9;color:#20261F;padding:calc(65px * var(--scale)) calc(65px * var(--scale));font-family:Menlo,monospace}.dark{background:#21251F;color:#F2F0E9}.brand{font-size:calc(20px * var(--scale));line-height:1.4;letter-spacing:-.025em;white-space:nowrap}.brand span{color:#78806C;margin:0 .5em}header{position:relative;z-index:2;margin-top:calc(62px * var(--scale));max-width:100%}h1{font-family:'Iowan Old Style','New York',Georgia,serif;font-weight:400;font-size:calc(104px * var(--scale));letter-spacing:-.047em;line-height:1.015;margin:0}.caption{font-size:calc(26px * var(--scale));line-height:1.45;letter-spacing:-.035em;max-width:calc(760px * var(--scale));margin:calc(30px * var(--scale)) 0 0;color:#555D50}.dark .caption{color:#D4D8CC}.visual{position:absolute;left:calc(65px * var(--scale));right:calc(65px * var(--scale));top:calc(605px * var(--scale));bottom:calc(110px * var(--scale));display:flex;flex-direction:column;justify-content:center;align-items:stretch;gap:calc(25px * var(--scale))}.primary{width:100%;position:relative}.capture{position:relative;overflow:hidden;isolation:isolate;background:#E2E5DC;width:100%;border:1px solid rgba(35,44,31,.15)}.capture img{position:absolute;max-width:none;height:auto;display:block}.capture-label,figcaption{font-size:calc(19px * var(--scale));line-height:1.4;letter-spacing:-.025em;color:#555D50;margin:calc(15px * var(--scale)) 0 0}.dark .capture-label,.dark figcaption{color:#C5CCBA}.capture-label{border-top:1px solid #C5C9BC;padding-top:calc(16px * var(--scale))}.dark .capture-label{border-color:#56604A}.note{margin:0;font-size:calc(24px * var(--scale));line-height:1.5;letter-spacing:-.035em;max-width:calc(780px * var(--scale))}.escape h1{max-width:calc(650px * var(--scale))}.escape .visual{top:calc(430px * var(--scale))}.escape .note{background:#D4E9A5;color:#20261F;padding:calc(23px * var(--scale)) calc(25px * var(--scale));align-self:flex-start}.palette header,.adaptive header,.source header{margin-top:calc(62px * var(--scale))}.palette h1,.adaptive h1,.source h1{font-size:calc(93px * var(--scale))}.palette .visual,.adaptive .visual{top:calc(465px * var(--scale))}.theme-grid{width:100%;display:flex;flex-direction:column;gap:calc(38px * var(--scale));align-items:flex-start;justify-content:center}.theme{margin:0;width:76%}.theme-1{align-self:flex-end}.theme figcaption{margin:0 0 calc(10px * var(--scale))}.adaptive-stack{display:flex;flex-direction:column;gap:calc(55px * var(--scale))}.adaptive-stack figure{margin:0}.adaptive-stack figcaption{margin:0 0 calc(16px * var(--scale))}.portrait-detail{width:78%;align-self:flex-end}.source .visual{top:calc(435px * var(--scale));gap:calc(35px * var(--scale));justify-content:center}.settings-detail{width:92%;align-self:flex-end}.repo{font-size:calc(24px * var(--scale));letter-spacing:-.04em;line-height:1.5;margin:0;color:#D4E9A5;overflow-wrap:anywhere}.source-footnote{margin:0;font-size:calc(22px * var(--scale));letter-spacing:-.035em;line-height:1.6;color:#CBD2C2}.bottom-mark{position:absolute;left:calc(65px * var(--scale));bottom:calc(38px * var(--scale));font-size:calc(17px * var(--scale));color:#737A68;letter-spacing:-.02em}.dark .bottom-mark{color:#A3AE96}.pending{min-height:calc(390px * var(--scale));display:flex;justify-content:center;align-items:center;background:#E0E3D8;color:#4E5B45;outline:2px dashed #88947B;outline-offset:-15px;text-align:center;font-size:calc(25px * var(--scale));line-height:1.7}.pending small{font-size:calc(16px * var(--scale))}.preview-watermark{position:absolute;right:calc(24px * var(--scale));top:calc(24px * var(--scale));font-size:calc(13px * var(--scale));font-family:Menlo,monospace;color:#9D4139;letter-spacing:.04em;background:#FFF8E9;padding:calc(7px * var(--scale));z-index:10}
.short-canvas{padding-top:calc(42px * var(--scale))}.short-canvas header{margin-top:calc(32px * var(--scale));max-width:92%}.short-canvas h1{font-size:calc(79px * var(--scale));line-height:1}.short-canvas .caption{font-size:calc(23px * var(--scale));margin-top:calc(20px * var(--scale))}.short-canvas .visual{top:calc(405px * var(--scale));bottom:calc(93px * var(--scale));gap:calc(18px * var(--scale))}.short-canvas.hero .visual,.short-canvas.indent .visual{top:calc(460px * var(--scale))}.short-canvas.escape .visual{top:calc(325px * var(--scale))}.short-canvas .note{font-size:calc(20px * var(--scale))}.short-canvas.palette .visual{top:calc(375px * var(--scale))}.short-canvas .theme-grid{display:grid;grid-template-columns:1fr 1fr;gap:calc(28px * var(--scale));align-items:start}.short-canvas .theme{width:100%;align-self:start}.short-canvas .theme-2{grid-column:1/3;width:76%;justify-self:center}.short-canvas .theme figcaption{font-size:calc(17px * var(--scale))}.short-canvas.adaptive .visual{top:calc(375px * var(--scale))}.short-canvas .adaptive-stack{gap:calc(30px * var(--scale))}.short-canvas .portrait-detail{width:62%}.short-canvas.source .visual{top:calc(340px * var(--scale));gap:calc(22px * var(--scale))}.short-canvas .settings-detail{width:80%}.short-canvas .source-footnote{font-size:calc(18px * var(--scale))}.short-canvas .repo{font-size:calc(21px * var(--scale))}
.phone.hero .visual,.phone.indent .visual{top:calc(500px * var(--scale))}.phone.escape .visual{top:calc(535px * var(--scale))}.phone.escape .primary{width:92%;align-self:flex-end}.phone.source .visual{top:calc(540px * var(--scale))}
.code-detail{width:82%;align-self:flex-start}.wide.escape .visual{top:calc(400px * var(--scale))}.wide.source .visual{top:calc(425px * var(--scale))}
.capture img{image-orientation:none}.phone.palette .visual{top:calc(550px * var(--scale))}.phone .theme{width:64%}.phone .theme-grid{gap:calc(26px * var(--scale))}
.duo-open{padding:calc(28px * var(--scale)) calc(50px * var(--scale))}.duo-open .brand{font-size:calc(17px * var(--scale));line-height:1.3}.duo-open header{margin-top:calc(23px * var(--scale));max-width:100%;display:grid;grid-template-columns:1.1fr 1fr;gap:calc(50px * var(--scale));align-items:start}.duo-open h1{font-size:calc(64px * var(--scale));max-width:none;line-height:1.025}.duo-open .caption{font-size:calc(21px * var(--scale));line-height:1.5;margin:calc(7px * var(--scale)) 0 0;max-width:none}.page.duo-open .visual{top:calc(260px * var(--scale));bottom:calc(60px * var(--scale));left:calc(50px * var(--scale));right:calc(50px * var(--scale));gap:calc(18px * var(--scale))}.duo-open .primary{width:100%;align-self:stretch}.duo-open .capture-label{font-size:calc(16px * var(--scale));margin-top:calc(10px * var(--scale));padding-top:calc(10px * var(--scale))}.duo-open .bottom-mark{left:calc(50px * var(--scale));bottom:calc(22px * var(--scale));font-size:calc(14px * var(--scale))}.duo-open.palette .visual{top:calc(235px * var(--scale))}.duo-open .theme-grid{gap:calc(22px * var(--scale))}.duo-open .theme-2{width:60%}.duo-open .theme figcaption{font-size:calc(16px * var(--scale))}.duo-open.source .visual{top:calc(250px * var(--scale));gap:calc(18px * var(--scale))}.duo-open .settings-detail{width:90%}.duo-open .repo{font-size:calc(19px * var(--scale))}.duo-open .source-footnote{font-size:calc(17px * var(--scale));line-height:1.5}
`;

const selectedFamilies = families.filter(f => familyFilter === 'all' || familyFilter.split(',').includes(f.id));
const selectedSlides = slides.filter(s => slideFilter === 'all' || slideFilter.split(',').includes(String(s.id)));
if (!selectedFamilies.length || !selectedSlides.length) throw new Error('No matching family or slide.');
const executablePath = argument('--chromium', process.env.TABFORGE_CHROMIUM);
const browser = await chromium.launch({ headless: true, ...(executablePath ? { executablePath } : {}) });
const receipts = [];
try {
  for (const family of selectedFamilies) {
    const page = await browser.newPage({ viewport: { width: family.width, height: family.height }, deviceScaleFactor: 1 });
    for (const slide of selectedSlides) {
      const html = await compose(family, slide);
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      const issues = await page.evaluate(() => {
        const headerBottom = document.querySelector('header').getBoundingClientRect().bottom;
        const footerTop = document.querySelector('.bottom-mark').getBoundingClientRect().top;
        return [...document.querySelectorAll('header,.capture,.note,.repo,.source-footnote,.capture-label,figcaption')].flatMap(element => {
          const box = element.getBoundingClientRect();
          const name = element.className || element.tagName;
          const found = [];
          if (box.left < -1 || box.top < -1 || box.right > innerWidth + 1 || box.bottom > innerHeight + 1) found.push(`${name} outside image`);
          if (element.tagName !== 'HEADER' && box.top < headerBottom + 10) found.push(`${name} overlaps headline or caption`);
          if (box.bottom > footerTop - 10) found.push(`${name} overlaps footer`);
          return found;
        });
      });
      if (issues.length && !placeholders) throw new Error(`${family.id} ${slide.id}: ${issues.join(', ')}`);
      // Closed and open Duo share one ASC slot. Keep both six-image local sets
      // without collisions; select at most ten combined assets before staging.
      const filename = `${family.id.startsWith('duo-') && !preview ? family.id + '-' : ''}${String(slide.id).padStart(2, '0')}.png`;
      const dir = preview ? path.join(outputRoot, 'previews', family.id) : path.join(outputRoot, 'screenshots', 'en-US', family.slot);
      await fs.mkdir(dir, { recursive: true });
      const output = path.join(dir, filename);
      await page.screenshot({ path: output, type: 'png', omitBackground: false });
      const sourceCrops = await page.evaluate(() => [...document.querySelectorAll('[data-capture]')].map(element => ({ file: element.dataset.capture, crop: JSON.parse(element.dataset.crop) })));
      // The HTML is an editable, self-contained composition proof, not a fake app capture.
      if (preview) await fs.writeFile(path.join(dir, filename.replace('.png', '.html')), html);
      const metadata = await sharp(output).metadata();
      const outputHash = crypto.createHash('sha256').update(await fs.readFile(output)).digest('hex');
      receipts.push({ family: family.id, slot: family.slot, slide: slide.id, file: path.relative(root, output), width: metadata.width, height: metadata.height, hasAlpha: !!metadata.hasAlpha, sha256: outputHash, sourceCrops, preview, placeholders, issues });
      console.log(`${preview ? 'Preview' : 'Rendered'} ${family.id}/${filename} (${metadata.width}×${metadata.height})`);
    }
    await page.close();
  }
} finally { await browser.close(); }
await fs.mkdir(outputRoot, { recursive: true });
const receiptFile = path.join(outputRoot, preview ? 'previews/render-receipt.json' : 'screenshots/render-receipt.json');
let previousReceipts = [];
try { previousReceipts = JSON.parse(await fs.readFile(receiptFile, 'utf8')).receipts || []; } catch (error) { if (error.code !== 'ENOENT') throw error; }
const combinedReceipts = [...new Map([...previousReceipts, ...receipts].map(receipt => [`${receipt.family}/${receipt.slide}`, receipt])).values()];
await fs.writeFile(receiptFile, JSON.stringify({ generatedAt: new Date().toISOString(), manifest: path.relative(root, manifestPath), renderer: 'release-prep/design/render-screenshots.mjs', receipts: combinedReceipts }, null, 2) + '\n');
