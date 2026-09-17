import { defineChain, type Chain } from "viem";
import { baseSepolia, foundry, mainnet } from "viem/chains";

export const ROBINHOOD_CHAIN_ID = 4663;
export const ROBINHOOD_TESTNET_CHAIN_ID = 46630;
export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const ETHEREUM_CHAIN_ID = 1;

export const ROBINHOOD_RPC = "https://rpc.mainnet.chain.robinhood.com";
export const ROBINHOOD_EXPLORER = "https://robinhoodchain.blockscout.com";
export const ETHEREUM_RPC = "https://ethereum.publicnode.com";
export const ETHEREUM_EXPLORER = "https://etherscan.io";
export const ROBINHOOD_TESTNET_RPC = "https://rpc.testnet.chain.robinhood.com";
export const ROBINHOOD_TESTNET_EXPLORER =
  "https://explorer.testnet.chain.robinhood.com";
export const BASE_SEPOLIA_RPC = "https://sepolia.base.org";
export const BASE_SEPOLIA_EXPLORER = "https://sepolia.basescan.org";

export const robinhoodChain = defineChain({
  id: ROBINHOOD_CHAIN_ID,
  name: "Robinhood Chain",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [ROBINHOOD_RPC] },
  },
  blockExplorers: {
    default: { name: "Blockscout", url: ROBINHOOD_EXPLORER },
  },
});

export const robinhoodTestnet = defineChain({
  id: ROBINHOOD_TESTNET_CHAIN_ID,
  name: "Robinhood Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [ROBINHOOD_TESTNET_RPC] },
  },
  blockExplorers: {
    default: { name: "Blockscout", url: ROBINHOOD_TESTNET_EXPLORER },
  },
});

export { baseSepolia, foundry, mainnet };

/** Block explorer origin for a partner collection chain. Defaults to Robinhood. */
export function explorerForPartnerChain(chainId?: number) {
  if (chainId === ETHEREUM_CHAIN_ID) return ETHEREUM_EXPLORER;
  return ROBINHOOD_EXPLORER;
}

export function configuredChainId() {
  const raw = process.env.NEXT_PUBLIC_CHAIN_ID?.trim();
  if (raw) return Number(raw);
  // Production / `next build` → 4663. Local `next dev` with env blank → 84532 dry-run.
  return process.env.NODE_ENV === "production"
    ? ROBINHOOD_CHAIN_ID
    : BASE_SEPOLIA_CHAIN_ID;
}

export function configuredRpc() {
  if (process.env.NEXT_PUBLIC_RPC_URL) return process.env.NEXT_PUBLIC_RPC_URL;
  const id = configuredChainId();
  if (id === BASE_SEPOLIA_CHAIN_ID) return BASE_SEPOLIA_RPC;
  if (id === ROBINHOOD_TESTNET_CHAIN_ID) return ROBINHOOD_TESTNET_RPC;
  if (id === foundry.id) return "http://127.0.0.1:8545";
  return ROBINHOOD_RPC;
}

export function explorerUrl() {
  if (process.env.NEXT_PUBLIC_EXPLORER_URL) {
    return process.env.NEXT_PUBLIC_EXPLORER_URL;
  }
  const id = configuredChainId();
  if (id === BASE_SEPOLIA_CHAIN_ID) return BASE_SEPOLIA_EXPLORER;
  if (id === ROBINHOOD_TESTNET_CHAIN_ID) return ROBINHOOD_TESTNET_EXPLORER;
  return ROBINHOOD_EXPLORER;
}

export function knownChains(): Chain[] {
  return [robinhoodChain, robinhoodTestnet, baseSepolia, foundry];
}

export function activeChain(): Chain {
  const id = configuredChainId();
  return knownChains().find((chain) => chain.id === id) ?? robinhoodChain;
}

export function isBaseSepolia() {
  return configuredChainId() === BASE_SEPOLIA_CHAIN_ID;
}

export function isRobinhoodMainnet() {
  return configuredChainId() === ROBINHOOD_CHAIN_ID;
}
