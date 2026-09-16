import { ComingSoon } from "@/components/coming-soon";
import { HopperExplainer } from "@/components/hub/hopper-explainer";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { contractsConfigured } from "@/lib/contracts";
import { FAQ, SITE, publicLinks } from "@/lib/site";
import Link from "next/link";

const STEPS = [
  {
    n: "01",
    title: "Mint on OpenSea",
    body: `4,244 public Terminal Pets. Price TBD. Each token mints Sealed — placeholder metadata, TBA, and a $TERM allotment. Name is Terminal Pet #{id}. Ignite and $TERM trading stay off.`,
  },
  {
    n: "02",
    title: "24h reveal",
    body: `Sealed for ${SITE.revealWindow}. Owner may call CollectionNFT.reveal() early; anyone can after that. One tx: metadata live, $TERM trading on, Ignite on, royalties switch from 7.5% TermFund to ${SITE.royaltyHopper} Hopper / ${SITE.royaltyTreasury} treasury.`,
  },
  {
    n: "03",
    title: "Ignite allotment",
    body: `The pet already has ${SITE.igniteFeeTerm} in escrow for one wake — token supply, not a DEX buy. You still pay ${SITE.igniteFeeEth} with Ignite: ${SITE.igniteEthSplit}. Team earns 0 from that ETH.`,
  },
  {
    n: "04",
    title: "Ignite",
    body: `Off until reveal. Then pay ${SITE.igniteFeeTerm} (allotment or wallet, ${SITE.igniteSplit}) plus exactly ${SITE.igniteFeeEth}. ${SITE.igniteHopper} of $TERM becomes Hopper ETH once a swap router is set. ${SITE.igniteBurn} burns. ${SITE.igniteAllotmentRefill} returns to allotment escrow. The ETH splits ${SITE.igniteEthSplit} — not TermFund, not treasury.`,
  },
  {
    n: "05",
    title: "Dial",
    body: "Lit holders pick up to 3 Robinhood Chain Stock Tokens. Weights sum to 100%. Changeable until the next Pulse snapshot.",
  },
  {
    n: "06",
    title: "Hopper fills",
    body: `ETH only, and only after reveal for royalties. Then ${SITE.royaltyHopper} of each secondary NFT sale, ${SITE.igniteEthHopper} of each Ignite ETH fee, ${SITE.igniteHopper} of each Ignite $TERM fee (as ETH when a swap router is set), plus ${SITE.tradeHopper} of canonical $TERM volume once the pool is live. Payouts lock ${SITE.hopperLock} after reveal while ETH accrues. Pre-reveal royalties go to TermFund. The other ${SITE.igniteEthBurn} of Ignite ETH buys $TERM and burns.`,
  },
  {
    n: "07",
    title: "Pulse",
    body: `Ladder, not a fixed line. First cycle: ${SITE.pulseLadderBootstrap}. After 1.0 ETH: ${SITE.pulseLadderCycle}. Never back to 0.1.`,
  },
  {
    n: "08",
    title: "TBA / rewards",
    body: "Credit the pet’s TBA (or the owner wallet if TBA delivery is off). Dialed pets get Stock Tokens. Undialed Lit get $TERM. Dormant earn nothing.",
  },
] as const;

const ECON = [
  { label: "Max supply", value: String(SITE.supply) },
  { label: "Public", value: String(SITE.publicSupply) },
  { label: "Team reserve", value: String(SITE.teamReserve) },
  { label: "Mint price", value: SITE.mintPrice },
  { label: "Reveal window", value: SITE.revealWindow },
  { label: "Ignite", value: SITE.igniteFee },
  { label: "Ignite ETH", value: SITE.igniteEthSplit },
  { label: "TermFund", value: "pre-reveal 7.5%" },
  { label: "Ignite $TERM split", value: `${SITE.igniteBurn} / ${SITE.igniteHopper} / ${SITE.igniteAllotmentRefill}` },
  { label: "$TERM skim", value: `${SITE.tradeFee} · ${SITE.tradeHopper}/${SITE.tradeBurn}/${SITE.tradeTreasury}` },
  { label: "Pulse ladder", value: "0.1→1.0 then 0.5–1.0" },
  { label: "Royalty", value: SITE.royalty },
  { label: "Pre-reveal royalties", value: "100% TermFund" },
  { label: "Hopper payout lock", value: SITE.hopperLock },
  { label: "Post-reveal split", value: `${SITE.royaltyHopper} / ${SITE.royaltyTreasury}` },
] as const;

const ROADMAP = [
  {
    state: "done" as const,
    title: "Contracts + tests",
    body: "Foundry suite for mint, 24h sealed reveal, hybrid Ignite, TermFund, TermMarket skim, Hopper lock, Dial, Pulse ladder, royalties, TBA.",
  },
  {
    state: "done" as const,
    title: "NFT metadata stub",
    body: `${SITE.artDomain} seed and trait tables stay. tokenURI is a placeholder SVG (PET# + state). Art intentionally removed; reconnect separately.`,
  },
  {
    state: "done" as const,
    title: "24h reveal gates",
    body: "Mint → sealed metadata, Ignite off, $TERM trading off, 7.5% royalties → TermFund. CollectionNFT.reveal() flips metadata, Ignite, trading, and 5/2.5 royalties in one tx. Owner early; anyone after 24h.",
  },
  {
    state: "now" as const,
    title: "Public hub",
    body: "This site. Ignite / Pulse / Hopper / Dial hub pages. Terminal route is ready. Pet stills are not served.",
  },
  {
    state: "next" as const,
    title: "Robinhood Chain deploy",
    body: "Not done. Do not broadcast until someone says go. Deploy stays sealed. Do not auto-reveal.",
  },
  {
    state: "done" as const,
    title: "$TERM market skim",
    body: "TermMarket ships in the repo (not fee-on-transfer). Inactive until TERM_POOL and TERM_SWAP_ROUTER are set. Then 3% of canonical swap input → 1.5% Hopper / 1% burn / 0.5% treasury. Trading itself is also off until reveal.",
  },
  {
    state: "next" as const,
    title: "OpenSea import",
    body: "Point the collection at the splitter. Honor ERC-2981. Open the 4,244. Pre-reveal earnings still hit the splitter — they just route 100% to TermFund until reveal.",
  },
] as const;

export function HubLanding() {
  const links = publicLinks();
  const live = contractsConfigured();

  return (
    <div className="relative">
      <div className="hub-grid pointer-events-none absolute inset-0 opacity-70" />

      <section className="relative overflow-hidden border-b border-border/60">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_0%,rgba(240,180,41,0.14),transparent_42%),radial-gradient(circle_at_90%_20%,rgba(96,165,250,0.08),transparent_36%)]" />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 sm:py-16 lg:grid-cols-[1.1fr_0.9fr] lg:items-center">
          <div className="space-y-6">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="outline" className="font-mono">
                {SITE.chain} · {SITE.chainId}
              </Badge>
              {live ? (
                <ComingSoon>Contracts live</ComingSoon>
              ) : (
                <ComingSoon />
              )}
            </div>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl lg:text-6xl">
              {SITE.name}
            </h1>
            <p className="max-w-xl text-lg text-muted-foreground">
              {SITE.tagline} Metadata names each token Terminal Pet #id.
              The collection is {SITE.name} ({SITE.symbol}). Memecoin is $TERM.
            </p>
            <p className="max-w-xl text-sm text-muted-foreground">
              {SITE.supply} handhelds. Mint on OpenSea. Pets mint Sealed for{" "}
              {SITE.revealWindow}: placeholder metadata, Ignite off, $TERM
              transfers off. Secondary royalties ({SITE.royalty}) go 100% to
              TermFund — nothing to Hopper, nothing to treasury from that
              stream. Reveal flips metadata live, turns on Ignite and $TERM
              trading, and switches royalties to {SITE.royaltyHopper} Hopper /{" "}
              {SITE.royaltyTreasury} treasury. Each pet includes a $TERM
              allotment for the token half of Ignite. That 1,000 $TERM splits{" "}
              {SITE.igniteBurn} burn / {SITE.igniteHopper} Hopper (as ETH) /{" "}
              {SITE.igniteAllotmentRefill} allotment refill, plus{" "}
              {SITE.igniteFeeEth} split {SITE.igniteEthSplit}. Team earns 0
              from that ETH. Dial aims a Lit Pulse at Stock Tokens — or leave
              it and earn $TERM.
            </p>
            <div className="flex flex-wrap gap-2">
              {links.opensea ? (
                <Button asChild>
                  <a href={links.opensea} rel="noreferrer" target="_blank">
                    Mint on OpenSea
                  </a>
                </Button>
              ) : (
                <Button disabled>Mint on OpenSea · soon</Button>
              )}
              <Button variant="outline" asChild>
                <Link href="/app">Ignite / Pulse app</Link>
              </Button>
              <Button variant="ghost" asChild>
                <Link href="/hopper">Hopper lock</Link>
              </Button>
            </div>
            <p className="font-mono text-[11px] text-muted-foreground">
              Mint {SITE.mintPrice} · Sealed {SITE.revealWindow} · Ignite{" "}
              {SITE.igniteFee} · Royalty {SITE.royalty}
            </p>
          </div>

          <div className="grid gap-3">
            <div className="rounded-[1.6rem] border border-primary/25 bg-card/70 p-5 shadow-[0_0_80px_rgba(240,180,41,0.08)]">
              <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
                MECHANICS ONLY
              </p>
              <p className="mt-3 text-lg font-medium">
                Art intentionally removed. Art will be reconnected separately.
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                tokenURI stays a placeholder SVG: rectangle + PET# + state.
                Seed {SITE.artDomain} and trait tables are unchanged.
              </p>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">SEALED</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  Hidden metadata until reveal.
                </p>
              </div>
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">DORMANT</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  Traits live. Ignite still off.
                </p>
              </div>
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">LIT</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  After Ignite. Dial / Pulse eligible.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        id="how"
        className="relative mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6"
      >
        <div className="mb-8 max-w-2xl space-y-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            LOOP
          </p>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Mint. Reveal. Ignite. Dial. Hopper. Pulse. TBA.
          </h2>
          <p className="text-muted-foreground">
            Pets mint Sealed. After {SITE.revealWindow} (or sooner if the owner
            activates), reveal flips metadata, enables Ignite and $TERM
            trading, and routes royalties to Hopper/treasury. Until then the
            full{" "}
            {SITE.royalty} creator royalty seeds TermFund. Ignite is hybrid:{" "}
            {SITE.igniteFeeTerm} splits {SITE.igniteBurn} burn /{" "}
            {SITE.igniteHopper} Hopper / {SITE.igniteAllotmentRefill} allotment
            refill, plus {SITE.igniteFeeEth} split {SITE.igniteEthSplit}. Dial
            aims Pulse.
          </p>
        </div>
        <ol className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          {STEPS.map((step) => (
            <li key={step.n}>
              <Card className="h-full">
                <CardHeader className="gap-2">
                  <p className="font-mono text-[11px] text-primary">{step.n}</p>
                  <CardTitle className="text-base">{step.title}</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  {step.body}
                </CardContent>
              </Card>
            </li>
          ))}
        </ol>
      </section>

      <section
        id="hopper"
        className="relative border-y border-border/60 bg-card/25"
      >
        <div className="mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6">
          <HopperExplainer compact />
          <div className="mt-6 flex flex-wrap gap-2">
            <Button variant="outline" asChild>
              <Link href="/hopper">Open the full Hopper page</Link>
            </Button>
            <Button variant="ghost" asChild>
              <Link href="/dial">How Dial aims Pulse</Link>
            </Button>
          </div>
        </div>
      </section>

      <section
        id="dial"
        className="relative mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6"
      >
        <div className="mb-8 max-w-2xl space-y-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            DIAL
          </p>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Up to 3 Stock Tokens. Weights to 100%. No Dial earns $TERM.
          </h2>
          <p className="text-muted-foreground">
            Lit only. Change Dial until the next Pulse snapshot. No Dial on
            file → that pet’s share buys $TERM. Pulse credits the TBA; tokens
            travel with the NFT.
          </p>
          <Button variant="outline" asChild>
            <Link href="/dial">Open the Dial page</Link>
          </Button>
        </div>
      </section>

      <section
        id="economics"
        className="relative mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6"
      >
        <div className="mb-8 max-w-2xl space-y-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            NUMBERS
          </p>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Fixed economics. Mint price still TBD.
          </h2>
          <p className="text-muted-foreground">
            Supply is locked. Royalties are mode-switched at reveal: pre-reveal
            the full {SITE.royalty} goes to TermFund; after reveal it is{" "}
            {SITE.royaltyHopper} Hopper / {SITE.royaltyTreasury} treasury.
            Pulse is a ladder, not a fixed 0.5 ETH line. Ignite stays off until
            reveal, then {SITE.igniteFeeTerm} ({SITE.igniteSplit}) plus exactly{" "}
            {SITE.igniteFeeEth} ({SITE.igniteEthSplit}). Team earns 0 from the
            ETH fee. The {SITE.igniteAllotmentRefill}{" "}
            $TERM cut refills allotment escrow, not treasury. Live $TERM trades
            on the canonical pool skim {SITE.tradeFee} once TERM_POOL is set.
            No live addresses. Do not point OpenSea earnings at a wallet — use
            the splitter.
          </p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {ECON.map((row) => (
            <Card key={row.label}>
              <CardHeader className="pb-2">
                <p className="font-mono text-[11px] text-muted-foreground">
                  {row.label}
                </p>
                <CardTitle className="text-2xl tabular-nums">{row.value}</CardTitle>
              </CardHeader>
            </Card>
          ))}
        </div>
      </section>

      <section
        id="art"
        className="relative border-y border-border/60 bg-card/25"
      >
        <div className="mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6">
          <div className="mb-8 max-w-2xl space-y-3">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              ART
            </p>
            <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
              Art intentionally removed; mechanics only.
            </h2>
            <p className="text-muted-foreground">
              Art will be reconnected separately. CollectionNFT still mints,
              reveals, and Ignites. tokenURI is a placeholder SVG (rectangle +
              PET# + SEALED / DORMANT / LIT). Seed domain {SITE.artDomain} and
              trait rolls are unchanged so a later art agent can plug drawing
              back in without remapping ids.
            </p>
          </div>
          <Card className="max-w-2xl">
            <CardHeader>
              <CardTitle className="text-base">NFT interface intact</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              name, symbol, tokenURI, contractURI, sealedTraits, and ERC-2981
              stay. No art-pass stills, no gallery, no species sheets.
            </CardContent>
          </Card>
        </div>
      </section>

      <section
        id="status"
        className="relative mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6"
      >
        <div className="mb-8 max-w-2xl space-y-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            STATUS
          </p>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Contracts ready. Not deployed.
          </h2>
          <p className="text-muted-foreground">
            Ready to deploy — not broadcast. Deploy stays sealed (placeholder
            metadata, Ignite off, $TERM trading off, royalties to TermFund)
            until CollectionNFT.reveal(). Addresses stay empty until Robinhood
            Chain deploy and the OpenSea import.
          </p>
        </div>
        <ol className="space-y-3">
          {ROADMAP.map((item) => (
            <li key={item.title}>
              <Card>
                <CardHeader className="flex flex-row items-start justify-between gap-4">
                  <div>
                    <CardTitle className="text-base">{item.title}</CardTitle>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {item.body}
                    </p>
                  </div>
                  <ComingSoon>
                    {item.state === "done"
                      ? "Done"
                      : item.state === "now"
                        ? "Now"
                        : "Next"}
                  </ComingSoon>
                </CardHeader>
              </Card>
            </li>
          ))}
        </ol>
      </section>

      <section
        id="faq"
        className="relative border-t border-border/60 bg-card/25"
      >
        <div className="mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6">
          <div className="mb-8 max-w-2xl space-y-3">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              FAQ
            </p>
            <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
              Short answers.
            </h2>
          </div>
          <Accordion
            type="single"
            collapsible
            defaultValue="faq-0"
            className="max-w-3xl rounded-xl border border-border/70 bg-card/60 px-4"
          >
            {FAQ.map((item, index) => (
              <AccordionItem key={item.q} value={`faq-${index}`}>
                <AccordionTrigger className="text-base">
                  {item.q}
                </AccordionTrigger>
                <AccordionContent className="text-muted-foreground">
                  {item.a}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </section>

      <section
        id="links"
        className="relative mx-auto max-w-6xl scroll-mt-28 px-4 py-16 sm:px-6"
      >
        <div className="mb-8 max-w-2xl space-y-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
            LINKS
          </p>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Places that will exist.
          </h2>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">OpenSea</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>Public mint after import. Collection name {SITE.name}.</p>
              {links.opensea ? (
                <Button size="sm" asChild>
                  <a href={links.opensea} rel="noreferrer" target="_blank">
                    Open collection
                  </a>
                </Button>
              ) : (
                <ComingSoon>Coming soon</ComingSoon>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">X</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>Announcements after deploy. Handle not set yet.</p>
              {links.x ? (
                <Button size="sm" variant="outline" asChild>
                  <a href={links.x} rel="noreferrer" target="_blank">
                    Open X
                  </a>
                </Button>
              ) : (
                <ComingSoon>Coming soon</ComingSoon>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Explorer</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>
                {SITE.chain} Blockscout. Contract pages appear after broadcast.
              </p>
              <Button size="sm" variant="outline" asChild>
                <a href={links.explorer} rel="noreferrer" target="_blank">
                  Open explorer
                </a>
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Terminal</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>
                Wallet tools: Ignite, Hopper fill, Pulse, claim, TBA. Dial is
                listed as deploying soon — no live picker yet.
              </p>
              <Button size="sm" asChild>
                <Link href="/app">Open the app</Link>
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Status</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>
                Contracts ready, not deployed. Art disconnected until a later
                reconnect.
              </p>
              <Button size="sm" variant="outline" asChild>
                <Link href="/#status">See status</Link>
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Hopper</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>Dedicated explainer for the locked ETH pot and Pulse ladder.</p>
              <Button size="sm" variant="outline" asChild>
                <Link href="/hopper">Read Hopper</Link>
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Dial</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>Up to 3 Stock Tokens, weights, no Dial → $TERM, TBA delivery.</p>
              <Button size="sm" variant="outline" asChild>
                <Link href="/dial">Read Dial</Link>
              </Button>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  );
}
