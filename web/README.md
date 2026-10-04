# Terminal Pets dapp

Next.js + wagmi + viem UI. The homepage is Ignite. How it works is `/how`. Hopper and Pulse are `/hopper`.

`/mint`, `/app`, `/arcade`, and `/eligible` redirect to `/`. `/dial` redirects to `/how`.

```bash
cp .env.example .env.local
# For Base Sepolia dry-run testing:
# NEXT_PUBLIC_CHAIN_ID=84532
npm install
npm run dev    # http://127.0.0.1:43147
```

`NEXT_PUBLIC_COLLECTION_NFT` aliases `NEXT_PUBLIC_COLLECTION_ADDRESS`. Robinhood mainnet is chain `4663` (CollectionNFT `0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166`). Production loads `web/.env.production`. Base Sepolia `84532` (or a blank chain env in local `next dev`) falls back to the dry-run stack.

Canonical public origin is `https://terminalpets.xyz` (`NEXT_PUBLIC_SITE_URL`, default in `lib/site.ts`). `https://terminal-pets.vercel.app` remains a fallback alias until DNS is fully cut over.

Ignite sends the on-chain `igniteFeeEth()` value. That fee is 0.002 ETH on the deployed Robinhood Chain module. The UI does not substitute a hardcoded fee if the read has not loaded.

Wallet connection uses the browser's injected wallet (MetaMask, Rabby, Coinbase extension, and other EIP-1193 wallets). Phones without an injected provider get links to open the site in MetaMask or Coinbase Wallet. WalletConnect is not bundled.
