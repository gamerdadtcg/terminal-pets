"use client";

import { PetImage } from "@/components/pet-image";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  dialRewardLabels,
  joinLabels,
  shellRarity,
  type DialView,
} from "@/lib/dial";
import { addresses, erc20Abi, zeroAddress } from "@/lib/contracts";
import { formatEthTrim, formatTerm, payoutLockCopy } from "@/lib/format";
import type { Address } from "viem";
import { useEffect } from "react";
import { useReadContract } from "wagmi";

type Props = {
  tokenId: bigint;
  lit?: boolean;
  pending?: bigint;
  igniteFeeEth?: bigint;
  igniteFeeTerm?: bigint;
  allotmentConsumed?: boolean;
  igniteStatus: "loading" | "open" | "closed" | "unknown";
  owner?: Address;
  busy?: boolean;
  justAwoke?: boolean;
  dial?: DialView | null;
  hopperUnlocked?: boolean;
  hopperUnlockTime?: bigint;
  refreshKey?: string;
  onIgnite: () => void;
  onApprove: () => void;
  onClaim: () => void;
};

export function TokenCard({
  tokenId,
  lit,
  pending,
  igniteFeeEth,
  igniteFeeTerm,
  allotmentConsumed,
  igniteStatus,
  owner,
  busy,
  justAwoke,
  dial,
  hopperUnlocked,
  hopperUnlockTime,
  refreshKey,
  onIgnite,
  onApprove,
  onClaim,
}: Props) {
  const needsWalletTerm = Boolean(!lit && allotmentConsumed);
  const allowance = useReadContract({
    address: addresses.term,
    abi: erc20Abi,
    functionName: "allowance",
    args: owner ? [owner, addresses.ignite] : undefined,
    query: {
      enabled:
        needsWalletTerm &&
        Boolean(owner) &&
        addresses.term !== zeroAddress &&
        addresses.ignite !== zeroAddress,
    },
  });
  const balance = useReadContract({
    address: addresses.term,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: owner ? [owner] : undefined,
    query: {
      enabled: needsWalletTerm && Boolean(owner) && addresses.term !== zeroAddress,
    },
  });
  const { refetch: refetchAllowance } = allowance;
  const { refetch: refetchBalance } = balance;

  useEffect(() => {
    if (!refreshKey || !needsWalletTerm) return;
    void refetchAllowance();
    void refetchBalance();
  }, [refreshKey, needsWalletTerm, refetchAllowance, refetchBalance]);

  const feeReady = igniteFeeEth !== undefined;
  const feeLabel = feeReady ? formatEthTrim(igniteFeeEth) : null;
  const termLabel =
    igniteFeeTerm !== undefined ? formatTerm(igniteFeeTerm) : "1,000 $TERM";
  const allowed = allowance.data;
  const held = balance.data;
  const approvalLoading = needsWalletTerm && allowance.isLoading;
  const needsApproval =
    needsWalletTerm &&
    igniteFeeTerm !== undefined &&
    allowed !== undefined &&
    allowed < igniteFeeTerm;
  const shortTerm =
    needsWalletTerm &&
    igniteFeeTerm !== undefined &&
    held !== undefined &&
    held < igniteFeeTerm;
  const igniteBlocked =
    busy ||
    !feeReady ||
    igniteStatus === "loading" ||
    igniteStatus === "closed" ||
    needsApproval ||
    approvalLoading ||
    shortTerm;
  const payoutCopy = payoutLockCopy(hopperUnlocked, hopperUnlockTime);
  const rewards = dial && dial.nLegs > 0 ? dialRewardLabels(dial) : [];
  const rewardLine = joinLabels(rewards);
  const rarity = dial ? shellRarity(dial.shellClass) : null;
  const hasTermFallback = rewards.includes("$TERM");
  const waiting = pending ?? BigInt(0);
  const canCollect = Boolean(lit) && waiting > BigInt(0);

  let collectHint: string | null = null;
  if (!lit) {
    collectHint = "Wake this pet first. Sleeping eggs don't earn payouts.";
  } else if (hopperUnlocked === false) {
    collectHint = payoutCopy;
  } else if (!canCollect) {
    collectHint = "Nothing is waiting yet. Payouts show up after Pulse runs.";
  }

  let igniteHint = "The 1,000 $TERM is already in this egg. You only send the ETH fee.";
  if (igniteStatus === "closed") {
    igniteHint = "Ignite isn't open yet.";
  } else if (igniteStatus === "loading") {
    igniteHint = "Checking whether Ignite is open…";
  } else if (!feeReady) {
    igniteHint = "Reading the Ignite fee from the contract…";
  } else if (shortTerm) {
    igniteHint = `This wallet needs ${termLabel} before this egg can wake.`;
  } else if (needsApproval || approvalLoading) {
    igniteHint = `You already took the $TERM out of this egg. Approve ${termLabel}, then Ignite.`;
  } else if (needsWalletTerm) {
    igniteHint = `Approved. Ignite spends ${termLabel} from this wallet plus ${feeLabel ?? "the ETH fee"}.`;
  }

  return (
    <Card
      id={`pet-${tokenId.toString()}`}
      className={
        justAwoke
          ? "border-primary/70 bg-card/90 shadow-[0_0_40px_rgba(240,180,41,0.12)]"
          : "border-border/80 bg-card/80"
      }
    >
      <CardHeader className="space-y-3 pb-3">
        <PetImage tokenId={tokenId} refreshKey={refreshKey} />
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="font-mono text-[11px] tracking-[0.2em] text-muted-foreground">
              {lit ? "AWAKE" : "SLEEPING EGG"}
            </p>
            <CardTitle className="font-mono text-xl">
              #{tokenId.toString()}
            </CardTitle>
          </div>
          <Badge variant={lit ? "default" : "secondary"}>
            {lit ? "Awake" : "Sleeping"}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {lit && (
          <div className="space-y-2 rounded-xl border border-primary/30 bg-primary/5 p-3">
            <p className="font-medium text-foreground">
              {justAwoke ? "Your pet is awake" : "This pet is awake"}
            </p>
            <p className="text-sm text-muted-foreground">
              {rewardLine
                ? `${rarity ? `${rarity} pet. ` : ""}Dial assigned ${rewardLine}.`
                : "Dial assigns this pet's stock rewards. They'll show here in a moment."}
              {hasTermFallback
                ? " $TERM fills any reward that isn't a stock token."
                : ""}
            </p>
            <p className="text-sm text-muted-foreground">
              Next: this pet earns from Pulse payouts, paid out of the Hopper
              ETH pot. {payoutCopy} Sleeping eggs do not earn.
            </p>
          </div>
        )}

        {!lit && (
          <p className="text-sm text-muted-foreground">{igniteHint}</p>
        )}

        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="rounded-md border border-border/70 bg-background/40 p-2">
            <p className="text-muted-foreground">Ignite fee</p>
            <p className="font-mono text-sm">{lit ? "Paid" : feeLabel ?? "Reading…"}</p>
          </div>
          <div className="rounded-md border border-border/70 bg-background/40 p-2">
            <p className="text-muted-foreground">Waiting payout</p>
            <p className="font-mono text-sm">{formatEthTrim(pending)}</p>
          </div>
        </div>

        {!lit && needsApproval && !shortTerm && (
          <Button className="h-11 w-full" onClick={onApprove} disabled={busy || !igniteFeeTerm}>
            {busy ? "Confirm in wallet…" : `Approve ${termLabel}`}
          </Button>
        )}
        {!lit && (
          <Button className="h-11 w-full" onClick={onIgnite} disabled={igniteBlocked}>
            {busy
              ? "Confirm in wallet…"
              : feeLabel
                ? `Ignite (${feeLabel})`
                : "Ignite"}
          </Button>
        )}
        {lit && (
          <div className="space-y-2">
            <Button
              className="h-11 w-full"
              variant={canCollect ? "default" : "outline"}
              onClick={onClaim}
              disabled={busy || !canCollect}
            >
              {busy && canCollect ? "Collecting…" : "Collect payout"}
            </Button>
            {collectHint && (
              <p className="text-xs text-muted-foreground">{collectHint}</p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
