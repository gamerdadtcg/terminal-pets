export const SITE = {
  name: "Terminal Pets",
  symbol: "TERM",
  petName: "Terminal Pets",
  tagline: "Handheld pets that sleep until you Ignite them.",
  description:
    "On-chain Tamagotchi terminals on Robinhood Chain. Mint on OpenSea. Pets mint Sealed for 24 hours: placeholder art, Ignite off, $TERM trading off, and 7.5% secondary royalties all to TermFund. Reveal flips art, Ignite, trading, and royalties to 5% Hopper / 2.5% treasury. Hopper claims stay locked 7 days after reveal while ETH accrues. Each pet comes with a $TERM Ignite allotment. Ignite splits that 1,000 $TERM 37.5% burn / 25% Hopper (as ETH) / 37.5% allotment refill, plus 0.002 ETH split 50% buy-and-burn $TERM / 50% Hopper. Team earns 0 from that ETH fee. Dial up to 3 Stock Tokens. Pulse pays Dialed Lit in Stock Tokens and undialed Lit in $TERM — typically to the TBA. Hopper stays ETH.",
  disclaimer:
    "Dial and Pulse Stock Token rewards are promotional on-chain rewards. They are not dividends, equity, shareholder rights, or ownership of any underlying company. Holding a pet or receiving Stock Tokens confers no legal interest in those companies. Not financial or investment advice.",
  chain: "Robinhood Chain",
  chainId: 4663,
  gas: "ETH",
  supply: 4444,
  teamReserve: 200,
  publicSupply: 4244,
  mintPrice: "TBD",
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
  artDomain: "AWAKEN_PET_V2",
  comboSpace: "826 billion",
  explorer: "https://robinhoodchain.blockscout.com",
  rpc: "https://rpc.mainnet.chain.robinhood.com",
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

export const SPECIES = [
  { name: "Blob", id: 2, file: "species-Blob-id2-lit.svg" },
  { name: "Cat", id: 3, file: "species-Cat-id3-lit.svg" },
  { name: "Dino", id: 12, file: "species-Dino-id12-lit.svg" },
  { name: "Fox", id: 16, file: "species-Fox-id16-lit.svg" },
  { name: "Ghost", id: 7, file: "species-Ghost-id7-lit.svg" },
  { name: "Bunny", id: 28, file: "species-Bunny-id28-lit.svg" },
  { name: "Bird", id: 15, file: "species-Bird-id15-lit.svg" },
  { name: "Frog", id: 5, file: "species-Frog-id5-lit.svg" },
  { name: "Bear", id: 1, file: "species-Bear-id1-lit.svg" },
  { name: "Robot", id: 11, file: "species-Robot-id11-lit.svg" },
  { name: "Owl", id: 4, file: "species-Owl-id4-lit.svg" },
  { name: "Bug", id: 6, file: "species-Bug-id6-lit.svg" },
] as const;

export const SHELLS = [
  "Egg",
  "Round",
  "Square",
  "Wave",
  "Slim",
  "Wide",
  "Octagon",
  "Clam",
] as const;

export const TRAIT_AXES = [
  "Shell",
  "Shell color",
  "Buttons",
  "Antenna",
  "Wallpaper",
  "Species",
  "Body",
  "Belly",
  "Eyes",
  "Pupil",
  "Mouth",
  "Cheeks",
  "Ears",
  "Accessory",
  "Generation",
] as const;

export function publicLinks() {
  const opensea = process.env.NEXT_PUBLIC_OPENSEA_URL?.trim() ?? "";
  const x = process.env.NEXT_PUBLIC_X_URL?.trim() ?? "";
  const explorer =
    process.env.NEXT_PUBLIC_EXPLORER_URL?.trim() || SITE.explorer;
  return { opensea, x, explorer };
}
