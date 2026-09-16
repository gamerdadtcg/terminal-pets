# Terminal Pets

Greenfield NFT collection for **Robinhood Chain** (EVM L2, chain id `4663`, native gas **ETH**).

Public collection name: **Terminal Pets**. NFT symbol: **TERM**. Memecoin: **`$TERM`**.

Collectors mint on OpenSea. After mint, each token is a unique handheld **pet** that starts **Sealed** (placeholder metadata, 24h reveal window) with a **TBA**. After `CollectionNFT.reveal()` it shows as **Dormant** until Ignite. Each token also gets a one-time **`$TERM` Ignite allotment** (placeholder **1,000 `$TERM`**) from token supply so the token half of the first wake does not need a live chart. **Ignite** is off until reveal. Then it is hybrid: that `$TERM` (**37.5% burn / 25% Hopper-as-ETH / 37.5% allotment escrow refill**) **plus exactly 0.002 ETH**. The ETH splits **50% buy `$TERM` and burn / 50% Hopper**. Team earns **0** from that ETH fee (not TermFund, not treasury). The 37.5% token cut returns to the per-pet allotment **pool** (that tokenId stays consumed). One-way **Dormant → Lit**. Lit stays with the NFT on transfer. **Royalties** (7.5% via **RoyaltySplitter**): **pre-reveal 100% → TermFund** (nothing to Hopper, nothing to treasury from that stream). **Post-reveal 5% Hopper / 2.5% treasury**. **Hopper** is ETH only after that: post-reveal NFT royalties, **50% of each Ignite ETH fee**, 25% of each Ignite `$TERM` fee (swapped to ETH when a router is set), plus, once the canonical TERM/ETH pool is live, a **1.5% TermMarket skim** of that pool’s volume. `$TERM` is **not** fee-on-transfer; public transfers are also **off until reveal**. **Dial**: Lit holders pick up to 3 Robinhood Chain Stock Tokens (weights = 100%). **Pulse** uses an escalating Hopper ETH **ladder** (not a fixed 0.5 ETH): bootstrap `0.1 → 1.0`, then cycle `0.5 → 1.0` forever (never back to 0.1). Snapshot Lit, read Dial. **Dialed Lit** swap their ETH share to Stock Tokens (ETH fallback if no router). **Undialed Lit** buy `$TERM` with that share and credit the TBA (or owner) — not raw ETH; claim reverts without router + `$TERM`. Hopper stays ETH. Dormant earn nothing. TermMarket ships in this repo but stays **inactive** until `TERM_POOL` and `TERM_SWAP_ROUTER` are set.

This repo is a complete MVP: Foundry contracts, tests, a Robinhood Chain deploy script, a Next.js hub + wallet dapp (wagmi / viem), and the Pocket Critter generative PFP art system under `art/`. The public homepage is a marketing hub. Contract addresses can stay empty until Robinhood Chain deploy.

**Ready to deploy — not deployed. Do not broadcast to chain `4663` until explicitly asked.**

## Configure name, symbol, max supply

Edit one file before deploy:

```solidity
// src/CollectionConfig.sol
NAME        = "Terminal Pets"
SYMBOL      = "TERM"
MAX_SUPPLY    = 4444          // 200 team + 4244 public
TEAM_RESERVE  = 200
PUBLIC_SUPPLY = 4244
```

Or override at deploy time without touching Solidity:

```bash
COLLECTION_NAME="Terminal Pets" \
COLLECTION_SYMBOL="TERM" \
MAX_SUPPLY=4444 \
TREASURY_ADDRESS=0xYourTreasury \
forge script script/Deploy.s.sol:Deploy --rpc-url robinhood --broadcast
# ↑ do not run on 4663 until the user says go
```

Other defaults in the same library: mint price `0`, **24h reveal delay**, Ignite **1,000 `$TERM`** (placeholder; **37.5% burn / 25% Hopper / 37.5% allotment refill**) **plus 0.002 ETH** (**50% buy/burn `$TERM` / 50% Hopper**), Ignite allotment escrow `4444 × 1,000 $TERM`, canonical swap skim **3%** (`150` / `100` / `50` bps → Hopper / burn / treasury), Pulse **ladder** (see below), royalty `750` bps (7.5%) to the RoyaltySplitter — **pre-reveal 100% TermFund**, **post-reveal `500` bps / 5% Hopper + `250` bps / 2.5% treasury**.

## Pulse ladder

`PulseDistributor.pulseThreshold()` is derived from phase + index. It advances **after** each successful `pulse()`. There is no owner `setPulseThreshold`.

### Bootstrap (first time only)

Hopper `available()` must reach the current rung. Step **0.1 ETH** up to **1.0 ETH**:

| Pulse # | Threshold |
| --- | --- |
| 1 | 0.1 ETH |
| 2 | 0.2 ETH |
| 3 | 0.3 ETH |
| 4 | 0.4 ETH |
| 5 | 0.5 ETH |
| 6 | 0.6 ETH |
| 7 | 0.7 ETH |
| 8 | 0.8 ETH |
| 9 | 0.9 ETH |
| 10 | 1.0 ETH |

### After bootstrap completes

After a successful Pulse at **1.0 ETH** during bootstrap, the next threshold is **0.5 ETH** — **never 0.1 again**. Then cycle:

| Then | Threshold |
| --- | --- |
| 1 | 0.5 ETH |
| 2 | 0.6 ETH |
| 3 | 0.7 ETH |
| 4 | 0.8 ETH |
| 5 | 0.9 ETH |
| 6 | 1.0 ETH |
| next | 0.5 ETH (repeat) |

Tracked as `bootstrapComplete` + `ladderIndex` on `PulseDistributor`.

## 24h reveal + staged activation

Deploy does **not** auto-reveal. Tokens mint **Sealed**. `CollectionNFT.revealAfter = deployTime + 24 hours`. Owner may call `reveal()` early; **anyone** may call it after `revealAfter`.

`reveal()` is atomic:

1. Flip metadata live (Sealed → Dormant egg JSON; ERC-4906 batch update). Product art is off-chain Pocket Critter GIF metadata once `setMetadataURIs` is called.
2. Enable `$TERM` public transfers (`TermToken.enableTrading`).
3. Enable Ignite (`IgniteModule.setIgniteEnabled(true)`).
4. Switch RoyaltySplitter to live (`setLive`) — 5% Hopper / 2.5% treasury.

Until that call:

| Gate | Pre-reveal | Post-reveal |
| --- | --- | --- |
| Metadata | Placeholder / Sealed | Live traits (Dormant until Ignite) |
| Ignite / allotment claim | Off (`IgniteClosed`) | On |
| `$TERM` public transfers | Off (`TradingClosed`; mint/burn still work) | On |
| Secondary royalties (7.5%) | **100% TermFund** | **5% Hopper / 2.5% treasury** |
| Hopper payouts (Pulse / claim) | Locked (`hopperUnlockTime = 0`) | Locked **7 days from reveal**, then open |

Hopper ETH already in the pot is **unchanged** by the pre-reveal royalty stream. After `reveal()`, ETH **still accrues** (Ignite hopper half, post-reveal royalties, deposits) but `reserve` / `release` / Pulse stay locked until `revealedAt + 7 days`. First Ignite does **not** unlock early. LP seeding is **manual ops** later via `TermFund.seedLiquidity` (pre-reveal royalty ETH + optional treasury `$TERM`). Do **not** divert Hopper to LP. Ignite ETH does not seed TermFund.

### Royalty routing

Always point OpenSea creator earnings at the **RoyaltySplitter**. The splitter has a `live` flag, flipped in the same `reveal()` transaction:

- **Pre-reveal (`live = false`):** every ETH payment (the full 7.5% creator royalty) is forwarded to **TermFund**. Preview returns `(0, 0)`. Nothing to Hopper. Nothing to treasury from this stream.
- **Post-reveal (`live = true`):** split 2/3 Hopper / 1/3 treasury (5% and 2.5% of sale), as before.

### Launch checklist (not deployed)

Do **not** broadcast to chain `4663` until explicitly asked.

1. Deploy contracts. Confirm `revealed = false`, `igniteEnabled = false`, `tradingEnabled = false`, splitter `live = false`.
2. `teamMint` the 200 reserve. OpenSea import. Point **7.5%** earnings at the RoyaltySplitter. `setMintOpen(true)`.
3. Mint window (up to 24h): secondary royalties fund TermFund. Hopper is untouched by that stream.
4. `CollectionNFT.reveal()` — owner anytime, or anyone after 24h. Art + Ignite + `$TERM` trading + 5/2.5 royalties in one tx. Hopper payouts then lock 7 days from that timestamp.
5. Later, when a DEX adapter exists: `TermFund.setRouter` + `seedLiquidity`. Set `TERM_SWAP_ROUTER` so Ignite can buy-and-burn the ETH half (and convert the `$TERM` Hopper cut). Optional `TERM_POOL` for TermMarket.

## Hybrid Ignite + TermFund

`ignite(tokenId)` is **payable**. Both legs are required:

| Leg | Amount | Where it goes |
| --- | --- | --- |
| `$TERM` | `IGNITE_FEE_TERM` = **1,000 `$TERM`** (placeholder) | **25% (2500 bps)** → ETH → Hopper (parks as `pendingHopperTerm` until `TERM_SWAP_ROUTER`, same settable-router pattern as Pulse). **37.5% (3750 bps)** burn. **37.5% (3750 bps)** → stays on IgniteModule as **allotment escrow refill** (not treasury). First wake uses the per-token allotment (or `claimIgniteAllotment` then `transferFrom`). |
| ETH | `IGNITE_FEE_ETH` = **0.002 ETH** (exact; over/under reverts) | **50% (`IGNITE_ETH_HOPPER_BPS`)** → Hopper ETH. **50% (`IGNITE_ETH_BURN_BPS`)** → buy `$TERM` via `swapRouter` → burn. **Not TermFund. Not treasury.** Collectors earn 0 from this leg. Production should set `TERM_SWAP_ROUTER` before collectors Ignite; if unset, the burn half parks as `pendingIgniteEthBurn` until `flushIgniteEthBurn`. |

So each Ignite: Hopper gets **50% of the 0.002 ETH** plus **25% of the `$TERM` fee as ETH** (when a swap router is set); **50% of the 0.002 ETH** buys `$TERM` and burns; **37.5% `$TERM` is burned**; **37.5% `$TERM` returns to allotment escrow**. Team earns 0 from the ETH fee.

### `$TERM` allotment

1. At `$TERM` deploy, mint `MAX_SUPPLY × IGNITE_FEE_TERM` into `IgniteModule`.
2. Each `tokenId` may spend that allotment **once** while Dormant (`ignite` from escrow, or claim to wallet first).
3. You still attach **0.002 ETH** on `ignite` (50% Hopper / 50% buy-and-burn).
4. The 37.5% Ignite `$TERM` cut **stays in this escrow** as pool refill. It does **not** go to treasury or TermFund. The same `tokenId` cannot spend allotment twice.

### TermFund (LP path)

`TermFund` receives **pre-reveal secondary royalties** via `receive()` (from RoyaltySplitter). There is **no owner withdraw**. Ignite ETH and Ignite `$TERM` refill do **not** land here. After reveal, secondary royalties stop landing here.

- **No DEX yet:** ETH sits in TermFund. Not stuck forever — owner later `setRouter` and `seedLiquidity`.
- **When a pool/router exists:** `seedLiquidity(termAmount, ethAmount)` uses any `$TERM` already in the fund, then pulls any shortfall from treasury (`TERM_INITIAL_SUPPLY`) if approved. LP tokens go to `lpRecipient` (default treasury).
- Optional deploy env: `TERM_LP_ROUTER`. Blank = custody until set.
- Ignite Hopper `$TERM` (25%) is **not** TermFund. It parks on IgniteModule until `setSwapRouter` + `flushHopperTerm` (or swaps immediately if the router is already set). Same `TERM_SWAP_ROUTER` env as TermMarket. The Ignite ETH burn-half uses that router too (`flushIgniteEthBurn` if it parked).

Hopper remains **post-reveal** royalty-ETH plus **50% of each Ignite ETH fee** plus Ignite’s converted 25% `$TERM` cut (when the swap router is live) plus (when the canonical pool is live) TermMarket’s Hopper slice. Pre-reveal royalties never enter it. Pulse ladder is unchanged.

## TermMarket (canonical `$TERM` trading skim)

`$TERM` is a **normal ERC-20**. There is no transfer tax. Aggregators / Uniswap-style routers keep working. Fees apply only when the **canonical TERM/ETH pool** calls `TermMarket.onSwap`.

Default skim is **3% of swap input** (`CollectionConfig.TRADE_FEE_BPS = 300`), then split:

| Cut | Bps | Of volume | Destination |
| --- | --- | --- |
| Hopper | `TRADE_HOPPER_BPS = 150` | **1.5%** | Swap to ETH if needed → `Hopper.deposit` (Pulse fuel) |
| Burn | `TRADE_BURN_BPS = 100` | **1.0%** | Buy `$TERM` if input is ETH, then `burn`. If input is `$TERM`, burn that cut directly. |
| Treasury | `TRADE_TREASURY_BPS = 50` | **0.5%** | ETH or `$TERM` to treasury |

Owner may retune the three cuts with `setFeeBps`, but they **must still sum to 300 bps**.

### Activation (not deployed)

`isActive()` is true only when **both** `canonicalPool` and `swapRouter` are set:

1. Deploy leaves them unset unless env `TERM_POOL` and `TERM_SWAP_ROUTER` are provided.
2. Owner later calls `setCanonicalPool` + `setSwapRouter`.
3. The live pool must call `onSwap(tokenIn, amountIn)` and pay/approve `quote(amountIn).totalFee` (`tokenIn == address(0)` for ETH). Other DEX routes are **untaxed** unless they opt in.

Ignite hybrid fees are separate from this skim: 1,000 `$TERM` (25/37.5/37.5 Hopper/burn/allotment refill) + 0.002 ETH (50% Hopper / 50% buy-and-burn `$TERM`). NFT royalties fund Hopper **after reveal** only.

Until a real DEX exists, tests use `MockTermPool` + `MockTermSwapRouter`. **Do not treat TermMarket as live on chain `4663`.**

## Network

| | |
| --- | --- |
| Name | Robinhood Chain |
| Chain ID | `4663` |
| Gas token | ETH |
| RPC | `https://rpc.mainnet.chain.robinhood.com` |
| Explorer | `https://robinhoodchain.blockscout.com` |

Add the network to any EVM wallet with those values.

## Contracts

| Contract | Role |
| --- | --- |
| `TermToken` | `$TERM` ERC-20 (`Terminal $TERM`). Owner mints treasury float + Ignite allotment escrow. Ignite burns 37.5%, refills allotment 37.5%, converts 25% to Hopper ETH. **Not fee-on-transfer.** Public transfers off until `reveal()`. |
| `TermFund` | Custodies **pre-reveal 7.5% royalties** for `$TERM` LP. **No Ignite ETH.** No owner withdraw. `setRouter` + `seedLiquidity` when a DEX adapter exists. |
| `TermMarket` | Canonical TERM/ETH swap companion. Skims 3% of opted-in pool volume → 1.5% Hopper / 1% burn / 0.5% treasury. Inactive until pool + swap router are set. Trading itself also waits on reveal. |
| `CollectionNFT` | ERC-721Enumerable + ERC-2981. Mints **Sealed**. `reveal()` (owner anytime / anyone after 24h) flips metadata, Ignite, `$TERM` trading, and royalty mode. OpenSea-friendly `mintTo` (4244 public). Owner `teamMint` / `ownerMint` (200 reserve). Royalties locked to the RoyaltySplitter. Name **Terminal Pets**, symbol **TERM**. |
| `IgniteModule` | Payable `ignite(tokenId)` — Dormant → Lit. **Off until reveal.** `$TERM` allotment or `transferFrom` (**25% Hopper / 37.5% burn / 37.5% allotment refill**) **plus exact 0.002 ETH (50% Hopper / 50% buy `$TERM` and burn)**. |
| `Hopper` | ETH only. **Post-reveal** royalty slice + optional paid mint + **50% of Ignite ETH** + Ignite `$TERM` hopper cut (as ETH) + TermMarket skim when live. **No pre-reveal royalties. No admin withdraw.** Distributor locked once. |
| `RoyaltySplitter` | ERC-2981 / OpenSea receiver. Pre-reveal: 100% → TermFund. Post-reveal (`setLive` in `reveal()`): 2/3 Hopper, 1/3 treasury. |
| `PulseDistributor` | Dial (up to 3 Stock Tokens, weights in bps = 10_000). Ladder `pulse()`. Dialed `claim` → Stock Tokens via `PULSE_ROUTER`. Undialed Lit → buy `$TERM` to TBA/owner (reverts without router+term). Hopper stays ETH. Optional TBA delivery. |
| `ERC6551Registry` + `ReceivableAccount` | Configurable TBA registry. Tests also ship `MockERC6551Registry`. |

### Hopper trust model

ETH in the Hopper is holder money (**post-reveal** royalty share, optional paid-mint proceeds, **50% of each Ignite ETH fee**, 25% of each Ignite `$TERM` fee once swapped to ETH, and — when the canonical `$TERM` pool is live — TermMarket’s 1.5% skim). Pre-reveal royalties go to **TermFund**, not here. The other 50% of Ignite ETH buys `$TERM` and burns. After reveal, the treasury’s 2.5% of sales never enters the Hopper.

- There is **no** `withdraw`, `sweep`, or owner rescue.
- The only outbound path is `PulseDistributor` → Lit terminals (owner or TBA).
- `lockDistributor` can be called **once**. After that, the owner cannot point the Hopper at a different spender.

Read the comments at the top of `src/Hopper.sol`.

### Art / metadata

Live product art is the **generative Pocket Critter** package vendored at [`art/`](art/README.md). Off-chain 2048 PNG compose / 512 GIF export (awake pet + matching dormant egg). Track A on-chain SVG (`scarfpack-3a194a4` / `TerminalRenderer` lit pets) is historical only — see [`docs/MAIN_ART_LOCK.md`](docs/MAIN_ART_LOCK.md).

`CollectionNFT.tokenURI` is lifecycle-switched:

| State | URI |
| --- | --- |
| Sealed | `hiddenURI` (typical single `hidden.json`) |
| Revealed Dormant | `{dormantBaseURI}{id}.json` → egg rock GIF |
| Lit (Ignite) | `{litBaseURI}{id}.json` → awake pet GIF |

Owner sets bases with `setMetadataURIs`. Trailing `/` appends `{tokenId}.json`. ERC-4906 `MetadataUpdate` still fires on Ignite. Until URIs are set, a **fallback** on-chain data-URI stub (rectangle + `PET#` + state + `OFF-CHAIN ART`) keeps mint/reveal/Ignite tests working — it is not product art.

`tokenTraits()` still returns the historical `AWAKEN_PET_V2` table for tests. Product traits are `art/schema/traits.json`. The old `ACC_N = 6` accessory list is obsolete for product art.

Metadata `name` is `Terminal Pet #{id}` (egg JSON uses `Terminal Pet Egg #{id}`). Collection `contractURI` name is `Terminal Pets`.

Regenerate sample GIFs (Python 3.10+ / Pillow):

```bash
pip install -r art/requirements.txt
python art/generator/generate_collection.py \
  --count 4444 --start 1 --limit 3 \
  --out-art art/export/gif-test/art \
  --out-metadata art/export/gif-test/metadata \
  --out-egg art/export/gif-test/egg \
  --out-egg-metadata art/export/gif-test/egg-metadata \
  --seed 42
```

Full 4444 export is optional and gitignored (`art/export/gif-full/`). After pinning, pass `--art-image-base` / `--egg-image-base` or run `art/generator/rewrite_image_uris.py`.

### Mint allocation

| Path | Supply | Who |
| --- | --- | --- |
| Public / OpenSea (`mint`, `mintTo`) | **4244** | Anyone while `mintOpen` |
| Team (`teamMint` / `ownerMint`) | **200** | Owner only, to treasury or any team wallet |
| Total | **4444** | Team + public cannot exceed this |

Public mint cannot consume the team reserve, even if the team has not minted yet. Unused team slots stay reserved; they are not released to OpenSea.

`CollectionNFT` mint functions:

- `mintTo(address to, uint256 quantity)` — marketplace / OpenSea-friendly (public cap)
- `mint(address to)` — single-token adapter (public cap)
- `mint(uint256 quantity)` — dapp mint to the caller (public cap)
- `teamMint` / `ownerMint` — owner-only reserve (team cap)

Mint starts **closed**. After deploy, mint the reserve with `teamMint(TREASURY_ADDRESS, 200)` (or a dedicated team wallet). Then open public mint when the OpenSea collection is ready. Paid public mint ETH is forwarded to the Hopper.

## OpenSea: point royalties at the RoyaltySplitter

ERC-2981 is wired to the **RoyaltySplitter** at `750` bps (7.5% of sale). **Pre-reveal** the splitter forwards **100% to TermFund**. **Post-reveal** it forwards 2/3 to the Hopper (5% of sale) and 1/3 to `TREASURY_ADDRESS` (2.5% of sale). Ignite fees do not go through the splitter.

1. Deploy and verify CollectionNFT, Hopper, RoyaltySplitter, Ignite, and Pulse on [Blockscout](https://robinhoodchain.blockscout.com) (see Deploy).
2. On OpenSea, **import an existing contract** and paste the `CollectionNFT` address on Robinhood Chain (`4663`).
3. Open collection **earnings / creator royalties**.
4. Set creator earnings to **7.5% (750 bps)** and the recipient to the **RoyaltySplitter** address (not Hopper, not a personal wallet, not treasury).
5. If OpenSea offers “honor on-chain royalties” / ERC-2981, enable it. `royaltyInfo` already returns the splitter and 750 bps.
6. Confirm the collection page shows the splitter as the fee recipient. Secondary sales that honor ERC-2981 then follow the live mode: TermFund until reveal, Hopper/treasury after.
7. Primary mint: list the drop on OpenSea, or turn `mintOpen` on and let collectors use `mintTo` / the dapp. After mint, OpenSea will show **Sealed** metadata until `reveal()`, then Dormant; Ignite updates `tokenURI` to Lit.

Do not route creator earnings to an EOA or directly to Hopper. The splitter is what keeps the pre-reveal TermFund path and the post-reveal 5% / 2.5% split.

## Develop

### Contracts (Foundry)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

git clone --recursive <this-repo>
cd <repo>
forge test
forge fmt
```

`forge test` is the success check for the contracts.

### Hub + dapp (`web/`)

Public marketing site and wallet tools share one Next.js app.

| Route | What |
| --- | --- |
| `/` | Hub: hero, how it works, Hopper, economics, generative art preview, status, FAQ, links |
| `/hopper` | Dedicated Hopper + Pulse ladder explainer |
| `/dial` | Dial explainer |
| `/app` | Ignite / allotment / Hopper / Pulse / TBA wallet tools (Dial picker not live) |

```bash
cd web
cp .env.example .env.local   # addresses optional until chain deploy
npm install
npm run dev                  # http://127.0.0.1:43147
npm run build
```

Without contract addresses the hub shows **Deploying soon**. The Terminal route still renders empty states and the Hopper explainer.

Environment (`web/.env.local` or Vercel project env):

```
NEXT_PUBLIC_CHAIN_ID=4663
NEXT_PUBLIC_RPC_URL=https://rpc.mainnet.chain.robinhood.com
NEXT_PUBLIC_EXPLORER_URL=https://robinhoodchain.blockscout.com
NEXT_PUBLIC_COLLECTION_ADDRESS=
NEXT_PUBLIC_IGNITE_ADDRESS=
NEXT_PUBLIC_HOPPER_ADDRESS=
NEXT_PUBLIC_PULSE_ADDRESS=
NEXT_PUBLIC_SPLITTER_ADDRESS=
NEXT_PUBLIC_TERM_ADDRESS=
NEXT_PUBLIC_TERM_FUND_ADDRESS=
NEXT_PUBLIC_TERM_MARKET_ADDRESS=
NEXT_PUBLIC_OPENSEA_URL=
NEXT_PUBLIC_X_URL=
```

### Deploy the hub to Vercel (Hobby / free)

The Next.js app lives in `web/`. Vercel must build that folder, not the Foundry root.

**One-command from this machine (after `vercel login`):**

```bash
cd web
npx vercel --prod --yes
```

**Dashboard / git import:**

1. Import the Origin (or GitHub) repository in [Vercel](https://vercel.com/new).
2. Set **Root Directory** to `web`.
3. Framework: Next.js (auto).
4. Add the `NEXT_PUBLIC_*` env vars from `.env.example` (leave addresses blank until deploy).
5. Deploy. Hobby is enough — no paid add-ons.

`web/vercel.json` pins the framework. After chain deploy, set the address env vars and redeploy; OpenSea / X links unlock the hero CTAs.

## Ready to deploy — not deployed

**Do not broadcast until the user says go.** Contracts and tests are green. No live addresses. This repo must not send transactions to Robinhood Chain `4663` until explicitly asked.

Placeholders still open:

| Item | Current placeholder | Where |
| --- | --- | --- |
| Ignite `$TERM` amount | `1_000 ether` (1,000 `$TERM`) | `CollectionConfig.IGNITE_FEE_TERM` |
| Ignite ETH amount | `0.002 ether` → 50% Hopper / 50% buy-and-burn `$TERM` | `CollectionConfig.IGNITE_FEE_ETH` |
| Ignite ETH split | `5000` / `5000` bps | `IGNITE_ETH_HOPPER_BPS` / `IGNITE_ETH_BURN_BPS` |
| Ignite allotment escrow | `MAX_SUPPLY × IGNITE_FEE_TERM` | minted to `IgniteModule` at deploy |
| `$TERM` treasury float | `1_000_000_000 ether` (LP pairing) | `TERM_INITIAL_SUPPLY` |
| TermFund DEX router | unset → ETH custody until `setRouter` | `TERM_LP_ROUTER` / `TermFund.setRouter` |
| TermMarket pool + swap router | unset → skim **inactive** (not deployed as a live tax) | `TERM_POOL` + `TERM_SWAP_ROUTER` / `TermMarket.setCanonicalPool` + `setSwapRouter` |
| Reveal delay | `24 hours` — owner may reveal early | `CollectionConfig.REVEAL_DELAY` |
| Royalty mode | Pre-reveal 100% TermFund; post-reveal 5/2.5 | `RoyaltySplitter.live` flipped in `reveal()` |
| Canonical swap fee | 3% = 1.5% Hopper / 1% burn / 0.5% treasury | `TRADE_*_BPS` in `CollectionConfig` |
| Pulse DEX router | required for undialed `$TERM` and Dialed stocks | `PULSE_ROUTER` / `setRouter` + `setTerm` |
| Chain contract addresses | empty | `web/.env.local` |
| Mint price | `0` / TBD | `MINT_PRICE_WEI` |
| Metadata URIs | unset → fallback stub | `CollectionNFT.setMetadataURIs` after pinning `art/` GIFs |

Later, when someone says go (commands only — do not run them now):

```bash
cp .env.example .env
# set PRIVATE_KEY and TREASURY_ADDRESS
# optional: IGNITE_FEE_TERM, IGNITE_FEE_ETH, TERM_INITIAL_SUPPLY, TERM_TOKEN, TERM_LP_ROUTER, TERM_POOL, TERM_SWAP_ROUTER, PULSE_ROUTER, TBA_*

# Local Anvil only (safe):
# anvil
# PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
# TREASURY_ADDRESS=0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
# MINT_OPEN=true \
# forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast

# Live Robinhood Chain — only after explicit go:
# source .env
# forge script script/Deploy.s.sol:Deploy \
#   --rpc-url https://rpc.mainnet.chain.robinhood.com \
#   --broadcast --verify --verifier blockscout \
#   --verifier-url https://robinhoodchain.blockscout.com/api/
```

After a future broadcast, copy TermToken, TermFund, TermMarket, Hopper, RoyaltySplitter, CollectionNFT, IgniteModule, PulseDistributor, TBA into `web/.env.local`, then `teamMint` / `setMintOpen`.

## Tests

`test/LaunchReveal.t.sol` covers the 24h window: sealed metadata, Ignite off, `$TERM` trading off, **pre-reveal royalties 100% TermFund** (Hopper and treasury unchanged, including when Hopper already holds ETH), owner may reveal early, anyone after 24h, and after reveal: revealed metadata + Ignite + trading + **5% Hopper / 2.5% treasury**.

`test/AwakenTerminals.t.sol` covers mint, **post-reveal** royalties (5/2.5), hybrid Ignite (0 ETH reverts; with mock router 25% Hopper ETH / 37.5% burn / 37.5% allotment refill + **0.002 ETH 50% Hopper / 50% buy-and-burn `$TERM`**; escrow refill; flushHopperTerm; flushIgniteEthBurn; claim-then-wallet `$TERM`), TermFund `seedLiquidity` does not spend allotment, no TermFund owner withdraw, Dial, Pulse ladder first rung, pro-rata Lit, **Dialed → stocks / undialed → `$TERM`**, TBA `$TERM` (not ETH), undialed revert without router, double-claim.

`test/PulseLadder.t.sol` covers bootstrap `0.1→1.0`, next threshold `0.5` (not `0.1`), and cycling `0.5–1.0`.

`test/TermMarket.t.sol` covers 300/150/100/50 bps quotes, inactive until pool **and** router, only the canonical pool may skim, ETH buy → Hopper 1.5% / burn 1% / treasury 0.5%, `$TERM` sell same split, `$TERM` transfers are not taxed, Ignite ETH is **50% Hopper / 50% parked burn-half** without a swap router (Hopper ETH from the `$TERM` leg waits on a swap router).

```bash
forge test -vv
```

## Layout

```
src/           CollectionNFT, Ignite, TermFund, TermMarket, Hopper, RoyaltySplitter, Pulse, TBA
script/        Deploy.s.sol
test/          Foundry tests (including MockTermPool / MockTermSwapRouter)
web/           Next.js hub (`/`), Hopper, Dial, Terminal (`/app`)
```

Out of scope: a live DEX on Robinhood Chain, launchpad, and any real-world stock-token product. TermMarket is the fee companion; production skim stays off until a pool + router are set.
