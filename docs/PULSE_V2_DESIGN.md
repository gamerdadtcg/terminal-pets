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

So **V1 Hopper keeps receiving**: royalties, Ignite's ETH half, and the TermMarket ETH skim. These cannot be redirected. Only the `$TERM`-derived slices can (via a replaceable swap router).

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

### HopperRedirectRouter (`src/HopperRedirectRouter.sol`), optional
Wraps Ignite's existing swap router. `$TERM` -> ETH swaps whose recipient is the V1 Hopper deliver to HopperV2 instead. Everything else passes through. Enabled with `REDIRECT_TERM_SLICES=true`.

## 4. Funding options

Where each fee currently goes, and what V2 can do:

| Fee path | Goes to | Redirectable? | V2 action |
|---|---|---|---|
| Ignite ETH half (0.001 ETH of 0.002) | V1 Hopper (hardwired) | No | none possible |
| Ignite 25% `$TERM` slice | swapped to ETH, V1 Hopper | Yes (`setSwapRouter`) | HopperRedirectRouter -> HopperV2 |
| TermMarket ETH-side skim | V1 Hopper (hardwired) | No (can set `setFeeBps` lower) | none, or lower bps |
| TermMarket `$TERM`-side skim | swapped, V1 Hopper | Yes (router) | redirect |
| Royalties (RoyaltySplitter, 2/3) | V1 Hopper (locked) | No | none |
| Old Pulse V1 | pays the 3 currently lit pets | n/a | keep as is |

Options for Ignite (currently paused; 3 lit, 0 epochs, V1 Hopper ~0.00317 ETH):

- **A. Re-enable at 0.002 ETH after migration.** Each Ignite sends 0.001 ETH to the V1 Hopper. V1 Pulse can only pay out while at most ~340 pets are lit (~2,100 if the V1 stockPool is zeroed). Past that, the V1 Hopper ETH is stranded. Not recommended.
- **B. Set `igniteFeeEth` to 0 (if the contract allows) and charge only `$TERM`.** Routes everything through redirectable paths, but it changes the Ignite economics, so it needs the owner's decision.
- **C. Zero V1's `stockPool`.** Raises V1's ceiling to ~2,100 pets but kills the Dial. Not recommended.
- **D. Keep Ignite paused** until the owner picks A/B/C. This is the current state and is safe.

Fee bps: set to zero on old paths where `setFeeBps` exists (Ignite, TermMarket) only with approval. It changes economics.

Old funds: the V1 Hopper keeps its ETH. V1 Pulse can still pay the 3 lit pets while lit stays under ~340. Royalties keep landing in the V1 Hopper.

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

## 6. Migration (`script/MigratePulseV2.s.sol`; **not executed**)

1. `deploy` (IgniteModule owner key): deploy HopperV2 + PulseDistributorV2, copy V1 stock pool, term, router, TBA config, shell overrides, lock the HopperV2 distributor, point Ignite's Dial hook at V2, optionally install the redirect router, hand ownership to `OWNER`. Does not touch Ignite's enabled flag, fee bps, or any V1 funds.
2. `register(pulseV2)` (any wallet): register every currently lit pet, in batches of 100.
3. Owner decision on Ignite re-enable (section 4).

`dryRun` simulates step 1 with no broadcast. Env: `PRIVATE_KEY`, `V1_HOPPER`, `V1_PULSE`, `COLLECTION`, `IGNITE`, optional `MAX_SUPPLY`, `OWNER`, `REDIRECT_TERM_SLICES`.

## 7. Caveats

- Ignite's ETH half and royalties still land in V1 Hopper (section 2).
- The per-tx gas cap was assumed, not verified on-chain.
- Swap gas is mocked; a live fork run is recommended before mainnet.
- Needs an independent audit before holding real funds: the contracts are new.
- Ownership handover is single-step Ownable. Verify the `OWNER` address before running.
- Pausing HopperV2 blocks both pulse reservation and payouts.
