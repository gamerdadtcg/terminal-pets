"use client";

import { Button } from "@/components/ui/button";
import { friendlyChainError } from "@/lib/chain-errors";
import { activeChain, configuredChainId } from "@/lib/chain";
import { shortAddress } from "@/lib/format";
import { SITE } from "@/lib/site";
import { cn } from "@/lib/utils";
import { useState, useSyncExternalStore } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";

function subscribe() {
  return () => {};
}

function readMobile() {
  return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
}

function readProvider() {
  return Boolean((window as Window & { ethereum?: unknown }).ethereum);
}

function readReady() {
  return true;
}

function walletLabel(name: string) {
  if (name === "Injected") return "Browser wallet";
  return name;
}

export function MobileWalletHelp({ className }: { className?: string }) {
  const href = SITE.url;
  const stripped = href.replace(/^https?:\/\//, "");
  const links = {
    metamask: `https://metamask.app.link/dapp/${stripped}`,
    coinbase: `https://go.cb-w.com/dapp?cb_url=${encodeURIComponent(href)}`,
  };

  return (
    <div className={cn("space-y-2 text-sm text-muted-foreground", className)}>
      <p>
        On a phone, open this page inside your wallet app. A normal mobile
        browser does not include MetaMask or Coinbase Wallet.
      </p>
      <div className="flex flex-wrap gap-2">
          <Button size="sm" variant="outline" asChild>
            <a href={links.metamask}>Open in MetaMask</a>
          </Button>
          <Button size="sm" variant="outline" asChild>
            <a href={links.coinbase}>Open in Coinbase Wallet</a>
          </Button>
        </div>
    </div>
  );
}

export function ConnectButton({ prominent = false }: { prominent?: boolean }) {
  const { address, isConnected, chainId, status } = useAccount();
  const { connect, connectors, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: switching } = useSwitchChain();
  const target = configuredChainId();
  const chain = activeChain();
  const ready = useSyncExternalStore(subscribe, readReady, () => false);
  const mobile = useSyncExternalStore(subscribe, readMobile, () => false);
  const hasProvider = useSyncExternalStore(subscribe, readProvider, () => false);
  const [menuOpen, setMenuOpen] = useState(false);

  const showMobileHelp = ready && mobile && !hasProvider;
  const busy = isPending || status === "connecting" || status === "reconnecting";

  function connectWith(connector = connectors[0]) {
    if (!connector) return;
    setMenuOpen(false);
    connect({ connector, chainId: target });
  }

  if (!isConnected) {
    const several = connectors.length > 1;
    const buttonClass = prominent ? "h-12 px-6 text-base" : undefined;

    return (
      <div className={cn("relative", prominent && "space-y-3")}>
        {several ? (
          <div className={cn("flex flex-wrap gap-2", prominent && "flex-col items-stretch")}>
            {connectors.map((connector) => (
              <Button
                key={connector.uid}
                className={buttonClass}
                onClick={() => connectWith(connector)}
                disabled={busy}
              >
                {busy ? "Connecting…" : walletLabel(connector.name)}
              </Button>
            ))}
          </div>
        ) : (
          <Button
            className={buttonClass}
            onClick={() => {
              if (showMobileHelp && !prominent) {
                setMenuOpen((open) => !open);
                return;
              }
              connectWith();
            }}
            disabled={busy || connectors.length === 0}
            aria-expanded={showMobileHelp && !prominent ? menuOpen : undefined}
          >
            {busy ? "Connecting…" : "Connect wallet"}
          </Button>
        )}
        {showMobileHelp && prominent && <MobileWalletHelp />}
        {showMobileHelp && !prominent && menuOpen && (
          <div className="absolute right-0 z-20 mt-2 w-72 rounded-xl border border-border bg-popover p-3 shadow-lg">
            <MobileWalletHelp />
          </div>
        )}
        {ready && !mobile && !hasProvider && prominent && (
          <p className="max-w-md text-sm text-muted-foreground">
            Install a browser wallet such as MetaMask, Coinbase Wallet, or
            Rabby, then refresh this page.
          </p>
        )}
        {error && (
          <p className="text-sm text-destructive">{friendlyChainError(error)}</p>
        )}
      </div>
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
          {switching ? "Switching…" : `Switch to ${chain.name}`}
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
