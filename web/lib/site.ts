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

export const SITE = {
  name: "Terminal Pets",
  symbol: "TERM",
  petName: "Terminal Pets",
  url: SITE_URL,
  urlAlias: SITE_URL_ALIAS,
  tagline: "Your eggs are ready. Wake them up.",
  description:
    "Minted out. Wake your Terminal Pet on Robinhood Chain: connect the wallet that holds your egg and Ignite it for 0.002 ETH. The $TERM is already in the egg. Awake pets can earn from the Hopper.",
  disclaimer:
    "Dial and Pulse stock rewards are promotional on-chain rewards. They are not dividends, equity, shareholder rights, or ownership of any underlying company. Holding a pet or receiving stock tokens confers no legal interest in those companies. Not financial or investment advice.",
  chain: "Robinhood Chain",
  chainId: 4663,
  gas: "ETH",
  supply: 4444,
  igniteFee: "0.002 ETH",
  igniteFeeTerm: "1,000 $TERM",
  igniteFeeEth: "0.002 ETH",
  hopperLock: "7 days",
  pulseLadderBootstrap: "0.1 → 0.2 → … → 1.0 ETH",
  pulseLadderCycle: "0.5 → 0.6 → … → 1.0 ETH, then back to 0.5",
  explorer: "https://robinhoodchain.blockscout.com",
  rpc: "https://rpc.mainnet.chain.robinhood.com",
  stocks: DIAL_COPY.poolLine,
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
    q: "How do I wake my egg?",
    a: "Connect the wallet that holds it, switch to Robinhood Chain, and press Ignite. It costs 0.002 ETH. The 1,000 $TERM is already inside the egg, so you do not buy that first.",
  },
  {
    q: "What do I need in my wallet?",
    a: "A little ETH on Robinhood Chain (chain id 4663): 0.002 for the Ignite fee, plus a bit more for gas. If you already moved the $TERM out of the egg, approve that $TERM and then Ignite.",
  },
  {
    q: "I don't see my egg.",
    a: "The mint is over. This page only lists eggs in the wallet you connected. If yours is in a different wallet, connect that one.",
  },
  {
    q: "What happens after Ignite?",
    a: `Your pet wakes up and Dial assigns its stock rewards (1 to 4, from ${SITE.stocks}). Awake pets can earn from the Hopper if Pulse runs. Sleeping eggs do not. You cannot put a pet back to sleep.`,
  },
  {
    q: "When can pets earn?",
    a: `The Hopper holds ETH. Pulse can run ${SITE.hopperLock} after the collection was revealed, and only if the pot is large enough. Your pet shows the date when the contract has one. If Pulse runs, an awake pet can have something to claim. Nothing is sent on a schedule.`,
  },
  {
    q: "Why can't I claim yet?",
    a: "Claim stays off until something is waiting. Pulse has to run first, which needs the Hopper pot to be large enough and the lock to be over. Sleeping eggs do not earn.",
  },
  {
    q: "What is Dial?",
    a: `The stock rewards assigned when you Ignite. You do not pick them. Rarer pets get more stocks. If a stock token is not set, that share can be $TERM instead. The pool is ${SITE.stocks}. These rewards are not ownership of the companies.`,
  },
  {
    q: "What are the Hopper and Pulse?",
    a: "The Hopper is the ETH pot. Pulse can split it among awake pets and turn each share into that pet's stocks (or $TERM), which you claim on the pet. The pot itself stays ETH until then. Nobody can withdraw it for themselves.",
  },
  {
    q: "I already took the $TERM out of my egg.",
    a: "Ignite then needs an approval so the pet can spend 1,000 $TERM from your wallet, plus the 0.002 ETH fee. The egg shows Approve first, then Ignite.",
  },
  {
    q: "The wallet showed an error.",
    a: "Usual causes: Ignite is not open, the ETH amount did not match the fee, this pet is not in the connected wallet, it is already awake, or the wallet needs more ETH on Robinhood Chain. The page turns those into a short message.",
  },
] as const;
