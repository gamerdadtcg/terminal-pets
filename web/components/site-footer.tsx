import { addresses, contractsConfigured, zeroAddress } from "@/lib/contracts";
import { explorerUrl } from "@/lib/chain";
import { explorerAddress } from "@/lib/format";
import { publicLinks, SITE } from "@/lib/site";
import Link from "next/link";

export function SiteFooter() {
  const links = publicLinks();
  const explorer = explorerUrl();
  const configured = contractsConfigured();
  const contracts = [
    ["Collection", addresses.collection],
    ["Ignite", addresses.ignite],
    ["Hopper", addresses.hopper],
    ["Pulse", addresses.pulse],
  ] as const;

  return (
    <footer className="border-t border-border/70 bg-background/60">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-10 sm:flex-row sm:items-start sm:justify-between sm:px-6">
        <div className="space-y-2">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            {SITE.symbol}
          </p>
          <p className="text-sm font-medium">{SITE.name}</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Minted out. Wake a sleeping egg on {SITE.chain}. Awake pets earn
            from the Hopper.
          </p>
          <p className="max-w-lg text-xs leading-relaxed text-muted-foreground/80">
            {SITE.disclaimer}
          </p>
        </div>
        <div className="flex flex-col gap-4 sm:items-end">
          <div className="grid grid-cols-2 gap-x-10 gap-y-2 font-mono text-xs text-muted-foreground sm:text-right">
            <Link className="hover:text-foreground" href="/how">
              How it works
            </Link>
            <Link className="hover:text-foreground" href="/hopper">
              Hopper & Pulse
            </Link>
            <Link className="hover:text-foreground" href="/how#faq">
              FAQ
            </Link>
            <a
              className="hover:text-foreground"
              href={links.explorer}
              rel="noreferrer"
              target="_blank"
            >
              Explorer
            </a>
            {links.opensea ? (
              <a className="hover:text-foreground" href={links.opensea}>
                OpenSea
              </a>
            ) : null}
            {links.x ? (
              <a className="hover:text-foreground" href={links.x}>
                X
              </a>
            ) : null}
          </div>
          {configured && (
            <ul className="space-y-1 font-mono text-xs text-muted-foreground sm:text-right">
              {contracts.map(([label, address]) =>
                address === zeroAddress ? null : (
                  <li key={label}>
                    <a
                      className="hover:text-foreground"
                      href={explorerAddress(explorer, address)}
                      target="_blank"
                      rel="noreferrer"
                    >
                      {label}
                    </a>
                  </li>
                ),
              )}
            </ul>
          )}
        </div>
      </div>
    </footer>
  );
}
