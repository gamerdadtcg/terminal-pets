"use client";

import {
  IgniteDialCanvas,
  type ArcadeRunResult,
} from "@/components/arcade/ignite-dial-canvas";
import { ConnectButton } from "@/components/connect-button";
import { Button } from "@/components/ui/button";
import {
  ARCADE_COPY,
  ARCADE_GTD_CAP,
  ARCADE_ROUND_MS,
  arcadeClosesAt,
  arcadeIsClosed,
} from "@/lib/arcade";
import { parseWalletAddress } from "@/lib/eligibility";
import { sealedCopy } from "@/lib/site";
import { cn } from "@/lib/utils";
import { useAccount } from "wagmi";
import {
  useEffect,
  useState,
  type FormEvent,
} from "react";

type BoardRow = {
  rank: number;
  wallet: string;
  short: string;
  score: number;
  ticksCaught: number;
  submittedAt: number;
  gtd: boolean;
};

type BoardResponse = {
  gtdCap: number;
  closed: boolean;
  closesAt: string;
  store: string;
  count: number;
  board: BoardRow[];
  you: { wallet: string; rank: number | null; score: number; gtd: boolean } | null;
};

type Phase = "idle" | "playing" | "ended";

export function ArcadeCabinet() {
  const { address, isConnected } = useAccount();
  const [phase, setPhase] = useState<Phase>("idle");
  const [runToken, setRunToken] = useState<string | null>(null);
  const [result, setResult] = useState<ArcadeRunResult | null>(null);
  const [wallet, setWallet] = useState("");
  const [submitState, setSubmitState] = useState<
    | { status: "idle" }
    | { status: "saving" }
    | { status: "ok"; message: string; rank: number; gtd: boolean; improved: boolean }
    | { status: "error"; message: string }
  >({ status: "idle" });
  const [board, setBoard] = useState<BoardResponse | null>(null);
  const [startError, setStartError] = useState<string | null>(null);
  const closed = arcadeIsClosed() || Boolean(board?.closed);

  const connectedWallet = address && parseWalletAddress(address) ? address : "";
  const walletValue = wallet || connectedWallet;
  const boardWallet = parseWalletAddress(walletValue) ?? "";

  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      const query = boardWallet
        ? `?wallet=${encodeURIComponent(boardWallet)}`
        : "";
      try {
        const response = await fetch(`/api/arcade/board${query}`, {
          cache: "no-store",
        });
        if (!response.ok || cancelled) return;
        const body = (await response.json()) as BoardResponse;
        if (!cancelled) setBoard(body);
      } catch {
        // Keep the last board if a poll fails.
      }
    }
    const id = window.setInterval(() => {
      void refresh();
    }, 12_000);
    void refresh();
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [boardWallet]);

  async function startGame() {
    setStartError(null);
    setSubmitState({ status: "idle" });
    setResult(null);
    try {
      const response = await fetch("/api/arcade/start", { method: "POST" });
      const body = (await response.json()) as {
        runToken?: string;
        message?: string;
      };
      if (!response.ok || !body.runToken) {
        setStartError(body.message ?? "Could not start a run.");
        return;
      }
      setRunToken(body.runToken);
      setPhase("playing");
    } catch {
      setStartError("Could not reach the arcade. Try again.");
    }
  }

  function onEnd(run: ArcadeRunResult) {
    setResult(run);
    setPhase("ended");
  }

  async function submitScore(event: FormEvent) {
    event.preventDefault();
    if (!result || !runToken) return;
    const parsed = parseWalletAddress(walletValue);
    if (!parsed) {
      setSubmitState({
        status: "error",
        message: "Paste a 0x wallet or connect one.",
      });
      return;
    }
    setSubmitState({ status: "saving" });
    try {
      const response = await fetch("/api/arcade/score", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          wallet: parsed,
          score: result.score,
          runToken,
          ticksCaught: result.ticksCaught,
          glitchesHit: result.glitchesHit,
          durationMs: result.durationMs,
        }),
      });
      const body = (await response.json()) as {
        message?: string;
        rank?: number;
        gtd?: boolean;
        improved?: boolean;
      };
      if (!response.ok) {
        setSubmitState({
          status: "error",
          message: body.message ?? "Could not lock that score.",
        });
        return;
      }
      setSubmitState({
        status: "ok",
        message: body.message ?? ARCADE_COPY.accepted,
        rank: body.rank ?? 0,
        gtd: Boolean(body.gtd),
        improved: Boolean(body.improved),
      });
      setRunToken(null);
      void fetch(
        `/api/arcade/board?wallet=${encodeURIComponent(parsed)}`,
        { cache: "no-store" },
      )
        .then((response) => (response.ok ? response.json() : null))
        .then((body: BoardResponse | null) => {
          if (body) setBoard(body);
        })
        .catch(() => undefined);
    } catch {
      setSubmitState({
        status: "error",
        message: "Could not reach the score board.",
      });
    }
  }

  const closeAt = board?.closesAt ?? arcadeClosesAt().toISOString();
  const closeLabel = new Date(closeAt).toLocaleString("en-US", {
    timeZone: "America/Los_Angeles",
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  });

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_minmax(280px,0.85fr)]">
      <div className="arcade-crt relative overflow-hidden rounded-[1.8rem] border border-primary/30 bg-[#07110c] p-3 shadow-[0_0_80px_rgba(124,255,154,0.08)] sm:p-4">
        <div className="pointer-events-none absolute inset-0 arcade-scan" />
        <div className="relative space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2 px-1">
            <p className="font-mono text-[11px] tracking-[0.28em] text-[#7CFF9A]">
              {ARCADE_COPY.badge}
            </p>
            <p className="font-mono text-[11px] text-[#F0B429]">
              {closed ? ARCADE_COPY.closed : `> CLOSE ${closeLabel}`}
            </p>
          </div>

          <div className="relative">
            <IgniteDialCanvas active={phase === "playing"} onEnd={onEnd} />
            {phase !== "playing" ? (
              <div className="absolute inset-0 flex flex-col justify-end rounded-[1.1rem] bg-black/55 p-4 sm:p-6">
                {phase === "idle" ? (
                  <div className="space-y-3">
                    <p className="font-mono text-sm text-[#7CFF9A]">
                      {ARCADE_COPY.prompt}
                      <span className="arcade-cursor">_</span>
                    </p>
                    <p className="font-mono text-xs text-[#c8ffd4]/80">
                      {ARCADE_COPY.play}
                    </p>
                    <p className="max-w-md text-sm text-muted-foreground">
                      {Math.round(ARCADE_ROUND_MS / 1000)}s rounds. Catch Dial
                      ticks ({"AAPL"}–{"TSLA"}, rare OMEGA). Dodge glitches.
                      Keep the sealed pet lit. Top {ARCADE_GTD_CAP} wallets lock
                      GTD (and FCFS via GTD). {sealedCopy.carousel}
                    </p>
                    {startError ? (
                      <p className="text-sm text-destructive">{startError}</p>
                    ) : null}
                    <div className="flex flex-wrap gap-2">
                      <Button onClick={() => void startGame()} disabled={closed}>
                        {closed ? "Contest closed" : "Play"}
                      </Button>
                      <p className="self-center font-mono text-[11px] text-muted-foreground">
                        Arrows / A D / drag
                      </p>
                    </div>
                  </div>
                ) : null}
                {phase === "ended" && result ? (
                  <div className="space-y-3">
                    <p className="font-mono text-sm text-[#7CFF9A]">
                      {ARCADE_COPY.locked}
                      <span className="arcade-cursor">_</span>
                    </p>
                    <p className="text-3xl font-semibold tracking-tight text-[#F0B429]">
                      {result.score}
                    </p>
                    <p className="font-mono text-xs text-[#c8ffd4]/80">
                      {result.ticksCaught} ticks · {result.glitchesHit} glitches
                      · {(result.durationMs / 1000).toFixed(1)}s
                    </p>
                    <form onSubmit={(event) => void submitScore(event)} className="space-y-2">
                      <label className="block space-y-1">
                        <span className="font-mono text-[11px] text-muted-foreground">
                          Wallet to lock
                        </span>
                        <input
                          value={walletValue}
                          onChange={(event) => setWallet(event.target.value)}
                          placeholder="0x…"
                          spellCheck={false}
                          autoComplete="off"
                          className="h-9 w-full rounded-lg border border-[#7CFF9A]/30 bg-black/40 px-3 font-mono text-xs text-[#c8ffd4] outline-none focus-visible:ring-3 focus-visible:ring-[#7CFF9A]/40"
                        />
                      </label>
                      <div className="flex flex-wrap items-center gap-2">
                        <Button
                          type="submit"
                          disabled={submitState.status === "saving" || closed}
                        >
                          {submitState.status === "saving"
                            ? "Locking…"
                            : "Lock score"}
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          onClick={() => void startGame()}
                          disabled={closed}
                        >
                          Play again
                        </Button>
                        {isConnected ? <ConnectButton /> : null}
                      </div>
                    </form>
                    {submitState.status === "ok" ? (
                      <p className="font-mono text-xs text-[#7CFF9A]">
                        {submitState.message} · rank {submitState.rank} ·{" "}
                        {submitState.gtd
                          ? ARCADE_COPY.gtd
                          : ARCADE_COPY.warm}
                      </p>
                    ) : null}
                    {submitState.status === "error" ? (
                      <p className="text-sm text-destructive">
                        {submitState.message}
                      </p>
                    ) : null}
                    {!isConnected ? (
                      <div className="pt-1">
                        <ConnectButton />
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>
      </div>

      <aside className="space-y-4">
        <div className="rounded-[1.6rem] border border-primary/25 bg-card/70 p-5">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            LIVE BOARD · {ARCADE_GTD_CAP} GTD
          </p>
          <h2 className="mt-2 text-lg font-medium">Hatch Score</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            One best score per wallet. Ties go to the earlier lock. Ranks 151+
            stay warm until they climb. Hub preview — not an on-chain mint
            allowlist.
          </p>
          {board?.you?.rank ? (
            <p className="mt-3 font-mono text-xs text-primary">
              Your rank {board.you.rank} · {board.you.score} pts ·{" "}
              {board.you.gtd ? "GTD LOCKED" : "WARM"}
            </p>
          ) : (
            <p className="mt-3 font-mono text-xs text-muted-foreground">
              {board?.count ?? 0} wallets on the board
            </p>
          )}
          <ol className="mt-4 max-h-[28rem] space-y-1 overflow-auto pr-1">
            {!board ? (
              <li className="px-2 py-6 text-center text-sm text-muted-foreground">
                Loading board…
              </li>
            ) : null}
            {(board?.board ?? []).map((row) => (
              <li
                key={row.wallet}
                className={cn(
                  "flex items-baseline justify-between gap-2 rounded-lg px-2 py-1.5 font-mono text-[11px]",
                  row.gtd
                    ? "bg-primary/10 text-foreground"
                    : "text-muted-foreground",
                )}
              >
                <span>
                  <span className="mr-2 text-primary">{row.rank}</span>
                  {row.short}
                </span>
                <span className="shrink-0">
                  {row.score}
                  {row.gtd ? (
                    <span className="ml-2 text-[10px] tracking-wide text-primary">
                      GTD
                    </span>
                  ) : (
                    <span className="ml-2 text-[10px] tracking-wide">WARM</span>
                  )}
                </span>
              </li>
            ))}
            {!board?.board.length && board ? (
              <li className="px-2 py-6 text-center text-sm text-muted-foreground">
                No scores yet. First ticks lock the board.
              </li>
            ) : null}
          </ol>
        </div>
      </aside>
    </div>
  );
}
