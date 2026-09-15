import { ComingSoon } from "@/components/coming-soon";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const RULES = [
  {
    title: "Lit only",
    body: "Dormant pets cannot Dial and earn nothing. Ignite first. No Dial means that Lit share buys $TERM — not raw ETH.",
  },
  {
    title: "Up to 3 tickers",
    body: "Pick Robinhood Chain Stock Tokens. Weights must sum to 100%. Change them any time before the next Pulse snapshot.",
  },
  {
    title: "Default is $TERM",
    body: "No Dial on file at snapshot means that Lit pet’s Pulse share buys $TERM (credited to the TBA when delivery is on). Skipping Dial is valid.",
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
          After you Ignite (allotment $TERM + 0.002 ETH), a Lit holder can Dial
          up to three Robinhood Chain Stock Tokens. When someone Pulses, the
          snapshot reads each Dial. If a DEX router is set, Hopper ETH swaps
          into those tokens; if not, Pulse still spends Hopper ETH. No Dial
          means that share buys $TERM for the TBA.
        </p>
      </div>

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
          anyone can Pulse. The call snapshots the Lit set, reads each Dial, converts that
            pet’s share of Hopper ETH into the demanded Stock Tokens on
            Robinhood Chain, and credits the TBA — or the owner wallet if TBA
            delivery is off.
          </p>
          <p>
            Undialed Lit get $TERM. Dormant earn nothing. Tokens that land
            in the TBA move with the NFT on sale.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
