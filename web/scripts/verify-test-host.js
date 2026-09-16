#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const publicDir = path.join(__dirname, "..", "public");
const GIF89A = Buffer.from("GIF89a");

function mustGif(filePath) {
  const fd = fs.openSync(filePath, "r");
  const buf = Buffer.alloc(6);
  fs.readSync(fd, buf, 0, 6, 0);
  fs.closeSync(fd);
  if (!buf.equals(GIF89A)) {
    throw new Error(`${filePath} is not GIF89a (got ${buf.toString("latin1")})`);
  }
}

function listNumeric(dir, ext) {
  return fs
    .readdirSync(dir)
    .filter((name) => name.endsWith(ext))
    .map((name) => Number.parseInt(name.slice(0, -ext.length), 10))
    .filter((n) => Number.isInteger(n))
    .sort((a, b) => a - b);
}

function assertGone(rel) {
  const full = path.join(publicDir, rel);
  if (fs.existsSync(full)) {
    throw new Error(`anti-snipe: ${rel} must not be published on the hub`);
  }
}

assertGone("metadata");
assertGone("art/test");
assertGone("art/test-egg");
assertGone("art/awake");
assertGone("art/dormant");

const artAwake = path.join(publicDir, "art", "examples", "awake");
const artEggs = path.join(publicDir, "art", "examples", "eggs");
const expected = Array.from({ length: 25 }, (_, i) => i + 1);

function assertIds(label, ids) {
  if (ids.join(",") !== expected.join(",")) {
    throw new Error(`${label} expected 1..25, got ${ids.join(",")}`);
  }
}

assertIds("art/examples/awake", listNumeric(artAwake, ".gif"));
assertIds("art/examples/eggs", listNumeric(artEggs, ".gif"));

for (const id of expected) {
  mustGif(path.join(artAwake, `${id}.gif`));
  mustGif(path.join(artEggs, `${id}.gif`));
}

for (const dir of [artAwake, artEggs]) {
  for (const name of fs.readdirSync(dir)) {
    if (name.toLowerCase().endsWith(".png")) {
      throw new Error(`PNG not allowed in example GIFs: ${path.join(dir, name)}`);
    }
  }
}

const hatchDir = path.join(publicDir, "art", "examples", "hatch");
const hatchFiles = [
  "P01_pudd_hatch.gif",
  "P04_puppo_hatch.gif",
  "P08_blop_hatch.gif",
  "P12_bolt_hatch.gif",
  "snag_hatch.gif",
  "anim_hatch.gif",
];
for (const name of hatchFiles) {
  mustGif(path.join(hatchDir, name));
}

const sealed = path.join(publicDir, "art", "examples", "sealed.png");
if (!fs.existsSync(sealed)) {
  throw new Error("missing art/examples/sealed.png");
}

console.log(
  "examples ok: 25 GIF89a awake + 25 GIF89a eggs under /art/examples; no public /metadata token JSON",
);
