import { DIAL_COPY } from "./dial";

/**
 * Canonical public production origin.
 * Override with NEXT_PUBLIC_SITE_URL. `terminal-pets.vercel.app` still
 * resolves as a fallback alias until DNS is fully cut over.
 */
export const DEFAULT_SITE_URL = "https://terminalpets.xyz";
export const SITE_URL_ALIAS = "https://terminal-pets.vercel.app";

export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL?.trim() || DEFAULT_SITE_URL
).replace(/\/$/, "");

export const SEALED_METADATA_PATH = "/metadata/hidden.json";
export const SEALED_METADATA_URI = `${SITE_URL}${SEALED_METADATA_PATH}`;
export const SEALED_METADATA_URI_ALIAS = `${SITE_URL_ALIAS}${SEALED_METADATA_PATH}`;

export const SITE = {
  name: "Terminal Pets",
  symbol: "TERM",
  petName: "Terminal Pets",
  url: SITE_URL,
  urlAlias: SITE_URL_ALIAS,
  tagline: "Handheld pets that sleep until you Ignite them.",
    description:
    "Generative Pocket Critter PFPs on Robinhood Chain. Free mint Friday, September 18, 2026, America/Los_Angeles (PT). Mint on this hub (CollectionNFT.mint / mintTo while mintOpen). Pets mint Sealed for 24 hours: every tokenURI is the same hidden.json — collectors cannot see traits until CollectionNFT.reveal(). Hub carousel GIFs are examples / not mint supply. Ignite off, $TERM trading off, and 7.5% secondary royalties all to TermFund until reveal. Reveal shows a dormant egg GIF, turns on Ignite and trading, and switches royalties to 5% Hopper / 2.5% treasury. Hopper claims stay locked 7 days after reveal while ETH accrues. Each pet comes with a $TERM Ignite allotment. Ignite splits that 1,000 $TERM 37.5% burn / 25% Hopper (as ETH) / 37.5% allotment refill, plus 0.002 ETH split 50% buy-and-burn $TERM / 50% Hopper. Team earns 0 from that ETH fee. Dial assigns 1–4 Stock Tokens by shell class at Ignite. Pulse pays Dialed Lit in Stock Tokens and undialed Lit in $TERM — typically to the TBA. Hopper stays ETH.",
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
    "1 per public phase window (GTD / FCFS / Public). On-chain the hub calls CollectionNFT.mint / mintTo while mintOpen — there are no separate phase contracts. Public mintOpen stays closed until Friday phases.",
  teamAllocation: {
    date: "Thursday, September 17, 2026",
    shortDate: "Thu Sep 17",
    time: "8:00 PM PT",
    name: "Team allocation",
    note: "teamMint 200 to the team wallet. Owner-only. Not a public mint.",
  },
  phases: [
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
  teamLine: `${mintSchedule.teamAllocation.date}, ${mintSchedule.teamAllocation.time} — ${mintSchedule.teamAllocation.name} only (${mintSchedule.teamAllocation.note})`,
  sentence: `${mintSchedule.teamAllocation.date}, ${mintSchedule.teamAllocation.time} — Team allocation only (teamMint 200 to the team wallet). Not a public mint. Public mintOpen stays closed until Friday. Free mint on ${mintSchedule.date}. Times are ${mintSchedule.timezoneIana} (${mintSchedule.timezoneLabel}): ${mintSchedule.phases.map(mintPhaseLine).join("; ")}. ${mintSchedule.rule}`,
} as const;

/** Shareable /eligible route. Hash-only #eligible cannot set distinct OG tags. */
export const ELIGIBLE_SHARE = {
  path: "/eligible",
  hash: "/#eligible",
  title: "Check your wallet",
  description: `Check GTD / FCFS partner eligibility for Terminal Pets. Free mint ${mintSchedule.date} ${mintSchedule.timezoneLabel}.`,
  image: "/og-eligible.png",
  imageWidth: 1200,
  imageHeight: 630,
  imageAlt:
    "Terminal Pets wallet checker — GTD / FCFS partner eligibility. Branding and partner logos only.",
} as const;

/** Anti-snipe copy. tokenURI is one hidden.json until CollectionNFT.reveal(). */
export const sealedCopy = {
  badge: "Sealed until reveal",
  label: "examples / not mint supply",
  hiddenUri: SEALED_METADATA_URI,
  hiddenUriAlias: SEALED_METADATA_URI_ALIAS,
  tokenUri:
    "Until CollectionNFT.reveal(), every tokenURI is the same sealed hidden.json. Collectors cannot see traits.",
  tokenUriLine: `Until CollectionNFT.reveal(), every tokenURI is ${SEALED_METADATA_URI}. Collectors cannot see traits. ${SEALED_METADATA_URI_ALIAS} still resolves until DNS is fully cut over.`,
  carousel:
    "Hub GIFs are examples / not mint supply. They are not live collection tokenIds.",
  sentence:
    "Until CollectionNFT.reveal(), every tokenURI is the same sealed hidden.json. Collectors cannot see traits, species, or rarity. Hub carousel GIFs are examples / not mint supply — not the 4444 mint files.",
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
    a: `${mintScheduleCopy.sentence} ${mintAllocation.sentence} Mint on this hub at /mint. The button calls CollectionNFT.mint (or mintTo) when on-chain mintOpen is true; if mintOpen is false the hub shows mint closed. Do not mint through OpenSea Studio’s deploy-Drop wizard — Studio currently has no BYO import and no Base Sepolia in Drop create. Each pet mints Sealed: every tokenURI is the same hidden.json until CollectionNFT.reveal(), so collectors cannot see traits. Dormant egg art, Ignite, and $TERM trading unlock at reveal.`,
  },
  {
    q: "Am I eligible for GTD or FCFS?",
    a: "The hub checker reads live ERC-721 balanceOf against announced partner collections on Robinhood Chain, plus School of NFTs holdings on Ethereum mainnet (same wallet addresses), plus wallets dropped on the GTD X thread, plus arcade top 150 from Ignite the Dial (/arcade). GTD if you hold any GTD partner NFT, your wallet is on that thread list, or you are arcade top 150. FCFS if you hold any FCFS partner NFT or you are GTD-eligible (GTD wallets also unlock FCFS). Public (Friday 10:00 AM PT) is open to everyone, no allowlist. This is a hub preview, not an on-chain mint allowlist — CollectionNFT still gates on mintOpen. Partner, thread, and arcade lists may grow before Travis locks mint phase.",
  },
  {
    q: "What is the arcade?",
    a: "Ignite the Dial is a short CRT mini-game at /arcade. Catch Dial ticks, dodge glitches, keep the sealed pet lit. One best score per wallet. Top 150 wallets lock GTD (and FCFS via GTD) on the hub checker. Play before Friday, September 18, 2026 5:00 AM PT so winners can merge before the 7:00 AM PT hub redeploy. Hub preview only — not an on-chain mint allowlist.",
  },
  {
    q: "How many can I mint?",
    a: `${mintSchedule.rule} Public phases on ${mintSchedule.date}: ${mintScheduleCopy.phasesLong}. Thursday team allocation is owner-only teamMint, not a collector mint. ${mintAllocation.sentence} Free mint — no mint price.`,
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
    a: `Ignite assigns 1–4 Robinhood Chain Stock Tokens from a fixed pool (${DIAL_COPY.poolLine}) by shell class: ALPHA Common → 1, BETA Rare → 2, DELTA Epic → 3, OMEGA Legendary → 4. Holders do not pick. Equal weights. Pulse swaps that Lit share into those tokens (to the TBA, or the owner if TBA delivery is off). If a Dial has no filled token addresses, that share buys $TERM — not ETH.`,
  },
  {
    q: "What are Stock Tokens here?",
    a: `Robinhood Chain Stock Tokens Pulse may buy with Hopper ETH according to each Lit pet’s assigned Dial (${DIAL_COPY.poolLine}). They credit the pet’s TBA (or the owner wallet if TBA delivery is off). They travel with the NFT; the owner can withdraw. They are not shares of those companies.`,
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
    q: "Can I see traits at mint?",
    a: `No. Until CollectionNFT.reveal(), every tokenURI is ${SEALED_METADATA_URI}. Collectors cannot see traits, species, or rarity. ${SEALED_METADATA_URI_ALIAS} still resolves as a fallback alias until DNS is fully cut over. Hub carousel GIFs are examples / not mint supply and are not the live 4444 files.`,
  },
  {
    q: "Where is the pet art?",
    a: "Generative Pocket Critter PFPs — off-chain composed PNG/GIF, not on-chain SVG. Tokens mint Sealed: every tokenURI is the same hidden.json until CollectionNFT.reveal(), so collectors cannot see traits. After reveal, dormant egg GIFs go live; Ignite swaps to the matching awake pet GIF. Hub carousel GIFs (~25) are examples / not mint supply — not live collection tokenIds, and not hosted as /metadata/{lit,dormant}/{id}.json. The 4444 pin stays private until after reveal. The old Track A TerminalRenderer SVG pets are not product art.",
  },
  {
    q: "Where do royalties go?",
    a: "Depends when you sell. Pre-reveal (mint → activation): the full 7.5% creator royalty goes to TermFund for $TERM LP — nothing to Hopper, nothing to treasury from that stream. After CollectionNFT.reveal(): 5% Hopper / 2.5% team treasury. Always point OpenSea earnings at the RoyaltySplitter.",
  },
  {
    q: "Are contract addresses live?",
    a: "Robinhood mainnet (4663) is live. CollectionNFT 0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166. On-chain mintOpen is still false until Friday — the hub reads that flag and does not fake it open. Production defaults are web/.env.production. Base Sepolia dry-run CollectionNFT 0xe1cC988CeC1C29764ba18523635De82d0C9B518F is the testing stack when NEXT_PUBLIC_CHAIN_ID=84532. Hybrid Ignite 0.002 ETH, Hopper 7 days, Dial 1–4 by shell class are product defaults.",
  },
  {
    q: "How does the 24h reveal work?",
    a: "Tokens mint Sealed — every tokenURI is the same hidden.json, so collectors cannot see traits. Ignite is off and $TERM public transfers are off. Secondary royalties (7.5%) go entirely to TermFund. After 24 hours anyone can call reveal(); the owner can call it earlier. Reveal serves dormant egg metadata, turns on Ignite and $TERM trading, and switches royalties to 5% Hopper / 2.5% treasury. Hopper payouts then stay locked 7 days from that reveal timestamp so people can Ignite before claims open. ETH from Ignite and post-reveal royalties still accrues in the pot. LP is seeded later from TermFund (pre-reveal royalties + optional treasury $TERM), not by draining the Hopper or taking Ignite ETH.",
  },
  {
    q: "How do $TERM trading fees work?",
    a: "Not a transfer tax — $TERM stays a normal ERC-20 so Uniswap-style routers keep working. Public transfers are off until reveal. After that, the canonical TERM/ETH pool calls TermMarket.onSwap. Default skim is 3% of input: 1.5% converted to ETH for the Hopper (Pulse fuel), 1.0% bought as $TERM and burned (or burned directly on sells), 0.5% treasury. Inactive until owner sets TERM_POOL and TERM_SWAP_ROUTER. Other pools are untaxed unless they opt in.",
  },
] as const;
