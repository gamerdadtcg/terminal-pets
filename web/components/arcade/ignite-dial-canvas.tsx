"use client";

import {
  ARCADE_MAX_COMBO,
  ARCADE_PET,
  ARCADE_TICKS,
  type ArcadeTickSymbol,
} from "@/lib/arcade";
import { useEffect, useRef } from "react";

export type ArcadeRunResult = {
  score: number;
  ticksCaught: number;
  glitchesHit: number;
  durationMs: number;
};

type Pad = {
  x: number;
  y: number;
  w: number;
  h: number;
  kind: "pad" | "glitch" | "crumble";
  vx: number;
  scored: boolean;
  dead: boolean;
};

type Pickup = {
  x: number;
  y: number;
  r: number;
  symbol: ArcadeTickSymbol;
  points: number;
};

type Floater = {
  x: number;
  y: number;
  text: string;
  life: number;
  color: string;
};

const W = 720;
const H = 440;
const PET_W = 50;
const PET_H = 56;
const GRAVITY = 1580;
const BOUNCE = -780;
const GLITCH_BOUNCE = -700;
const MAX_VX = 480;

function pickTick(): { symbol: ArcadeTickSymbol; points: number } {
  if (Math.random() < 0.08) return { symbol: "OMEGA", points: 120 };
  const pool = ARCADE_TICKS.filter((tick) => tick.symbol !== "OMEGA");
  return pool[Math.floor(Math.random() * pool.length)] ?? pool[0];
}

function aabb(
  ax: number,
  ay: number,
  aw: number,
  ah: number,
  bx: number,
  by: number,
  bw: number,
  bh: number,
) {
  return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
}

function wrapX(x: number) {
  if (x + PET_W / 2 < 0) return x + W;
  if (x + PET_W / 2 > W) return x - W;
  return x;
}

export function IgniteDialCanvas({
  active,
  onEnd,
}: {
  active: boolean;
  onEnd: (result: ArcadeRunResult) => void;
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const onEndRef = useRef(onEnd);

  useEffect(() => {
    onEndRef.current = onEnd;
  }, [onEnd]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const g = ctx;
    const view = canvas;

    const sprite = new Image();
    sprite.src = ARCADE_PET.src;
    let cancelled = false;
    let frame = 0;

    function drawSprite(
      x: number,
      y: number,
      face: number,
      squash: number,
      ghost: boolean,
    ) {
      if (!sprite.complete || sprite.naturalWidth === 0) return;
      const h = PET_H * squash;
      const w = PET_W / squash;
      g.save();
      g.imageSmoothingEnabled = false;
      if (ghost) g.globalAlpha = 0.45;
      g.translate(x + PET_W / 2, y + PET_H);
      g.scale(face, 1);
      g.drawImage(sprite, -w / 2, -h, w, h);
      g.restore();
    }

    function drawBolt(
      x: number,
      y: number,
      face: number,
      squash: number,
      ghost: boolean,
    ) {
      drawSprite(x, y, face, squash, ghost);
      if (x < PET_W) drawSprite(x + W, y, face, squash, ghost);
      if (x + PET_W > W) drawSprite(x - W, y, face, squash, ghost);
    }

    if (!active) {
      function preview() {
        if (cancelled) return;
        g.fillStyle = "#07110c";
        g.fillRect(0, 0, W, H);
        g.strokeStyle = "rgba(124,255,154,0.06)";
        for (let x = 0; x < W; x += 28) {
          g.beginPath();
          g.moveTo(x, 0);
          g.lineTo(x, H);
          g.stroke();
        }
        g.fillStyle = "rgba(124,255,154,0.7)";
        g.fillRect(W / 2 - 48, H - 78, 96, 12);
        drawBolt((W - PET_W) / 2, H - 78 - PET_H, 1, 1, false);
        g.fillStyle = "rgba(0,0,0,0.12)";
        for (let y = 0; y < H; y += 3) g.fillRect(0, y, W, 1);
      }
      if (sprite.complete) preview();
      else sprite.onload = preview;
      return () => {
        cancelled = true;
      };
    }

    view.focus();

    const pet = {
      x: (W - PET_W) / 2,
      y: H - 98,
      vx: 0,
      vy: BOUNCE,
    };
    let camY = 0;
    let face = 1;
    let squash = 1;
    let left = false;
    let right = false;
    let pointerX: number | null = null;
    let hitIFrames = 0;
    let shake = 0;
    let flash = 0;
    const pads: Pad[] = [];
    const pickups: Pickup[] = [];
    const floaters: Floater[] = [];
    let score = 0;
    let ticksCaught = 0;
    let glitchesHit = 0;
    let combo = 1;
    let comboT = 0;
    let charge = 100;
    let bestHeight = 0;
    let topY = H - 36;
    let last = performance.now();
    const started = last;
    let lastSafeX = W / 2;
    let ended = false;

    function float(x: number, y: number, text: string, color: string) {
      floaters.push({ x, y, text, life: 0.7, color });
    }

    function endRun(now: number) {
      if (ended) return;
      ended = true;
      onEndRef.current({
        score,
        ticksCaught,
        glitchesHit,
        durationMs: Math.round(now - started),
      });
    }

    function pushPad(
      x: number,
      y: number,
      w: number,
      kind: Pad["kind"],
      vx: number,
    ) {
      pads.push({
        x,
        y,
        w,
        h: 12,
        kind,
        vx,
        scored: false,
        dead: false,
      });
    }

    function spawnTick(padX: number, padW: number, padY: number) {
      const tick = pickTick();
      pickups.push({
        x: padX + padW / 2,
        y: padY - 22,
        r: tick.symbol === "OMEGA" ? 16 : 13,
        symbol: tick.symbol,
        points: tick.points,
      });
    }

    function addChoice(y: number, heat: number) {
      const threat = Math.min(2.2, heat);
      const w = Math.round(Math.max(64, 100 - threat * 18));
      const split = 44 + Math.min(1, threat) * 20;
      const pairW = w * 2 + split;
      const margin = 20;
      const maxLeft = W - margin - pairW;
      const prefer = lastSafeX - pairW / 2;
      const jitter = (Math.random() - 0.5) * (50 + Math.min(1, threat) * 40);
      const left = Math.max(margin, Math.min(maxLeft, prefer + jitter));
      const safeOnLeft = Math.random() < 0.5;
      const leftKind: Pad["kind"] = safeOnLeft ? "pad" : "glitch";
      const rightKind: Pad["kind"] = safeOnLeft ? "glitch" : "pad";
      const rightX = left + w + split;
      pushPad(left, y, w, leftKind, 0);
      pushPad(rightX, y, w, rightKind, 0);
      lastSafeX = (safeOnLeft ? left : rightX) + w / 2;
      if (Math.random() < 0.34) {
        spawnTick(safeOnLeft ? left : rightX, w, y);
      }
    }

    function fillPads(heat: number) {
      while (topY > camY - 180) {
        const gap = 70 + Math.min(0.9, heat) * 28 + Math.random() * 10;
        topY -= gap;
        addChoice(topY, heat);
      }
    }

    const startW = 128;
    const startX = (W - startW) / 2;
    pushPad(startX, H - 36, startW, "pad", 0);
    lastSafeX = startX + startW / 2;
    topY = H - 36;
    fillPads(0);

    function localX(event: PointerEvent) {
      const rect = view.getBoundingClientRect();
      return ((event.clientX - rect.left) / rect.width) * W;
    }

    function aimFrom(event: PointerEvent) {
      const rect = view.getBoundingClientRect();
      const pad = 40;
      const over =
        event.clientX >= rect.left - pad &&
        event.clientX <= rect.right + pad &&
        event.clientY >= rect.top - pad &&
        event.clientY <= rect.bottom + pad;
      if (!over) return;
      pointerX = Math.max(0, Math.min(W, localX(event)));
    }

    const onKey = (event: KeyboardEvent) => {
      const down = event.type === "keydown";
      if (
        event.key === "ArrowLeft" ||
        event.key === "a" ||
        event.key === "A"
      ) {
        left = down;
        event.preventDefault();
      }
      if (
        event.key === "ArrowRight" ||
        event.key === "d" ||
        event.key === "D"
      ) {
        right = down;
        event.preventDefault();
      }
    };

    const onPointer = (event: PointerEvent) => {
      if (event.type === "pointercancel") return;
      aimFrom(event);
      if (event.type === "pointerdown") {
        try {
          view.setPointerCapture(event.pointerId);
        } catch {
          // Capture is optional; mouse already tracks on window.
        }
        event.preventDefault();
      }
    };

    window.addEventListener("keydown", onKey);
    window.addEventListener("keyup", onKey);
    window.addEventListener("pointermove", onPointer);
    view.addEventListener("pointerdown", onPointer);
    view.addEventListener("pointermove", onPointer);

    function bounceOn(pad: Pad) {
      const screenY = pad.y - camY;
      if (pad.kind === "glitch") {
        pet.vy = GLITCH_BOUNCE;
        squash = 0.78;
        if (hitIFrames <= 0) {
          pad.scored = true;
          glitchesHit += 1;
          combo = 1;
          comboT = 0;
          charge -= 18;
          hitIFrames = 0.4;
          shake = 0.28;
          flash = 0.5;
          float(pet.x + 20, screenY - 8, "PENALTY", "#ff6b8a");
        }
        return;
      }
      pet.vy = BOUNCE;
      squash = 0.72;
      if (pad.kind === "crumble") pad.dead = true;
      if (!pad.scored) {
        pad.scored = true;
        combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
        comboT = 2.2;
        const gain = 25 * combo;
        score += gain;
        charge = Math.min(100, charge + 2);
        float(
          pet.x + 24,
          screenY - 10,
          pad.kind === "crumble" ? `SNAP +${gain}` : `PAD +${gain}`,
          "#7CFF9A",
        );
      }
    }

    function feetHit(pad: Pad) {
      if (pad.dead) return false;
      const footY = pet.y + PET_H;
      if (pet.vy <= 0) return false;
      if (footY < pad.y - 2 || footY > pad.y + pad.h + 10) return false;
      const xs = [pet.x, pet.x - W, pet.x + W];
      return xs.some((x) =>
        aabb(x + 10, footY - 8, PET_W - 20, 10, pad.x, pad.y, pad.w, pad.h),
      );
    }

    function loop(now: number) {
      if (ended || cancelled) return;
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      const elapsed = now - started;
      const height = Math.max(0, Math.floor(H - 98 - pet.y));
      if (height > bestHeight) {
        score += height - bestHeight;
        bestHeight = height;
      }
      const heat = elapsed / 28_000 + bestHeight / 4000;

      hitIFrames = Math.max(0, hitIFrames - dt);
      shake = Math.max(0, shake - dt * 8);
      flash = Math.max(0, flash - dt * 3);
      comboT = Math.max(0, comboT - dt);
      if (comboT <= 0 && combo > 1) combo = 1;
      squash += (1 - squash) * Math.min(1, dt * 12);

      if (pointerX !== null) {
        const target = pointerX - PET_W / 2;
        pet.vx = (target - pet.x) / Math.max(dt, 1 / 240);
        pet.x = wrapX(target);
      } else {
        if (left) pet.vx -= 3200 * dt;
        if (right) pet.vx += 3200 * dt;
        if (!left && !right) pet.vx *= Math.pow(0.08, dt);
        pet.vx = Math.max(-MAX_VX, Math.min(MAX_VX, pet.vx));
        pet.x = wrapX(pet.x + pet.vx * dt);
      }
      if (Math.abs(pet.vx) > 8) face = pet.vx < 0 ? -1 : 1;

      pet.vy = Math.min(920, pet.vy + GRAVITY * dt);
      pet.y += pet.vy * dt;

      const follow = pet.y - H * 0.4;
      if (follow < camY) camY = follow;
      fillPads(heat);

      for (const pad of pads) {
        if (pad.dead) continue;
        if (pad.vx !== 0) {
          pad.x += pad.vx * dt;
          if (pad.x < 12 || pad.x + pad.w > W - 12) pad.vx *= -1;
        }
        if (feetHit(pad)) bounceOn(pad);
      }
      for (let i = pads.length - 1; i >= 0; i -= 1) {
        if (pads[i].dead || pads[i].y > camY + H + 70) pads.splice(i, 1);
      }

      for (let i = pickups.length - 1; i >= 0; i -= 1) {
        const pickup = pickups[i];
        const sx = [pet.x, pet.x - W, pet.x + W];
        const hit = sx.some(
          (x) =>
            Math.hypot(x + PET_W / 2 - pickup.x, pet.y + PET_H / 2 - pickup.y) <
            pickup.r + 16,
        );
        if (hit) {
          combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
          comboT = 2.4;
          const gain = pickup.points * combo;
          score += gain;
          ticksCaught += 1;
          charge = Math.min(100, charge + 10);
          float(pickup.x, pickup.y - camY - 8, `+${gain} ${pickup.symbol}`, "#F0B429");
          pickups.splice(i, 1);
          continue;
        }
        if (pickup.y > camY + H + 40) pickups.splice(i, 1);
      }

      for (let i = floaters.length - 1; i >= 0; i -= 1) {
        floaters[i].life -= dt;
        floaters[i].y -= 26 * dt;
        if (floaters[i].life <= 0) floaters.splice(i, 1);
      }

      charge -= (0.4 + Math.min(1.8, heat) * 0.45) * dt;

      const fallen = pet.y - camY > H - 6;
      if (charge <= 0 || fallen) {
        charge = Math.max(0, charge);
        draw(now);
        endRun(now);
        return;
      }

      draw(now);
      frame = requestAnimationFrame(loop);
    }

    function draw(now: number) {
      const ox = (Math.random() - 0.5) * shake * 10;
      const oy = (Math.random() - 0.5) * shake * 6;
      g.save();
      g.translate(ox, oy);
      g.fillStyle = "#07110c";
      g.fillRect(-16, -16, W + 32, H + 32);

      g.strokeStyle = "rgba(124,255,154,0.05)";
      const grid = 28;
      const gy = -((camY * 0.45) % grid);
      for (let x = 0; x < W; x += grid) {
        g.beginPath();
        g.moveTo(x, 0);
        g.lineTo(x, H);
        g.stroke();
      }
      for (let y = gy; y < H; y += grid) {
        g.beginPath();
        g.moveTo(0, y);
        g.lineTo(W, y);
        g.stroke();
      }

      for (const pad of pads) {
        const y = pad.y - camY;
        if (y < -20 || y > H + 20 || pad.dead) continue;
        if (pad.kind === "glitch") {
          g.fillStyle = "rgba(180,40,70,0.42)";
          g.strokeStyle = "#ff6b8a";
          g.fillRect(pad.x, y, pad.w, pad.h);
          g.strokeRect(pad.x + 0.5, y + 0.5, pad.w - 1, pad.h - 1);
          g.fillStyle = "rgba(255,255,255,0.12)";
          for (let n = 0; n < 4; n += 1) {
            g.fillRect(pad.x + 4 + n * 9, y + 3, pad.w * 0.18, 2);
          }
        } else if (pad.kind === "crumble") {
          g.fillStyle = "rgba(240,180,41,0.2)";
          g.strokeStyle = "#F0B429";
          g.setLineDash([5, 4]);
          g.fillRect(pad.x, y, pad.w, pad.h);
          g.strokeRect(pad.x + 0.5, y + 0.5, pad.w - 1, pad.h - 1);
          g.setLineDash([]);
        } else {
          g.fillStyle = "rgba(124,255,154,0.22)";
          g.strokeStyle = "#7CFF9A";
          g.fillRect(pad.x, y, pad.w, pad.h);
          g.strokeRect(pad.x + 0.5, y + 0.5, pad.w - 1, pad.h - 1);
          g.fillStyle = "rgba(124,255,154,0.55)";
          g.fillRect(pad.x + 6, y + 3, pad.w - 12, 3);
        }
      }

      for (const pickup of pickups) {
        const y = pickup.y - camY;
        if (y < -24 || y > H + 24) continue;
        const omega = pickup.symbol === "OMEGA";
        g.fillStyle = omega ? "rgba(240,180,41,0.22)" : "rgba(124,255,154,0.16)";
        g.strokeStyle = omega ? "#F0B429" : "#7CFF9A";
        g.beginPath();
        g.arc(pickup.x, y, pickup.r, 0, Math.PI * 2);
        g.fill();
        g.stroke();
        g.fillStyle = omega ? "#F0B429" : "#c8ffd4";
        g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
        g.textAlign = "center";
        g.textBaseline = "middle";
        g.fillText(pickup.symbol, pickup.x, y);
      }

      const ghost = hitIFrames > 0 && Math.floor(now / 80) % 2 === 0;
      drawBolt(pet.x, pet.y - camY, face, squash, ghost);

      for (const floater of floaters) {
        g.globalAlpha = Math.min(1, floater.life * 2);
        g.fillStyle = floater.color;
        g.font = "11px ui-monospace, SFMono-Regular, Menlo, monospace";
        g.textAlign = "center";
        g.fillText(floater.text, floater.x, floater.y);
        g.globalAlpha = 1;
      }

      g.fillStyle = "rgba(8,18,12,0.78)";
      g.fillRect(10, 8, W - 20, 40);
      g.strokeStyle = "rgba(124,255,154,0.35)";
      g.strokeRect(10.5, 8.5, W - 21, 39);
      g.textAlign = "start";
      g.textBaseline = "alphabetic";
      g.font = "12px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillStyle = "#7CFF9A";
      g.fillText(`SCORE ${score}`, 22, 26);
      g.fillStyle = "#F0B429";
      g.fillText(`COMBO x${combo}`, 168, 26);
      g.fillStyle = "#9ad7aa";
      g.fillText(`HGT ${bestHeight}`, W - 118, 26);
      g.fillStyle = "rgba(124,255,154,0.15)";
      g.fillRect(22, 32, 210, 8);
      g.fillStyle = charge > 28 ? "#7CFF9A" : "#F0B429";
      g.fillRect(22, 32, 2.1 * Math.max(0, charge), 8);
      g.fillStyle = "#7CFF9A";
      g.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillText(`${ARCADE_PET.name} LIT`, 240, 40);

      if (flash > 0) {
        g.fillStyle = `rgba(255,107,138,${flash * 0.18})`;
        g.fillRect(0, 0, W, H);
      }
      g.fillStyle = "rgba(0,0,0,0.12)";
      for (let y = 0; y < H; y += 3) g.fillRect(0, y, W, 1);
      g.restore();
    }

    const start = () => {
      if (cancelled) return;
      frame = requestAnimationFrame(loop);
    };
    if (sprite.complete && sprite.naturalWidth > 0) start();
    else sprite.onload = start;

    return () => {
      cancelled = true;
      ended = true;
      cancelAnimationFrame(frame);
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("keyup", onKey);
      window.removeEventListener("pointermove", onPointer);
      view.removeEventListener("pointerdown", onPointer);
      view.removeEventListener("pointermove", onPointer);
    };
  }, [active]);

  return (
    <div className="relative overflow-hidden rounded-[1.1rem] bg-black">
      <canvas
        ref={canvasRef}
        width={W}
        height={H}
        tabIndex={0}
        aria-label={`${ARCADE_PET.name} climber. Steer left and right. Bounce up. Avoid glitch pads. Collect Dial ticks.`}
        className="block h-auto w-full cursor-pointer touch-none outline-none focus-visible:ring-3 focus-visible:ring-primary/40"
      />
    </div>
  );
}
