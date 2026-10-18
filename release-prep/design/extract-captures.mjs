#!/usr/bin/env node
/** Export native XCTest screenshot attachments without modifying their pixels. */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import os from 'node:os';
import { createRequire } from 'node:module';

const modules = process.env.TABFORGE_NODE_MODULES || path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require = createRequire(import.meta.url);
try { require.resolve('sharp'); }
catch { require = createRequire(path.join(modules, '_tabforge-extractor.cjs')); }
if (process.env.TABFORGE_NODE_MODULES) require = createRequire(path.join(modules, '_tabforge-extractor.cjs'));
const sharp = require('sharp');

const argument = (flag, fallback) => {
  const index = process.argv.indexOf(flag);
  return index < 0 ? fallback : process.argv[index + 1];
};
if (process.argv.includes('--help')) {
  console.log('Usage: node release-prep/design/extract-captures.mjs --attachments <xcresult-export-directory> --family <family-id> [--captures <comma-separated-names>] [--raw-root <directory>] [--source-result <xcresult>] [--crop-overrides <json>] [--reuse-for <comma-separated-family-ids>]');
  process.exit(0);
}
const attachmentsArgument = argument('--attachments');
const family = argument('--family');
const supported = new Set(['iphone-medium', 'iphone-large', 'ipad-13', 'ipad-11', 'duo-closed', 'duo-open']);
if (!attachmentsArgument || !supported.has(family)) throw new Error('Supply --attachments and a supported --family. Use --help for syntax.');
const attachments = path.resolve(attachmentsArgument);
const rawRoot = path.resolve(argument('--raw-root', 'artifacts/app-store-release-2026-10-18/raw'));
const manifestFile = path.join(rawRoot, 'manifest.json');
const sourceResult = argument('--source-result');
const reuseFamilies = (argument('--reuse-for', '')).split(',').filter(Boolean);
if (reuseFamilies.some(id => !supported.has(id) || id === family)) throw new Error('Invalid --reuse-for family.');
const captureNames = ['standard', 'dark', 'darcula', 'terminal', 'settings', 'compact'];
const requestedCaptures = argument('--captures', captureNames.join(',')).split(',').filter(Boolean);
if (!requestedCaptures.length || requestedCaptures.some(name => !captureNames.includes(name))) throw new Error('Invalid --captures name.');
const allFiles = [];
async function walk(directory) {
  for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) await walk(filename);
    else if (entry.isFile()) allFiles.push(filename);
  }
}
await walk(attachments);
const documents = [];
for (const filename of allFiles.filter(file => /\.(json|txt)$/i.test(file))) {
  try {
    const data = await fs.readFile(filename, 'utf8');
    documents.push({ filename, value: JSON.parse(data) });
  } catch { /* Some attachments have text content rather than JSON. */ }
}
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
const recordSources = new Map();
for (const document of documents) {
  const single = document.value?.capture;
  const captures = single?.name ? [single] : Array.isArray(document.value?.captures) ? document.value.captures : [];
  for (const record of captures.filter(record => requestedCaptures.includes(record.name))) {
    const existing = recordSources.get(record.name);
    if (existing && JSON.stringify(canonical(existing.record)) !== JSON.stringify(canonical(record))) throw new Error(`Conflicting geometry for ${record.name}; export only the intended capture run.`);
    if (!existing || single) recordSources.set(record.name, { record, filename: document.filename });
  }
}
if (requestedCaptures.some(name => !recordSources.has(name))) throw new Error('Geometry does not contain the requested capture set.');

const attachmentRecords = [];
function visit(value) {
  if (Array.isArray(value)) value.forEach(visit);
  else if (value && typeof value === 'object') {
    const exported = value.exportedFileName || value.exportedFilename || value.fileName || value.filename;
    if (typeof exported === 'string' && /\.png$/i.test(exported)) attachmentRecords.push({ ...value, exportedFileName: exported });
    Object.values(value).forEach(visit);
  }
}
documents.forEach(document => visit(document.value));
function matchesName(candidate, name) {
  return new RegExp(`^${name}(?:$|[_. /-])`, 'i').test(path.basename(String(candidate)));
}
function locate(name) {
  const candidates = [];
  for (const record of attachmentRecords) {
    const names = [record.name, record.suggestedHumanReadableName, record.suggestedName, record.attachmentName, record.exportedFileName].filter(Boolean);
    if (names.some(candidate => matchesName(candidate, name))) {
      const filename = allFiles.find(file => path.basename(file) === path.basename(record.exportedFileName));
      if (filename) candidates.push({ filename, attachmentRecord: record });
    }
  }
  if (!candidates.length) {
    allFiles.filter(file => /\.png$/i.test(file) && matchesName(file, name)).forEach(filename => candidates.push({ filename, attachmentRecord: null }));
  }
  const unique = [...new Map(candidates.map(candidate => [candidate.filename, candidate])).values()];
  if (unique.length !== 1) throw new Error(`Expected one ${name} screenshot; found ${unique.length}.`);
  return unique[0];
}
function pngSize(data) {
  if (!data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) throw new Error('The capture must be a PNG.');
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}
function rectangle(value, label) {
  if (!value || !['x', 'y', 'width', 'height'].every(key => Number.isFinite(value[key])) || value.width <= 0 || value.height <= 0) throw new Error(`Invalid ${label} geometry.`);
  return value;
}
function convert(pointRectangle, record, pixels) {
  const bounds = rectangle(record.appBounds, 'app bounds');
  const rect = rectangle(pointRectangle, 'capture rectangle');
  const scaleX = pixels.width / bounds.width;
  const scaleY = pixels.height / bounds.height;
  if (Math.abs(scaleX - scaleY) > .015) throw new Error(`Non-proportional screenshot scale for ${record.name}: ${scaleX} versus ${scaleY}.`);
  const left = Math.max(0, Math.floor((rect.x - bounds.x) * scaleX));
  const top = Math.max(0, Math.floor((rect.y - bounds.y) * scaleY));
  const right = Math.min(pixels.width, Math.ceil((rect.x + rect.width - bounds.x) * scaleX));
  const bottom = Math.min(pixels.height, Math.ceil((rect.y + rect.height - bounds.y) * scaleY));
  if (right <= left || bottom <= top) throw new Error(`The ${record.name} crop does not intersect the image.`);
  return { x: left, y: top, width: right - left, height: bottom - top };
}
const cropOverridesFile = argument('--crop-overrides');
const cropOverrides = cropOverridesFile ? JSON.parse(await fs.readFile(path.resolve(cropOverridesFile), 'utf8')) : {};
const overrides = cropOverrides.families?.[family] || cropOverrides[family] || {};
let manifest;
try { manifest = JSON.parse(await fs.readFile(manifestFile, 'utf8')); }
catch (error) { if (error.code !== 'ENOENT') throw error; manifest = { schemaVersion: 1, families: {}, slots: {} }; }
manifest.families ||= {};
manifest.slots ||= {};
manifest.slots['duo-open'] = 'APP_IPHONE_DUO';
manifest.slots['duo-closed'] = 'APP_IPHONE_DUO';
const familyEntries = { ...(manifest.families[family] || {}) };
await fs.mkdir(path.join(rawRoot, family), { recursive: true });
for (const name of requestedCaptures) {
  const located = locate(name);
  const recordSource = recordSources.get(name);
  const record = recordSource.record;
  const originalData = await fs.readFile(located.filename);
  const originalPixels = pngSize(originalData);
  if (originalPixels.width !== record.screenshotPixels?.width || originalPixels.height !== record.screenshotPixels?.height) throw new Error(`${name} PNG dimensions disagree with capture geometry.`);
  const metadata = await sharp(originalData).metadata();
  const bounds = rectangle(record.appBounds, 'app bounds');
  const scaleDifference = dimensions => Math.abs(dimensions.width / bounds.width - dimensions.height / bounds.height);
  let data = originalData;
  let pixels = originalPixels;
  let normalization = null;
  if (scaleDifference(originalPixels) > .015) {
    if (!metadata.orientation || !metadata.autoOrient || scaleDifference(metadata.autoOrient) > .015) throw new Error(`${name} image cannot be mapped proportionally to its captured window, even after EXIF orientation.`);
    // A 90-degree EXIF correction rearranges existing pixels without resizing
    // or inventing content. Keep the original native attachment separately.
    data = await sharp(originalData).rotate().png({ compressionLevel: 9 }).toBuffer();
    pixels = pngSize(data);
    normalization = { exifOrientation: metadata.orientation, originalPixels, normalizedPixels: pixels, operation: 'Lossless EXIF orientation normalization; no resize, crop, interpolation or generated content' };
    const originalsDirectory = path.join(rawRoot, family, 'originals');
    await fs.mkdir(originalsDirectory, { recursive: true });
    await fs.writeFile(path.join(originalsDirectory, `${name}.png`), originalData);
  }
  const filename = path.join(rawRoot, family, `${name}.png`);
  await fs.writeFile(filename, data);
  const entry = {
    file: path.relative(rawRoot, filename),
    sourcePixels: pixels,
    provenance: {
      captureName: name,
      sourceFamily: family,
      sha256: crypto.createHash('sha256').update(data).digest('hex'),
      originalSha256: crypto.createHash('sha256').update(originalData).digest('hex'),
      exportedAttachment: path.relative(attachments, located.filename),
      geometryAttachment: path.relative(attachments, recordSource.filename),
      ...(sourceResult ? { sourceResult: path.relative(process.cwd(), path.resolve(sourceResult)) } : {}),
      nativeCapture: true,
      pixelModification: normalization ? normalization.operation : 'None; copied byte for byte from XCTest attachment',
      ...(normalization ? { orientationNormalization: normalization, originalFile: path.relative(rawRoot, path.join(rawRoot, family, 'originals', `${name}.png`)) } : {}),
      syntheticContent: true,
      inputProfile: record.inputProfile,
      theme: record.theme,
      keyboardAppearance: record.keyboardAppearance,
      windowOrientation: record.windowOrientation,
      terminalIsRemoteConnection: false,
      pointGeometry: record,
    },
  };
  if (record.keyboardVisible) {
    entry.keyboard = convert(record.visibleKeyboardSurface || record.keyboardSurface, record, pixels);
    const keyboard = entry.keyboard;
    const above = Math.min(keyboard.y, Math.round(keyboard.height * .34));
    entry.working = { x: keyboard.x, y: keyboard.y - above, width: keyboard.width, height: keyboard.height + above };
    if (record.toolbar) entry.toolbar = convert(record.toolbar, record, pixels);
    if (record.editor) entry.editor = convert(record.editor, record, pixels);
  } else {
    // The current capture test verifies the source/privacy rows are visible,
    // but does not export their frames. Keep the complete real screen until
    // a reviewer supplies a measured, tighter settings detail crop.
    entry.detail = { x: 0, y: 0, width: pixels.width, height: pixels.height };
    entry.cropReview = 'Settings detail is the full native capture; review a tighter source/privacy/security crop before final artwork.';
  }
  const override = overrides[name];
  if (override) {
    for (const key of ['keyboard', 'working', 'toolbar', 'editor', 'code', 'detail']) {
      if (!override[key]) continue;
      const rect = rectangle(override[key], `override ${name}/${key}`);
      if (rect.x < 0 || rect.y < 0 || rect.x + rect.width > pixels.width || rect.y + rect.height > pixels.height) throw new Error(`Out-of-bounds override ${name}/${key}.`);
      entry[key] = rect;
    }
    entry.provenance.cropOverrideSource = path.relative(process.cwd(), path.resolve(cropOverridesFile));
    if (override.detail) delete entry.cropReview;
  }
  familyEntries[name] = entry;
  console.log(`${family}/${name}.png ${pixels.width}×${pixels.height}${entry.keyboard ? ` keyboard ${entry.keyboard.width}×${entry.keyboard.height}` : ' settings detail needs visual review'}`);
}
manifest.families[family] = familyEntries;
for (const reusedFamily of reuseFamilies) {
  // This is explicit, never automatic. Frameless UI may be composed at a
  // proportional scale, but provenance must retain the actual source family.
  manifest.families[reusedFamily] = Object.fromEntries(Object.entries(familyEntries).map(([name, entry]) => [name, {
    ...entry,
    provenance: { ...entry.provenance, reusedForFamily: reusedFamily, reuseNote: 'Same native UI capture, scaled proportionally in frameless artwork; no other device bezel or shape is implied.' },
  }]));
}
manifest.content = 'Bundled synthetic examples captured through native app interactions';
manifest.coordinateSpace = 'All crop rectangles are original source-image pixels';
manifest.updatedAt = new Date().toISOString();
const geometryRecord = { schemaVersion: 1, coordinateSpace: 'XCTest screen/window points; source screenshot raster dimensions retained per frame', captures: requestedCaptures.map(name => recordSources.get(name).record), geometryAttachments: requestedCaptures.map(name => path.relative(attachments, recordSources.get(name).filename)) };
await fs.writeFile(path.join(rawRoot, family, requestedCaptures.length === captureNames.length ? 'capture-geometry.json' : `capture-geometry-${requestedCaptures.join('-')}.json`), JSON.stringify(geometryRecord, null, 2) + '\n');
await fs.writeFile(manifestFile, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Manifest updated: ${path.relative(process.cwd(), manifestFile)}`);
