import { DialExplainer } from "@/components/hub/dial-explainer";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import { SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `Dial · ${SITE.name}`,
  description:
    "Ignite assigns 1–4 Robinhood Chain Stock Tokens by shell class (ALPHA–OMEGA) from HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA. Pulse converts Hopper ETH per Dial.",
};

export default function DialPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 lg:grid-cols-[1fr_280px]">
          <DialExplainer />
          <aside className="space-y-4 lg:pt-16">
            <div className="rounded-2xl border border-border/70 bg-card/70 p-4">
              <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
                DIAL
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                Eight Stock Tokens. ALPHA 1 … OMEGA 4. Assigned at Ignite —
                holders do not pick. Awake pet GIF after Ignite.
              </p>
            </div>
            <Button className="w-full" asChild>
              <Link href="/hopper">Hopper still holds ETH</Link>
            </Button>
            <Button className="w-full" variant="outline" asChild>
              <Link href="/#faq">Stock Token FAQ</Link>
            </Button>
          </aside>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
