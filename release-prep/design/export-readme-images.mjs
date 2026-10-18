#!/usr/bin/env node
/** Whole-device crops of genuine Device Hub captures, with no app UI retouching. */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {deviceCutout} from './device-cutout.mjs';
const argument=(flag,fallback)=>{const i=process.argv.indexOf(flag);return i<0?fallback:process.argv[i+1];};
const root=process.cwd();const outputRoot=path.resolve(argument('--output-root','artifacts/app-store-release-2026-10-18'));
const modules=process.env.TABFORGE_NODE_MODULES||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let require=createRequire(import.meta.url);try{require.resolve('sharp');}catch{require=createRequire(path.join(modules,'_tabforge-readme.cjs'));}if(process.env.TABFORGE_NODE_MODULES)require=createRequire(path.join(modules,'_tabforge-readme.cjs'));const sharp=require('sharp');
const definitions=[
 ['iphone','iphone-light-clean-window.png',{left:650,top:136,width:762,height:1548},'iPhone portrait'],
 ['ipad','ipad-light-clean-window.png',{left:483,top:131,width:1105,height:1552},'iPad portrait'],
 ['duo-closed','duo-closed-light-clean-window.png',{left:546,top:224,width:990,height:1368},'Duo closed'],
 ['duo-open','duo-open-light-clean-window.png',{left:88,top:226,width:1900,height:1365},'Duo open'],
 ['duo-tabletop','duo-tabletop-light-clean-window.png',{left:478,top:184,width:1112,height:1458},'Duo tabletop'],
];
await fs.mkdir('docs/images',{recursive:true});const receipts=[];
for(const[id,name,crop,label]of definitions){const source=path.join(outputRoot,'framed-captures',name);const output=`docs/images/keyboard-${id}.webp`;const cut=await deviceCutout(sharp,source,crop);await sharp(cut.buffer).resize({width:1200,withoutEnlargement:true}).webp({quality:92,effort:6}).toFile(output);const m=await sharp(output).metadata();receipts.push({file:output,label,width:m.width,height:m.height,sha256:crypto.createHash('sha256').update(await fs.readFile(output)).digest('hex'),source:path.relative(root,source),sourceSHA256:crypto.createHash('sha256').update(await fs.readFile(source)).digest('hex'),crop,pixelChanges:'Whole-device crop, connected exterior white matte removal, proportional reduction where needed, and WebP encoding; opaque app and chassis pixels unchanged'});console.log(`${output} (${m.width}×${m.height})`);}
await fs.writeFile(path.join(outputRoot,'framed-captures/readme-image-provenance.json'),JSON.stringify({generatedAt:new Date().toISOString(),receipts},null,2)+'\n');
