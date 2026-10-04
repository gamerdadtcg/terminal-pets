import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { PULSE_BOOTSTRAP, PULSE_CYCLE, SITE } from "@/lib/site";

export function HopperExplainer() {
  return (
    <div className="space-y-8">
      <div className="max-w-2xl space-y-3">
        <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
          HOPPER & PULSE
        </p>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          The pot, then the payout.
        </h1>
        <p className="text-muted-foreground">
          The Hopper is an ETH pot. It fills when eggs are Ignited and when
          pets are sold. Pulse is the payout: it splits the pot among awake
          pets and turns each share into that pet&apos;s stocks. Sleeping eggs
          earn nothing. Nobody can withdraw the pot for themselves.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Hopper</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            ETH only. Payouts stayed locked for {SITE.hopperLock} after the
            collection was revealed, while the pot could still grow. The date
            on the right comes from the contract when it has one.
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Pulse</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            Anyone can run a payout once the pot reaches the current rung and
            the lock is over. Awake pets split it. Dial decides which stocks
            they receive. If a stock token is not set, that share is $TERM.
          </CardContent>
        </Card>
      </div>

      <Card className="border-primary/35">
        <CardHeader>
          <CardTitle className="text-base">How big the pot has to be</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-muted-foreground">
          <p>
            The first payouts step up from 0.1 ETH to 1.0 ETH. After that they
            cycle from 0.5 ETH to 1.0 ETH and never go back to 0.1. Below the
            current rung, the ETH just stays in the pot.
          </p>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <p className="mb-2 font-medium text-foreground">First time</p>
              <p className="mb-2 font-mono text-[11px]">{SITE.pulseLadderBootstrap}</p>
              <ol className="flex flex-wrap gap-1.5">
                {PULSE_BOOTSTRAP.map((rung) => (
                  <li
                    key={`b-${rung}`}
                    className="rounded-md border border-border/70 bg-background/50 px-2 py-1 font-mono text-[11px] text-foreground"
                  >
                    {rung} ETH
                  </li>
                ))}
              </ol>
            </div>
            <div>
              <p className="mb-2 font-medium text-foreground">After that</p>
              <p className="mb-2 font-mono text-[11px]">{SITE.pulseLadderCycle}</p>
              <ol className="flex flex-wrap gap-1.5">
                {PULSE_CYCLE.map((rung) => (
                  <li
                    key={`c-${rung}`}
                    className="rounded-md border border-border/70 bg-background/50 px-2 py-1 font-mono text-[11px] text-foreground"
                  >
                    {rung} ETH
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
