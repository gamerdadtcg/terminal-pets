# Pulse V2: design, funding options, migration

Status: **proposal, nothing deployed or broadcast.** Branch `fix/pulse-v2`. Base: deployed commit `23ba2397d304`.
Merge and deploy require the owner's explicit approval.

## 1. Problem (V1, measured)

| Issue | V1 behaviour | Measured |
|---|---|---|
| `pulse()` loops the whole lit bitmap, resolving every pet's Dial legs | gas grows ~linearly with lit pets | 325,790 (1 lit); 8.73M (100); 44.1M (500); 89.0M (1,000); ~418M (4,444). Breaks at ~340 lit pets under a ~32M per-tx cap |
| Same loop with no resolved legs | still linear | 13.6M (1,000); 30.1M (2,000), ~13.6k per pet |
| `_claim` loops every epoch | ~50k gas per unpaid epoch | 1 epoch 156k; 10 epochs 653k; 50 epochs 2.74M; 200 epochs 10.2M |
| `SwapFailed` in `_buyTerm` / `_swapLeg` | reverts the whole claim | holder cannot get paid until the pool recovers |
| V1 Hopper | no withdraw, pause, or upgrade; its distributor is locked to V1 Pulse | funds can only leave via V1 Pulse |

If pulse can never run, ETH in the Hopper is stranded: the DoS in the report.

The ~32M per-tx cap is the Arbitrum Orbit default and was not confirmed on-chain. The design targets **15M per tx** to stay well inside any plausible cap.

## 2. What is and is not changeable on the live contracts

Changeable by the owner:
- `IgniteModule.setPulseDistributor` (Dial hook; owner-only, not set-once), `setSwapRouter`, `setFeeBps`.
- `TermMarket.setFeeBps`, TermFund setters.

Fixed (immutable or set-once):
- Hopper address inside CollectionNFT, IgniteModule, TermMarket, RoyaltySplitter. The royalty receiver is locked.
- `setIgniteModule` is set-once.
- Ignite's 50% ETH half (`quoteEth`) is a constant that sends to the V1 Hopper.
- The TermMarket ETH-side skim goes to the V1 Hopper.

So **V1 Hopper keeps receiving**: royalties, Ignite's ETH half (until Option B zeroes `igniteFeeEth`), and the TermMarket ETH skim. These cannot be redirected. Only the `$TERM`-derived slices can (via a replaceable swap router).

## 3. V2 design

### PulseDistributorV2 (`src/PulseDistributorV2.sol`)
- **O(1) pulse.** Each pet records `litFrom` (the epoch it joined) when Ignite calls `assignDial` or someone calls permissionless `registerLit(ids)`. `pulse()` requires `registeredCount == ignite.litCount()`, so the share set is exact. It then writes one prefix-sum entry `cumShare[epoch]` and does no per-pet work.
- **Claims are O(1) in epochs.** Each pet has a cursor `claimedThrough`; payout is `cumShare[end] - cumShare[start]`. `claim`, `claimUpTo(id, endEpoch)` (epoch ranges), `claimMany`, and `claimManyBounded(ids, minGasLeft)` (stops when gas runs low).
- **Failed swaps are skipped.** A failing leg falls back to plain ETH, and if that fails too the amount is credited to the pet (`creditOf`, `withdrawCredit`). One bad token or pool never blocks a claim.
- **Packed one-slot Dial.** Stock tokens, router, TBA registry, and `deliverToTba` are resolved at claim time, so owner fixes to those settings apply to existing pets.
- Same ladder as V1 (copied from V1 immutables): 0.1 -> 1.0, then 0.5 -> 1.0, step 0.1.

### HopperV2 (`src/HopperV2.sol`)
- Same trust model: only the locked distributor moves ETH in the normal path.
- Reveal clock read from V1 Hopper, so the lock stays 7 days after the reveal that already happened. No new waiting period is introduced.
- `pause()` / `unpause()` (owner). While paused, `reserve` and `release` revert.
- Emergency withdraw: only while paused, owner proposes `(to, amount)`, waits **7 days**, then executes. Public event and view, cancellable, auto-cancelled by `unpause()`. Use a multisig owner. This is the only owner path to ETH.

### HopperRedirectRouter (`src/HopperRedirectRouter.sol`)
Wraps Ignite's existing swap router. `$TERM` -> ETH swaps whose recipient is the V1 Hopper deliver to HopperV2 instead. Everything else passes through. Deployed by step 1 and installed on Ignite and TermMarket by steps 4 and 5.

## 4. Funding: Option B (chosen by the owner)

Where each fee goes **after** this migration:

| Fee path | Before | After Option B |
|---|---|---|
| Ignite ETH fee (`igniteFeeEth`, 0.002 ETH) | 0.001 ETH to V1 Hopper (hardwired), 0.001 ETH buy-and-burn | **Set to 0.** Nothing is charged in ETH, so nothing more lands in V1 Hopper from Ignite |
| Ignite `$TERM` fee (`igniteFee`, 1000 TERM = 1e21) | 25% to ETH to V1 Hopper, 37.5% burn, 37.5% allotment-escrow refill | Unchanged amounts and bps. The 25% swap's ETH is redirected to **HopperV2** |
| TermMarket `$TERM`-side skim | swapped to ETH, V1 Hopper | Swapped to ETH, **HopperV2** (bps unchanged) |
| TermMarket ETH-side skim | V1 Hopper (hardwired) | Unchanged: still V1 Hopper (cannot be redirected) |
| Royalties (RoyaltySplitter) | V1 Hopper (locked) | Unchanged: still V1 Hopper |
| Pulse | V1 Pulse | V2 for all new Ignites; V1 Pulse can still pay the 3 pets lit before the migration, while lit stays under ~340 |

Live facts used (supplied by the owner; step 1 reads the router on-chain and `verifyState` re-checks the fee values): Ignite `swapRouter` = `0xDe6dF0527608A20121ecD6aA009C198Ca1cba28F`, `igniteFee` = 1e21, `igniteFeeEth` = 2e15, `pendingHopperTerm` = 0. The redirect router wraps that same adapter; step 1 refuses to run if TermMarket's router is set to a different adapter.

### What changes for holders and the hopper
- **With allotment escrow, a holder's Ignite is free in ETH and TERM.** The module holds 1,000 TERM per token as a first-wake allotment, and Ignite is one-way, so every Ignite uses that allotment. The holder pays gas only: `ignite(tokenId)` with `msg.value == 0` and no `$TERM` approval.
- **The Hopper gets 25% of the 1000 TERM (250 TERM) swapped to ETH** on each Ignite, delivered to HopperV2. The ETH received depends on the live pool price; the tests use a 1:1 mock.
- 37.5% of the fee (375 TERM) is burned and 37.5% stays in the module as escrow refill, as before.
- **Per-Ignite hopper income drops.** The hardwired 0.001 ETH half is gone, and the 0.001 ETH buy-and-burn is gone. The burn from `$TERM` remains.
- `ignite()` now reverts with `WrongEthFee` for any non-zero `msg.value`.

### Risks to know before step 7
- The 250 TERM -> ETH swap runs inside every `ignite()`. If the pool is thin the swap gets a poor price, and if the swap fails `ignite()` reverts (`SwapFailed`), so Ignite blocks until the pool recovers. Check live liquidity first.
- V1 Hopper still gets royalties and the TermMarket ETH skim. That ETH is only reachable through V1 Pulse (which breaks past ~340 lit pets) and is stranded beyond that. Not fixable on-chain: the receivers are immutable or locked.
- Pausing HopperV2 blocks pulse reservation and payouts.

## 5. Measured gas (V2, Foundry, mock harness)

All batches are below 15M gas.

| Operation | Gas |
|---|---|
| `registerLit`, batch of 100 | 5.72M max (~57k per pet) |
| `pulse()` at 4,444 lit | 177,754 (first epoch); <= 143,618 after |
| Claim, worst case 4 legs/pet (~100k gas swap mock), batch of 25 | 10.63M max (~400k per pet); 178 batches cover 4,444 pets |
| Claim, natural dial mix, batch of 60 | 12.88M max (~193k per pet) |
| `claimManyBounded` (12M gas, 2M floor) | 26 four-leg pets, 10.26M used |
| Single claim, 1 vs 201 unpaid epochs | ~127k in both cases |

Real DEX swaps may cost more than the mock; size live batches from a dry run and use `claimManyBounded`.

## 6. Migration (Option B): `script/MigratePulseV2.s.sol` (**not executed**)

Each step is its own script entrypoint and its own transaction(s), for separate owner approval. Ignite is paused throughout and is only enabled by step 7.

| # | Entrypoint | Signer | On-chain effect | Live state touched |
|---|---|---|---|---|
| 1 | `step1Deploy()` | Ignite owner | Deploy HopperV2, PulseDistributorV2, HopperRedirectRouter (wrapping Ignite's current router). Copy V1 config and shell overrides, lock HopperV2's distributor to PulseV2, transfer ownership of both to `OWNER` | None |
| 2 | `step2Register()` | any | `PulseV2.registerLit` in batches of 100 for every currently lit pet (3 today) | PulseV2 only |
| 3 | `step3DialHook()` | Ignite owner | `Ignite.setPulseDistributor(PulseV2)` | Ignite |
| 4 | `step4IgniteRouter()` | Ignite owner | `Ignite.setSwapRouter(redirect)` | Ignite |
| 5 | `step5MarketRouter()` | TermMarket owner | `TermMarket.setSwapRouter(redirect)` | TermMarket |
| 6 | `step6ZeroEthFee()` | Ignite owner | `Ignite.setIgniteFeeEth(0)`. `igniteFee` (1e21) and all bps stay | Ignite |
| - | `verifyState(false)` | none (read-only) | Checks steps 1-6 hold: hooks, routers, fee 0 and 1e21, `pendingHopperTerm == 0`, `registeredCount == litCount`, Ignite still disabled | None |
| 7 | `step7EnableIgnite()` | Ignite owner | `Ignite.setIgniteEnabled(true)`. **Separate final decision.** The script re-runs the checks and refuses if any fail | Ignite |

`dryRun()` simulates steps 1-6 plus the checks with a prank and no broadcast. It never runs step 7. Env: `PRIVATE_KEY`, `V1_HOPPER`, `V1_PULSE`, `COLLECTION`, `IGNITE`, `TERM_MARKET`, optional `MAX_SUPPLY`, `OWNER`. Steps 2-7 also need `PULSE_V2`, `HOPPER_V2`, `REDIRECT` (printed by step 1).

Ordering: step 1 first, then 2, then 3 to 6 in any order (all while Ignite is paused). Steps 3 to 6 take effect only once Ignite is enabled. V1 Hopper, V1 Pulse, royalties, and `igniteFee` are never modified.

Rollback before step 7 is just setting the router, hook, and fee back with the same owner setters. After step 7, ignited pets are one-way.

## 7. Caveats

- Ignite's former ETH half is not recovered; the TermMarket ETH skim and royalties still land in V1 Hopper (section 4).
- The per-tx gas cap was assumed, not verified on-chain.
- Swap gas and price are mocked; a live fork run is recommended before mainnet.
- Needs an independent audit before holding real funds: the contracts are new.
- Ownership handover is single-step Ownable. Verify the `OWNER` address before running step 1.
