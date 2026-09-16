# Robinhood mainnet prep (chain `4663`)

Checklist **before** any broadcast to Robinhood Chain mainnet. This file does **not** authorize a deploy.

**Do not broadcast to `4663` until the owner explicitly says go.** `script/Deploy.s.sol` does not check chain id. A `--rpc-url robinhood` (or the mainnet RPC URL) with `--broadcast` is a live launch. No one should run those commands from this document.

Studio Drop rehearsal (Base Sepolia / Sepolia): [`STUDIO_DROP_DRYRUN.md`](STUDIO_DROP_DRYRUN.md). Token + Studio rules: [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md). RH testnet mechanics (`46630`) are **not** a mainnet dress rehearsal for SeaDrop.

## 0. Hard stops

- Owner has **not** said go → do not `--broadcast` to `robinhood` / `4663`.
- Studio Drop dry-run on a SeaDrop chain is incomplete (no import-existing + 1 mint) → do not treat RH MICRO smoke as a substitute.
- Any MICRO env still in the shell (`HOPPER_LOCK_SECONDS`, tiny `IGNITE_FEE_ETH`, `PULSE_*_WEI`) → **unset**. Those values must never reach mainnet.
- Canonical (or Studio-documented) SeaDrop **not confirmed** on `4663` → do not deploy.
- Dial: fewer than **8 real** Robinhood Chain Stock Token addresses → leave slots `address(0)`; **do not invent**.
- Metadata: hub test host (tokens 1–25) is **not** production art → full 4444 pin first (or accept sealed stub until pin).

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
   - If Studio has no Robinhood / no SeaDrop on `4663` → **do not broadcast**. Hub `mintOpen` is a separate product decision, not a silent substitute for a Drop you cannot configure.

Do **not** deploy SeaDrop ourselves as part of this launch.

## 3. Dial — all 8 real RH stock addresses

Order is fixed. Owner `PulseDistributor.setStockToken(slot, token)` / `setStockTokens` **when the real Robinhood Chain Stock Token ERC-20s are known**. Leave `address(0)` until then. Pulse undialed fallback (buy `$TERM`) applies if assigned slots are still zero.

| Slot | Symbol | Mainnet ERC-20 |
| --- | --- | --- |
| 0 | HOOD | *unset — do not invent* |
| 1 | AAPL | *unset — do not invent* |
| 2 | MSFT | *unset — do not invent* |
| 3 | GOOGL | *unset — do not invent* |
| 4 | AMZN | *unset — do not invent* |
| 5 | META | *unset — do not invent* |
| 6 | NVDA | *unset — do not invent* |
| 7 | TSLA | *unset — do not invent* |

RH **testnet** AMZN / TSLA samples in [`DIAL.md`](DIAL.md) are **46630-only**. Do not copy them onto `4663`. Do not paste placeholders. A mainnet table with real addresses lands in a follow-up when ops has them from Robinhood Chain docs / explorers — not in this checklist.

`PULSE_ROUTER` (and `TERM_SWAP_ROUTER` / `TERM_POOL`) stay blank until real DEX adapters exist. Undialed Pulse **reverts** without router + `$TERM`; Dialed claims fall back to ETH. Production should set routers before collectors rely on Pulse / Ignite buy-and-burn.

## 4. Full metadata pin (off-hub; not public web/ until after reveal)

**Anti-snipe.** Do **not** publish real 4444 lit/dormant JSON under `web/public/` until **after reveal**. Hub GIFs at `/art/examples` are **Examples — not the mint supply.** Never `setMetadataURIs` to:

```text
https://terminal-pets.vercel.app/metadata/hidden.json
https://terminal-pets.vercel.app/metadata/dormant/{id}.json
https://terminal-pets.vercel.app/metadata/lit/{id}.json
https://terminal-pets.vercel.app/art/examples/…
```

Those hub metadata paths are gone (404 is correct). `/art/examples` is demo art only.

Plan:

1. Export the full set privately (gitignored `art/export/gif-full/`; hours; seed locked when ops chooses):

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

2. Pin **four** trees **off-hub** (IPFS or a private bucket — not `web/public/`):
   - Awake GIFs (`art/`)
   - Dormant egg GIFs (`egg/`)
   - Lit JSON (`metadata/`)
   - Dormant JSON (`egg-metadata/`)
   - Plus sealed `hidden.json` (see `art/export/sealed/hidden.json`)
3. Rewrite `image` fields to the pinned GIF bases (`--art-image-base` / `--egg-image-base` or `art/generator/rewrite_image_uris.py`).
4. After CollectionNFT is live (and **after** owner says go), owner may set a **sealed** `hiddenURI` (no traits) before mint. Set dormant/lit bases only when you are ready to reveal — and **do not** copy those JSON trees onto public `web/` until after reveal:

```text
CollectionNFT.setMetadataURIs(
  hiddenURI,        // ipfs://…/hidden.json   (no trailing slash; sealed stub, no traits)
  dormantBaseURI,   // ipfs://…/egg-metadata/ (trailing slash → {id}.json) — after reveal
  litBaseURI        // ipfs://…/metadata/     (trailing slash → {id}.json) — after reveal
)
```

5. Optional: `setShellClassOverride` from generative `Shell Class` **before Ignite** so Dial counts match PFPs ([`DIAL.md`](DIAL.md)).
6. Do **not** use Studio’s metadata-upload / reveal wizard as source of truth ([`MAIN_ART_LOCK.md`](MAIN_ART_LOCK.md), [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md)).

Sealed stub until pin is the pre-reveal plan. Do not leak 4444 traits on the public hub.

## 5. Wallets (mainnet ≠ testnet deployer)

| Role | Address | Notes |
| --- | --- | --- |
| Treasury | `0x0c821a853711bF03C4C6b776CfD657f2ee97733e` | `TREASURY_ADDRESS`. 2.5% post-reveal royalties + TermFund `$TERM` / LP recipient. Must accept ETH. |
| Team allocation | `0xD1A80572b04fe5Df429dFdAc26b5Aa412a5fBE31` | `teamMint(this, 200)` after deploy. **Not** a Studio Team stage. |
| RH testnet deployer | `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37` | Recorded on `46630` only. **Not** mainnet team. **Not** a default `OWNER`. Do not send the 200 reserve here. |

`OWNER` = the production owner EOA that will sign Studio Drop `update*` txs, `reveal()`, `setMetadataURIs`, `setStockToken`, and `teamMint`. Set it explicitly. Do **not** default to the testnet deployer. Deployer `PRIVATE_KEY` may be a dedicated deploy key; if `OWNER !=` deployer, the script transfers TermToken ownership to `OWNER`.

## 6. Deploy env (when owner has said go — commands not run from this PR)

Defaults only. Canonical SeaDrop unless §2 recorded a different Studio address. Studio-only public mint → `MINT_OPEN=false`.

```bash
# DO NOT RUN until the owner says go.
# cp .env.example .env

export TREASURY_ADDRESS=0x0c821a853711bF03C4C6b776CfD657f2ee97733e
export OWNER=<production-owner-EOA>   # not 0xA71c… testnet deployer
export SEADROP_ADDRESS=0x00005EA00Ac477B1030CE78506496e8C2dE24bf5
# If Studio's 4663 SeaDrop differs, use that address instead — do not guess.
export MINT_OPEN=false

unset HOPPER_LOCK_SECONDS
unset PULSE_BOOTSTRAP_START_WEI
unset PULSE_CYCLE_START_WEI
unset PULSE_LADDER_STEP_WEI
# IGNITE_FEE_ETH must remain 0.002 ETH (2000000000000000). Do not export MICRO 5e13.

# Then, only after explicit go:
# source .env
# cast chain-id --rpc-url robinhood   # expect 4663 — abort otherwise
# forge script script/Deploy.s.sol:Deploy --rpc-url robinhood --broadcast
```

Leave `TERM_LP_ROUTER`, `TERM_POOL`, `TERM_SWAP_ROUTER`, `PULSE_ROUTER` blank until real adapters exist. Leave Dial slots unset at deploy.

After a future broadcast (not now): confirm console `HopperPayoutLock=604800`, `IgniteFeeETH=2000000000000000`, Pulse production wei, `SeaDrop` = the address from §2, `Treasury` = `0x0c821a…773e`. Then:

```bash
# After owner says go and deploy succeeded — not now:
cast send "$COLLECTION" "teamMint(address,uint256)" \
  0xD1A80572b04fe5Df429dFdAc26b5Aa412a5fBE31 200 \
  --rpc-url robinhood
```

Do **not** `reveal()` until mint-window policy says so.

## 7. Post-deploy Studio + royalties

1. Verify CollectionNFT (and splitter / Hopper / Ignite) on [Robinhood Blockscout](https://robinhoodchain.blockscout.com).
2. OpenSea Studio: **import existing** CollectionNFT. **Never** the deploy wizard.
3. Creator earnings **7.5% (750 bps)** → **RoyaltySplitter**. Enable ERC-2981 if offered.
4. Drop stages: free, **1 per wallet** per stage, Public last. Limited edition 4444 on-chain; SeaDrop public 4244. Creator payout for primary ETH → Hopper if that fuel should Pulse.
5. Confirm `isAllowedSeaDrop` for the Studio SeaDrop address.
6. `setMetadataURIs` to the **pinned off-hub** 4444 bases (§4). Never the hub `/art/examples` tree or public `web/public/metadata`.
7. Wire Dial only with the eight **real** `4663` stock addresses (§3).
8. Copy addresses into hub `NEXT_PUBLIC_*`. Leave `mintOpen` false unless the hub should also mint (shares the 4244 cap with SeaDrop).

## 8. Explicit: no broadcast until owner says go

This PR / checklist is prep only.

- No `forge script … --rpc-url robinhood --broadcast`
- No `--chain 4663` verify-on-deploy
- No CI job that sends mainnet txs
- No “helpfully” running the §6 block

When the owner says go, re-read §0–§7 on that day (SeaDrop address, stock tokens, pin CIDs, env unset of MICRO vars) and broadcast from a human-held `.env`.

## Explicit do-nots

- **Do not broadcast to `4663` from this document.**
- **Do not** reuse RH testnet MICRO economics (`HOPPER_LOCK_SECONDS=900`, tiny Ignite / Pulse).
- **Do not** invent Dial mainnet stock addresses or a Robinhood SeaDrop address.
- **Do not** `teamMint` the 200 reserve to `0xA71c…` (testnet deployer).
- **Do not** publish 4444 lit/dormant metadata to public `web/` until after reveal.
- **Do not** point production metadata at hub `/art/examples` or the deleted `/metadata` tree.
- **Do not** use Studio’s deploy wizard on mainnet.

## References

- `src/CollectionConfig.sol` — locked production constants
- `script/Deploy.s.sol` — env overrides (must stay default on mainnet)
- [`STUDIO_DROP_DRYRUN.md`](STUDIO_DROP_DRYRUN.md) — Base Sepolia / Sepolia Studio path
- [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md)
- [`DIAL.md`](DIAL.md) — slots; testnet samples are not mainnet
- [`MAIN_ART_LOCK.md`](MAIN_ART_LOCK.md) / `art/generator/README-generate.md` — full export + pin
- [`TESTNET_DEPLOY.md`](TESTNET_DEPLOY.md) — `46630` only
- [`deployments/robinhood-testnet.json`](../deployments/robinhood-testnet.json) / [`deployments/robinhood-testnet-micro.json`](../deployments/robinhood-testnet-micro.json) — recorded testnet stacks, not mainnet templates
