"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { WagmiProvider, createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { foundry } from "wagmi/chains";
import {
  configuredRpc,
  robinhoodChain,
} from "@/lib/chain";

const config = createConfig({
  chains: [robinhoodChain, foundry],
  connectors: [injected()],
  transports: {
    [robinhoodChain.id]: http(configuredRpc()),
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
