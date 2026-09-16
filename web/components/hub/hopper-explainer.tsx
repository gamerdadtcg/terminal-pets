import { ComingSoon } from "@/components/coming-soon";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { PULSE_BOOTSTRAP, PULSE_CYCLE, SITE } from "@/lib/site";

const FLOWS = [
  {
    title: "Ignite ETH",
    share: SITE.igniteEthSplit,
    body: `Every wake attaches exactly ${SITE.igniteFeeEth}. ${SITE.igniteEthHopper} goes to the Hopper as ETH. ${SITE.igniteEthBurn} buys $TERM via the swap router and burns. Not TermFund. Not treasury. Team earns 0 from this fee.`,
  },
  {
    title: "Ignite $TERM",
    share: `${SITE.igniteHopper} as ETH`,
    body: `${SITE.igniteFeeTerm} splits ${SITE.igniteBurn} burn, ${SITE.igniteHopper} swapped to ETH for the Hopper (parks until a swap router is set), ${SITE.igniteAllotmentRefill} returned to allotment escrow. That last cut is pool refill, not treasury, and does not un-consume this pet’s allotment.`,
  },
  {
    title: "Pre-reveal royalties",
    share: `100% of ${SITE.royalty}`,
    body: `From mint until CollectionNFT.reveal(), the full ${SITE.royalty} creator royalty goes to TermFund to seed $TERM LP. Hopper and treasury get nothing from that stream. Hopper ETH already in the pot is untouched.`,
  },
  {
    title: "Post-reveal secondary sales",
    share: SITE.royaltyHopper,
    body: `After reveal, the same ${SITE.royalty} royalty hits the RoyaltySplitter and splits live: two-thirds (${SITE.royaltyHopper} of the sale) here, one-third (${SITE.royaltyTreasury}) to treasury. The switch is atomic with metadata + Ignite + $TERM trading.`,
  },
  {
    title: "Canonical $TERM trades",
    share: `${SITE.tradeHopper} of volume`,
    body: `When the TERM/ETH pool is live (and trading has been enabled at reveal), TermMarket skims ${SITE.tradeFee} of that pool’s input: ${SITE.tradeHopper} becomes ETH for the Hopper, ${SITE.tradeBurn} buys (or already is) $TERM and burns, ${SITE.tradeTreasury} to treasury. Not a transfer tax. Off until the pool is set.`,
  },
] as const;

export function HopperExplainer({ compact = false }: { compact?: boolean }) {
  return (
    <div className="space-y-8">
      <div className="max-w-2xl space-y-3">
        <ComingSoon>Locked pot · no admin withdraw</ComingSoon>
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          The Hopper is holder money.
        </h2>
        <p className="text-muted-foreground">
          Think of it as the tank on the back of the handheld. After reveal,
          ETH comes from {SITE.royaltyHopper} of each secondary NFT sale,{" "}
          {SITE.igniteEthHopper} of each Ignite ETH fee, {SITE.igniteHopper} of
          each Ignite $TERM fee (swapped once a router is set), and — once the
          canonical TERM/ETH pool is live — TermMarket’s {SITE.tradeHopper} skim
          of that volume. Payouts stay locked for {SITE.hopperLock} after
          reveal while that ETH still accrues — first Ignite does not unlock
          early. During the {SITE.revealWindow} sealed window the full{" "}
          {SITE.royalty} royalty stream goes to TermFund, not here. The other
          half of Ignite ETH buys $TERM and burns. LP seeding is
          manual ops from TermFund — it does not drain the Hopper. Pulse
          requires Hopper available() to meet the current ladder rung, and
          hopperUnlocked().
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {FLOWS.map((flow) => (
          <Card key={flow.title}>
            <CardHeader>
              <p className="font-mono text-[11px] tracking-[0.2em] text-primary">
                {flow.share}
              </p>
              <CardTitle className="text-lg">{flow.title}</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              {flow.body}
            </CardContent>
          </Card>
        ))}
      </div>

      <Card className="border-primary/35">
        <CardHeader>
          <CardTitle className="text-base">Pulse ladder</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-muted-foreground">
          <p>
            Anyone can Pulse when{" "}
            <span className="text-foreground">available() ≥ current rung</span>
            . Permissionless. Snapshot the Lit set, read each Dial, swap that
            share of Hopper ETH into assigned Stock Tokens (Dial) or $TERM
            (unfilled Dial). The Hopper pot itself stays ETH.
          </p>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <p className="mb-2 font-medium text-foreground">
                Bootstrap (once)
              </p>
              <p className="mb-2 font-mono text-[11px]">
                {SITE.pulseLadderBootstrap}
              </p>
              <ol className="flex flex-wrap gap-1.5">
                {PULSE_BOOTSTRAP.map((rung, i) => (
                  <li
                    key={`b-${rung}`}
                    className="rounded-md border border-border/70 bg-background/50 px-2 py-1 font-mono text-[11px] text-foreground"
                  >
                    {i + 1}. {rung} ETH
                  </li>
                ))}
              </ol>
            </div>
            <div>
              <p className="mb-2 font-medium text-foreground">
                After 1.0 — forever
              </p>
              <p className="mb-2 font-mono text-[11px]">
                {SITE.pulseLadderCycle}
              </p>
              <ol className="flex flex-wrap gap-1.5">
                {PULSE_CYCLE.map((rung, i) => (
                  <li
                    key={`c-${rung}`}
                    className="rounded-md border border-border/70 bg-background/50 px-2 py-1 font-mono text-[11px] text-foreground"
                  >
                    {i + 1}. {rung} ETH
                  </li>
                ))}
              </ol>
            </div>
          </div>
          <p>
            After the bootstrap Pulse at 1.0 ETH, the next rung is{" "}
            <span className="text-foreground">0.5 ETH — never 0.1 again</span>.
            Below the current rung, the tank stays ETH. No sweep. No owner
            rescue.
          </p>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Who earns</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>
              <span className="text-foreground">Lit only</span>, pro-rata. A
              Dormant pet is asleep and earns nothing. Undialed Lit get $TERM.
            </p>
            <p>
              Pulse credits the TBA when delivery is on, else the owner
              wallet. Stock Tokens in the TBA travel with the NFT.
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">What never enters</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>
              Pre-reveal royalties (full {SITE.royalty} → TermFund). After
              reveal, team treasury ({SITE.royaltyTreasury} of each sale)
              stays out. The burn half of Ignite ETH never enters (it buys
              $TERM and burns). Mint is free (0 ETH). If a mint price is later
              set, paid proceeds are a separate path.
            </p>
            <p>
              The distributor address can be locked once. After that the owner
              cannot point the Hopper at a different spender.
            </p>
          </CardContent>
        </Card>
      </div>

      {!compact && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Trust model</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3 text-sm text-muted-foreground sm:grid-cols-3">
            <p>
              <span className="block font-medium text-foreground">No withdraw</span>
              There is no sweep, skim, or owner rescue on the Hopper.
            </p>
            <p>
              <span className="block font-medium text-foreground">One outbound path</span>
              Pulse → Lit terminals (Stock Tokens or $TERM, TBA or owner).
            </p>
            <p>
              <span className="block font-medium text-foreground">Splitter first</span>
              OpenSea royalties must hit RoyaltySplitter, not an EOA.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
