import type { Address } from "viem";

/** Base Sepolia dry-run stack (chain 84532). Same CREATE sequence as the RH testnet 7-day stack. */
export const BASE_SEPOLIA_DRYRUN = {
  chainId: 84532,
  collection: "0xe1cC988CeC1C29764ba18523635De82d0C9B518F" as Address,
  hopper: "0xD99319e6dd9A92DDb3D5D3991e5b99AD7C76a284" as Address,
  splitter: "0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2" as Address,
  ignite: "0x0C25076F1bF9f6187ed3b7D890F480a92837636F" as Address,
  term: "0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166" as Address,
  termFund: "0x6f5A98D16005e10be0733A3b5576B3059559afa8" as Address,
  termMarket: "0x44400280e8A2D5b6B403b6a2864E44A0f643441B" as Address,
  pulse: "0xb8d8d9363a64dfD433E006bE43c2B150370Fc274" as Address,
} as const;
