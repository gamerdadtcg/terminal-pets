# Terminal Pets dapp

Next.js + wagmi + viem UI. Primary mint is `/mint` (`CollectionNFT.mint` / `mintTo` while `mintOpen`). Ignite, Hopper, Pulse, and TBA live on `/app`.

```bash
cp .env.example .env.local
# For Base Sepolia dry-run testing:
# NEXT_PUBLIC_CHAIN_ID=84532
npm install
npm run dev    # http://127.0.0.1:43147
```

`NEXT_PUBLIC_COLLECTION_NFT` aliases `NEXT_PUBLIC_COLLECTION_ADDRESS`. Robinhood mainnet is chain `4663` (addresses empty until deploy). Base Sepolia `84532` falls back to dry-run CollectionNFT `0xe1cC988CeC1C29764ba18523635De82d0C9B518F` when collection env is blank.

See the repository root README for deploy, 24h sealed reveal (every tokenURI is hidden.json until CollectionNFT.reveal()), generative Pocket Critter examples (not mint supply), OpenSea royalty → RoyaltySplitter (pre-reveal 100% TermFund; post-reveal 5/2.5), Pulse ladder, `$TERM` allotment, and contract addresses. Studio BYO is blocked — hub mint is primary.
