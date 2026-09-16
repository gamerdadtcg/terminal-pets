# OpenSea Studio Drop (SeaDrop) — our CollectionNFT

Terminal Pets mints on OpenSea **into this repo’s `CollectionNFT`**. Do **not** use OpenSea Studio’s **“deploy Drop contract”** wizard. That path deploys OpenSea’s generic `ERC721SeaDrop` (ERC721A) and would be a **different token** — no Ignite, Hopper, Pulse, Dial, or our `tokenURI` lifecycle.

This document is configuration-only. **Do not broadcast** to Robinhood Chain (`4663`) or any live network from this repo until the owner explicitly asks.

## Why a custom token (not the wizard)

Studio’s wizard is for collections whose whole product is “upload metadata + mint.” Ours is one ERC-721:

| After mint | Same `tokenId` |
| --- | --- |
| Reveal | Sealed → dormant egg metadata (`setMetadataURIs`) |
| Ignite | Dormant → Lit (`0.002 ETH` + `$TERM`; Dial assigned by shell class, 1–4 stocks) |
| Hopper | 7-day payout lock from `reveal()` |
| Pulse | Ladder claims for Lit pets |
| Royalties | ERC-2981 → RoyaltySplitter (pre-reveal TermFund / post-reveal Hopper + treasury) |
| Metadata refresh | ERC-4906 |

OpenSea’s SeaDrop 1.0 contract is allowed to call `mintSeaDrop` on **our** token. Stages (Team / GTD / FCFS / Public) live on SeaDrop and are configured in Studio. They all mint the same collection.

## SeaDrop 1.0 address (confirmed)

Canonical SeaDrop 1.0, same CREATE2 address on every chain OpenSea has deployed it to:

`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`

Sources (current as of this change):

- [OpenSea SeaDrop docs](https://docs.opensea.io/docs/seadrop)
- [ProjectOpenSea/seadrop README](https://github.com/ProjectOpenSea/seadrop)

Robinhood Chain (`4663`) is **not** in that public deployment table. Before a live Drop:

1. Confirm Studio lists the chain and that SeaDrop is at this address (or note the address Studio uses).
2. If it differs, owner calls `CollectionNFT.updateAllowedSeaDrop([thatAddress])`.
3. Deploy script default is `CollectionConfig.SEADROP` / env `SEADROP_ADDRESS`.

Do **not** deploy SeaDrop ourselves as part of this work.

## What the token implements

`CollectionNFT` implements `INonFungibleSeaDropToken` (SeaDrop 1.0 token interface) on **OpenZeppelin ERC-721Enumerable + ERC-2981**, rather than inheriting `ERC721SeaDrop`.

Inheriting `ERC721SeaDrop` would pull ERC721A, OpenZeppelin 4.x, and solc `0.8.17`, and would replace our enumerable `tokensOfOwner`, three-URI metadata, and royalty splitter. OpenSea’s guidance is: start from `ERC721SeaDrop` **or** implement the equivalent mint interface and **do not change mint entrypoints**. We kept:

- `mintSeaDrop(address minter, uint256 quantity)` — only allowed SeaDrop
- `getMintStats(address minter)` → `(minterNumMinted, currentTotalSupply, maxSupply)`
- `updateAllowedSeaDrop` / constructor `allowedSeaDrop`
- Owner forwards: `updatePublicDrop`, `updateAllowList`, `updateDropURI`, `updateCreatorPayoutAddress`, `updateAllowedFeeRecipient`, `updateSignedMintValidationParams`, `updatePayer`, `updateTokenGatedDrop`
- ERC-165: `INonFungibleSeaDropToken` + `ISeaDropTokenContractMetadata`
- `SeaDropTokenDeployed` on construct

`getMintStats` reports the **public** allocation (`publicMinted` / `publicSupply()` = 4244), not team reserve. Team mint does not inflate SeaDrop’s supply counter or consume a collector’s `minterNumMinted`.

## Supply (unchanged)

| Path | Cap | Who |
| --- | --- | --- |
| SeaDrop (`mintSeaDrop`) + dapp `mint` / `mintTo` | **4244** | Shared public cap |
| `teamMint` / `ownerMint` | **200** | Owner only, outside SeaDrop |
| Total | **4444** | Immutable `maxSupply` |

`setMaxSupply` is a no-op when the value equals deploy `maxSupply`; any other value reverts. Do not ask Studio to “resize” the collection.

## Studio stages (free mint, 1 per phase)

Configure **in Studio Drop settings**, not in Solidity:

| Stage | Typical allowlist | Wallet limit |
| --- | --- | --- |
| Team | Merkle / allowlist | 1 |
| GTD | Merkle / allowlist | 1 |
| FCFS | Merkle / allowlist | 1 |
| Public | Public drop (required last stage) | 1 |

Price `0` for a free mint. Studio writes `PublicDrop` / allowlists onto SeaDrop by sending txs from the collection owner through our `update*` functions. OpenSea’s Drop primary fee (currently 10% on Studio drops) is SeaDrop `feeBps` + allowed fee recipient — set creator payout to **Hopper** if primary ETH should still fuel Pulse. Secondary royalties stay on the **RoyaltySplitter** (7.5% ERC-2981).

The 200 `teamMint` reserve is **not** a Studio Team stage. Mint that on-chain to treasury (or a team wallet) with `teamMint`. A Studio “Team” allowlist would spend **public** 4244 supply.

## Metadata — keep our URIs

Do **not** use Studio’s metadata-upload / reveal wizard as the source of truth. Product art is off-chain Pocket Critter GIFs. After pinning (or using the hub test host):

```text
CollectionNFT.setMetadataURIs(
  hiddenURI,        // e.g. https://terminal-pets.vercel.app/metadata/hidden.json
  dormantBaseURI,   // e.g. https://terminal-pets.vercel.app/metadata/dormant/
  litBaseURI        // e.g. https://terminal-pets.vercel.app/metadata/lit/
)
```

Trailing `/` → `{id}.json`. Ignite still flips `tokenURI` Sealed → Dormant → Lit and emits ERC-4906. `setBaseURI` exists only for the SeaDrop metadata interface (hidden vs dormant heuristic); prefer `setMetadataURIs`.

## Procedure (no wizard)

1. **Deploy our stack** with Foundry (`script/Deploy.s.sol`) when the owner says go. Constructor `allowedSeaDrop` should include canonical SeaDrop (or `SEADROP_ADDRESS`). Confirm `isAllowedSeaDrop`.
2. `teamMint(treasury, 200)` (or split across team wallets). Optional `setMetadataURIs`. Do **not** `reveal()` until the mint window policy says so.
3. Verify CollectionNFT on the chain explorer.
4. OpenSea Studio: **import existing contract** / add the **already-deployed** CollectionNFT address. Never “Drop a collection → deploy contract.”
5. Collection earnings: **7.5%** to the **RoyaltySplitter**. Enable ERC-2981 if offered.
6. Drop setup → Settings: limited edition **4444** on-chain (do not change max supply). Public mintable via SeaDrop is **4244**. Add Team / GTD / FCFS allowlists, then Public, **1 per wallet per stage**, free (`0`).
7. Creator payout for **primary** Drop proceeds → Hopper (or the address ops chooses). Fee recipient = OpenSea’s Drop fee wallet as Studio instructs.
8. Test mint on Studio’s preview/test path if offered. Then `reveal()` (owner anytime, or anyone after 24h). Hopper payouts unlock **7 days after reveal**. Ignite fee stays **0.002 ETH**.

## Testnet then mainnet

1. **Testnet first** on a chain where Studio Drop + SeaDrop 1.0 already exist (OpenSea’s documented list: e.g. Sepolia / Base Sepolia — pick whatever Studio currently offers). Deploy **this** CollectionNFT, authorize SeaDrop, import the address, configure stages, mint 1, `reveal()`, Ignite, confirm Dial / `tokenURI`.
2. **Robinhood mainnet (`4663`) only after** SeaDrop is confirmed on that chain and the owner asks to broadcast. Same bytecode, same authorize + Studio import flow. Never use the Studio deploy wizard on mainnet either.

This PR does **not** deploy anywhere.

## Dapp mint

`mint` / `mintTo` remain for the hub, gated by `mintOpen`, and share the 4244 public cap with SeaDrop. Leave `mintOpen` false if OpenSea is the only public path.

## References

- `src/CollectionNFT.sol` — `mintSeaDrop`, `getMintStats`, allowed SeaDrop list
- `src/CollectionConfig.sol` — `SEADROP`, `MAX_SUPPLY`, `TEAM_RESERVE`, `PUBLIC_SUPPLY`
- `src/interfaces/seadrop/` — vendored SeaDrop 1.0 ABI (no OZ 4.x submodule)
- `test/SeaDropMint.t.sol`
