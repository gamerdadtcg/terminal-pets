"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { WagmiProvider, createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import {
  BASE_SEPOLIA_RPC,
  ROBINHOOD_RPC,
  ROBINHOOD_TESTNET_RPC,
  baseSepolia,
  configuredChainId,
  configuredRpc,
  foundry,
  robinhoodChain,
  robinhoodTestnet,
} from "@/lib/chain";

const rpcFor = (id: number, fallback: string) =>
  configuredChainId() === id ? configuredRpc() : fallback;

const config = createConfig({
  chains: [robinhoodChain, robinhoodTestnet, baseSepolia, foundry],
  connectors: [injected()],
  transports: {
    [robinhoodChain.id]: http(rpcFor(robinhoodChain.id, ROBINHOOD_RPC)),
    [robinhoodTestnet.id]: http(
      rpcFor(robinhoodTestnet.id, ROBINHOOD_TESTNET_RPC),
    ),
    [baseSepolia.id]: http(rpcFor(baseSepolia.id, BASE_SEPOLIA_RPC)),
    [foundry.id]: http("http://127.0.0.1:8545"),
  },
  ssr: true,
});

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
