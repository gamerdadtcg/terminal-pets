"use client";

import {
  ARCADE_MAX_COMBO,
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

type Kind = "tick" | "glitch";

type Entity = {
  kind: Kind;
  x: number;
  y: number;
  w: number;
  h: number;
  vy: number;
  symbol?: ArcadeTickSymbol;
  points?: number;
  rot: number;
};

const W = 640;
const H = 420;

function pickTick(): { symbol: ArcadeTickSymbol; points: number } {
  const roll = Math.random();
  if (roll < 0.07) return { symbol: "OMEGA", points: 120 };
  const pool = ARCADE_TICKS.filter((tick) => tick.symbol !== "OMEGA");
  return pool[Math.floor(Math.random() * pool.length)] ?? pool[0];
}

function hit(a: { x: number; y: number; w: number; h: number }, b: Entity) {
  return (
    a.x < b.x + b.w &&
    a.x + a.w > b.x &&
    a.y < b.y + b.h &&
    a.y + a.h > b.y
  );
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
    if (!canvas || !active) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const view = canvas;
    const g = ctx;

    const player = { x: W / 2 - 26, y: H - 78, w: 52, h: 62, vx: 0 };
    const keys = { left: false, right: false };
    let pointerX: number | null = null;
    const entities: Entity[] = [];
    let score = 0;
    let ticksCaught = 0;
    let glitchesHit = 0;
    let combo = 1;
    let charge = 100;
    let spawnAcc = 0;
    let spawnEvery = 1080;
    let last = performance.now();
    const started = last;
    let ended = false;
    let flash = 0;
    let eggImg: HTMLImageElement | null = null;

    const img = new Image();
    img.src = "/art/examples/egg/2.gif";
    img.onload = () => {
      eggImg = img;
    };

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

    function spawn() {
      const elapsed = performance.now() - started;
      const glitchChance = 0.18 + Math.min(0.16, elapsed / 280_000);
      if (Math.random() < glitchChance) {
        entities.push({
          kind: "glitch",
          x: 18 + Math.random() * (W - 56),
          y: -28,
          w: 34,
          h: 28,
          vy: 95 + elapsed / 220,
          rot: (Math.random() - 0.5) * 0.4,
        });
        return;
      }
      const tick = pickTick();
      entities.push({
        kind: "tick",
        x: 16 + Math.random() * (W - 88),
        y: -26,
        w: 72,
        h: 26,
        vy: 88 + elapsed / 240 + (tick.symbol === "OMEGA" ? 18 : 0),
        symbol: tick.symbol,
        points: tick.points,
        rot: (Math.random() - 0.5) * 0.2,
      });
    }

    function toCanvasX(clientX: number) {
      const rect = view.getBoundingClientRect();
      return ((clientX - rect.left) / rect.width) * W;
    }

    const onKey = (event: KeyboardEvent) => {
      if (event.key === "ArrowLeft" || event.key === "a" || event.key === "A") {
        keys.left = event.type === "keydown";
        event.preventDefault();
      }
      if (event.key === "ArrowRight" || event.key === "d" || event.key === "D") {
        keys.right = event.type === "keydown";
        event.preventDefault();
      }
    };

    const onPointer = (event: PointerEvent) => {
      if (event.type === "pointerup" || event.type === "pointercancel") {
        pointerX = null;
        return;
      }
      pointerX = toCanvasX(event.clientX);
    };

    window.addEventListener("keydown", onKey, { passive: false });
    window.addEventListener("keyup", onKey);
    view.addEventListener("pointerdown", onPointer);
    view.addEventListener("pointermove", onPointer);
    view.addEventListener("pointerup", onPointer);
    view.addEventListener("pointercancel", onPointer);

    let frame = 0;
    function loop(now: number) {
      if (ended) return;
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      const elapsed = now - started;
      const remain = Math.max(0, ARCADE_ROUND_MS - elapsed);

      if (keys.left) player.vx = -340;
      else if (keys.right) player.vx = 340;
      else if (pointerX !== null) {
        const target = pointerX - player.w / 2;
        player.vx = Math.max(-420, Math.min(420, (target - player.x) * 8));
      } else {
        player.vx *= 0.78;
      }
      player.x = Math.max(8, Math.min(W - player.w - 8, player.x + player.vx * dt));

      spawnEvery = Math.max(460, 1080 - elapsed / 55);
      spawnAcc += dt * 1000;
      if (spawnAcc >= spawnEvery) {
        spawnAcc = 0;
        spawn();
      }

      charge -= (6.2 + elapsed / 40_000) * dt;
      flash = Math.max(0, flash - dt * 3);

      for (const entity of entities) {
        entity.y += entity.vy * dt;
        entity.rot += dt * (entity.kind === "glitch" ? 2 : 0.4);
      }

      for (let i = entities.length - 1; i >= 0; i -= 1) {
        const entity = entities[i];
        if (hit(player, entity)) {
          if (entity.kind === "tick") {
            const gain = (entity.points ?? 50) * combo;
            score += gain;
            ticksCaught += 1;
            combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
            charge = Math.min(100, charge + 16);
            flash = 0.45;
          } else {
            glitchesHit += 1;
            combo = 1;
            charge -= 26;
            flash = 0.8;
          }
          entities.splice(i, 1);
          continue;
        }
        if (entity.y > H + 20) {
          if (entity.kind === "tick") {
            combo = 1;
            charge -= 5;
          }
          entities.splice(i, 1);
        }
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
      g.fillStyle = "#07110c";
      g.fillRect(0, 0, W, H);

      g.strokeStyle = "rgba(124,255,154,0.07)";
      g.lineWidth = 1;
      for (let x = 0; x < W; x += 28) {
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

      const glow = g.createRadialGradient(
        player.x + player.w / 2,
        player.y + 10,
        8,
        player.x + player.w / 2,
        player.y,
        90,
      );
      glow.addColorStop(0, `rgba(240,180,41,${0.16 + charge / 900})`);
      glow.addColorStop(1, "rgba(240,180,41,0)");
      g.fillStyle = glow;
      g.fillRect(0, 0, W, H);

      g.fillStyle = "rgba(8,18,12,0.72)";
      g.fillRect(10, 8, W - 20, 46);
      g.strokeStyle = "rgba(124,255,154,0.35)";
      g.strokeRect(10.5, 8.5, W - 21, 45);

      g.font = "12px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillStyle = "#7CFF9A";
      g.fillText(`SCORE ${score}`, 22, 28);
      g.fillStyle = "#F0B429";
      g.fillText(`COMBO x${combo}`, 150, 28);
      g.fillStyle = "#9ad7aa";
      g.fillText(`T ${Math.ceil(remain / 1000)}s`, W - 86, 28);

      g.fillStyle = "rgba(124,255,154,0.15)";
      g.fillRect(22, 36, 200, 8);
      g.fillStyle = charge > 28 ? "#7CFF9A" : "#F0B429";
      g.fillRect(22, 36, 2 * Math.max(0, charge), 8);
      g.fillStyle = "#7CFF9A";
      g.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillText("PET LIT", 230, 44);

      for (const entity of entities) {
        g.save();
        g.translate(entity.x + entity.w / 2, entity.y + entity.h / 2);
        g.rotate(entity.rot * 0.15);
        if (entity.kind === "tick") {
          const omega = entity.symbol === "OMEGA";
          g.fillStyle = omega ? "rgba(240,180,41,0.2)" : "rgba(124,255,154,0.12)";
          g.strokeStyle = omega ? "#F0B429" : "#7CFF9A";
          g.lineWidth = 1.4;
          g.beginPath();
          if (typeof g.roundRect === "function") {
            g.roundRect(-entity.w / 2, -entity.h / 2, entity.w, entity.h, 4);
          } else {
            g.rect(-entity.w / 2, -entity.h / 2, entity.w, entity.h);
          }
          g.fill();
          g.stroke();
          g.fillStyle = omega ? "#F0B429" : "#c8ffd4";
          g.font = "11px ui-monospace, SFMono-Regular, Menlo, monospace";
          g.textAlign = "center";
          g.textBaseline = "middle";
          g.fillText(entity.symbol ?? "TICK", 0, 1);
          g.textAlign = "start";
          g.textBaseline = "alphabetic";
        } else {
          g.fillStyle = "rgba(180,40,70,0.35)";
          g.strokeStyle = "#ff6b8a";
          g.lineWidth = 1.4;
          g.fillRect(-entity.w / 2, -entity.h / 2, entity.w, entity.h);
          g.strokeRect(-entity.w / 2, -entity.h / 2, entity.w, entity.h);
          g.fillStyle = "#ffd0da";
          g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
          g.textAlign = "center";
          g.textBaseline = "middle";
          g.fillText("GLITCH", 0, 1);
          g.textAlign = "start";
          g.textBaseline = "alphabetic";
          for (let n = 0; n < 5; n += 1) {
            g.fillStyle = `rgba(255,255,255,${0.12 + Math.random() * 0.2})`;
            g.fillRect(
              -entity.w / 2 + Math.random() * entity.w,
              -entity.h / 2 + Math.random() * entity.h,
              3,
              2,
            );
          }
        }
        g.restore();
      }

      const px = player.x;
      const py = player.y;
      if (eggImg) {
        g.save();
        g.shadowColor = "rgba(124,255,154,0.55)";
        g.shadowBlur = 18;
        g.drawImage(eggImg, px, py, player.w, player.h);
        g.restore();
      } else {
        g.fillStyle = "#163222";
        g.strokeStyle = "#7CFF9A";
        g.beginPath();
        g.ellipse(px + player.w / 2, py + 28, 20, 26, 0, 0, Math.PI * 2);
        g.fill();
        g.stroke();
      }

      g.fillStyle = "rgba(124,255,154,0.8)";
      g.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillText("SEALED", px + 8, py + player.h + 12);

      if (flash > 0) {
        g.fillStyle = `rgba(240,180,41,${flash * 0.18})`;
        g.fillRect(0, 0, W, H);
      }

      g.fillStyle = "rgba(0,0,0,0.12)";
      for (let y = 0; y < H; y += 3) {
        g.fillRect(0, y, W, 1);
      }
    }

    frame = requestAnimationFrame(loop);

    return () => {
      ended = true;
      cancelAnimationFrame(frame);
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("keyup", onKey);
      view.removeEventListener("pointerdown", onPointer);
      view.removeEventListener("pointermove", onPointer);
      view.removeEventListener("pointerup", onPointer);
      view.removeEventListener("pointercancel", onPointer);
    };
  }, [active]);

  return (
    <canvas
      ref={canvasRef}
      width={W}
      height={H}
      tabIndex={0}
      aria-label="Ignite the Dial arcade. Move with arrows, A D, or touch. Catch Dial ticks and dodge glitches."
      className="h-auto w-full cursor-pointer touch-none rounded-[1.1rem] bg-black outline-none focus-visible:ring-3 focus-visible:ring-primary/40"
    />
  );
}
