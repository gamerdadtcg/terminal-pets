import { FaqList } from "@/components/faq-list";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SHELL_DIAL, STOCK_POOL } from "@/lib/dial";
import { SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "How it works",
  description:
    "Sleeping eggs wake with Ignite. Dial assigns stock rewards. The Hopper holds ETH. Pulse can run after a 7-day lock, and awake pets can claim if it does.",
};

export default function HowPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative mx-auto flex max-w-3xl flex-col gap-10 px-4 py-12 sm:px-6">
          <div className="space-y-3">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              HOW IT WORKS
            </p>
            <h1 className="text-4xl font-semibold tracking-tight">
              Egg, wake up, claim.
            </h1>
            <p className="text-lg text-muted-foreground">
              The mint is over. If you hold an egg, connect that wallet on the
              Ignite page and wake it. This is the short version of what the
              words mean.
            </p>
            <Button asChild>
              <Link href="/">Ignite an egg</Link>
            </Button>
          </div>

          <section className="space-y-2">
            <h2 className="text-2xl font-semibold">Sleeping egg and awake pet</h2>
            <p className="text-muted-foreground">
              Every pet starts as a sleeping egg. Ignite is the one-time
              wake-up. After that the pet stays awake, even if you sell it.
              You cannot put it back to sleep. Sleeping eggs do not earn.
              Awake pets can, if Pulse runs.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-2xl font-semibold">Ignite</h2>
            <p className="text-muted-foreground">
              Press Ignite and confirm {SITE.igniteFeeEth} in your wallet. The{" "}
              {SITE.igniteFeeTerm} is already inside the egg, so you do not buy
              it first. If you already moved that $TERM out, the egg asks you
              to approve it, then Ignite. You need the ETH on {SITE.chain}{" "}
              (chain id {SITE.chainId}), plus a little extra for gas.
            </p>
          </section>

          <section id="dial" className="space-y-4">
            <h2 className="text-2xl font-semibold">Dial</h2>
            <p className="text-muted-foreground">
              When the pet wakes, Dial assigns its stock rewards. You do not
              pick them. A common pet gets one stock. Rarer pets get more, up
              to four. If a stock token is not set, that share can be $TERM
              instead.
            </p>
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Stocks Dial can assign</CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {STOCK_POOL.map((stock) => (
                    <li
                      key={stock.symbol}
                      className="rounded-xl border border-border/70 bg-background/50 px-3 py-3"
                    >
                      <p className="font-mono text-sm font-semibold">{stock.symbol}</p>
                      <p className="text-xs text-muted-foreground">{stock.name}</p>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle className="text-base">How many stocks</CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2 text-sm text-muted-foreground">
                  {SHELL_DIAL.map((row) => (
                    <li key={row.className}>
                      <span className="text-foreground">{row.rarity}</span>
                      {" · "}
                      {row.stocks} {row.stocks === 1 ? "stock" : "stocks"}
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
            <p className="text-sm text-muted-foreground">{SITE.disclaimer}</p>
          </section>

          <section className="space-y-2">
            <h2 className="text-2xl font-semibold">Hopper</h2>
            <p className="text-muted-foreground">
              The Hopper is a pot of ETH. It fills when people Ignite and when
              pets are sold. Nobody can take the pot for themselves. It sits
              there until someone runs Pulse.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-2xl font-semibold">Pulse</h2>
            <p className="text-muted-foreground">
              Pulse can share the pot with awake pets once the pot is big
              enough, and {SITE.hopperLock} have passed since the collection
              was revealed. Anyone can run it. Each share can be turned into
              that pet&apos;s stocks, or $TERM. If something is waiting, come
              back to Ignite and press Claim.
            </p>
            <Button variant="outline" asChild>
              <Link href="/hopper">Hopper & Pulse</Link>
            </Button>
          </section>

          <section id="faq" className="space-y-3">
            <h2 className="text-2xl font-semibold">Questions</h2>
            <FaqList />
          </section>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
