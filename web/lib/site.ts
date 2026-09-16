export const SITE = {
  name: "Terminal Pets",
  symbol: "TERM",
  petName: "Terminal Pets",
  tagline: "Handheld pets that sleep until you Ignite them.",
    description:
    "Generative Pocket Critter PFPs on Robinhood Chain. Free mint Friday, September 18, 2026, America/Los_Angeles (PT). Mint on OpenSea. Pets mint Sealed for 24 hours: hidden metadata, Ignite off, $TERM trading off, and 7.5% secondary royalties all to TermFund. Reveal shows a dormant egg GIF, turns on Ignite and trading, and switches royalties to 5% Hopper / 2.5% treasury. Hopper claims stay locked 7 days after reveal while ETH accrues. Each pet comes with a $TERM Ignite allotment. Ignite splits that 1,000 $TERM 37.5% burn / 25% Hopper (as ETH) / 37.5% allotment refill, plus 0.002 ETH split 50% buy-and-burn $TERM / 50% Hopper. Team earns 0 from that ETH fee. Dial assigns 1–4 Stock Tokens by shell class at Ignite. Pulse pays Dialed Lit in Stock Tokens and undialed Lit in $TERM — typically to the TBA. Hopper stays ETH.",
  disclaimer:
    "Dial and Pulse Stock Token rewards are promotional on-chain rewards. They are not dividends, equity, shareholder rights, or ownership of any underlying company. Holding a pet or receiving Stock Tokens confers no legal interest in those companies. Not financial or investment advice.",
  chain: "Robinhood Chain",
  chainId: 4663,
  gas: "ETH",
  supply: 4444,
  teamReserve: 200,
  publicSupply: 4244,
  teamReserveUse: "airdrops, burns, giveaways, and similar",
  mintPrice: "Free",
  igniteFee: "1,000 $TERM + 0.002 ETH",
  igniteFeeTerm: "1,000 $TERM",
  igniteFeeEth: "0.002 ETH",
  igniteEthSplit: "50% buy/burn $TERM / 50% Hopper",
  igniteEthHopper: "50%",
  igniteEthBurn: "50%",
  igniteSplit: "37.5% burn / 25% Hopper / 37.5% allotment refill",
  igniteHopper: "25%",
  igniteBurn: "37.5%",
  igniteAllotmentRefill: "37.5%",
  termFund: "TermFund",
  revealWindow: "24 hours",
  hopperLock: "7 days",
  tradeFee: "3%",
  tradeHopper: "1.5%",
  tradeBurn: "1.0%",
  tradeTreasury: "0.5%",
  pulseThreshold: "ladder",
  pulseLadderBootstrap: "0.1 → 0.2 → … → 1.0 ETH",
  pulseLadderCycle: "0.5 → 0.6 → … → 1.0 ETH, then back to 0.5",
  royalty: "7.5%",
  royaltyHopper: "5%",
  royaltyTreasury: "2.5%",
  artSystem: "Pocket Critter",
  artCompose: "2048 PNG compose / 512 GIF export",
  explorer: "https://robinhoodchain.blockscout.com",
  rpc: "https://rpc.mainnet.chain.robinhood.com",
} as const;

/** Hub / app mint-split line. Matches CollectionConfig MAX_SUPPLY / TEAM_RESERVE / PUBLIC_SUPPLY. */
export const mintAllocation = {
  sentence: `Total supply is ${SITE.supply}. ${SITE.teamReserve} are reserved for the team for ${SITE.teamReserveUse}. Public mint is the remaining ${SITE.publicSupply}.`,
  appHint: `Free mint · ${SITE.publicSupply} public / ${SITE.teamReserve} team (${SITE.teamReserveUse})`,
} as const;

/** Hub mint drop schedule. Copy only — CollectionNFT has mintOpen + mintPrice (default 0), not phase contracts. */
export const mintSchedule = {
  date: "Friday, September 18, 2026",
  timezoneLabel: "PT",
  timezoneIana: "America/Los_Angeles",
  price: "Free",
  perPhase: 1,
  rule:
    "Everyone may mint 1 in every phase that gets added or opened for them (1 per phase).",
  phases: [
    { time: "7:00 AM PT", name: "Team" },
    { time: "8:00 AM PT", name: "GTD", note: "guaranteed" },
    { time: "9:00 AM PT", name: "FCFS" },
    { time: "10:00 AM PT", name: "Public" },
  ],
} as const;

export function mintPhaseLine(
  phase: (typeof mintSchedule.phases)[number],
): string {
  return "note" in phase && phase.note
    ? `${phase.time} — ${phase.name} (${phase.note})`
    : `${phase.time} — ${phase.name}`;
}

export const mintScheduleCopy = {
  headline: `Free mint · ${mintSchedule.date} · ${mintSchedule.timezoneIana} (${mintSchedule.timezoneLabel})`,
  when: `Free mint on ${mintSchedule.date}. Times are ${mintSchedule.timezoneIana} (${mintSchedule.timezoneLabel}).`,
  phases: mintSchedule.phases.map(mintPhaseLine).join(" · "),
  phasesLong: mintSchedule.phases.map(mintPhaseLine).join("; "),
  sentence: `Free mint on ${mintSchedule.date}. Times are ${mintSchedule.timezoneIana} (${mintSchedule.timezoneLabel}): ${mintSchedule.phases.map(mintPhaseLine).join("; ")}. ${mintSchedule.rule}`,
} as const;

export const PULSE_BOOTSTRAP = [
  "0.1",
  "0.2",
  "0.3",
  "0.4",
  "0.5",
  "0.6",
  "0.7",
  "0.8",
  "0.9",
  "1.0",
] as const;

export const PULSE_CYCLE = ["0.5", "0.6", "0.7", "0.8", "0.9", "1.0"] as const;

export function publicLinks() {
  const opensea = process.env.NEXT_PUBLIC_OPENSEA_URL?.trim() ?? "";
  const x = process.env.NEXT_PUBLIC_X_URL?.trim() ?? "";
  const explorer =
    process.env.NEXT_PUBLIC_EXPLORER_URL?.trim() || SITE.explorer;
  return { opensea, x, explorer };
}

export const FAQ = [
  {
    q: "When can I mint?",
    a: `${mintScheduleCopy.sentence} ${mintAllocation.sentence} After contracts land on Robinhood Chain and the OpenSea collection is imported. Each pet mints Sealed (hidden metadata) with a TBA and a one-time $TERM Ignite allotment. Dormant egg art, Ignite, and $TERM trading unlock at reveal.`,
  },
  {
    q: "How many can I mint?",
    a: `${mintSchedule.rule} Same-day schedule on ${mintSchedule.date}: ${mintScheduleCopy.phasesLong}. ${mintAllocation.sentence} Free mint — no mint price.`,
  },
  {
    q: "What is $TERM?",
    a: "Terminal Pets’ own ERC-20 memecoin on Robinhood Chain. Symbol $TERM. Not AGENT / freights.one. Collection NFT symbol stays TERM. Each pet’s allotment covers the $TERM half of one Ignite from token supply. Ignite splits the 1,000 $TERM fee 37.5% burn / 25% to Hopper as ETH / 37.5% back into the allotment escrow (pool refill — that tokenId stays consumed). Plus 0.002 ETH: 50% buys $TERM and burns, 50% to Hopper. Team earns 0 from that ETH fee. $TERM is not fee-on-transfer. When the canonical TERM/ETH pool is live, TermMarket skims 3% of that pool’s swap volume: 1.5% to Hopper (as ETH), 1% buy/burn, 0.5% treasury.",
  },
  {
    q: "Do I need to buy $TERM to Ignite?",
    a: "Not for the $TERM half of the first wake. Minting a pet reserves 1,000 $TERM (placeholder) in the IgniteModule escrow for that tokenId. Ignite spends the allotment directly — no DEX buy. You can instead claimIgniteAllotment while Dormant, then approve and Ignite from your wallet. You still send 0.002 ETH with Ignite: 50% buys $TERM and burns, 50% goes to Hopper. Team earns 0 from that ETH fee. 25% of the $TERM fee becomes Hopper ETH once a swap router is set (otherwise it parks until flush). 37.5% of the fee returns to the allotment pool for other pets. After this token’s allotment is used, that id cannot claim again. v1 Lit stays Lit on transfer.",
  },
  {
    q: "What is Ignite?",
    a: "A one-way wake, off until reveal. Hybrid fee: 1,000 $TERM (allotment or wallet) split 37.5% burned, 25% converted to ETH for the Hopper, 37.5% returned to the Ignite allotment escrow — not treasury — plus exactly 0.002 ETH, half buy-and-burn $TERM, half Hopper. Team earns 0 from the ETH fee. The pet turns Lit and stays Lit on transfer. You cannot un-Ignite.",
  },
  {
    q: "What is Dial?",
    a: "Ignite assigns 1–4 Robinhood Chain Stock Tokens from a fixed pool (HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA) by shell class: ALPHA Common → 1, BETA Rare → 2, DELTA Epic → 3, OMEGA Legendary → 4. Holders do not pick. Equal weights. Pulse swaps that Lit share into those tokens (to the TBA, or the owner if TBA delivery is off). If a Dial has no filled token addresses, that share buys $TERM — not ETH.",
  },
  {
    q: "What are Stock Tokens here?",
    a: "Robinhood Chain Stock Tokens Pulse may buy with Hopper ETH according to each Lit pet’s assigned Dial (HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA). They credit the pet’s TBA (or the owner wallet if TBA delivery is off). They travel with the NFT; the owner can withdraw. They are not shares of those companies.",
  },
  {
    q: "Do I own the stock company?",
    a: "No. Dial and Pulse Stock Token rewards are promotional on-chain rewards. They are not dividends, equity, shareholder rights, or ownership of any underlying company. Holding a pet or receiving Stock Tokens confers no legal interest in those companies. Not financial or investment advice.",
  },
  {
    q: "What if a pet has no Dial?",
    a: "Every Lit pet is assigned Dial at Ignite. If those stock addresses are still unset, or assignment was skipped, that Lit pet’s Pulse share buys $TERM via the market router and credits the TBA (or the owner wallet if TBA delivery is off). Not ETH. Dormant pets are not assigned Dial and earn nothing on Pulse.",
  },
  {
    q: "What is the Hopper?",
    a: "A locked ETH pot with no admin withdraw. After reveal it fills from 5% of each secondary NFT sale via the RoyaltySplitter, from 50% of each Ignite 0.002 ETH fee, from 25% of each Ignite $TERM fee (swapped to ETH when a router is set), and — once the canonical $TERM market is live — from a 1.5% TermMarket swap skim. During the 24h sealed window, secondary royalties do not enter the Hopper — they go 100% to TermFund. After reveal, Hopper claims and Pulse payouts stay locked for 7 days (timer from reveal, not from first Ignite) while ETH still accrues. Then claims open. The other 50% of Ignite ETH buys $TERM and burns. Hopper stays ETH until Pulse.",
  },
  {
    q: "What is TermFund?",
    a: "The $TERM liquidity pot. Pre-reveal, 100% of the 7.5% secondary royalty stream lands here to seed LP. Ignite’s 0.002 ETH does not. Ignite’s 37.5% $TERM refill stays on IgniteModule as allotment escrow, not here. Team can later seedLiquidity with fund ETH plus treasury $TERM — manual ops, not an automatic Hopper divert. No owner withdraw.",
  },
  {
    q: "How does the Pulse ladder work?",
    a: "Not a fixed 0.5 ETH line. Bootstrap (once): Hopper available() must hit 0.1 ETH, then 0.2, 0.3 … up to 1.0 ETH, stepping 0.1 each successful Pulse. After the Pulse at 1.0 during bootstrap, the next threshold is 0.5 ETH — never 0.1 again. Then it cycles 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, back to 0.5, forever.",
  },
  {
    q: "Who earns from Pulse?",
    a: "Lit terminals only, pro-rata at the snapshot. Pulse reads each Dial, swaps Hopper ETH into the assigned Stock Tokens, and credits TBAs (or owner wallets). Lit pets with no filled Dial addresses get $TERM the same way. Dormant earn nothing. The Hopper pot itself stays ETH.",
  },
  {
    q: "What is a TBA?",
    a: "A token-bound account (ERC-6551) attached at mint. Pulse typically delivers Stock Tokens or $TERM there. Those assets travel with the NFT. The owner can withdraw. Delivery to the owner wallet is used if TBA delivery is off.",
  },
  {
    q: "Where is the pet art?",
    a: "Generative Pocket Critter PFPs — off-chain composed PNG/GIF, not on-chain SVG. Tokens mint Sealed (hidden metadata), reveal as a dormant egg rock GIF, then swap to the matching awake pet GIF on Ignite. Sample previews are on this hub. The old Track A TerminalRenderer SVG pets are not product art.",
  },
  {
    q: "Where do royalties go?",
    a: "Depends when you sell. Pre-reveal (mint → activation): the full 7.5% creator royalty goes to TermFund for $TERM LP — nothing to Hopper, nothing to treasury from that stream. After CollectionNFT.reveal(): 5% Hopper / 2.5% team treasury. Always point OpenSea earnings at the RoyaltySplitter.",
  },
  {
    q: "Are contract addresses live?",
    a: "Contracts are ready to deploy and not broadcast. No live addresses yet. Hybrid Ignite, TermFund, TermMarket skim (off until TERM_POOL + router), 24h sealed reveal, Dial, Pulse ladder are in the repo. Robinhood Chain deploy waits until someone says go.",
  },
  {
    q: "How does the 24h reveal work?",
    a: "Tokens mint Sealed — hidden metadata, Ignite off, $TERM public transfers off. Secondary royalties (7.5%) go entirely to TermFund. After 24 hours anyone can call reveal(); the owner can call it earlier. Reveal serves dormant egg metadata, turns on Ignite and $TERM trading, and switches royalties to 5% Hopper / 2.5% treasury. Hopper payouts then stay locked 7 days from that reveal timestamp so people can Ignite before claims open. ETH from Ignite and post-reveal royalties still accrues in the pot. LP is seeded later from TermFund (pre-reveal royalties + optional treasury $TERM), not by draining the Hopper or taking Ignite ETH.",
  },
  {
    q: "How do $TERM trading fees work?",
    a: "Not a transfer tax — $TERM stays a normal ERC-20 so Uniswap-style routers keep working. Public transfers are off until reveal. After that, the canonical TERM/ETH pool calls TermMarket.onSwap. Default skim is 3% of input: 1.5% converted to ETH for the Hopper (Pulse fuel), 1.0% bought as $TERM and burned (or burned directly on sells), 0.5% treasury. Inactive until owner sets TERM_POOL and TERM_SWAP_ROUTER. Other pools are untaxed unless they opt in.",
  },
] as const;
