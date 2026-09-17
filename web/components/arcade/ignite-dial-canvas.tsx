"use client";

import {
  ARCADE_MAX_COMBO,
  ARCADE_PET,
  ARCADE_ROUND_MS,
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

type Panel = {
  x: number;
  y: number;
  w: number;
  h: number;
  scored: boolean;
  hit: boolean;
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
const GROUND = H - 54;
const PET_W = 52;
const PET_H = 52;
const GRAVITY = 2450;
const JUMP_V = -640;
const HOLD_GRAVITY = 1280;

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

export function IgniteDialCanvas({
  active,
  onEnd,
}: {
  active: boolean;
  onEnd: (result: ArcadeRunResult) => void;
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const petRef = useRef<HTMLImageElement | null>(null);
  const onEndRef = useRef(onEnd);

  useEffect(() => {
    onEndRef.current = onEnd;
  }, [onEnd]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const sprite = petRef.current;
    if (!canvas || !active) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const view = canvas;
    const g = ctx;
    view.focus();

    const pet = {
      x: 118,
      y: GROUND - PET_H,
      vy: 0,
      grounded: true,
      jumps: 2,
    };
    let holding = false;
    let coyote = 0;
    let jumpBuf = 0;
    let hitIFrames = 0;
    let shake = 0;
    let flash = 0;
    const panels: Panel[] = [];
    const pickups: Pickup[] = [];
    const floaters: Floater[] = [];
    let score = 0;
    let ticksCaught = 0;
    let glitchesHit = 0;
    let combo = 1;
    let comboT = 0;
    let charge = 100;
    let spawnAcc = 0.9;
    let last = performance.now();
    const started = last;
    let ended = false;
    let scrollX = 0;

    function float(x: number, y: number, text: string, color: string) {
      floaters.push({ x, y, text, life: 0.7, color });
    }

    function endRun(now: number) {
      if (ended) return;
      ended = true;
      if (sprite) sprite.style.opacity = "0";
      onEndRef.current({
        score,
        ticksCaught,
        glitchesHit,
        durationMs: Math.round(now - started),
      });
    }

    function jump() {
      if (pet.grounded || coyote > 0) {
        pet.vy = JUMP_V;
        pet.grounded = false;
        coyote = 0;
        jumpBuf = 0;
        pet.jumps = 1;
        return;
      }
      if (pet.jumps > 0) {
        pet.jumps -= 1;
        pet.vy = JUMP_V;
        jumpBuf = 0;
        return;
      }
      jumpBuf = 0.12;
    }

    function placePet(rot = 0) {
      if (!sprite) return;
      sprite.style.left = `${(pet.x / W) * 100}%`;
      sprite.style.top = `${(pet.y / H) * 100}%`;
      sprite.style.transform = `rotate(${rot}deg)`;
    }

    function spawn(elapsed: number) {
      const heat = Math.min(1, elapsed / 34_000);
      const x = W + 30;
      const roll = Math.random();
      if (roll < 0.42) {
        const h = 36 + heat * 22 + Math.random() * 10;
        panels.push({
          x,
          y: GROUND - h,
          w: 38 + heat * 16,
          h,
          scored: false,
          hit: false,
        });
        if (Math.random() < 0.7) {
          const tick = pickTick();
          pickups.push({
            x: x + 18,
            y: GROUND - h - 58,
            r: 14,
            symbol: tick.symbol,
            points: tick.points,
          });
        }
        return;
      }
      if (roll < 0.68) {
        const h = 86 + heat * 50;
        panels.push({
          x,
          y: 48,
          w: 44 + heat * 10,
          h,
          scored: false,
          hit: false,
        });
        const tick = pickTick();
        pickups.push({
          x: x + 22,
          y: GROUND - 36,
          r: 14,
          symbol: tick.symbol,
          points: tick.points,
        });
        return;
      }
      const gap = 124 - heat * 32;
      const minTop = 58;
      const maxTop = GROUND - gap - 36;
      const topH = minTop + Math.random() * Math.max(20, maxTop - minTop - 48);
      panels.push({
        x,
        y: 48,
        w: 48,
        h: topH,
        scored: false,
        hit: false,
      });
      panels.push({
        x,
        y: 48 + topH + gap,
        w: 48,
        h: GROUND - (48 + topH + gap),
        scored: false,
        hit: false,
      });
      const tick = pickTick();
      pickups.push({
        x: x + 24,
        y: 48 + topH + gap / 2,
        r: tick.symbol === "OMEGA" ? 16 : 14,
        symbol: tick.symbol,
        points: tick.points,
      });
    }

    const onKey = (event: KeyboardEvent) => {
      if (event.key === " " || event.key === "ArrowUp" || event.key === "w" || event.key === "W") {
        if (event.type === "keydown" && !event.repeat) jump();
        holding = event.type === "keydown";
        event.preventDefault();
      }
    };

    const onPointer = (event: PointerEvent) => {
      if (event.type === "pointerdown") {
        holding = true;
        jump();
        event.preventDefault();
      }
      if (event.type === "pointerup" || event.type === "pointercancel") {
        holding = false;
      }
    };

    window.addEventListener("keydown", onKey);
    window.addEventListener("keyup", onKey);
    view.addEventListener("pointerdown", onPointer);
    view.addEventListener("pointerup", onPointer);
    view.addEventListener("pointercancel", onPointer);

    let frame = 0;
    function loop(now: number) {
      if (ended) return;
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      const elapsed = now - started;
      const remain = Math.max(0, ARCADE_ROUND_MS - elapsed);
      const heat = Math.min(1, elapsed / 36_000);
      const speed = 210 + heat * 140;

      hitIFrames = Math.max(0, hitIFrames - dt);
      shake = Math.max(0, shake - dt * 8);
      flash = Math.max(0, flash - dt * 3);
      comboT = Math.max(0, comboT - dt);
      if (comboT <= 0 && combo > 1) combo = 1;
      coyote = Math.max(0, coyote - dt);
      jumpBuf = Math.max(0, jumpBuf - dt);
      scrollX += speed * dt;

      const grav = holding && pet.vy < 0 ? HOLD_GRAVITY : GRAVITY;
      pet.vy = Math.min(820, pet.vy + grav * dt);
      pet.y += pet.vy * dt;

      if (pet.y + PET_H >= GROUND) {
        pet.y = GROUND - PET_H;
        pet.vy = 0;
        if (!pet.grounded) pet.jumps = 1;
        pet.grounded = true;
        coyote = 0.09;
        if (jumpBuf > 0) jump();
      } else {
        if (pet.grounded) coyote = 0.09;
        pet.grounded = false;
      }
      if (pet.y < 50) {
        pet.y = 50;
        if (pet.vy < 0) pet.vy = 0;
      }

      spawnAcc += dt;
      const every = Math.max(0.78, 1.28 - heat * 0.5);
      if (spawnAcc >= every) {
        spawnAcc = 0;
        spawn(elapsed);
      }

      for (const panel of panels) panel.x -= speed * dt;
      for (const pickup of pickups) pickup.x -= speed * dt;

      charge -= (2.6 + heat * 1.4) * dt;

      const hitbox = {
        x: pet.x + 10,
        y: pet.y + 10,
        w: PET_W - 20,
        h: PET_H - 16,
      };

      for (let i = panels.length - 1; i >= 0; i -= 1) {
        const panel = panels[i];
        if (
          !panel.hit &&
          hitIFrames <= 0 &&
          aabb(hitbox.x, hitbox.y, hitbox.w, hitbox.h, panel.x, panel.y, panel.w, panel.h)
        ) {
          panel.hit = true;
          glitchesHit += 1;
          combo = 1;
          comboT = 0;
          charge -= 24;
          hitIFrames = 0.7;
          shake = 0.32;
          flash = 0.55;
          pet.vy = -220;
          float(pet.x + 20, pet.y, "PENALTY", "#ff6b8a");
        }
        if (!panel.scored && !panel.hit && panel.x + panel.w < pet.x) {
          panel.scored = true;
          combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
          comboT = 2.2;
          const gain = 40 * combo;
          score += gain;
          charge = Math.min(100, charge + 6);
          float(pet.x + 24, pet.y - 8, `CLEAR +${gain}`, "#7CFF9A");
        }
        if (panel.x + panel.w < -40) panels.splice(i, 1);
      }

      for (let i = pickups.length - 1; i >= 0; i -= 1) {
        const pickup = pickups[i];
        const dx = pet.x + PET_W / 2 - pickup.x;
        const dy = pet.y + PET_H / 2 - pickup.y;
        if (Math.hypot(dx, dy) < pickup.r + 16) {
          combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
          comboT = 2.4;
          const gain = pickup.points * combo;
          score += gain;
          ticksCaught += 1;
          charge = Math.min(100, charge + 10);
          float(pickup.x, pickup.y - 8, `+${gain} ${pickup.symbol}`, "#F0B429");
          pickups.splice(i, 1);
          continue;
        }
        if (pickup.x < -30) pickups.splice(i, 1);
      }

      for (let i = floaters.length - 1; i >= 0; i -= 1) {
        floaters[i].life -= dt;
        floaters[i].y -= 26 * dt;
        if (floaters[i].life <= 0) floaters.splice(i, 1);
      }

      if (sprite) {
        const rot = Math.max(-18, Math.min(22, pet.vy * 0.028));
        sprite.style.opacity =
          hitIFrames > 0 && Math.floor(now / 80) % 2 === 0 ? "0.45" : "1";
        placePet(rot);
      }

      if (charge <= 0 || remain <= 0) {
        charge = Math.max(0, charge);
        draw(remain);
        endRun(now);
        return;
      }

      draw(remain);
      frame = requestAnimationFrame(loop);
    }

    function draw(remain: number) {
      const ox = (Math.random() - 0.5) * shake * 10;
      const oy = (Math.random() - 0.5) * shake * 6;
      g.save();
      g.translate(ox, oy);
      g.fillStyle = "#07110c";
      g.fillRect(-16, -16, W + 32, H + 32);

      g.strokeStyle = "rgba(124,255,154,0.06)";
      for (let x = -((scrollX * 0.4) % 28); x < W; x += 28) {
        g.beginPath();
        g.moveTo(x, 0);
        g.lineTo(x, H);
        g.stroke();
      }
      for (let y = 0; y < H; y += 28) {
        g.beginPath();
        g.moveTo(0, y);
        g.lineTo(W, y);
        g.stroke();
      }

      g.fillStyle = "#0b1810";
      g.fillRect(0, GROUND, W, H - GROUND);
      g.strokeStyle = "rgba(124,255,154,0.45)";
      g.beginPath();
      g.moveTo(0, GROUND + 0.5);
      g.lineTo(W, GROUND + 0.5);
      g.stroke();
      g.fillStyle = "rgba(124,255,154,0.12)";
      for (let x = -((scrollX) % 26); x < W; x += 26) {
        g.fillRect(x, GROUND + 6, 14, 3);
      }

      for (const panel of panels) {
        g.fillStyle = panel.hit ? "rgba(120,30,50,0.55)" : "rgba(180,40,70,0.38)";
        g.strokeStyle = "#ff6b8a";
        g.lineWidth = 1.6;
        g.fillRect(panel.x, panel.y, panel.w, panel.h);
        g.strokeRect(panel.x + 0.5, panel.y + 0.5, panel.w - 1, panel.h - 1);
        g.fillStyle = "rgba(255,255,255,0.08)";
        for (let n = 0; n < 7; n += 1) {
          g.fillRect(
            panel.x + 3,
            panel.y + 4 + n * 7,
            panel.w - 6,
            2,
          );
        }
        if (panel.h > 28) {
          g.fillStyle = "#ffd0da";
          g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
          g.textAlign = "center";
          g.textBaseline = "middle";
          g.save();
          g.translate(panel.x + panel.w / 2, panel.y + panel.h / 2);
          g.rotate(-Math.PI / 2);
          g.fillText("GLITCH", 0, 0);
          g.restore();
        }
      }

      for (const pickup of pickups) {
        const omega = pickup.symbol === "OMEGA";
        g.fillStyle = omega ? "rgba(240,180,41,0.22)" : "rgba(124,255,154,0.16)";
        g.strokeStyle = omega ? "#F0B429" : "#7CFF9A";
        g.beginPath();
        g.arc(pickup.x, pickup.y, pickup.r, 0, Math.PI * 2);
        g.fill();
        g.stroke();
        g.fillStyle = omega ? "#F0B429" : "#c8ffd4";
        g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
        g.textAlign = "center";
        g.textBaseline = "middle";
        g.fillText(pickup.symbol, pickup.x, pickup.y);
      }

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
      g.fillText(`T ${Math.ceil(remain / 1000)}s`, W - 92, 26);
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

    if (sprite) {
      sprite.style.opacity = "1";
      placePet(0);
    }

    frame = requestAnimationFrame(loop);

    return () => {
      ended = true;
      cancelAnimationFrame(frame);
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("keyup", onKey);
      view.removeEventListener("pointerdown", onPointer);
      view.removeEventListener("pointerup", onPointer);
      view.removeEventListener("pointercancel", onPointer);
      if (sprite) sprite.style.opacity = "0";
    };
  }, [active]);

  return (
    <div className="relative overflow-hidden rounded-[1.1rem] bg-black">
      <canvas
        ref={canvasRef}
        width={W}
        height={H}
        tabIndex={0}
        aria-label={`${ARCADE_PET.name} jumper. Tap or space to jump. Avoid glitch panels. Collect Dial ticks.`}
        className="block h-auto w-full cursor-pointer touch-none outline-none focus-visible:ring-3 focus-visible:ring-primary/40"
      />
      {/* Native img so the example SNAG GIF animates as an overlay. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        ref={petRef}
        src={ARCADE_PET.src}
        alt={`${ARCADE_PET.name} example pet, not mint supply`}
        width={PET_W}
        height={PET_H}
        draggable={false}
        className="pointer-events-none absolute top-0 left-0 origin-center object-contain opacity-0"
        style={{
          width: `${(PET_W / W) * 100}%`,
          height: "auto",
          aspectRatio: "1 / 1",
        }}
      />
    </div>
  );
}
