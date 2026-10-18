#!/usr/bin/env node
/** Build a local, clickable artwork gallery and a deterministic contact sheet. */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const argument = (flag, fallback) => {
  const index = process.argv.indexOf(flag);
  return index < 0 ? fallback : process.argv[index + 1];
};
const root = path.resolve(argument('--output-root', 'artifacts/app-store-release-2026-10-18'));
const modules = process.env.TABFORGE_NODE_MODULES || path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require = createRequire(import.meta.url);
try { require.resolve('playwright'); require.resolve('sharp'); }
catch { require = createRequire(path.join(modules, '_tabforge-review.cjs')); }
if (process.env.TABFORGE_NODE_MODULES) require = createRequire(path.join(modules, '_tabforge-review.cjs'));
const sharp = require('sharp');
const { chromium } = require('playwright');
const manifest = JSON.parse(await fs.readFile(path.join(root, 'raw/manifest.json'), 'utf8'));
let framedReceipts=[];try{framedReceipts=JSON.parse(await fs.readFile(path.join(root,'screenshots/framed-render-receipt.json'),'utf8')).receipts||[];}catch(error){if(error.code!=='ENOENT')throw error;}
const duoSelection = JSON.parse(await fs.readFile(path.resolve(argument('--duo-selection', 'release-prep/design/duo-selection.json')), 'utf8'));
if (duoSelection.selection.length > duoSelection.maximumCount) throw new Error('Duo upload selection exceeds its screenshot limit.');
const selectedDuo = new Set(duoSelection.selection.map(item => `${item.family}/${item.slide}`));
const definitions = [
  ['iphone-medium', 'iPhone', 'APP_IPHONE_61'],
  ['iphone-large', 'Large iPhone', 'APP_IPHONE_69'],
  ['ipad-11', 'iPad 11-inch', 'APP_IPAD_PRO_3GEN_11'],
  ['ipad-13', 'iPad 13-inch', 'APP_IPAD_PRO_3GEN_129'],
  ['duo-closed', 'Duo closed', 'APP_IPHONE_DUO'],
  ['duo-open', 'Duo open', 'APP_IPHONE_DUO'],
  ['duo-tabletop', 'Duo tabletop', 'APP_IPHONE_DUO'],
];
const headings = ['A keyboard for writing code', 'Indent without leaving the keys', 'Keep terminal controls close', 'Choose your keyboard theme', 'Make room for your work', 'See how your keyboard works'];
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const families = [];
for (const [id, label, defaultSlot] of definitions) {
  const slot = manifest.slots?.[id] || defaultSlot;
  const files = [];
  for (let slide = 1; slide <= 6; slide++) {
    const receipt=framedReceipts.find(item=>item.family===id&&item.slide===slide);if(framedReceipts.length&&!receipt)continue;
    const filename = `${id.startsWith('duo-') ? id + '-' : ''}${String(slide).padStart(2, '0')}.png`;
    const file = path.join(root, 'screenshots/en-US', slot, filename);
    try {
      const data = await fs.readFile(file);
      const metadata = await sharp(data).metadata();
      files.push({ slide, title: receipt?.title || (slide === 5 && (id.startsWith("ipad") || id === "duo-open") ? "Use the space you have" : headings[slide - 1]), file: path.relative(root, file), width: metadata.width, height: metadata.height, sha256: crypto.createHash('sha256').update(data).digest('hex'), ...(receipt?{sources:receipt.sources}:{}), ...(id.startsWith('duo-') ? { selectedForUpload: selectedDuo.has(`${id}/${slide}`) } : {}), dataURL: `data:image/png;base64,${data.toString('base64')}` });
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  if (files.length) families.push({ id, label, slot, files, sourceFamily: manifest.families[id]?.standard?.provenance?.sourceFamily || id });
}
if (!families.length) throw new Error('No final screenshot images exist yet.');
let header = '';
try { await fs.access(path.join(root, 'creative/header-3840x1646.png')); header = 'creative/header-3840x1646.png'; } catch { /* Header is optional while work is in progress. */ }
const card = (item, embedded) => {
  const url = `${escape(item.file)}?v=${item.sha256.slice(0, 12)}`;
  return `<figure><a href="${url}" target="_blank"><img src="${embedded ? item.dataURL : url}" alt="${escape(item.title)}"></a><figcaption>${escape(item.title)}<small>${item.width} × ${item.height} px${typeof item.selectedForUpload === 'boolean' ? `<br>${item.selectedForUpload ? 'Selected for the shared Duo slot' : 'Additional local option'}` : ''}</small></figcaption></figure>`;
};
const section = (family, embedded) => `<section class="family" data-family="${family.id}"><div class="family-heading"><h2>${escape(family.label)}</h2><span>${family.files.length} ${family.files.length === 1 ? 'image' : 'images'}</span></div><p class="provenance">${framedReceipts.length ? 'Genuine native UI with Simulator device frames. Duo fold poses are actual Device Hub captures.' : 'Native app captures with original crop provenance.'}</p><div class="grid">${family.files.map(item => card(item, embedded)).join('')}</div></section>`;
const styles = `*{box-sizing:border-box}html{background:#F2F0E9;color:#20261F}body{margin:0;padding:48px;font-family:Menlo,monospace}header{max-width:1100px;margin-bottom:40px}h1,h2{font-family:'Iowan Old Style',Georgia,serif;font-weight:400;letter-spacing:-.035em}h1{font-size:56px;line-height:1.08;margin:20px 0}h2{font-size:32px;margin:0}p{line-height:1.6;font-size:14px;color:#555D50}.eyebrow{font-size:13px}.header-art{width:100%;max-width:1400px;display:block;margin:32px 0 48px}.filters{display:flex;gap:10px;flex-wrap:wrap;margin:32px 0}button{border:1px solid #BFC7B3;border-radius:0;background:transparent;font:13px Menlo,monospace;color:#20261F;padding:12px 16px;cursor:pointer}button[aria-pressed=true]{background:#D4E9A5;border-color:#536641}.family{margin:48px 0 64px}.family-heading{display:flex;align-items:center;gap:24px}.family-heading span{font-size:12px;color:#6C7463}.provenance{margin:10px 0 22px;font-size:12px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:28px}figure{margin:0}figure img{display:block;width:100%;height:auto;border:1px solid #CCD0C4}figcaption{font-size:13px;line-height:1.5;margin-top:10px}figcaption small{display:block;color:#69725E;font-size:11px}footer{font-size:12px;line-height:1.7;color:#69725E;border-top:1px solid #CCD0C4;padding-top:20px;max-width:1000px}a{color:inherit}.sheet{padding:30px}.sheet header,.sheet .header-art,.sheet .filters,.sheet footer,.sheet .provenance{display:none}.sheet .family{margin:0 0 36px}.sheet .family-heading{margin-bottom:16px}.sheet h2{font-size:30px}.sheet .grid{grid-template-columns:repeat(6,minmax(0,1fr));gap:18px}.sheet figcaption{font-size:12px}.sheet .family-heading span{font-size:12px}@media(max-width:900px){body{padding:24px}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}h1{font-size:42px}}`;
const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>TabForge App Store artwork</title><style>${styles}</style></head><body><header><div class="eyebrow">TabForge App Store preparation</div><h1>A keyboard for writing code</h1><p>Review the listing images at full size. Every keyboard and settings panel in the screenshots is a genuine native capture. The separate header is brand artwork. Screenshot compositions preserve complete keys and device frames. The Duo images include actual closed, open and tabletop poses.</p></header>${header ? `<a href="${header}"><img class="header-art" src="${header}" alt="TabForge product-page header"></a>` : ''}<nav class="filters" aria-label="Choose a device family"><button data-filter="all" aria-pressed="true">All devices</button>${families.map(f => `<button data-filter="${f.id}" aria-pressed="false">${escape(f.label)}</button>`).join('')}</nav>${families.map(f => section(f, false)).join('')}<footer>The source capture manifest records hashes, crop bounds and layout provenance. Export slots can share the same genuine captured device within different-sized marketing canvases. The device frame continues to represent the captured device. Native window chrome outside the chassis is removed with a deterministic exterior mask; app pixels remain intact. Closed, open and tabletop Duo images share one App Store slot; no more than ten combined images may be selected for upload.</footer><script>document.querySelectorAll('[data-filter]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('[data-filter]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelectorAll('[data-family]').forEach(item=>item.hidden=button.dataset.filter!=='all'&&item.dataset.family!==button.dataset.filter)}));</script></body></html>`;
await fs.writeFile(path.join(root, 'index.html'), html);
await fs.writeFile(path.join(root, 'screenshots/asset-manifest.json'), JSON.stringify({ generatedAt: new Date().toISOString(), duoUploadSelection: duoSelection, families: families.map(family => ({ family: family.id, label: family.label, slot: family.slot, sourceFamily: family.sourceFamily, assets: family.files.map(({ dataURL, ...asset }) => asset) })) }, null, 2) + '\n');
const sheetHTML = `<!doctype html><html><head><meta charset="utf-8"><style>${styles}</style></head><body class="sheet">${families.map(f => section(f, true)).join('')}</body></html>`;
const executablePath = argument('--chromium', process.env.TABFORGE_CHROMIUM);
const browser = await chromium.launch({ headless: true, ...(executablePath ? { executablePath } : {}) });
try {
  const page = await browser.newPage({ viewport: { width: 2100, height: 1200 }, deviceScaleFactor: 1 });
  await page.setContent(sheetHTML, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await fs.mkdir(path.join(root, 'previews'), { recursive: true });
  await page.screenshot({ path: path.join(root, 'previews/contact-sheet.png'), fullPage: true, type: 'png', omitBackground: false });
  const phone = families.find(family => family.id === 'iphone-medium');
  if (phone) {
    await page.setViewportSize({ width: 1800, height: 1200 });
    const phoneHTML = `<!doctype html><html><head><meta charset="utf-8"><style>${styles}.phone-sheet .grid{grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}.phone-sheet .family{margin-bottom:0}.phone-sheet figcaption{font-size:14px}.phone-sheet figcaption small{font-size:12px}</style></head><body class="sheet phone-sheet">${section(phone, true)}</body></html>`;
    await page.setContent(phoneHTML, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(root, 'previews/iphone-contact-sheet.png'), fullPage: true, type: 'png', omitBackground: false });
  }
  await browser.close();
} catch (error) { await browser.close(); throw error; }
console.log(`Gallery: ${path.relative(process.cwd(), path.join(root, 'index.html'))}`);
console.log(`Contact sheet: ${path.relative(process.cwd(), path.join(root, 'previews/contact-sheet.png'))}`);
console.log(`iPhone contact sheet: ${path.relative(process.cwd(), path.join(root, 'previews/iphone-contact-sheet.png'))}`);
