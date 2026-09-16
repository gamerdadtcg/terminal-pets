import { ComingSoon } from "@/components/coming-soon";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { DIAL_COPY, SHELL_DIAL, STOCK_POOL } from "@/lib/dial";
import { SITE } from "@/lib/site";

const RULES = [
  {
    title: "Assigned at Ignite",
    body: "When a pet becomes Lit, the contract assigns Dial automatically. Holders do not pick tickers or weights.",
  },
  {
    title: "Shell class sets the count",
    body: `${DIAL_COPY.classLine}. Class follows generative-art rarity (ALPHA Common … OMEGA Legendary).`,
  },
  {
    title: "Equal weights",
    body: "Assigned stocks split the Pulse share equally (bps sum to 100%). Remainder lands on the last leg.",
  },
  {
    title: "TBA delivery",
    body: "Pulse credits the pet’s TBA when delivery is on. Stock Tokens in the TBA travel with the NFT. The owner can withdraw.",
  },
] as const;

export function DialExplainer() {
  return (
    <div className="space-y-8">
      <div className="max-w-2xl space-y-3">
        <ComingSoon>In contracts · not deployed</ComingSoon>
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          Dial aims a Lit Pulse at Stock Tokens.
        </h2>
        <p className="text-muted-foreground">
          After Ignite (allotment $TERM + 0.002 ETH), Dial is assigned
          automatically: {DIAL_COPY.classLine}, drawn from the eight Robinhood
          Chain Stock Tokens below. Picks are random without replacement,
          deterministic from token id. When someone Pulses, Hopper ETH swaps
          into those tokens (or $TERM if a Dial has no filled addresses).
          Dormant earn nothing.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Possible stocks</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-muted-foreground">
            Eight Robinhood Chain Stock Tokens. Owner fills ERC-20 addresses
            when they are known. Not a holder menu.
          </p>
          <ul className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {STOCK_POOL.map((stock) => (
              <li
                key={stock.symbol}
                className="rounded-xl border border-border/70 bg-background/50 px-3 py-3"
              >
                <p className="font-mono text-sm font-semibold tracking-wide">
                  {stock.symbol}
                </p>
                <p className="text-xs text-muted-foreground">{stock.name}</p>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Shell class → Dial count</CardTitle>
        </CardHeader>
        <CardContent>
          <table className="w-full text-left text-sm">
            <thead className="text-muted-foreground">
              <tr>
                <th className="pb-2 font-medium">Class</th>
                <th className="pb-2 font-medium">Art rarity</th>
                <th className="pb-2 font-medium">Stocks</th>
              </tr>
            </thead>
            <tbody>
              {SHELL_DIAL.map((row) => (
                <tr key={row.className} className="border-t border-border/60">
                  <td className="py-2 font-mono">{row.className}</td>
                  <td className="py-2 text-muted-foreground">{row.rarity}</td>
                  <td className="py-2">{row.stocks}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2">
        {RULES.map((rule) => (
          <Card key={rule.title}>
            <CardHeader>
              <CardTitle className="text-base">{rule.title}</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              {rule.body}
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">What Pulse does with a Dial</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <p>
            Hopper still holds ETH until Pulse. At the current ladder rung,
            anyone can Pulse. The call snapshots the Lit set, reads each Dial,
            converts that pet’s share of Hopper ETH into the assigned Stock
            Tokens on Robinhood Chain, and credits the TBA — or the owner
            wallet if TBA delivery is off.
          </p>
          <p>
            If a Lit Dial has no filled token addresses, that share buys $TERM.
            Dormant earn nothing. Tokens that land in the TBA move with the NFT
            on sale.
          </p>
        </CardContent>
      </Card>

      <p className="max-w-2xl text-xs text-muted-foreground">{SITE.disclaimer}</p>
    </div>
  );
}
