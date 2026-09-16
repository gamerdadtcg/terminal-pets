#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const publicDir = path.join(__dirname, "..", "public");
const GIF89A = Buffer.from("GIF89a");
const ORIGIN = "https://terminal-pets.vercel.app";

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

const artTest = path.join(publicDir, "art", "test");
const artEgg = path.join(publicDir, "art", "test-egg");
const litDir = path.join(publicDir, "metadata", "lit");
const dormantDir = path.join(publicDir, "metadata", "dormant");

const artIds = listNumeric(artTest, ".gif");
const eggIds = listNumeric(artEgg, ".gif");
const litIds = listNumeric(litDir, ".json");
const dormantIds = listNumeric(dormantDir, ".json");
const expected = Array.from({ length: 25 }, (_, i) => i + 1);

function assertIds(label, ids) {
  if (ids.join(",") !== expected.join(",")) {
    throw new Error(`${label} expected 1..25, got ${ids.join(",")}`);
  }
}

assertIds("art/test", artIds);
assertIds("art/test-egg", eggIds);
assertIds("metadata/lit", litIds);
assertIds("metadata/dormant", dormantIds);

for (const id of expected) {
  mustGif(path.join(artTest, `${id}.gif`));
  mustGif(path.join(artEgg, `${id}.gif`));
}

for (const dir of [artTest, artEgg]) {
  for (const name of fs.readdirSync(dir)) {
    if (name.toLowerCase().endsWith(".png")) {
      throw new Error(`PNG not allowed in test host: ${path.join(dir, name)}`);
    }
  }
}

function checkJson(filePath, expectedImage) {
  const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (typeof data.image !== "string" || !data.image.endsWith(".gif")) {
    throw new Error(`${filePath} image must be a .gif URL`);
  }
  if (data.image.toLowerCase().includes(".png")) {
    throw new Error(`${filePath} image must not reference PNG`);
  }
  if (data.image !== expectedImage) {
    throw new Error(`${filePath} image expected ${expectedImage}, got ${data.image}`);
  }
}

checkJson(
  path.join(publicDir, "metadata", "hidden.json"),
  `${ORIGIN}/art/test-egg/1.gif`,
);

for (const id of expected) {
  checkJson(
    path.join(litDir, `${id}.json`),
    `${ORIGIN}/art/test/${id}.gif`,
  );
  checkJson(
    path.join(dormantDir, `${id}.json`),
    `${ORIGIN}/art/test-egg/${id}.gif`,
  );
}

console.log("test host ok: 25 GIF89a lit + 25 GIF89a egg + JSON HTTPS .gif images");
