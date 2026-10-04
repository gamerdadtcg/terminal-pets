"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { friendlyChainError } from "@/lib/chain-errors";
import {
  activeChain,
  configuredChainId,
  configuredRpc,
  explorerUrl,
} from "@/lib/chain";
import { SITE } from "@/lib/site";
import { useSwitchChain } from "wagmi";

export function NetworkHelp({ connected }: { connected: boolean }) {
  const { switchChain, isPending, error } = useSwitchChain();
  const chain = activeChain();
  const chainId = configuredChainId();
  const rpc = configuredRpc();
  const explorer = explorerUrl();

  return (
    <Card className="border-primary/40">
      <CardHeader>
        <p className="font-mono text-[11px] tracking-[0.22em] text-primary">
          NETWORK
        </p>
        <CardTitle className="text-xl">
          {connected
            ? `Add or switch to ${chain.name}`
            : `You'll use ${chain.name}`}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 text-sm text-muted-foreground">
        <p>
          Ignite only works on {chain.name}, chain id {chainId}. Most wallets
          do not have this network yet. After you connect, one button adds it
          and switches over.
        </p>
        {connected && (
          <Button
            className="h-11 px-5"
            onClick={() => switchChain({ chainId })}
            disabled={isPending}
          >
            {isPending ? "Asking your wallet…" : `Add or switch to ${chain.name}`}
          </Button>
        )}
        <dl className="grid gap-2 rounded-xl border border-border/70 bg-background/40 p-3 font-mono text-xs text-foreground sm:grid-cols-2">
          <div>
            <dt className="text-muted-foreground">Network</dt>
            <dd>{chain.name}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Chain ID</dt>
            <dd>{chainId}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Currency</dt>
            <dd>ETH</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Explorer</dt>
            <dd className="truncate">
              <a className="underline-offset-2 hover:underline" href={explorer}>
                {explorer.replace(/^https?:\/\//, "")}
              </a>
            </dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-muted-foreground">RPC</dt>
            <dd className="break-all">{rpc}</dd>
          </div>
        </dl>
        <p>
          Have about {SITE.igniteFeeEth} on this chain for the Ignite fee, plus
          a little extra for gas. If your wallet does not prompt you, add the
          network by hand with the details above.
        </p>
        {error && <p className="text-destructive">{friendlyChainError(error)}</p>}
      </CardContent>
    </Card>
  );
}
