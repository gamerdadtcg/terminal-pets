"use client";

import { Button } from "@/components/ui/button";
import { configuredChainId } from "@/lib/chain";
import { shortAddress } from "@/lib/format";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { injected } from "wagmi/connectors";

export function ConnectButton() {
  const { address, isConnected, chainId, status } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: switching } = useSwitchChain();
  const target = configuredChainId();

  if (!isConnected) {
    return (
      <Button
        onClick={() => connect({ connector: injected() })}
        disabled={isPending || status === "connecting"}
      >
        {isPending ? "Connecting…" : "Connect wallet"}
      </Button>
    );
  }

  if (chainId !== target) {
    return (
      <div className="flex items-center gap-2">
        <Button
          variant="destructive"
          onClick={() => switchChain({ chainId: target })}
          disabled={switching}
        >
          {switching ? "Switching…" : "Switch network"}
        </Button>
        <Button variant="ghost" onClick={() => disconnect()}>
          Disconnect
        </Button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <span className="hidden font-mono text-xs text-muted-foreground sm:inline">
        {shortAddress(address ?? "")}
      </span>
      <Button variant="outline" onClick={() => disconnect()}>
        Disconnect
      </Button>
    </div>
  );
}
