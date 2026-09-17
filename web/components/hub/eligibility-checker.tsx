"use client";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { FCFS_PARTNERS, GTD_PARTNERS } from "@/lib/allowlist-partners";
import { ROBINHOOD_CHAIN_ID } from "@/lib/chain";
import type { EligibilityResult } from "@/lib/eligibility";
import {
  ELIGIBILITY_COPY,
  FCFS_VIA_GTD_REASON,
  parseWalletAddress,
} from "@/lib/eligibility";
import { explorerAddress, shortAddress } from "@/lib/format";
import {
  MANUAL_GTD_REASON,
  MANUAL_GTD_THREAD_URL,
} from "@/lib/manual-gtd-wallets";
import { mintSchedule, SITE } from "@/lib/site";
import { cn } from "@/lib/utils";
import { useMemo, useState, type FormEvent } from "react";
import { useAccount } from "wagmi";

type CheckState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "invalid"; message: string }
  | { status: "error"; message: string }
  | { status: "ok"; result: EligibilityResult };

export function EligibilityChecker({
  compact = false,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  const { address: connected, isConnected } = useAccount();
  const [input, setInput] = useState("");
  const [state, setState] = useState<CheckState>({ status: "idle" });
  const explorer = SITE.explorer;

  const connectedOk = Boolean(connected && parseWalletAddress(connected));

  async function runCheck(raw: string) {
    const parsed = parseWalletAddress(raw);
    if (!parsed) {
      setState({
        status: "invalid",
        message: raw.trim()
          ? ELIGIBILITY_COPY.invalidAddress
          : "Paste a wallet address or use the connected wallet.",
      });
      return;
    }

    setState({ status: "loading" });
    try {
      const response = await fetch(
        `/api/eligibility?address=${encodeURIComponent(parsed)}`,
        { cache: "no-store" },
      );
      const body = (await response.json()) as
        | EligibilityResult
        | { message?: string };
      if (!response.ok) {
        setState({
          status: response.status === 400 ? "invalid" : "error",
          message:
            "message" in body && body.message
              ? body.message
              : "Could not check holdings. Try again in a moment.",
        });
        return;
      }
      setState({ status: "ok", result: body as EligibilityResult });
    } catch {
      setState({
        status: "error",
        message:
          "Could not reach the eligibility checker. Check your connection and try again.",
      });
    }
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    const raw = input.trim() || (connectedOk && connected ? connected : "");
    void runCheck(raw);
  }

  function useConnected() {
    if (!connected) return;
    setInput(connected);
    void runCheck(connected);
  }

  const gtdHoldings =
    state.status === "ok"
      ? state.result.holdings.filter((holding) => holding.phase === "GTD")
      : [];
  const fcfsHoldings =
    state.status === "ok"
      ? state.result.holdings.filter((holding) => holding.phase === "FCFS")
      : [];

  const resultSummary = useMemo(() => {
    if (state.status !== "ok") return null;
    const { gtd, fcfs, manualGtd } = state.result;
    const gtdNft = gtdHoldings.length > 0;
    const fcfsNft = fcfsHoldings.length > 0;
    if (gtd) {
      if (fcfsNft) {
        return "This wallet can mint in GTD and FCFS (and Public). FCFS is yes from FCFS partner NFTs and GTD eligibility. Hub preview — mint still needs mintOpen.";
      }
      if (manualGtd && gtdNft) {
        return "This wallet can mint in GTD via partner NFT and the GTD thread list (and Public). FCFS is included via GTD eligibility.";
      }
      if (manualGtd) {
        return "This wallet can mint in GTD as a GTD thread wallet (and Public). FCFS is included via GTD eligibility.";
      }
      return "This wallet can mint in GTD (and Public). FCFS is included via GTD eligibility.";
    }
    if (fcfs) {
      return "This wallet can mint in FCFS (and Public). GTD needs a GTD partner NFT or a GTD thread wallet.";
    }
    return "No GTD or FCFS partner NFTs, and not on the GTD thread list. Public phase is still open to everyone.";
  }, [state, gtdHoldings.length, fcfsHoldings.length]);

  return (
    <section
      id="eligible"
      className={cn(
        "scroll-mt-28 rounded-[1.6rem] border border-primary/25 bg-card/70 p-5 shadow-[0_0_80px_rgba(240,180,41,0.08)]",
        className,
      )}
    >
      <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
        PHASE ELIGIBILITY · LIVE HOLDINGS + THREAD LIST
      </p>
      <h2 className={cn("mt-3 font-medium", compact ? "text-lg" : "text-xl")}>
        Check GTD / FCFS eligibility
      </h2>
      <p className="mt-2 text-sm text-muted-foreground">
        Paste a wallet (or use the connected one). We read live ERC-721{" "}
        <span className="font-mono text-foreground">balanceOf</span> on{" "}
        {SITE.chain} (chain {ROBINHOOD_CHAIN_ID}) plus wallets from the{" "}
        <a
          href={MANUAL_GTD_THREAD_URL}
          target="_blank"
          rel="noreferrer"
          className="text-foreground underline-offset-2 hover:underline"
        >
          GTD X thread
        </a>
        . GTD-eligible wallets also unlock FCFS phase eligibility. Hub preview
        only — not a Merkle / on-chain mint allowlist. GTD is still unlocked;
        last-minute adds may land before mint.
      </p>

      <form onSubmit={onSubmit} className="mt-4 space-y-3">
        <label className="block space-y-1.5">
          <span className="font-mono text-[11px] tracking-wide text-muted-foreground">
            Wallet address
          </span>
          <input
            value={input}
            onChange={(event) => setInput(event.target.value)}
            placeholder="0x…"
            spellCheck={false}
            autoComplete="off"
            inputMode="text"
            aria-invalid={state.status === "invalid"}
            className="h-9 w-full rounded-lg border border-border bg-background px-3 font-mono text-xs text-foreground outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
          />
        </label>
        <div className="flex flex-wrap items-center gap-2">
          <Button type="submit" disabled={state.status === "loading"}>
            {state.status === "loading" ? "Checking…" : "Check"}
          </Button>
          {isConnected && connectedOk && (
            <Button
              type="button"
              variant="outline"
              onClick={useConnected}
              disabled={state.status === "loading"}
            >
              Use connected wallet
            </Button>
          )}
        </div>
      </form>

      <div className="mt-4" aria-live="polite">
        {state.status === "loading" && (
          <p className="text-sm text-muted-foreground">
            Reading partner balances on {SITE.chain}…
          </p>
        )}
        {state.status === "invalid" && (
          <p className="text-sm text-destructive">{state.message}</p>
        )}
        {state.status === "error" && (
          <p className="text-sm text-destructive">{state.message}</p>
        )}
        {state.status === "ok" && (
          <div className="space-y-3">
            <p className="font-mono text-[11px] text-muted-foreground">
              {shortAddress(state.result.address)} · chain{" "}
              {state.result.chainId}
            </p>
            <div className="grid gap-2 sm:grid-cols-3">
              <PhaseResult
                label="GTD"
                time={mintSchedule.phases[0]?.time}
                yes={state.result.gtd}
              />
              <PhaseResult
                label="FCFS"
                time={mintSchedule.phases[1]?.time}
                yes={state.result.fcfs}
              />
              <PhaseResult
                label="Public"
                time={mintSchedule.phases[2]?.time}
                yes
                note="everyone"
              />
            </div>
            {resultSummary ? (
              <p className="text-sm text-foreground">{resultSummary}</p>
            ) : null}
            <GtdReasons
              manualGtd={state.result.manualGtd}
              holdings={gtdHoldings}
              explorer={explorer}
            />
            <FcfsReasons
              fcfsViaGtd={state.result.fcfsViaGtd}
              holdings={fcfsHoldings}
              explorer={explorer}
            />
            {state.result.failed.length > 0 ? (
              <p className="text-xs text-muted-foreground">
                Could not read {state.result.failed.length} collection
                {state.result.failed.length === 1 ? "" : "s"} (
                {state.result.failed.map((item) => item.name).join(", ")}).
                Results may be incomplete.
              </p>
            ) : null}
          </div>
        )}
      </div>

      {!compact && (
        <div className="mt-5 grid gap-3 sm:grid-cols-2">
          <PartnerList phase="GTD" collections={GTD_PARTNERS} explorer={explorer} />
          <PartnerList
            phase="FCFS"
            collections={FCFS_PARTNERS}
            explorer={explorer}
          />
        </div>
      )}
      {compact && (
        <div className="mt-4 space-y-1 font-mono text-[11px] text-muted-foreground">
          <p>
            GTD: {GTD_PARTNERS.map((item) => item.name).join(" · ")} · GTD
            thread wallets
          </p>
          <p>
            FCFS: {FCFS_PARTNERS.map((item) => item.name).join(" · ")} · GTD
            carryover
          </p>
        </div>
      )}

      <p className="mt-4 text-sm text-muted-foreground">{ELIGIBILITY_COPY.schedule}</p>
      <p className="mt-1 text-sm text-muted-foreground">
        {ELIGIBILITY_COPY.publicNote}
      </p>
      <p className="mt-2 text-xs text-muted-foreground">
        {ELIGIBILITY_COPY.disclaimer}
      </p>
    </section>
  );
}

function PhaseResult({
  label,
  time,
  yes,
  note,
}: {
  label: string;
  time?: string;
  yes: boolean;
  note?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-xl border px-3 py-3",
        yes
          ? "border-primary/40 bg-primary/8"
          : "border-border/70 bg-background/50",
      )}
    >
      <p className="font-mono text-[11px] text-primary">
        {time ?? label}
      </p>
      <p className="mt-1 text-sm font-medium">
        {label}{" "}
        <span className={yes ? "text-primary" : "text-muted-foreground"}>
          {yes ? "yes" : "no"}
        </span>
        {note ? (
          <span className="ml-1 font-normal text-muted-foreground">
            ({note})
          </span>
        ) : null}
      </p>
    </div>
  );
}

function GtdReasons({
  manualGtd,
  holdings,
  explorer,
}: {
  manualGtd: boolean;
  holdings: EligibilityResult["holdings"];
  explorer: string;
}) {
  const empty = !manualGtd && holdings.length === 0;
  return (
    <div>
      <p className="font-mono text-[11px] text-muted-foreground">GTD reasons</p>
      {empty ? (
        <p className="mt-1 text-sm text-muted-foreground">
          No GTD partner NFTs and not on the GTD thread list
        </p>
      ) : (
        <ul className="mt-1 space-y-1">
          {manualGtd ? (
            <li className="text-sm">
              {MANUAL_GTD_REASON}
              <span className="ml-1 font-mono text-xs text-muted-foreground">
                (manual list)
              </span>
            </li>
          ) : null}
          {holdings.map((holding) => (
            <li key={holding.address} className="text-sm">
              <a
                href={explorerAddress(explorer, holding.address)}
                target="_blank"
                rel="noreferrer"
                className="text-foreground underline-offset-2 hover:underline"
              >
                {holding.name}
              </a>
              <span className="ml-1 font-mono text-xs text-muted-foreground">
                × {holding.balance}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function FcfsReasons({
  fcfsViaGtd,
  holdings,
  explorer,
}: {
  fcfsViaGtd: boolean;
  holdings: EligibilityResult["holdings"];
  explorer: string;
}) {
  const empty = !fcfsViaGtd && holdings.length === 0;
  return (
    <div>
      <p className="font-mono text-[11px] text-muted-foreground">FCFS reasons</p>
      {empty ? (
        <p className="mt-1 text-sm text-muted-foreground">
          No FCFS partner NFTs and not GTD-eligible
        </p>
      ) : (
        <ul className="mt-1 space-y-1">
          {fcfsViaGtd ? (
            <li className="text-sm">
              {FCFS_VIA_GTD_REASON}
              <span className="ml-1 font-mono text-xs text-muted-foreground">
                (GTD carryover)
              </span>
            </li>
          ) : null}
          {holdings.map((holding) => (
            <li key={holding.address} className="text-sm">
              <a
                href={explorerAddress(explorer, holding.address)}
                target="_blank"
                rel="noreferrer"
                className="text-foreground underline-offset-2 hover:underline"
              >
                {holding.name}
              </a>
              <span className="ml-1 font-mono text-xs text-muted-foreground">
                × {holding.balance}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function PartnerList({
  phase,
  collections,
  explorer,
}: {
  phase: "GTD" | "FCFS";
  collections: typeof GTD_PARTNERS;
  explorer: string;
}) {
  return (
    <div className="rounded-xl border border-border/70 bg-background/40 px-3 py-3">
      <p className="font-mono text-[11px] text-primary">{phase} partners</p>
      <ul className="mt-2 space-y-1.5">
        {collections.map((collection) => (
          <li
            key={collection.address}
            className="flex items-baseline justify-between gap-2 text-sm"
          >
            <a
              href={explorerAddress(explorer, collection.address)}
              target="_blank"
              rel="noreferrer"
              className="truncate underline-offset-2 hover:underline"
            >
              {collection.name}
            </a>
            <Badge variant="outline" className="font-mono shrink-0">
              {shortAddress(collection.address)}
            </Badge>
          </li>
        ))}
      </ul>
      {phase === "GTD" ? (
        <p className="mt-2 text-xs text-muted-foreground">
          Plus{" "}
          <a
            href={MANUAL_GTD_THREAD_URL}
            target="_blank"
            rel="noreferrer"
            className="underline-offset-2 hover:underline"
          >
            GTD thread wallets
          </a>{" "}
          (manual list — hub preview, not on-chain mint allowlist). GTD also
          unlocks FCFS.
        </p>
      ) : (
        <p className="mt-2 text-xs text-muted-foreground">
          GTD-eligible wallets also unlock FCFS phase eligibility (hub preview).
        </p>
      )}
    </div>
  );
}
