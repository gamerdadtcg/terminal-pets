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
| TermMarket fees (3% total: 1.5% hopper / 1% burn / 0.5% treasury) | Hopper cut hardwired to the V1 Hopper (ETH side: `hopper.deposit`; `$TERM` side: swapped to the V1 Hopper address) | **Fixed.** `setFeeBps(0, 100, 200)` + `setTreasury(TermMarketFeeForwarder)`. Same 3% total, same 1% burn. The forwarder sends 75% of the treasury stream to **HopperV2** and 25% to the real treasury (ETH immediately, `$TERM` via a keeper `flushTerm`). Nothing more lands in the V1 Hopper |
| Royalties (RoyaltySplitter) | V1 Hopper (locked) | Unchanged: still V1 Hopper |
| Pulse | V1 Pulse | V2 for all new Ignites; V1 Pulse can still pay the 3 pets lit before the migration, while lit stays under ~340 |

Live facts used (supplied by the owner; step 1 reads the router on-chain and `verifyState` re-checks the fee values): Ignite `swapRouter` = `0xDe6dF0527608A20121ecD6aA009C198Ca1cba28F`, `igniteFee` = 1e21, `igniteFeeEth` = 2e15, `pendingHopperTerm` = 0. The redirect router wraps that same adapter; step 1 refuses to run if TermMarket's router is set to a different adapter.

### What changes for holders and the hopper
- **With allotment escrow, a holder's Ignite is free in ETH and TERM.** The module holds 1,000 TERM per token as a first-wake allotment, and Ignite is one-way, so every Ignite uses that allotment. The holder pays gas only: `ignite(tokenId)` with `msg.value == 0` and no `$TERM` approval.
- **The Hopper gets 25% of the 1000 TERM (250 TERM) swapped to ETH** on each Ignite, delivered to HopperV2. The ETH received depends on the live pool price; the tests use a 1:1 mock.
- 37.5% of the fee (375 TERM) is burned and 37.5% stays in the module as escrow refill, as before.
- **Per-Ignite hopper income drops.** The hardwired 0.001 ETH half is gone, and the 0.001 ETH buy-and-burn is gone. The burn from `$TERM` remains.
- `ignite()` now reverts with `WrongEthFee` for any non-zero `msg.value`.

### TermMarketFeeForwarder (`src/TermMarketFeeForwarder.sol`)
`TermMarket` hard-wires its Hopper cut to the V1 Hopper, so the cut is moved into the treasury cut and the treasury is pointed at a forwarder that splits it back out (parts are read from the live TermMarket at step 1b: 150 / 200 to HopperV2, the rest to the current treasury).
- ETH: `receive()` splits and pushes immediately with a 100k gas cap per recipient. It never reverts, so a bad recipient cannot block trades; an undeliverable share is kept (`owedHopper` / `owedTreasury`) and anyone can `retry()`. `sync()` accounts forced ETH.
- `$TERM`: arrives by plain transfer. The keeper (or owner) calls `flushTerm(minEthOut)`: the treasury share goes to the treasury as `$TERM`, the Hopper share is swapped to ETH for HopperV2 and reverts below `minEthOut` (the router has no min-out argument, so this is a balance-delta check). It is deliberately not permissionless so nobody can pass 0 and sandwich it.
- No ETH or `$TERM` is created or lost: tests assert conservation under fuzzing.

### Soft-fail in HopperRedirectRouter
If the DEX swap reverts, a swap requested by Ignite returns the 250 `$TERM` to Ignite and returns 0, so `ignite()` still completes (the 250 TERM stays in Ignite's escrow instead of becoming ETH). Without this, anyone who moves the tiny pool could revert every `ignite()`. TermMarket still reverts on a failed swap.

### Royalties: confirmed not redirectable
`RoyaltySplitter.hopper` is `immutable` and the splitter has no setter. `CollectionNFT.royaltyReceiver` is `immutable` and `setRoyaltyInfo` reverts `RoyaltyReceiverLocked`. Both confirmed on mainnet (`royaltyReceiver()` = splitter, `splitter.hopper()` = V1 Hopper, splitter owner = the deployer EOA but it has no admin setter, bytecode identical to the repo build). The only lever is `CollectionNFT.setRoyaltyBps(bps)` (owner): lowering or zeroing royalties is an economics change, not a redirect, and it does not recover anything already in the V1 Hopper. Royalty ETH therefore keeps accruing in the V1 Hopper, reachable only through V1 Pulse.

### Risks to know before step 9
- **The pool is very thin** (read-only, live: 0.010396 ETH / 712,452 TERM). 250 TERM sells for about 3.6e-6 ETH (fork: 3,635,866,570,269 wei, 0.07% price impact). At that size Option B's Hopper income is negligible: the 0.1 ETH pulse threshold will not be reached from Ignite or TermMarket flows. Hopper funding really depends on manual top-ups or a deeper pool.
- Sandwiching the 250 TERM swap is unprofitable (fork: attacker lost ~840 TERM round-tripping 200k TERM to cost the victim ~1.4e-6 ETH). The adapter's slippage guard does not stop a front-run (it quotes at call time), but the exposure is the notional of 250 TERM.
- V1 Hopper still gets royalties. That ETH is only reachable through V1 Pulse (which breaks past ~340 lit pets under the verified 32M cap) and is stranded beyond that.
- TermMarket is inactive today (no canonical pool, no router). Do steps 7 and 8 before activating it. The stock V2 pair does not call `onSwap`, so activation needs a pool or hook that does.
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

## 6. Migration (Option B + fee fix): `script/MigratePulseV2.s.sol` (**not executed**)

Each step is its own script entrypoint and its own transaction(s), for separate owner approval. Ignite is paused throughout and is only enabled by step 9.

| # | Entrypoint | Signer | On-chain effect | Live state touched |
|---|---|---|---|---|
| 1 | `step1Deploy()` | Ignite owner | Deploy HopperV2, PulseDistributorV2, HopperRedirectRouter (wrapping Ignite's current router; Ignite is the soft-fail caller). Copy V1 config and shell overrides, lock HopperV2's distributor to PulseV2, transfer ownership of both to `OWNER` | None |
| 1b | `step1bDeployForwarder()` | TermMarket owner | Deploy TermMarketFeeForwarder (parts and real treasury read from the live TermMarket), transfer ownership to `OWNER` | None |
| 2 | `step2Register()` | any | `PulseV2.registerLit` in batches of 100 for every currently lit pet (3 today) | PulseV2 only |
| 3 | `step3DialHook()` | Ignite owner | `Ignite.setPulseDistributor(PulseV2)` | Ignite |
| 4 | `step4IgniteRouter()` | Ignite owner | `Ignite.setSwapRouter(redirect)` | Ignite |
| 5 | `step5MarketRouter()` | TermMarket owner | `TermMarket.setSwapRouter(redirect)` | TermMarket |
| 6 | `step6ZeroEthFee()` | Ignite owner | `Ignite.setIgniteFeeEth(0)`. `igniteFee` (1e21) and all bps stay | Ignite |
| 7 | `step7MarketTreasury()` | TermMarket owner | `TermMarket.setTreasury(forwarder)` | TermMarket |
| 8 | `step8MarketFeeBps()` | TermMarket owner | `TermMarket.setFeeBps(0, burn, hopper + treasury)` = `(0, 100, 200)`. Total 3% and burn 1% unchanged. Refuses if the live bps differ from the forwarder's parts | TermMarket |
| - | `verifyState(false)` | none (read-only) | Checks steps 1-8: hooks, routers, fee 0 and 1e21, `pendingHopperTerm == 0`, `registeredCount == litCount`, market treasury == forwarder, `hopperBps == 0`, total 3%, owners, Ignite still disabled | None |
| 9 | `step9EnableIgnite()` | Ignite owner | `Ignite.setIgniteEnabled(true)`. **Separate final decision.** The script re-runs the checks and refuses if any fail | Ignite |

`dryRun()` simulates steps 1-8 plus the checks with a prank and no broadcast (verified against the live chain, no broadcast). It never runs step 9. Env: `PRIVATE_KEY`, `V1_HOPPER`, `V1_PULSE`, `COLLECTION`, `IGNITE`, `TERM_MARKET`, optional `MAX_SUPPLY`, `OWNER`. Later steps also need `PULSE_V2`, `HOPPER_V2`, `REDIRECT`, `FORWARDER` (printed by steps 1 and 1b).

Ordering: step 1, then 1b, then 2, then 3 to 8 (all while Ignite is paused; do 7 before 8). V1 Hopper, V1 Pulse, royalties, and `igniteFee` are never modified.

Rollback before step 9: set the router, hook, fee, treasury and bps back with the same owner setters. After step 9, ignited pets are one-way.

Keeper: once TermMarket is active, someone must call `forwarder.flushTerm(minEthOut)` now and then (owner or `setKeeper`). Until then `$TERM` simply waits in the forwarder.

## 7. Caveats

- Ignite's former ETH half is not recovered; royalties still land in V1 Hopper (section 4).
- The per-tx gas cap is verified: 32,000,000 (`ArbGasInfo.getMaxTxGasLimit()` on the Arbitrum Orbit chain, ArbOS 116). The block `gasLimit` field shows 0x4000000000000 and is not the cap.
- Swap price and gas were rehearsed on a mainnet fork (`test/fork/MainnetFork.t.sol`): real `ignite()` with 0 ETH ~499k gas, `pulse()` ~178k, a real claim 290k-480k gas per pet (real stock-token swaps).
- See `docs/AUDIT_INTERNAL.md` for the internal audit. It is not a substitute for an independent audit before holding real funds.
- Ownership handover is single-step Ownable. Verify the `OWNER` address before running step 1.
