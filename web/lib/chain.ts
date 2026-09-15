import { defineChain } from "viem";
import { foundry } from "viem/chains";

export const ROBINHOOD_CHAIN_ID = 4663;
export const ROBINHOOD_RPC = "https://rpc.mainnet.chain.robinhood.com";
export const ROBINHOOD_EXPLORER = "https://robinhoodchain.blockscout.com";

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

export function configuredChainId() {
  const raw = process.env.NEXT_PUBLIC_CHAIN_ID;
  return raw ? Number(raw) : ROBINHOOD_CHAIN_ID;
}

export function configuredRpc() {
  return process.env.NEXT_PUBLIC_RPC_URL || ROBINHOOD_RPC;
}

export function explorerUrl() {
  return process.env.NEXT_PUBLIC_EXPLORER_URL || ROBINHOOD_EXPLORER;
}

export function activeChain() {
  return configuredChainId() === foundry.id ? foundry : robinhoodChain;
}
