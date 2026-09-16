import { ComingSoon } from "@/components/coming-soon";
import { ArtGallery } from "@/components/hub/art-gallery";
import { HopperExplainer } from "@/components/hub/hopper-explainer";
import { MintScheduleCard } from "@/components/hub/mint-schedule";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { collectionConfigured } from "@/lib/contracts";
import { activeChain, configuredChainId } from "@/lib/chain";
import {
  FAQ,
  SITE,
  mintAllocation,
  mintSchedule,
  mintScheduleCopy,
  publicLinks,
} from "@/lib/site";
import Link from "next/link";

const STEPS = [
  {
    n: "01",
    title: "Free mint",
    body: `${mintScheduleCopy.sentence} ${mintAllocation.sentence} Mint on this hub when mintOpen is true. Each token mints Sealed — hidden metadata, TBA, and a $TERM allotment. Name is Terminal Pet #{id}. Ignite and $TERM trading stay off.`,
  },
  {
    n: "02",
    title: "24h reveal",
    body: `Sealed for ${SITE.revealWindow}. Owner may call CollectionNFT.reveal() early; anyone can after that. One tx: dormant egg metadata live, $TERM trading on, Ignite on, royalties switch from 7.5% TermFund to ${SITE.royaltyHopper} Hopper / ${SITE.royaltyTreasury} treasury.`,
  },
  {
    n: "03",
    title: "Ignite allotment",
    body: `The pet already has ${SITE.igniteFeeTerm} in escrow for one wake — token supply, not a DEX buy. You still pay ${SITE.igniteFeeEth} with Ignite: ${SITE.igniteEthSplit}. Team earns 0 from that ETH.`,
  },
  {
    n: "04",
    title: "Ignite",
    body: `Off until reveal. Then pay ${SITE.igniteFeeTerm} (allotment or wallet, ${SITE.igniteSplit}) plus exactly ${SITE.igniteFeeEth}. ${SITE.igniteHopper} of $TERM becomes Hopper ETH once a swap router is set. ${SITE.igniteBurn} burns. ${SITE.igniteAllotmentRefill} returns to allotment escrow. The ETH splits ${SITE.igniteEthSplit} — not TermFund, not treasury. On-screen, Ignite is the hatch: the egg cracks, splits, flashes, and the pet wakes.`,
  },
  {
    n: "05",
    title: "Dial",
    body: "Ignite assigns 1–4 Robinhood Chain Stock Tokens by shell class (ALPHA 1 … OMEGA 4) from HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA. Holders do not pick.",
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
    body: "Credit the pet’s TBA (or the owner wallet if TBA delivery is off). Dialed pets get their assigned Stock Tokens. Lit with no filled Dial addresses get $TERM. Dormant earn nothing.",
  },
] as const;

const ECON = [
  { label: "Max supply", value: String(SITE.supply) },
  { label: "Public mint", value: String(SITE.publicSupply) },
  {
    label: "Team reserve",
    value: String(SITE.teamReserve),
    note: "Airdrops, burns, giveaways",
  },
  { label: "Mint price", value: SITE.mintPrice, note: "0 ETH" },
  { label: "Mint date", value: "Fri Sep 18", note: mintSchedule.date },
  {
    label: "Per phase",
    value: String(mintSchedule.perPhase),
    note: "1 in every phase opened for you",
  },
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
    title: "Generative PFP metadata",
    body: "Pocket Critter off-chain GIFs. tokenURI: sealed JSON → dormant egg → awake pet on Ignite. ERC-4906 MetadataUpdate stays. Old on-chain SVG pets are not product art.",
  },
  {
    state: "done" as const,
    title: "25-token GIF test host",
    body: "Hub hosts tokens 1–25 as animated GIFs + JSON at /art/test, /art/test-egg, and /metadata/{hidden,dormant,lit}. After Vercel deploy, setMetadataURIs can use the terminal-pets.vercel.app HTTPS bases. Not a chain deploy.",
  },
  {
    state: "next" as const,
    title: "Pin collection GIFs",
    body: "Generate the remaining 4444 awake + egg GIFs, pin JSON to IPFS/HTTP, then CollectionNFT.setMetadataURIs. A 25-token HTTPS GIF test path is already on this hub.",
  },
  {
    state: "done" as const,
    title: "24h reveal gates",
    body: "Mint → sealed metadata, Ignite off, $TERM trading off, 7.5% royalties → TermFund. CollectionNFT.reveal() flips metadata, Ignite, trading, and 5/2.5 royalties in one tx. Owner early; anyone after 24h.",
  },
  {
    state: "now" as const,
    title: "Public hub mint",
    body: "This site. /mint calls CollectionNFT.mint / mintTo while mintOpen. Ignite / Pulse / Hopper / Dial pages. Terminal route is ready. 25-token GIF test host + sample previews on the hub.",
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
    title: "OpenSea Studio (not the mint path)",
    body: `Studio Drop create currently has no BYO import and no Base Sepolia. Hub mint is primary. Do not use Studio’s deploy-Drop wizard. OpenSea can still show the collection after import. ${SITE.publicSupply} public / ${SITE.teamReserve} team. Phase times are hub copy until on-chain mintOpen.`,
  },
] as const;

export function HubLanding() {
  const links = publicLinks();
  const live = collectionConfigured();
  const chain = activeChain();
  const chainId = configuredChainId();

  return (
    <div className="relative">
      <div className="hub-grid pointer-events-none absolute inset-0 opacity-70" />

      <section className="relative overflow-hidden border-b border-border/60">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_0%,rgba(240,180,41,0.14),transparent_42%),radial-gradient(circle_at_90%_20%,rgba(96,165,250,0.08),transparent_36%)]" />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 sm:py-16 lg:grid-cols-[1.1fr_0.9fr] lg:items-center">
          <div className="space-y-6">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="outline" className="font-mono">
                {chain.name} · {chainId}
              </Badge>
              <Badge variant="outline" className="font-mono">
                Free mint · {mintSchedule.date} · {mintSchedule.timezoneLabel}
              </Badge>
              {live ? (
                <ComingSoon>Hub mint</ComingSoon>
              ) : (
                <ComingSoon />
              )}
            </div>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl lg:text-6xl">
              {SITE.name}
            </h1>
            <p className="max-w-xl text-lg text-muted-foreground">
              {SITE.tagline} Generative Pocket Critter PFPs. Metadata names
              each token Terminal Pet #id. The collection is {SITE.name} (
              {SITE.symbol}). Memecoin is $TERM.
            </p>
            <p className="max-w-xl text-sm text-muted-foreground">
              {mintScheduleCopy.sentence} {mintAllocation.sentence} Mint on
              this hub. Pets mint Sealed for {SITE.revealWindow}: hidden
              metadata, Ignite off, $TERM transfers off. Reveal shows a
              dormant egg GIF; Ignite swaps metadata to the matching awake
              pet. Secondary royalties (
              {SITE.royalty}) go 100% to TermFund — nothing to Hopper, nothing
              to treasury from that stream. Reveal flips metadata live, turns
              on Ignite and $TERM trading, and switches royalties to{" "}
              {SITE.royaltyHopper} Hopper / {SITE.royaltyTreasury} treasury.
              Each pet includes a $TERM allotment for the token half of Ignite.
              That 1,000 $TERM splits {SITE.igniteBurn} burn /{" "}
              {SITE.igniteHopper} Hopper (as ETH) / {SITE.igniteAllotmentRefill}{" "}
              allotment refill, plus {SITE.igniteFeeEth} split{" "}
              {SITE.igniteEthSplit}. Team earns 0 from that ETH. Dial assigns
              1–4 Stock Tokens by shell class at Ignite.
            </p>
            <div className="flex flex-wrap gap-2">
              <Button asChild>
                <Link href="/mint">Mint</Link>
              </Button>
              <Button variant="outline" asChild>
                <Link href="/app">Ignite / Pulse app</Link>
              </Button>
              <Button variant="ghost" asChild>
                <Link href="/hopper">Hopper lock</Link>
              </Button>
              {links.opensea ? (
                <Button variant="ghost" asChild>
                  <a href={links.opensea} rel="noreferrer" target="_blank">
                    View on OpenSea
                  </a>
                </Button>
              ) : null}
            </div>
            <p className="font-mono text-[11px] text-muted-foreground">
              {SITE.supply} total · {SITE.publicSupply} public /{" "}
              {SITE.teamReserve} team · Free mint · {mintSchedule.date} ·{" "}
              {mintScheduleCopy.phases} · 1 / phase · Sealed{" "}
              {SITE.revealWindow} · Ignite {SITE.igniteFee} · Royalty{" "}
              {SITE.royalty}
            </p>
          </div>

          <div className="grid gap-3">
            <MintScheduleCard />
            <div className="rounded-[1.6rem] border border-border/70 bg-card/70 p-5">
              <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
                GENERATIVE PFP
              </p>
              <p className="mt-3 text-lg font-medium">
                Dormant egg. Ignite cracks it open.
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                Modular Pocket Critter GIFs (2048 compose, 512 export). Off-chain
                JSON tokenURI — not the old on-chain SVG pets. Ignite is the
                hatch: crack, split, flash, awake pet.
              </p>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <figure className="overflow-hidden rounded-xl border border-border/70 bg-black/40">
                  <img
                    src="/art/test-egg/2.gif"
                    alt="Sample dormant Terminal Pet egg GIF"
                    className="aspect-square w-full object-cover"
                    width={512}
                    height={512}
                  />
                  <figcaption className="px-2 py-1.5 font-mono text-[10px] text-muted-foreground">
                    Dormant · SNAG egg
                  </figcaption>
                </figure>
                <figure className="overflow-hidden rounded-xl border border-border/70 bg-black/40">
                  <img
                    src="/art/test/2.gif"
                    alt="Sample awakened Terminal Pet GIF"
                    className="aspect-square w-full object-cover"
                    width={512}
                    height={512}
                  />
                  <figcaption className="px-2 py-1.5 font-mono text-[10px] text-muted-foreground">
                    Lit · SNAG awake
                  </figcaption>
                </figure>
              </div>
              <figure className="mt-2 overflow-hidden rounded-xl border border-primary/25 bg-black/40">
                <img
                  src="/art/hatch/snag_hatch.gif"
                  alt="SNAG Ignite hatch GIF: egg cracks, splits, flashes, and the pet wakes"
                  className="aspect-square w-full object-cover"
                  width={512}
                  height={512}
                />
                <figcaption className="px-2 py-1.5 font-mono text-[10px] text-muted-foreground">
                  Hatch · Ignite cracks the egg. Pet wakes.{" "}
                  <Link href="/#art" className="text-primary underline-offset-2 hover:underline">
                    More hatches
                  </Link>
                </figcaption>
              </figure>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">SEALED</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  Hidden / generic metadata until reveal.
                </p>
              </div>
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">DORMANT</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  Matching egg rock GIF. Ignite still off.
                </p>
              </div>
              <div className="rounded-2xl border border-border/70 bg-card/60 p-3">
                <p className="font-mono text-[10px] text-primary">LIT</p>
                <p className="mt-1 text-xs text-muted-foreground">
                  Hatch complete. Awake pet GIF. Dial / Pulse eligible.
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
            {mintScheduleCopy.sentence} {mintAllocation.sentence} Pets mint
            Sealed. After {SITE.revealWindow} (or sooner if the owner
            activates), reveal flips metadata, enables Ignite and $TERM
            trading, and routes royalties to Hopper/treasury. Until then the
            full {SITE.royalty} creator royalty seeds TermFund. Ignite is
            hybrid: {SITE.igniteFeeTerm} splits {SITE.igniteBurn} burn /{" "}
            {SITE.igniteHopper} Hopper / {SITE.igniteAllotmentRefill} allotment
            refill, plus {SITE.igniteFeeEth} split {SITE.igniteEthSplit}. Dial
            aims Pulse.
          </p>
        </div>
        <Card className="mb-6 border-primary/25">
          <CardHeader className="gap-2">
            <p className="font-mono text-[11px] text-primary">MINT SCHEDULE</p>
            <CardTitle className="text-base">
              {mintScheduleCopy.headline}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <ol className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {mintSchedule.phases.map((phase) => (
                <li
                  key={`loop-${phase.name}`}
                  className="rounded-xl border border-border/70 bg-background/40 px-3 py-3"
                >
                  <p className="font-mono text-[11px] text-primary">
                    {phase.time}
                  </p>
                  <p className="mt-1 text-sm font-medium">
                    {phase.name}
                    {"note" in phase && phase.note ? (
                      <span className="ml-1 font-normal text-muted-foreground">
                        ({phase.note})
                      </span>
                    ) : null}
                  </p>
                </li>
              ))}
            </ol>
            <p className="text-sm text-muted-foreground">
              {mintSchedule.rule} {mintAllocation.sentence}
            </p>
          </CardContent>
        </Card>
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
            Shell class assigns 1–4 stocks. No holder picker.
          </h2>
          <p className="text-muted-foreground">
            Lit only. ALPHA 1 / BETA 2 / DELTA 3 / OMEGA 4 from HOOD, AAPL,
            MSFT, GOOGL, AMZN, META, NVDA, TSLA. Equal weights. Unfilled Dial
            addresses → that pet’s share buys $TERM. Pulse credits the TBA;
            tokens travel with the NFT.
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
            Fixed economics. Free mint.
          </h2>
          <p className="text-muted-foreground">
            Supply is locked at {SITE.supply}: {SITE.publicSupply} public mint,{" "}
            {SITE.teamReserve} reserved for the team for {SITE.teamReserveUse}.{" "}
            {mintScheduleCopy.sentence} Royalties are mode-switched at reveal:
            pre-reveal the full {SITE.royalty} goes to TermFund; after reveal it
            is {SITE.royaltyHopper} Hopper / {SITE.royaltyTreasury} treasury.
            Pulse is a ladder, not a fixed 0.5 ETH line. Ignite stays off until
            reveal, then {SITE.igniteFeeTerm} ({SITE.igniteSplit}) plus exactly{" "}
            {SITE.igniteFeeEth} ({SITE.igniteEthSplit}). Team earns 0 from the
            ETH fee. The {SITE.igniteAllotmentRefill} $TERM cut refills
            allotment escrow, not treasury. Live $TERM trades on the canonical
            pool skim {SITE.tradeFee} once TERM_POOL is set. Hub mint is the
            primary path. Do not point OpenSea earnings at a wallet — use the
            splitter.
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
                {"note" in row && row.note ? (
                  <p className="text-xs text-muted-foreground">{row.note}</p>
                ) : null}
              </CardHeader>
            </Card>
          ))}
        </div>
      </section>

      <section
        id="art"
        className="relative scroll-mt-28 border-y border-border/60 bg-card/25"
      >
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="mb-8 max-w-2xl space-y-3">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              ART
            </p>
            <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
              Generative PFPs. Egg sleeps. Ignite cracks it open.
            </h2>
            <p className="text-muted-foreground">
              {SITE.artSystem} system: modular layers, 12 pets, matching eggs,
              Robinhood-green backgrounds ({SITE.artCompose}). Reveal serves the
              dormant egg GIF. Ignite is the hatch — crack, split, flash — then
              tokenURI swaps to the awake pet GIF (ERC-4906). Composed hatch
              GIFs are below; frame PNGs stay in the art package. This hub hosts
              tokens 1–25 as animated GIFs for setMetadataURIs. Old on-chain SVG
              Track A pets and art-pass trait catalogs are not product art.
            </p>
          </div>
          <ArtGallery />
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
            Hub mint is the public path.
          </h2>
          <p className="text-muted-foreground">
            {mintScheduleCopy.sentence} {mintAllocation.sentence} CollectionNFT
            has mintOpen + mintPrice (default 0 / free) — Team / GTD / FCFS /
            Public times are hub copy, not phase contracts. Mint on{" "}
            <Link href="/mint" className="text-primary underline-offset-2 hover:underline">
              /mint
            </Link>{" "}
            when mintOpen is true; the hub shows mint closed otherwise. Robinhood
            mainnet (4663) addresses are env-driven. Base Sepolia dry-run is for
            testing. Do not use OpenSea Studio’s deploy-Drop wizard.
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
            Mint, app, Hopper, Dial.
          </h2>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Mint</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>
                Primary path: this hub. Connect a wallet, switch to the
                configured chain, mint 1 via CollectionNFT.mint when mintOpen
                is true. {mintScheduleCopy.sentence}
              </p>
              <Button size="sm" asChild>
                <Link href="/mint">Open mint</Link>
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">OpenSea</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>
                Collection page after import — not the mint wizard. Studio Drop
                create currently has no BYO import / no Base Sepolia.{" "}
                {SITE.publicSupply} public of {SITE.supply}. Collection name{" "}
                {SITE.name}.
              </p>
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
                Wallet tools: Ignite, Hopper fill, Pulse, claim, TBA. Dial
                assigns on Ignite in the contracts; the app does not offer a
                picker.
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
                Contracts ready, not deployed. Generative PFP samples on the
                hub. Full collection GIFs pin before mint.
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
              <p>
                8 Stock Tokens, ALPHA–OMEGA 1–4 legs, assigned at Ignite, TBA
                delivery.
              </p>
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
