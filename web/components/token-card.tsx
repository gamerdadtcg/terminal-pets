"use client";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { explorerAddress, formatEth, shortAddress } from "@/lib/format";
import { explorerUrl } from "@/lib/chain";

type Props = {
  tokenId: bigint;
  lit?: boolean;
  pending?: bigint;
  tba?: `0x${string}`;
  deliverToTba?: boolean;
  igniteFee?: bigint;
  allotmentConsumed?: boolean;
  busy?: boolean;
  onIgnite: () => void;
  onClaim: () => void;
  onClaimAllotment: () => void;
};

export function TokenCard({
  tokenId,
  lit,
  pending,
  tba,
  deliverToTba,
  allotmentConsumed,
  busy,
  onIgnite,
  onClaim,
  onClaimAllotment,
}: Props) {
  const state = lit ? "Lit" : "Dormant";
  const explorer = explorerUrl();

  return (
    <Card className="border-border/80 bg-card/80">
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0 pb-3">
        <div>
          <p className="font-mono text-[11px] tracking-[0.2em] text-muted-foreground">
            TERMINAL
          </p>
          <CardTitle className="font-mono text-xl">#{tokenId.toString()}</CardTitle>
        </div>
        <Badge variant={lit ? "default" : "secondary"}>{state}</Badge>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="rounded-md border border-border/70 bg-background/40 p-2">
            <p className="text-muted-foreground">Pending Pulse</p>
            <p className="font-mono text-sm">{formatEth(pending)}</p>
          </div>
          <div className="rounded-md border border-border/70 bg-background/40 p-2">
            <p className="text-muted-foreground">Ignite fee</p>
            <p className="font-mono text-sm">
              {lit ? "—" : "1,000 $TERM + 0.002 ETH"}
            </p>
          </div>
        </div>
        {!lit && (
          <p className="text-xs text-muted-foreground">
            {allotmentConsumed
              ? "Allotment already pulled. Approve $TERM, then Ignite with 0.002 ETH."
              : "Allotment still in escrow. Ignite spends it (37.5% burn / 25% Hopper / 37.5% allotment refill) plus 0.002 ETH (50% buy/burn $TERM, 50% Hopper). Team earns 0 from that ETH."}
          </p>
        )}
        {tba && tba !== "0x0000000000000000000000000000000000000000" && (
          <p className="text-xs text-muted-foreground">
            TBA{" "}
            <a
              className="font-mono text-foreground underline-offset-2 hover:underline"
              href={explorerAddress(explorer, tba)}
              target="_blank"
              rel="noreferrer"
            >
              {shortAddress(tba)}
            </a>
            {deliverToTba ? " · Pulse delivers here" : ""}
          </p>
        )}
        <div className="flex flex-wrap gap-2">
          {!lit && (
            <Button size="sm" onClick={onIgnite} disabled={busy}>
              Ignite
            </Button>
          )}
          {!lit && !allotmentConsumed && (
            <Button
              size="sm"
              variant="outline"
              onClick={onClaimAllotment}
              disabled={busy}
            >
              Claim $TERM allotment
            </Button>
          )}
          <Button
            size="sm"
            variant="outline"
            onClick={onClaim}
            disabled={busy || !pending || pending === BigInt(0)}
          >
            Claim Pulse
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
