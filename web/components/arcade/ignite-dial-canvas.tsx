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

type Tick = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  symbol: ArcadeTickSymbol;
  points: number;
  flee: boolean;
};

type Glitch = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  phase: number;
  grazed: boolean;
  windup: number;
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
const DASH_PAD = { x: W - 96, y: H - 84, w: 80, h: 64 };

function pickTick(): { symbol: ArcadeTickSymbol; points: number; flee: boolean } {
  if (Math.random() < 0.08) return { symbol: "OMEGA", points: 120, flee: true };
  const pool = ARCADE_TICKS.filter((tick) => tick.symbol !== "OMEGA");
  const tick = pool[Math.floor(Math.random() * pool.length)] ?? pool[0];
  return { ...tick, flee: false };
}

function edge(): { x: number; y: number } {
  const side = Math.floor(Math.random() * 4);
  if (side === 0) return { x: Math.random() * W, y: -18 };
  if (side === 1) return { x: Math.random() * W, y: H + 18 };
  if (side === 2) return { x: -18, y: Math.random() * H };
  return { x: W + 18, y: Math.random() * H };
}

function dist(ax: number, ay: number, bx: number, by: number) {
  return Math.hypot(ax - bx, ay - by);
}

function inDashPad(x: number, y: number) {
  return (
    x >= DASH_PAD.x &&
    x <= DASH_PAD.x + DASH_PAD.w &&
    y >= DASH_PAD.y &&
    y <= DASH_PAD.y + DASH_PAD.h
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
    view.focus();

    const player = {
      x: W / 2,
      y: H / 2,
      vx: 0,
      vy: 0,
      r: 18,
    };
    const keys = {
      left: false,
      right: false,
      up: false,
      down: false,
      dash: false,
    };
    let pointer: { x: number; y: number } | null = null;
    let dashT = 0;
    let dashCd = 0;
    let hitIFrames = 0;
    let shake = 0;
    const ticks: Tick[] = [];
    const glitches: Glitch[] = [];
    const floaters: Floater[] = [];
    const afterimages: Array<{ x: number; y: number; life: number }> = [];
    let score = 0;
    let ticksCaught = 0;
    let glitchesHit = 0;
    let combo = 1;
    let comboT = 0;
    let charge = 100;
    let tickAcc = 0;
    let glitchAcc = 400;
    let last = performance.now();
    const started = last;
    let ended = false;
    let flash = 0;
    let eggImg: HTMLImageElement | null = null;
    let dialRot = 0;

    const img = new Image();
    img.src = "/art/examples/egg/2.gif";
    img.onload = () => {
      eggImg = img;
    };

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

    function toLocal(clientX: number, clientY: number) {
      const rect = view.getBoundingClientRect();
      return {
        x: ((clientX - rect.left) / rect.width) * W,
        y: ((clientY - rect.top) / rect.height) * H,
      };
    }

    function tryDash() {
      if (dashCd > 0 || dashT > 0) return;
      let dx = player.vx;
      let dy = player.vy;
      if (keys.left) dx -= 1;
      if (keys.right) dx += 1;
      if (keys.up) dy -= 1;
      if (keys.down) dy += 1;
      if (pointer) {
        dx = pointer.x - player.x;
        dy = pointer.y - player.y;
      }
      const len = Math.hypot(dx, dy) || 1;
      player.vx = (dx / len) * 680;
      player.vy = (dy / len) * 680;
      dashT = 0.16;
      dashCd = 0.62;
    }

    function spawnTick() {
      const pos = edge();
      const spec = pickTick();
      const towardX = W / 2 - pos.x;
      const towardY = H / 2 - pos.y;
      const len = Math.hypot(towardX, towardY) || 1;
      ticks.push({
        x: pos.x,
        y: pos.y,
        vx: (towardX / len) * (40 + Math.random() * 40),
        vy: (towardY / len) * (40 + Math.random() * 40),
        r: spec.flee ? 15 : 14,
        symbol: spec.symbol,
        points: spec.points,
        flee: spec.flee,
      });
    }

    function spawnGlitch(elapsed: number) {
      const pos = edge();
      glitches.push({
        x: pos.x,
        y: pos.y,
        vx: 0,
        vy: 0,
        r: 13,
        phase: Math.random() * Math.PI * 2,
        grazed: false,
        windup: elapsed < 8_000 ? 0.55 : 0.28,
      });
    }

    const onKey = (event: KeyboardEvent) => {
      const down = event.type === "keydown";
      if (["ArrowLeft", "a", "A"].includes(event.key)) keys.left = down;
      if (["ArrowRight", "d", "D"].includes(event.key)) keys.right = down;
      if (["ArrowUp", "w", "W"].includes(event.key)) keys.up = down;
      if (["ArrowDown", "s", "S"].includes(event.key)) keys.down = down;
      if (event.key === " " || event.key === "Shift") {
        if (down && !keys.dash) tryDash();
        keys.dash = down;
        event.preventDefault();
      }
      if (event.key.startsWith("Arrow") || ["a", "A", "d", "D", "w", "W", "s", "S"].includes(event.key)) {
        event.preventDefault();
      }
    };

    const onPointer = (event: PointerEvent) => {
      const local = toLocal(event.clientX, event.clientY);
      if (event.type === "pointerdown") {
        view.setPointerCapture(event.pointerId);
        if (inDashPad(local.x, local.y)) {
          tryDash();
          return;
        }
        pointer = local;
        return;
      }
      if (event.type === "pointermove" && pointer) {
        if (!inDashPad(local.x, local.y)) pointer = local;
        return;
      }
      if (event.type === "pointerup" || event.type === "pointercancel") {
        pointer = null;
      }
    };

    window.addEventListener("keydown", onKey);
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
      const t = elapsed / 1000;
      const heat = Math.min(1, t / 36);

      dashT = Math.max(0, dashT - dt);
      dashCd = Math.max(0, dashCd - dt);
      hitIFrames = Math.max(0, hitIFrames - dt);
      shake = Math.max(0, shake - dt * 8);
      flash = Math.max(0, flash - dt * 3);
      comboT = Math.max(0, comboT - dt);
      if (comboT <= 0 && combo > 1) combo = 1;
      dialRot += dt * (0.25 + heat);

      let ax = 0;
      let ay = 0;
      if (keys.left) ax -= 1;
      if (keys.right) ax += 1;
      if (keys.up) ay -= 1;
      if (keys.down) ay += 1;
      if (pointer && dashT <= 0) {
        ax = pointer.x - player.x;
        ay = pointer.y - player.y;
        const plen = Math.hypot(ax, ay);
        if (plen < 10) {
          ax = 0;
          ay = 0;
        }
      }
      const alen = Math.hypot(ax, ay);
      if (dashT <= 0) {
        if (alen > 0) {
          const accel = 1680;
          player.vx += (ax / alen) * accel * dt;
          player.vy += (ay / alen) * accel * dt;
        }
        player.vx *= Math.pow(0.08, dt);
        player.vy *= Math.pow(0.08, dt);
        const speed = Math.hypot(player.vx, player.vy);
        const max = 265;
        if (speed > max) {
          player.vx = (player.vx / speed) * max;
          player.vy = (player.vy / speed) * max;
        }
      }
      player.x = Math.max(22, Math.min(W - 22, player.x + player.vx * dt));
      player.y = Math.max(52, Math.min(H - 22, player.y + player.vy * dt));
      if (dashT > 0) {
        afterimages.push({ x: player.x, y: player.y, life: 0.18 });
      }

      const tickEvery = Math.max(0.48, 0.95 - heat * 0.5);
      const glitchEvery = Math.max(0.62, 1.55 - heat * 0.85);
      tickAcc += dt;
      glitchAcc += dt;
      if (tickAcc >= tickEvery && ticks.length < 7) {
        tickAcc = 0;
        spawnTick();
      }
      const glitchCap = t < 8 ? 1 : t < 18 ? 2 : t < 30 ? 3 : 4;
      if (glitchAcc >= glitchEvery && glitches.length < glitchCap) {
        glitchAcc = 0;
        spawnGlitch(elapsed);
      }

      charge -= (3.4 + heat * 1.6) * dt;

      for (const tick of ticks) {
        if (tick.flee) {
          const d = dist(tick.x, tick.y, player.x, player.y) || 1;
          tick.vx += ((tick.x - player.x) / d) * 140 * dt;
          tick.vy += ((tick.y - player.y) / d) * 140 * dt;
        } else {
          tick.vx += (Math.sin(now / 280 + tick.x) * 18 - tick.vx * 0.15) * dt;
          tick.vy += (Math.cos(now / 310 + tick.y) * 18 - tick.vy * 0.15) * dt;
        }
        const spd = Math.hypot(tick.vx, tick.vy);
        const cap = tick.flee ? 150 : 95;
        if (spd > cap) {
          tick.vx = (tick.vx / spd) * cap;
          tick.vy = (tick.vy / spd) * cap;
        }
        tick.x += tick.vx * dt;
        tick.y += tick.vy * dt;
        if (tick.x < -40 || tick.x > W + 40 || tick.y < -40 || tick.y > H + 40) {
          const wrap = edge();
          tick.x = wrap.x;
          tick.y = wrap.y;
        }
      }

      const seek = 95 + heat * 130;
      for (const glitch of glitches) {
        glitch.phase += dt * 6;
        glitch.windup = Math.max(0, glitch.windup - dt);
        const lead = 0.18 + heat * 0.12;
        const tx = player.x + player.vx * lead;
        const ty = player.y + player.vy * lead;
        const d = dist(glitch.x, glitch.y, tx, ty) || 1;
        if (glitch.windup <= 0) {
          glitch.vx += ((tx - glitch.x) / d) * seek * dt;
          glitch.vy += ((ty - glitch.y) / d) * seek * dt;
        }
        const wobble = 42;
        glitch.vx += Math.cos(glitch.phase) * wobble * dt;
        glitch.vy += Math.sin(glitch.phase * 1.3) * wobble * dt;
        const spd = Math.hypot(glitch.vx, glitch.vy);
        const cap = 70 + heat * 110;
        if (spd > cap) {
          glitch.vx = (glitch.vx / spd) * cap;
          glitch.vy = (glitch.vy / spd) * cap;
        }
        glitch.x += glitch.vx * dt;
        glitch.y += glitch.vy * dt;
      }

      for (let i = ticks.length - 1; i >= 0; i -= 1) {
        const tick = ticks[i];
        if (dist(player.x, player.y, tick.x, tick.y) < player.r + tick.r - 2) {
          combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
          comboT = 2.4;
          const gain = tick.points * combo;
          score += gain;
          ticksCaught += 1;
          charge = Math.min(100, charge + 11);
          flash = 0.28;
          float(tick.x, tick.y - 10, `+${gain} ${tick.symbol}`, tick.flee ? "#F0B429" : "#7CFF9A");
          ticks.splice(i, 1);
        }
      }

      const dashing = dashT > 0;
      for (let i = glitches.length - 1; i >= 0; i -= 1) {
        const glitch = glitches[i];
        const d = dist(player.x, player.y, glitch.x, glitch.y);
        if (!glitch.grazed && d < 46 && d > player.r + glitch.r) {
          glitch.grazed = true;
          const gain = 20 * combo;
          score += gain;
          float(glitch.x, glitch.y, `CLOSE +${gain}`, "#c8ffd4");
        }
        if (d < player.r + glitch.r - 1) {
          if (dashing) {
            combo = Math.min(ARCADE_MAX_COMBO, combo + 1);
            comboT = 2.4;
            const gain = 90 * combo;
            score += gain;
            flash = 0.5;
            shake = 0.22;
            float(glitch.x, glitch.y, `IGNITE +${gain}`, "#F0B429");
            glitches.splice(i, 1);
            continue;
          }
          if (hitIFrames <= 0) {
            glitchesHit += 1;
            combo = 1;
            comboT = 0;
            charge -= 30;
            hitIFrames = 0.55;
            shake = 0.35;
            flash = 0.7;
            float(player.x, player.y - 16, "HIT", "#ff6b8a");
            glitches.splice(i, 1);
          }
        }
      }

      for (let i = floaters.length - 1; i >= 0; i -= 1) {
        floaters[i].life -= dt;
        floaters[i].y -= 28 * dt;
        if (floaters[i].life <= 0) floaters.splice(i, 1);
      }
      for (let i = afterimages.length - 1; i >= 0; i -= 1) {
        afterimages[i].life -= dt;
        if (afterimages[i].life <= 0) afterimages.splice(i, 1);
      }

      if (charge <= 0 || remain <= 0) {
        charge = Math.max(0, charge);
        draw(remain, t);
        endRun(now);
        return;
      }

      draw(remain, t);
      frame = requestAnimationFrame(loop);
    }

    function draw(remain: number, t: number) {
      const ox = (Math.random() - 0.5) * shake * 12;
      const oy = (Math.random() - 0.5) * shake * 12;
      g.save();
      g.translate(ox, oy);

      g.fillStyle = "#07110c";
      g.fillRect(-20, -20, W + 40, H + 40);

      g.strokeStyle = "rgba(124,255,154,0.06)";
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

      g.save();
      g.translate(W / 2, H / 2 + 8);
      g.rotate(dialRot);
      g.strokeStyle = "rgba(240,180,41,0.14)";
      g.lineWidth = 2;
      g.beginPath();
      g.arc(0, 0, 132, 0, Math.PI * 2);
      g.stroke();
      const labels = ["AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA"];
      g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillStyle = "rgba(240,180,41,0.28)";
      g.textAlign = "center";
      g.textBaseline = "middle";
      labels.forEach((label, i) => {
        const a = (i / labels.length) * Math.PI * 2;
        g.fillText(label, Math.cos(a) * 148, Math.sin(a) * 148);
      });
      g.restore();

      for (const ghost of afterimages) {
        g.globalAlpha = ghost.life * 2;
        g.fillStyle = "rgba(124,255,154,0.35)";
        g.beginPath();
        g.arc(ghost.x, ghost.y, 14, 0, Math.PI * 2);
        g.fill();
        g.globalAlpha = 1;
      }

      for (const glitch of glitches) {
        g.strokeStyle = "rgba(255,107,138,0.22)";
        g.setLineDash([4, 6]);
        g.beginPath();
        g.moveTo(glitch.x, glitch.y);
        g.lineTo(player.x, player.y);
        g.stroke();
        g.setLineDash([]);
        g.save();
        g.translate(glitch.x, glitch.y);
        g.rotate(glitch.phase * 0.2);
        g.fillStyle = "rgba(180,40,70,0.4)";
        g.strokeStyle = "#ff6b8a";
        g.lineWidth = 1.5;
        g.beginPath();
        g.moveTo(0, -glitch.r);
        g.lineTo(glitch.r, 0);
        g.lineTo(0, glitch.r);
        g.lineTo(-glitch.r, 0);
        g.closePath();
        g.fill();
        g.stroke();
        g.restore();
      }

      for (const tick of ticks) {
        const omega = tick.symbol === "OMEGA";
        g.fillStyle = omega ? "rgba(240,180,41,0.2)" : "rgba(124,255,154,0.14)";
        g.strokeStyle = omega ? "#F0B429" : "#7CFF9A";
        g.lineWidth = 1.5;
        g.beginPath();
        g.arc(tick.x, tick.y, tick.r + 2, 0, Math.PI * 2);
        g.fill();
        g.stroke();
        g.fillStyle = omega ? "#F0B429" : "#c8ffd4";
        g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
        g.textAlign = "center";
        g.textBaseline = "middle";
        g.fillText(tick.symbol, tick.x, tick.y);
      }

      const glow = g.createRadialGradient(player.x, player.y, 4, player.x, player.y, 70);
      glow.addColorStop(0, `rgba(240,180,41,${0.2 + charge / 700})`);
      glow.addColorStop(1, "rgba(240,180,41,0)");
      g.fillStyle = glow;
      g.beginPath();
      g.arc(player.x, player.y, 70, 0, Math.PI * 2);
      g.fill();

      if (eggImg) {
        g.save();
        g.shadowColor = dashT > 0 ? "rgba(240,180,41,0.9)" : "rgba(124,255,154,0.55)";
        g.shadowBlur = dashT > 0 ? 24 : 16;
        g.drawImage(eggImg, player.x - 20, player.y - 24, 40, 48);
        g.restore();
      } else {
        g.fillStyle = "#163222";
        g.strokeStyle = "#7CFF9A";
        g.beginPath();
        g.ellipse(player.x, player.y, 16, 20, 0, 0, Math.PI * 2);
        g.fill();
        g.stroke();
      }

      g.fillStyle = "rgba(124,255,154,0.75)";
      g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.textAlign = "center";
      g.fillText("SEALED", player.x, player.y + 30);

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
      g.fillText("PET LIT", 240, 40);

      const ready = dashCd <= 0;
      g.fillStyle = ready ? "rgba(240,180,41,0.22)" : "rgba(20,30,24,0.72)";
      g.strokeStyle = ready ? "#F0B429" : "rgba(124,255,154,0.25)";
      g.lineWidth = 1.5;
      g.beginPath();
      if (typeof g.roundRect === "function") {
        g.roundRect(DASH_PAD.x, DASH_PAD.y, DASH_PAD.w, DASH_PAD.h, 10);
      } else {
        g.rect(DASH_PAD.x, DASH_PAD.y, DASH_PAD.w, DASH_PAD.h);
      }
      g.fill();
      g.stroke();
      g.fillStyle = ready ? "#F0B429" : "#6a8f74";
      g.font = "11px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.textAlign = "center";
      g.fillText("DASH", DASH_PAD.x + DASH_PAD.w / 2, DASH_PAD.y + 28);
      g.font = "9px ui-monospace, SFMono-Regular, Menlo, monospace";
      g.fillText(ready ? "SPACE" : dashCd.toFixed(1), DASH_PAD.x + DASH_PAD.w / 2, DASH_PAD.y + 44);

      if (flash > 0) {
        g.fillStyle = `rgba(240,180,41,${flash * 0.16})`;
        g.fillRect(0, 0, W, H);
      }
      g.fillStyle = "rgba(0,0,0,0.12)";
      for (let y = 0; y < H; y += 3) g.fillRect(0, y, W, 1);

      g.restore();
      void t;
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
      aria-label="Ignite the Dial. Move with WASD or drag. Dash with space or the DASH pad. Hunt Dial ticks, dash through glitches to ignite them."
      className="h-auto w-full cursor-pointer touch-none rounded-[1.1rem] bg-black outline-none focus-visible:ring-3 focus-visible:ring-primary/40"
    />
  );
}
