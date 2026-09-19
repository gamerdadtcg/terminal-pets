# Robinhood mainnet (chain `4663`)

Live stack recorded in [`deployments/robinhood-mainnet.json`](../deployments/robinhood-mainnet.json) (2026-09-16, git `23ba2397d304`). Hub production defaults (`web/.env.production` + `web/lib/deployments.ts`) point at these addresses.

**Do not re-broadcast** `forge script` to `4663` from this repo. `mintOpen` is still **false**. `teamMint` and `reveal()` have not run. Hub mint UX reads on-chain `mintOpen` — do not fake it open.

Studio Drop rehearsal (Base Sepolia / Sepolia): [`STUDIO_DROP_DRYRUN.md`](STUDIO_DROP_DRYRUN.md). Token + Studio rules: [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md). RH testnet mechanics (`46630`) are **not** this stack.

## Live addresses (4663)

| Role | Address |
| --- | --- |
| CollectionNFT | `0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166` |
| Hopper | `0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2` |
| RoyaltySplitter | `0xe1cC988CeC1C29764ba18523635De82d0C9B518F` |
| TermToken | `0xCa75Bc5eD48Bd9B8D1a939253e40e7AE3e61DAA6` |
| TermFund | `0x0C25076F1bF9f6187ed3b7D890F480a92837636F` |
| IgniteModule | `0x29e8dB2073583720C3CBf741d278d942B65cb92B` |
| TermMarket | `0x78f2c0577321053722Daa1f5eE31E5071a7D9F30` |
| PulseDistributor | `0x7326F7D277610288FBeA373712c89E47AF9AC61E` |
| ERC6551Registry | `0x3992160500FB69e88227436020B6600be1CeF023` |
| ReceivableAccount | `0xb8d8d9363a64dfD433E006bE43c2B150370Fc274` |
| SeaDrop | `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` |
| Owner / Deployer | `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37` |
| Treasury | `0x0c821a853711bF03C4C6b776CfD657f2ee97733e` |

RPC `https://rpc.mainnet.chain.robinhood.com`. Explorer [Blockscout](https://robinhoodchain.blockscout.com). Economics: Hopper lock 7 days, Ignite 0.002 ETH + 1,000 `$TERM`, Pulse 0.1 / 0.5 / 0.1 ETH, `maxSupply` 4444 / team 200. Dial slots 1–7 are the seven live RH stock tokens; slot 0 is `address(0)`. `hiddenURI` is `https://terminalpets.xyz/metadata/hidden.json`. Dormant/lit bases empty until reveal.

## 0. Remaining hard stops

- Do **not** re-run `forge script … --broadcast` to `robinhood` / `4663`.
- Do **not** `setMintOpen(true)` — public mint is already sold out (4244/4244).
- Do **not** `reveal()` until dormant/lit bases are set on-chain (hosted URIs in §4). After that, owner `reveal()` shows eggs; pets stay Ignite-gated.
- Any MICRO env still in the shell (`HOPPER_LOCK_SECONDS`, tiny `IGNITE_FEE_ETH`, `PULSE_*_WEI`) → **unset**. Those values must never reach a new stack.
- Metadata: hub public tree is **only** `hidden.json` until after reveal. Demo GIFs at `/art/examples/` are **examples / not mint supply**. Do **not** commit or deploy 4444 GIF/JSON to `web/public/metadata/{lit,dormant}` or git before reveal policy.

## 1. Production price lock (do not retune at deploy)

Mainnet uses `CollectionConfig` defaults. Leave the MICRO / short-lock overrides **unset**.

| Knob | Production lock | Wei / units | Never on mainnet |
| --- | --- | --- | --- |
| Public mint | Free | `MINT_PRICE_WEI=0` | paid mint unless owner changes policy |
| Supply | **4444** total | `MAX_SUPPLY` | shrinking supply |
| Team reserve | **200** | `TEAM_RESERVE` | minting team via Studio (that spends 4244 public) |
| Public / SeaDrop | **4244** | `PUBLIC_SUPPLY` | — |
| Ignite ETH | **0.002 ETH** (50% Hopper / 50% buy-`$TERM`-and-burn) | `2000000000000000` | `IGNITE_FEE_ETH=50000000000000` (MICRO) |
| Ignite `$TERM` | **1,000 `$TERM`** (25% Hopper / 37.5% burn / 37.5% allotment refill) | `1000000000000000000000` | — |
| Hopper payout lock | **7 days after `reveal()`** | `604800` seconds | `HOPPER_LOCK_SECONDS=900` |
| Pulse bootstrap | **0.1 → 1.0 ETH** | start `1e17`, step `1e17`, cap `1e18` | `PULSE_BOOTSTRAP_START_WEI=1e14` etc. |
| Pulse after bootstrap | **0.5 → 1.0 ETH** (never back to 0.1) | cycle start `5e17` | `PULSE_CYCLE_START_WEI` micro |
| Royalties | **7.5%** ERC-2981 → RoyaltySplitter | `750` bps | earnings to EOA / Hopper / treasury directly |
| Reveal delay | **24 hours** (owner may reveal early) | `REVEAL_DELAY` | — |

Pulse ladder is immutable at PulseDistributor construct. Hopper `payoutLock` is immutable. Getting MICRO values onto `4663` cannot be patched without a new stack.

## 2. Confirm SeaDrop on Robinhood `4663` + Studio

Canonical SeaDrop 1.0 (listed chains such as Sepolia / Base Sepolia — **not** listed for Robinhood in OpenSea’s public table):

`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`

Before any mainnet Drop:

1. OpenSea Studio chain list includes **Robinhood Chain (`4663`)** (or the exact Studio name for that network).
2. Studio can **import an existing contract** on that chain (same as the dry-run). Never the deploy wizard.
3. Confirm the SeaDrop address Studio will call:
   - If it is canonical CREATE2 → `SEADROP_ADDRESS=0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` (Deploy.s.sol default).
   - If Studio shows a **different** address → set `SEADROP_ADDRESS` to **that** value (or `updateAllowedSeaDrop` after deploy). **Do not invent.**
   - If Studio has no Robinhood / no SeaDrop on `4663` → skip Studio Drop. Hub `mintOpen` is a separate product decision, not a silent substitute for a Drop you cannot configure.

Do **not** deploy SeaDrop ourselves as part of this launch.

## 3. Dial — 7 live RH stock addresses (slot 0 unused)

Order is fixed. Owner `PulseDistributor.setStockToken(slot, token)` / `setStockTokens` for **slots 1–7**. Slot 0 stays `address(0)` — official Robinhood Chain `/rhj/assets` (chainId `4663`) has **no HOOD stock token**. Do **not** invent a HOOD ERC-20. Pulse undialed fallback (buy `$TERM`) applies if an assigned slot is still zero (including a pick of unused slot 0).

| Slot | Symbol | Mainnet ERC-20 (`4663`) |
| --- | --- | --- |
| 0 | *unused* | `address(0)` — no HOOD token |
| 1 | AAPL | `0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9` |
| 2 | MSFT | `0xe93237C50D904957Cf27E7B1133b510C669c2e74` |
| 3 | GOOGL | `0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3` |
| 4 | AMZN | `0x12f190a9F9d7D37a250758b26824B97CE941bF54` |
| 5 | META | `0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35` |
| 6 | NVDA | `0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC` |
| 7 | TSLA | `0x322F0929c4625eD5bAd873c95208D54E1c003b2d` |

Live pool: **AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA**. Addresses verified from Robinhood `/rhj/assets` on `4663`. Leave slots unset at deploy if you are not ready to wire them; do not invent extras.

RH **testnet** AMZN / TSLA samples in [`DIAL.md`](DIAL.md) are **46630-only**. Do not copy those testnet samples onto `4663`.

`PULSE_ROUTER` (and `TERM_SWAP_ROUTER` / `TERM_POOL`) stay blank until real DEX adapters exist. Undialed Pulse **reverts** without router + `$TERM`; Dialed claims fall back to ETH. Production should set routers before collectors rely on Pulse / Ignite buy-and-burn.

## 4. Full metadata pin (anti-snipe — not on the hub until after reveal)

Until `CollectionNFT.reveal()`, **every** `tokenURI` is the same sealed JSON:

```text
https://terminalpets.xyz/metadata/hidden.json
```

`https://terminal-pets.vercel.app/metadata/hidden.json` still resolves as a fallback alias until DNS is fully cut over. Prefer `NEXT_PUBLIC_SITE_URL` / `https://terminalpets.xyz` for collector-facing copy.

Collectors cannot see traits. Hub carousel GIFs (~25) at `/art/examples/` are **examples / not mint supply** — not live tokenIds, not the 4444 files.

**Do not** host or git-commit:

```text
web/public/metadata/lit/{id}.json
web/public/metadata/dormant/{id}.json
```

Those paths are gitignored. Publishing them before reveal lets snipers enumerate traits even while on-chain `tokenURI` is `hidden.json`.

Plan:

1. Export the full set (gitignored `art/export/gif-full/`; hours; seed locked when ops chooses — **must not** be the public demo files):

```bash
python art/generator/generate_collection.py \
  --count 4444 --start 1 \
  --out-art art/export/gif-full/art \
  --out-metadata art/export/gif-full/metadata \
  --out-egg art/export/gif-full/egg \
  --out-egg-metadata art/export/gif-full/egg-metadata \
  --seed 42 \
  --progress-every 25
```

2. Pin **four** trees (or equivalent **private** HTTP buckets), not on this hub:
   - Awake GIFs (`art/`)
   - Dormant egg GIFs (`egg/`)
   - Lit JSON (`metadata/`)
   - Dormant JSON (`egg-metadata/`)
   - Plus sealed `hidden.json` (see `art/export/sealed/hidden.json` / hub `web/public/metadata/hidden.json`)
3. Rewrite `image` fields to the pinned GIF bases (`--art-image-base` / `--egg-image-base` or `art/generator/rewrite_image_uris.py`).
4. Full 4444 GIF + JSON is hosted on Vercel Blob (not this hub, not Pinata — no JWT was available). `image` fields already point at the GIF bases. Owner must `setMetadataURIs` **before** `reveal()` (`revealAfter` has already passed, so anyone can reveal; empty dormant/lit would fall back to the on-chain SVG stub):

```text
hiddenURI        = https://terminalpets.xyz/metadata/hidden.json
dormantBaseURI   = https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/egg-metadata/
litBaseURI       = https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/metadata/
egg GIFs         = https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/egg/{id}.gif
awake GIFs       = https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/art/{id}.gif
```

Trailing `/` on the bases appends `{tokenId}.json`. After `reveal()`, un-Ignited tokens serve egg JSON (`State: Dormant`). Ignite still flips `tokenURI` to lit pet JSON (`State: Lit`).

```bash
export COLLECTION=0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166
export RPC=https://rpc.mainnet.chain.robinhood.com

# 1) URIs first — do not skip
cast send "$COLLECTION" \
  "setMetadataURIs(string,string,string)" \
  "https://terminalpets.xyz/metadata/hidden.json" \
  "https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/egg-metadata/" \
  "https://aeslbpvh4kdzd9lk.public.blob.vercel-storage.com/metadata/" \
  --rpc-url "$RPC"

# 2) only after the tx above confirms
cast send "$COLLECTION" "reveal()" --rpc-url "$RPC"
```

5. Optional: `setShellClassOverride` from generative `Shell Class` **before Ignite** so Dial counts match PFPs ([`DIAL.md`](DIAL.md)).
6. Do **not** use Studio’s metadata-upload / reveal wizard as source of truth ([`MAIN_ART_LOCK.md`](MAIN_ART_LOCK.md), [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md)).

On-chain `tokenURI` stays sealed `hidden.json` until owner `reveal()`. Hosted Blob JSON is enumerable by URL once the host is known; Ignite still gates which `tokenURI` marketplaces serve.

## 5. Wallets (mainnet ≠ testnet deployer)

| Role | Address | Notes |
| --- | --- | --- |
| Treasury | `0x0c821a853711bF03C4C6b776CfD657f2ee97733e` | `TREASURY_ADDRESS`. 2.5% post-reveal royalties + TermFund `$TERM` / LP recipient. Must accept ETH. |
| Team allocation | `0xD1A80572b04fe5Df429dFdAc26b5Aa412a5fBE31` | Owner `teamMint(this, 200)` **Thursday, September 17, 2026, 8:00 PM PT**. **Not** a public mint. **Not** a Studio Team stage. |
| Owner / Deployer | `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37` | Live `4663` owner and deployer (same EOA as the recorded 46630 stacks). **Not** the team allocation wallet. Do not send the 200 reserve here. |

`OWNER` signs `teamMint`, Friday `setMintOpen(true)`, `reveal()`, `setMetadataURIs`, and any Studio `update*` txs. The live stack already transferred TermToken ownership to this owner.

## 6. Remaining owner ops (no forge broadcast)

The stack is live. **Hub mint is primary** → owner `setMintOpen(true)` when Friday opens. Studio BYO is currently blocked. Do **not** re-run `Deploy.s.sol`.

```bash
# DO NOT re-broadcast Deploy.s.sol.
export COLLECTION=0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166
```

Leave `TERM_LP_ROUTER`, `TERM_POOL`, `TERM_SWAP_ROUTER`, `PULSE_ROUTER` blank until real adapters exist. Dial slots 1–7 are already wired.

Then:

```bash
# Thursday Sep 17 2026, 8:00 PM PT — owner-only. Not a public mint. Not now:
cast send "$COLLECTION" "teamMint(address,uint256)" \
  0xD1A80572b04fe5Df429dFdAc26b5Aa412a5fBE31 200 \
  --rpc-url robinhood
```

Do **not** `setMintOpen(true)` (public mint is already 4244/4244). Do **not** `reveal()` until `setMetadataURIs` with the Blob bases in §4 confirms.

## 7. Post-deploy Studio + royalties

1. Verify CollectionNFT (and splitter / Hopper / Ignite) on [Robinhood Blockscout](https://robinhoodchain.blockscout.com).
2. OpenSea Studio: **import existing** CollectionNFT. **Never** the deploy wizard.
3. Creator earnings **7.5% (750 bps)** → **RoyaltySplitter**. Enable ERC-2981 if offered.
4. Drop stages: free, **1 per wallet** per stage, Public last. Limited edition 4444 on-chain; SeaDrop public 4244. Creator payout for primary ETH → Hopper if that fuel should Pulse.
5. Confirm `isAllowedSeaDrop` for the Studio SeaDrop address.
6. `setMetadataURIs` already set **hidden.json**. Dormant/lit HTTP bases are hosted on Vercel Blob (§4) — still never the hub `/metadata/{lit,dormant}` trees. Owner must write those bases on-chain, then `reveal()`.
7. Dial slots 1–7 are already the seven live `4663` stock addresses (§3). Leave slot 0 `address(0)`.
8. Hub production already has these `NEXT_PUBLIC_*` defaults (`web/.env.production`). Leave `mintOpen` false until **Friday** GTD / FCFS / Public (8:00 / 9:00 / 10:00 AM PT, September 18, 2026). Thursday `teamMint` is owner-only. Do not send collectors to Studio’s wizard.

## 8. Explicit: no forge re-broadcast

The 4663 stack is recorded. This repo still must not send deploy transactions.

- No `forge script … --rpc-url robinhood --broadcast`
- No `--chain 4663` verify-on-deploy from CI
- No CI job that sends mainnet txs
- No “helpfully” re-running Deploy.s.sol

Owner ops that remain (`setMetadataURIs` dormant/lit + `reveal()`) are human-signed `cast send`s from `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37`, not a new deploy.

## Explicit do-nots

- **Do not re-broadcast** `forge script` to `4663` from this document.
- **Do not** fake hub `mintOpen` — read the on-chain flag.
- **Do not** reuse RH testnet MICRO economics (`HOPPER_LOCK_SECONDS=900`, tiny Ignite / Pulse).
- **Do not** invent Dial mainnet stock addresses (including a HOOD ERC-20) or a Robinhood SeaDrop address.
- **Do not** `teamMint` the 200 reserve to `0xA71c…` (owner / deployer). Send it to the team wallet.
- **Do not** point production metadata at hub `/art/examples/` or resurrect `/metadata/{lit,dormant}/{id}.json` before reveal.
- **Do not** use Studio’s deploy wizard on mainnet.

## References

- `src/CollectionConfig.sol` — locked production constants
- `script/Deploy.s.sol` — env overrides (must stay default on mainnet)
- [`STUDIO_DROP_DRYRUN.md`](STUDIO_DROP_DRYRUN.md) — Base Sepolia / Sepolia Studio path
- [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md)
- [`DIAL.md`](DIAL.md) — slots; testnet samples are not mainnet
- [`MAIN_ART_LOCK.md`](MAIN_ART_LOCK.md) / `art/generator/README-generate.md` — full export + pin
- [`TESTNET_DEPLOY.md`](TESTNET_DEPLOY.md) — `46630` only
- [`deployments/robinhood-mainnet.json`](../deployments/robinhood-mainnet.json) — live `4663` record
- [`deployments/robinhood-testnet.json`](../deployments/robinhood-testnet.json) / [`deployments/robinhood-testnet-micro.json`](../deployments/robinhood-testnet-micro.json) — recorded testnet stacks, not this mainnet
