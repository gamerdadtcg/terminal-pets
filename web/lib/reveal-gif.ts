import { GIFEncoder, applyPalette, quantize } from "gifenc";
import { decompressFrames, parseGIF, type ParsedFrame } from "gifuct-js";

export type RevealCaption = {
  title: string;
  subtitle: string;
};

type Painted = {
  rgba: Uint8ClampedArray;
  delayMs: number;
  width: number;
  height: number;
};

const BAR = 72;
const GOLD = "#f0b429";
const INK = "#10140f";
const PAPER = "#f4f1e8";

function blitPatch(
  canvas: Uint8ClampedArray,
  width: number,
  height: number,
  frame: ParsedFrame,
) {
  const { left, top, width: patchWidth, height: patchHeight } = frame.dims;
  const patch = frame.patch;
  for (let y = 0; y < patchHeight; y++) {
    const dy = top + y;
    if (dy < 0 || dy >= height) continue;
    for (let x = 0; x < patchWidth; x++) {
      const dx = left + x;
      if (dx < 0 || dx >= width) continue;
      const src = (y * patchWidth + x) * 4;
      if (patch[src + 3] === 0) continue;
      const dst = (dy * width + dx) * 4;
      canvas[dst] = patch[src];
      canvas[dst + 1] = patch[src + 1];
      canvas[dst + 2] = patch[src + 2];
      canvas[dst + 3] = 255;
    }
  }
}

function clearRect(
  canvas: Uint8ClampedArray,
  width: number,
  height: number,
  frame: ParsedFrame,
) {
  const { left, top, width: patchWidth, height: patchHeight } = frame.dims;
  for (let y = 0; y < patchHeight; y++) {
    const dy = top + y;
    if (dy < 0 || dy >= height) continue;
    for (let x = 0; x < patchWidth; x++) {
      const dx = left + x;
      if (dx < 0 || dx >= width) continue;
      const dst = (dy * width + dx) * 4;
      canvas[dst] = 0;
      canvas[dst + 1] = 0;
      canvas[dst + 2] = 0;
      canvas[dst + 3] = 255;
    }
  }
}

function decodeGif(buffer: ArrayBuffer): Painted[] {
  const gif = parseGIF(buffer);
  const frames = decompressFrames(gif, true);
  const width = gif.lsd.width;
  const height = gif.lsd.height;
  if (!width || !height || frames.length === 0) {
    throw new Error("GIF has no frames");
  }
  const canvas = new Uint8ClampedArray(width * height * 4);
  canvas.fill(255);
  const painted: Painted[] = [];
  for (const frame of frames) {
    const restore = frame.disposalType === 3 ? canvas.slice() : null;
    blitPatch(canvas, width, height, frame);
    painted.push({
      rgba: canvas.slice(),
      delayMs: Math.max(40, frame.delay * 10 || 100),
      width,
      height,
    });
    if (frame.disposalType === 2) clearRect(canvas, width, height, frame);
    else if (restore) canvas.set(restore);
  }
  return painted;
}

function blend(
  from: Uint8ClampedArray,
  to: Uint8ClampedArray,
  t: number,
) {
  const out = new Uint8ClampedArray(from.length);
  const keep = 1 - t;
  for (let i = 0; i < from.length; i += 4) {
    out[i] = from[i] * keep + to[i] * t;
    out[i + 1] = from[i + 1] * keep + to[i + 1] * t;
    out[i + 2] = from[i + 2] * keep + to[i + 2] * t;
    out[i + 3] = 255;
  }
  return out;
}

function paintCaption(
  ctx: CanvasRenderingContext2D,
  width: number,
  artHeight: number,
  caption: RevealCaption,
) {
  ctx.fillStyle = INK;
  ctx.fillRect(0, artHeight, width, BAR);
  ctx.fillStyle = GOLD;
  ctx.font = "600 22px ui-monospace, monospace";
  ctx.textBaseline = "alphabetic";
  const title = fit(ctx, caption.title, width - 40);
  ctx.fillText(title, 20, artHeight + 30);
  ctx.fillStyle = PAPER;
  ctx.font = "16px ui-monospace, monospace";
  const subtitle = fit(ctx, caption.subtitle, width - 40);
  ctx.fillText(subtitle, 20, artHeight + 54);
}

function fit(ctx: CanvasRenderingContext2D, text: string, maxWidth: number) {
  let shown = text;
  while (shown.length > 1 && ctx.measureText(shown).width > maxWidth) {
    shown = `${shown.slice(0, -2)}…`;
  }
  return shown;
}

function sequence(egg: Painted[], pet: Painted[]): Painted[] {
  const lastEgg = egg[egg.length - 1];
  const firstPet = pet[0];
  if (!lastEgg || !firstPet) throw new Error("GIF has no frames");
  if (
    lastEgg.width !== firstPet.width ||
    lastEgg.height !== firstPet.height
  ) {
    throw new Error("Egg and pet art are different sizes");
  }
  const opening = [0.35, 0.7].map((t) => ({
    rgba: blend(lastEgg.rgba, firstPet.rgba, t),
    delayMs: 90,
    width: lastEgg.width,
    height: lastEgg.height,
  }));
  return [...egg, ...opening, ...pet, ...pet];
}

export async function composeRevealGif(
  eggBytes: ArrayBuffer,
  petBytes: ArrayBuffer,
  caption: RevealCaption,
) {
  const frames = sequence(decodeGif(eggBytes), decodeGif(petBytes));
  const sample = frames[0];
  if (!sample) throw new Error("GIF has no frames");
  const width = sample.width;
  const height = sample.height + BAR;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) throw new Error("Could not draw the post");

  const encoder = GIFEncoder({ initialCapacity: 512 * 1024 });
  let first = true;
  for (const frame of frames) {
    const pixels = new Uint8ClampedArray(frame.rgba);
    ctx.putImageData(new ImageData(pixels, frame.width, frame.height), 0, 0);
    paintCaption(ctx, width, frame.height, caption);
    const rgba = ctx.getImageData(0, 0, width, height).data;
    const palette = quantize(rgba, 128, { format: "rgb565" });
    const index = applyPalette(rgba, palette, "rgb565");
    encoder.writeFrame(index, width, height, {
      palette,
      delay: frame.delayMs,
      repeat: first ? 0 : undefined,
      dispose: 1,
    });
    first = false;
  }
  encoder.finish();
  return encoder.bytes();
}
