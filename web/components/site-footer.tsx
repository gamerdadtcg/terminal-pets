import { publicLinks, SITE } from "@/lib/site";
import Link from "next/link";

export function SiteFooter() {
  const links = publicLinks();

  return (
    <footer className="border-t border-border/70 bg-background/60">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-10 sm:px-6 sm:flex-row sm:items-start sm:justify-between">
        <div className="space-y-2">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            {SITE.symbol}
          </p>
          <p className="text-sm font-medium">{SITE.name}</p>
          <p className="max-w-sm text-sm text-muted-foreground">
            Collection on {SITE.chain}. Metadata names each token Terminal Pet
            #id. On-chain SVG. No IPFS.
          </p>
          <p className="max-w-lg text-xs leading-relaxed text-muted-foreground/80">
            {SITE.disclaimer}
          </p>
        </div>
        <div className="grid grid-cols-2 gap-x-10 gap-y-2 font-mono text-xs text-muted-foreground sm:text-right">
          <Link className="hover:text-foreground" href="/#how">
            How it works
          </Link>
          <Link className="hover:text-foreground" href="/hopper">
            Hopper
          </Link>
          <Link className="hover:text-foreground" href="/dial">
            Dial
          </Link>
          <Link className="hover:text-foreground" href="/gallery">
            Gallery
          </Link>
          <Link className="hover:text-foreground" href="/art-pass">
            Art pass
          </Link>
          <Link className="hover:text-foreground" href="/app">
            Terminal
          </Link>
          {links.opensea ? (
            <a className="hover:text-foreground" href={links.opensea}>
              OpenSea
            </a>
          ) : (
            <span>OpenSea · soon</span>
          )}
          {links.x ? (
            <a className="hover:text-foreground" href={links.x}>
              X
            </a>
          ) : (
            <span>X · soon</span>
          )}
          <a
            className="hover:text-foreground"
            href={links.explorer}
            rel="noreferrer"
            target="_blank"
          >
            Explorer
          </a>
          <Link className="hover:text-foreground" href="/#faq">
            FAQ
          </Link>
        </div>
      </div>
    </footer>
  );
}
