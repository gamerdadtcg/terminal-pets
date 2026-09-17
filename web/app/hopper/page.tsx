import { HopperUnlockCountdown } from "@/components/hopper-unlock-countdown";
import { HopperExplainer } from "@/components/hub/hopper-explainer";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import { SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `The Hopper · ${SITE.name}`,
  description:
    "Locked ETH pot. After reveal: 5% of secondary NFT sales, 50% of each Ignite 0.002 ETH, 25% of each Ignite $TERM fee (as ETH), plus a 1.5% TermMarket skim once the canonical $TERM pool is live. The other 50% of Ignite ETH buys $TERM and burns. Pre-reveal royalties go to TermFund.",
};

export default function HopperPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 lg:grid-cols-[1fr_280px]">
          <div className="space-y-4">
            <HopperUnlockCountdown />
            <HopperExplainer />
          </div>
          <aside className="space-y-4 lg:pt-16">
            <div className="rounded-2xl border border-border/70 bg-card/70 p-4">
              <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
                MECHANICS
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                Hopper holds ETH until Pulse. Pets show as egg GIFs until Ignite.
              </p>
            </div>
            <Button className="w-full" asChild>
              <Link href="/mint">Mint on this hub</Link>
            </Button>
            <Button className="w-full" variant="outline" asChild>
              <Link href="/arcade">Arcade · GTD</Link>
            </Button>
            <Button className="w-full" variant="outline" asChild>
              <Link href="/dial">How Dial aims Pulse</Link>
            </Button>
            <Button className="w-full" variant="outline" asChild>
              <Link href="/#economics">See economics</Link>
            </Button>
          </aside>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
