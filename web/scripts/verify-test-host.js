#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const publicDir = path.join(__dirname, "..", "public");
const GIF89A = Buffer.from("GIF89a");
// Canonical public origin. terminal-pets.vercel.app still resolves as a fallback alias.
const ORIGIN = "https://terminalpets.xyz";

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

const examplesAwake = path.join(publicDir, "art", "examples", "awake");
const examplesEgg = path.join(publicDir, "art", "examples", "egg");
const metadataDir = path.join(publicDir, "metadata");
const litDir = path.join(metadataDir, "lit");
const dormantDir = path.join(metadataDir, "dormant");

if (fs.existsSync(litDir)) {
  throw new Error(
    "anti-snipe: do not host collection lit JSON at web/public/metadata/lit",
  );
}
if (fs.existsSync(dormantDir)) {
  throw new Error(
    "anti-snipe: do not host collection dormant JSON at web/public/metadata/dormant",
  );
}

const awakeIds = listNumeric(examplesAwake, ".gif");
const eggIds = listNumeric(examplesEgg, ".gif");
const expected = Array.from({ length: 25 }, (_, i) => i + 1);

function assertIds(label, ids) {
  if (ids.join(",") !== expected.join(",")) {
    throw new Error(`${label} expected demo 1..25, got ${ids.join(",")}`);
  }
}

assertIds("art/examples/awake", awakeIds);
assertIds("art/examples/egg", eggIds);

for (const id of expected) {
  mustGif(path.join(examplesAwake, `${id}.gif`));
  mustGif(path.join(examplesEgg, `${id}.gif`));
}

for (const dir of [examplesAwake, examplesEgg]) {
  for (const name of fs.readdirSync(dir)) {
    if (name.toLowerCase().endsWith(".png")) {
      throw new Error(`PNG not allowed in examples: ${path.join(dir, name)}`);
    }
  }
}

const hiddenPath = path.join(metadataDir, "hidden.json");
const hidden = JSON.parse(fs.readFileSync(hiddenPath, "utf8"));
if (hidden.image !== `${ORIGIN}/art/sealed.png`) {
  throw new Error(
    `${hiddenPath} image expected ${ORIGIN}/art/sealed.png, got ${hidden.image}`,
  );
}
if (hidden.attributes?.some((a) => a.trait_type !== "State")) {
  throw new Error(`${hiddenPath} must only expose State=Sealed (no traits)`);
}
if (!String(hidden.description || "").toLowerCase().includes("cannot see traits")) {
  throw new Error(`${hiddenPath} description must say collectors cannot see traits`);
}

const metadataNames = fs.readdirSync(metadataDir);
if (metadataNames.some((name) => name !== "hidden.json")) {
  throw new Error(
    `anti-snipe: web/public/metadata must only contain hidden.json, got ${metadataNames.join(",")}`,
  );
}

const hatchDir = path.join(publicDir, "art", "hatch");
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

console.log(
  "examples ok: 25 demo GIFs (not mint supply) + sealed hidden.json only + 6 hatch GIFs",
);
