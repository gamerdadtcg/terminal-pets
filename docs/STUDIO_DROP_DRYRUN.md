# OpenSea Studio Drop dry-run (Base Sepolia)

Ordered rehearsal of **import-existing CollectionNFT + Studio Drop** on a chain where OpenSea has actually deployed SeaDrop 1.0. Prefer **Base Sepolia**. Fallback **Sepolia**. This is not a Robinhood launch.

**Hub mint is the primary public path.** OpenSea Studio’s current Drop-create UI has **no bring-your-own / import-existing CollectionNFT** and **no Base Sepolia** in the chain picker. Do **not** tell users to mint via the Studio deploy-wizard (that would be a different ERC721SeaDrop). Collectors mint on the hub (`/mint`) with `CollectionNFT.mint` / `mintTo` while on-chain `mintOpen` is true. The hub shows a closed state when `mintOpen` is false.

**Anti-snipe:** until `CollectionNFT.reveal()`, every `tokenURI` is the same sealed `hidden.json`. Collectors cannot see traits. Hub carousel GIFs are **examples / not mint supply**. Do **not** host 4444 (or tokenId) lit/dormant JSON at `web/public/metadata/{lit,dormant}` or point `setMetadataURIs` dormant/lit bases at this hub before reveal.

Current Base Sepolia dry-run CollectionNFT: `0xe1cC988CeC1C29764ba18523635De82d0C9B518F` (chain `84532`). Hub env: `NEXT_PUBLIC_CHAIN_ID=84532` and `NEXT_PUBLIC_COLLECTION_NFT` (or the built-in 84532 fallback). Robinhood mainnet `4663` stays env-driven and is **not** broadcast from this document.

**Do not broadcast to Robinhood mainnet `4663` from this document.** `script/Deploy.s.sol` does not check chain id; the RPC you pass is the network you hit. Use `--rpc-url base_sepolia` (or `sepolia`). Never `--rpc-url robinhood`.

Robinhood testnet (`46630`) is mechanics-only. Canonical SeaDrop 1.0 is **not** listed there. Those stacks stay where they are:

| Stack | Where | Studio? |
| --- | --- | --- |
| 7-day RH testnet | [`deployments/robinhood-testnet.json`](../deployments/robinhood-testnet.json) / [`RH_TESTNET_DEPLOY_ADDRESSES.md`](RH_TESTNET_DEPLOY_ADDRESSES.md) | No |
| SHORT-LOCK MICRO (tiny Ignite / Pulse) | [`deployments/robinhood-testnet-micro.json`](../deployments/robinhood-testnet-micro.json) / [`RH_TESTNET_MICRO_SMOKE.md`](RH_TESTNET_MICRO_SMOKE.md) | No |

Studio Drop configuration (why not the wizard, stages, royalties): [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md). Robinhood mainnet prep (no broadcast): [`MAINNET_PREP.md`](MAINNET_PREP.md).

## Why Base Sepolia (not 46630)

Canonical SeaDrop 1.0, same CREATE2 on every chain OpenSea listed:

`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`

Sources: [OpenSea SeaDrop docs](https://docs.opensea.io/docs/seadrop), [ProjectOpenSea/seadrop](https://github.com/ProjectOpenSea/seadrop). Listed examples include Sepolia and Base Sepolia. **Not** Robinhood (`4663` / `46630`).

Studio must be able to **import an already-deployed contract** on the same chain. If Studio’s chain picker has no Base Sepolia, use Sepolia. If it has neither, **stop** — see [§8 Blockers](#8-blockers--stop-here). Do not invent a SeaDrop address. Do not use Studio’s **deploy Drop contract** wizard.

## Production-shaped deploy (required)

This dry-run deploys **production economics** so Studio QA matches mainnet bytecode defaults. The RH MICRO stack (`HOPPER_LOCK_SECONDS=900`, tiny Ignite / Pulse) is **forbidden** here and on mainnet.

| Knob | Production (this run) | Do **not** set |
| --- | --- | --- |
| Ignite ETH | `0.002 ether` (`CollectionConfig.IGNITE_FEE_ETH`) | `IGNITE_FEE_ETH=50000000000000` (MICRO) |
| Hopper lock | `7 days` (`CollectionConfig.HOPPER_LOCK`) | `HOPPER_LOCK_SECONDS=900` |
| Pulse bootstrap | `0.1 → 1.0 ETH` | `PULSE_BOOTSTRAP_START_WEI` / `PULSE_CYCLE_START_WEI` / `PULSE_LADDER_STEP_WEI` |
| Pulse cycle | `0.5 → 1.0 ETH` | same |
| Supply | `4444` total / `200` team / `4244` public | shrinking `MAX_SUPPLY` |
| Mint price | `0` (free) | paid mint |
| Royalties | `750` bps (7.5%) → RoyaltySplitter | pointing earnings at an EOA |
| SeaDrop | canonical `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` | `SEADROP_ADDRESS=0x0` (RH testnet smoke only) |

Unset or `0` for `HOPPER_LOCK_SECONDS` and `PULSE_*_WEI` → Solidity defaults. Leave `IGNITE_FEE_ETH` at the `.env.example` production value (`2000000000000000`) or omit it.

## 1. Prerequisites

1. **Wallet with Base Sepolia ETH.** Throwaway deployer is fine. Never reuse a funded Robinhood mainnet key. Faucets: [Alchemy Base Sepolia](https://www.alchemy.com/faucets/base-sepolia), [Superchain faucet](https://console.optimism.io/faucet). Deploy of the full stack historically costs on the order of ~0.002+ ETH of gas plus one Ignite (`0.002 ETH`) if you wake a token after reveal.
2. **OpenSea account** that can open [Studio](https://opensea.io/studio) and sign with the **same owner** you set as `OWNER` (or the deployer if `OWNER` is blank). Studio Drop `update*` calls must come from the CollectionNFT owner.
3. **Foundry** (`forge`, `cast`) and a local `.env` (`cp .env.example .env`). Gitignored. Do not paste `PRIVATE_KEY` into chat, git, or this markdown.
4. **`TREASURY_ADDRESS`** that can receive ETH (EOA or `receive()`). Dry-run may use the throwaway deployer. Mainnet treasury is **not** required on this chain.
5. Confirm Studio currently lists **Base Sepolia** (or Sepolia) **before** broadcasting. If the UI has no SeaDrop chain you can import onto, do not deploy.

```bash
cast chain-id --rpc-url base_sepolia
# expect 84532
```

## 2. Networks

| | Prefer | Fallback | Never this run |
| --- | --- | --- | --- |
| Name | Base Sepolia | Ethereum Sepolia | Robinhood Chain / RH testnet |
| Chain ID | `84532` | `11155111` | `4663` / `46630` |
| Foundry `--rpc-url` | `base_sepolia` | `sepolia` | `robinhood` / `testnet` |
| Env RPC | `BASE_SEPOLIA_RPC_URL` | `SEPOLIA_RPC_URL` | `ROBINHOOD_RPC_URL` |
| Public RPC (example) | `https://sepolia.base.org` | `https://rpc.sepolia.org` | — |
| Explorer | [sepolia.basescan.org](https://sepolia.basescan.org) | [sepolia.etherscan.io](https://sepolia.etherscan.io) | — |
| SeaDrop 1.0 | `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` | same CREATE2 | **not listed** on Robinhood |

Gas token is ETH on both Sepolia networks.

## 3. Env (production defaults + canonical SeaDrop)

```bash
cp .env.example .env
# fill PRIVATE_KEY (throwaway) and TREASURY_ADDRESS
```

Exact exports for this dry-run. Copy as-is; **do not** add MICRO lines from `.env.example`.

```bash
source .env

export SEADROP_ADDRESS=0x00005EA00Ac477B1030CE78506496e8C2dE24bf5
export MINT_OPEN=false
export BASE_SEPOLIA_RPC_URL="${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}"

# Production economics — leave unset so CollectionConfig defaults apply:
unset HOPPER_LOCK_SECONDS
unset PULSE_BOOTSTRAP_START_WEI
unset PULSE_CYCLE_START_WEI
unset PULSE_LADDER_STEP_WEI
# Do not export a tiny IGNITE_FEE_ETH. Default / .env.example is 0.002 ETH:
# IGNITE_FEE_ETH=2000000000000000
```

`OWNER` defaults to the deployer. `TREASURY_ADDRESS` is required by `Deploy.s.sol`. Leave DEX adapters blank (`TERM_LP_ROUTER`, `TERM_POOL`, `TERM_SWAP_ROUTER`, `PULSE_ROUTER`). Leave Dial stock slots unset — this chain is not Robinhood Stock Tokens.

Sepolia fallback: same exports, plus `SEPOLIA_RPC_URL` (example `https://rpc.sepolia.org`) and `--rpc-url sepolia` below.

## 4. Simulate, then broadcast (Base Sepolia)

Confirm chain id **84532**. Abort if you see `4663` or `46630`.

```bash
source .env
cast chain-id --rpc-url base_sepolia
# expect 84532
```

Dry-run (no `--broadcast` — still reads `PRIVATE_KEY`):

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url base_sepolia
```

Confirm console: `SeaDrop` is `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`, `HopperPayoutLock` is `604800` (7 days), `IgniteFeeETH` is `2000000000000000`, Pulse rungs are production wei (`PulseBootstrapStart` `100000000000000000` / `PulseCycleStart` `500000000000000000` / `PulseLadderStep` `100000000000000000`). **Stop here until you intend to deploy to Base Sepolia.**

Broadcast:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url base_sepolia --broadcast
```

Sepolia fallback (only if Studio has no Base Sepolia — see §8):

```bash
cast chain-id --rpc-url sepolia
# expect 11155111
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast
```

Copy CollectionNFT, Hopper, RoyaltySplitter, IgniteModule, PulseDistributor, TermToken from the console. Foundry also writes `broadcast/Deploy.s.sol/84532/` (or `11155111/`).

## 5. Post-deploy on-chain (owner)

Replace `$COLLECTION` / `$HOPPER` / `$IGNITE` / `$PULSE` from the logs. RPC alias matches the chain you broadcast to.

### 5.1 Sealed metadata only (anti-snipe)

Set **hiddenURI only** for the mint window. Every `tokenURI` is this JSON until `reveal()`. Do **not** publish per-token dormant/lit JSON on the hub (`/metadata/{lit,dormant}/{id}.json` is removed). Hub GIFs at `/art/examples/` are **examples / not mint supply**.

```bash
cast send "$COLLECTION" \
  "setMetadataURIs(string,string,string)" \
  "https://terminal-pets.vercel.app/metadata/hidden.json" \
  "" \
  "" \
  --rpc-url base_sepolia
```

Leave dormant/lit bases empty (or a private pin) until after `reveal()`. Trailing `/` on those bases would append `{tokenId}.json` and leak traits if the files are public.

### 5.2 Confirm canonical SeaDrop is allowed

```bash
cast call "$COLLECTION" "isAllowedSeaDrop(address)(bool)" \
  0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 \
  --rpc-url base_sepolia
```

Expect `true`. If `false`, **do not import in Studio**. Owner may `updateAllowedSeaDrop([canonical])`. If Studio documents a **different** SeaDrop on this chain, authorize **that** address (do not guess).

Also confirm production knobs survived deploy:

```bash
cast call "$HOPPER" "payoutLock()(uint256)" --rpc-url base_sepolia
# expect 604800
cast call "$IGNITE" "igniteFeeEth()(uint256)" --rpc-url base_sepolia
# expect 2000000000000000
cast call "$PULSE" "bootstrapStart()(uint256)" --rpc-url base_sepolia
# expect 100000000000000000
cast call "$COLLECTION" "mintOpen()(bool)" --rpc-url base_sepolia
# expect false
```

Optional: `teamMint` **one** token to the dry-run wallet for a non-Studio backup path. Do **not** `teamMint(200)` here. Hub mint is primary: owner may `setMintOpen(true)` so `/mint` can call `mint` / `mintTo`. Studio Drop is blocked in the current UI (no BYO import / no Base Sepolia in Drop create) — do not send collectors to the wizard.

Do **not** `reveal()` until after a Studio mint (or until you are done configuring stages). Owner may reveal early; anyone may after 24h.

## 6. OpenSea Studio — import existing only

1. Open [OpenSea Studio](https://opensea.io/studio) with the **owner** wallet, on **Base Sepolia** (or Sepolia if that is the fallback).
2. **Import existing contract** / add the **already-deployed** `CollectionNFT` address from §4.
3. **Never** “Drop a collection → deploy contract.” That wizard deploys OpenSea’s generic `ERC721SeaDrop` — a different token, no Ignite / Hopper / Pulse / Dial / our `tokenURI`.
4. Collection earnings: **7.5%** to the **RoyaltySplitter**. Enable ERC-2981 if offered. Not Hopper, not treasury, not an EOA.
5. Drop setup → Settings:
   - Limited edition **4444** on-chain (do not ask Studio to resize). Public SeaDrop cap is **4244**.
   - Free mint (`0`).
   - Stages **1 per wallet** (GTD / FCFS allowlists if you want them, then **Public** last). Do not add a Friday 7am Team stage for the 200 reserve — that is owner `teamMint` Thursday 8:00 PM PT. A Studio “Team” stage spends **public** supply.
   - Creator payout for **primary** Drop ETH → Hopper (or the address ops chooses). Fee recipient = OpenSea’s Drop fee wallet as Studio instructs.
6. Publish / enable the Public stage.

If Studio cannot find the contract, cannot select the chain, or tries to deploy a new one: **stop** (§8). Public mint continues on the **hub** (`mintOpen`), not the wizard.

## 7. Mint 1, then reveal / Ignite notes

1. From a **different** wallet than a 1/wallet allowlist already filled (or the public stage), mint **exactly 1** through the **hub** (`/mint` while `mintOpen`). Confirm the NFT appears as **Sealed** (`hidden.json` — no traits). Studio mint is blocked in the current UI.
2. On-chain:

```bash
cast call "$COLLECTION" "publicMinted()(uint256)" --rpc-url base_sepolia
# expect 1 after a successful Studio mint
cast call "$COLLECTION" "tokenURI(uint256)(string)" 1 --rpc-url base_sepolia
cast call "$COLLECTION" "getMintStats(address)(uint256,uint256,uint256)" "$MINTER" --rpc-url base_sepolia
```

3. **Reveal** (owner anytime). Starts the **7-day** Hopper payout lock — do **not** shorten it on this stack.

```bash
cast send "$COLLECTION" "reveal()" --rpc-url base_sepolia
```

Expect `tokenURI` still `https://terminal-pets.vercel.app/metadata/hidden.json` until reveal (same URI for every token). After reveal, point dormant/lit bases at a **private pin**, not this hub’s old `/metadata/dormant/` tree. Ignite and `$TERM` transfers turn on. RoyaltySplitter `live` → 5% Hopper / 2.5% treasury.

4. **Ignite** the minted token from its owner. Exact **0.002 ETH** (production). Without `TERM_SWAP_ROUTER`, 25% `$TERM` parks as `pendingHopperTerm` and 50% of the ETH parks as `pendingIgniteEthBurn`. Hopper still receives 50% of the 0.002 ETH.

```bash
cast send "$IGNITE" "ignite(uint256)" 1 --value 0.002ether --rpc-url base_sepolia
cast call "$COLLECTION" "isLit(uint256)(bool)" 1 --rpc-url base_sepolia
cast call "$COLLECTION" "tokenURI(uint256)(string)" 1 --rpc-url base_sepolia
cast call "$COLLECTION" "tokenURI(uint256)(string)" 1 --rpc-url base_sepolia
# expect the private dormant/lit pin you set at reveal — not hub /metadata/lit/1.json
cast call "$PULSE" "getDial(uint256)" 1 --rpc-url base_sepolia
```

Dial slots will be `address(0)` unless you wired stocks (do not invent Robinhood mainnet stock addresses on Sepolia). That is expected; undialed Pulse claims need a router + `$TERM`. Hopper `hopperUnlocked()` stays **false** for 7 days after reveal — do not Pulse/claim on this dry-run unless you wait. Pulse+claim smoke already ran on RH MICRO (`46630`); this run is **Studio + SeaDrop + URI lifecycle**.

5. Record the CollectionNFT address, Studio drop URL, and whether import / 1-mint succeeded. That evidence is what unblocks [`MAINNET_PREP.md`](MAINNET_PREP.md) — it does **not** authorize a `4663` broadcast.

## 8. Blockers — stop here

Treat these as hard stops. Do not work around them with the wizard, a homemade SeaDrop, or Robinhood.

| Blocker | What to do |
| --- | --- |
| Studio chain picker has **no Base Sepolia** | Try **Sepolia** (`11155111`) with the same production env and `--rpc-url sepolia`. Public mint still goes through the **hub**. |
| Studio has **neither** Base Sepolia nor Sepolia (no SeaDrop test chain you can import onto) | **Stop the Studio path.** Do not use the deploy wizard. Do not use RH testnet (`46630`) as a Studio substitute. Collectors mint on the hub (`CollectionNFT.mint` while `mintOpen`). |
| Studio only offers **“deploy Drop contract”** / generic ERC721SeaDrop / **no BYO import** | **Stop.** Our token is `CollectionNFT`. Wizard = different collection. Hub mint is primary. |
| `isAllowedSeaDrop(canonical)` is `false` after deploy | **Stop** importing. Fix allowlist (`SEADROP_ADDRESS` / `updateAllowedSeaDrop`) first. |
| Studio’s SeaDrop address **differs** from canonical | Owner `updateAllowedSeaDrop([studioAddress])`. Do not guess. Do not deploy SeaDrop ourselves. |
| Import UI missing or contract not detected after verify | Verify CollectionNFT on the explorer, wait for indexers, retry import. Still no wizard. |
| Someone proposes MICRO env on this chain or on `4663` | Refuse. Production Ignite **0.002**, Hopper **7 days**, Pulse **0.1→1.0 then 0.5→1.0**. |

This document does **not** broadcast to `4663`. No `--rpc-url robinhood`. No mainnet `PRIVATE_KEY`.

## Explicit do-nots

- **Do not broadcast to `4663`.** No mainnet RPC, no `--chain 4663`.
- **Do not** set `HOPPER_LOCK_SECONDS`, tiny `IGNITE_FEE_ETH`, or `PULSE_*_WEI` micro overrides.
- **Do not** use Studio’s deploy wizard. Studio UI currently has no BYO import and no Base Sepolia in Drop create — hub mint is primary.
- **Do not** treat RH testnet / MICRO stacks as Studio Drop evidence.
- **Do not** invent Dial stock-token addresses.
- **Do not** `reveal()` before you have finished stage config unless you accept Ignite/`$TERM` trading turning on.
- **Do not** publish 4444 (or tokenId) lit/dormant JSON to `web/public/metadata/{lit,dormant}` or git until after reveal. Hub carousel is examples / not mint supply.
- **Do not** put private keys in git or this markdown.

## References

- `script/Deploy.s.sol` — `SEADROP_ADDRESS` defaults to `CollectionConfig.SEADROP`
- `src/CollectionNFT.sol` — `mintSeaDrop`, `isAllowedSeaDrop`, `setMetadataURIs`
- [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md) — interface, stages, royalties
- [`MAINNET_PREP.md`](MAINNET_PREP.md) — checklist before any Robinhood `4663` broadcast
- [`TESTNET_DEPLOY.md`](TESTNET_DEPLOY.md) — RH `46630` mechanics (not Studio)
- [`MAIN_ART_LOCK.md`](MAIN_ART_LOCK.md) — examples vs sealed hidden.json vs 4444 pin
- `foundry.toml` — `base_sepolia` / `sepolia` RPC aliases
