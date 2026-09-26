import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, symlinkSync, unlinkSync } from 'node:fs';
import { resolve } from 'node:path';
import { gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { assertCheckoutTarget, copyShellAssets, packageWebExport } from '../web-build.mjs';
const root = resolve(import.meta.dirname,'../..');
const receipts = resolve(root,'evidence/visual-upgrade-20260923/shell');
mkdirSync(receipts,{recursive:true});
const isolated = mkdtempSync(resolve(receipts,'packaging-'));
const raw = resolve(isolated,'raw'), packed = resolve(isolated,'packed');
mkdirSync(raw); mkdirSync(packed);

test('standalone shell assets retain source bytes in raw and packaged output',() => {
  const copied = copyShellAssets(root,raw);
  assert.ok(copied.includes('assets/aeral-hero-v1.png'));
  assert.ok(copied.includes('showcase.css'));
  assert.ok(copied.includes('showcase.js'));
  const wasm = Buffer.from([0,97,115,109,1,0,0,0]);
  writeFileSync(resolve(raw,'index.wasm'),wasm);
  writeFileSync(resolve(raw,'index.pck'),'synthetic-test-package');
  const {files,rawFiles} = packageWebExport(root,raw,packed);
  for (const name of copied) {
    const source = readFileSync(resolve(root,'godot/web',name));
    assert.deepEqual(readFileSync(resolve(raw,name)),source);
    assert.deepEqual(readFileSync(resolve(packed,name)),source);
    assert.equal(files.find(f=>f.name===name).sha256,createHash('sha256').update(source).digest('hex'));
    assert.equal(rawFiles.find(f=>f.name===name).bytes,source.length);
  }
  assert.deepEqual(gunzipSync(readFileSync(resolve(packed,'index.wasm'))),wasm);
  assert.deepEqual(readFileSync(resolve(raw,'index.wasm')),wasm);
  writeFileSync(resolve(receipts,'packaging-receipt.json'),JSON.stringify({isolated,files,rawFiles,syntheticEngineBytes:true},null,2));
});

test('recursive rebuild targets cannot be checkout root, parent or similarly named sibling',() => {
  assert.throws(()=>assertCheckoutTarget(root,root),/outside checkout/);
  assert.throws(()=>assertCheckoutTarget(root,resolve(root,'..')),/outside checkout/);
  assert.throws(()=>assertCheckoutTarget(root,root+'-other/out'),/outside checkout/);
  assert.equal(assertCheckoutTarget(root,resolve(isolated,'valid/path')),resolve(isolated,'valid/path'));
});

test('junctions are rejected before writes or recursive removal',() => {
  const junction = resolve(isolated,'redirect');
  symlinkSync(root,junction,process.platform==='win32'?'junction':'dir');
  try { assert.throws(()=>assertCheckoutTarget(root,resolve(junction,'out')),/linked build path/); }
  finally { unlinkSync(junction); }
});
