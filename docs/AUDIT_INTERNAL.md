# Internal audit: Pulse V2 + TermMarket fee fix (PR #43)

Scope: `PulseDistributorV2`, `HopperV2`, `HopperRedirectRouter`, `TermMarketFeeForwarder`, `RoyaltySplitterV2`, `script/MigratePulseV2.s.sol`.
Not in scope: the live V1 contracts (unchanged), the external DEX adapter `0xDe6d…`, the stock tokens.
This is an internal review by the author's tooling, **not** an independent audit. Nothing has been broadcast or deployed; all chain access was read-only (fork / `eth_call`).

## Method

1. Manual review of every function (reentrancy, access control, accounting and rounding, DoS, swap and slippage, MEV, timelock, ownership).
2. Slither 0.11 over `src/` (134 raw results, 53 in the in-scope contracts, all triaged below).
3. Foundry unit, fuzz and stateful invariant tests (`test/PulseV2.t.sol`, `test/PulseV2Invariant.t.sol`, `test/TermMarketFeeForwarder.t.sol`, `test/MigratePulseV2.t.sol`, `test/PulseV2Gas.t.sol`).
4. Mainnet-fork rehearsal against the live Robinhood Chain (4663) contracts (`test/fork/MainnetFork.t.sol`) and a `forge script dryRun()` simulation against the live RPC. Owner impersonated locally; no transaction sent.

## Findings

| ID | Severity | Title | Status |
|---|---|---|---|
| F-01 | High | TermMarket ETH skim (and `$TERM` skim) hard-wired to the V1 Hopper | **Fixed** (forwarder + steps 7, 8) |
| F-02 | High | A failing 250 TERM swap reverts every `ignite()` (cheap DoS on a tiny pool) | **Fixed** (Ignite-only soft-fail in `HopperRedirectRouter`) |
| F-03 | Medium | Forwarder would re-split its own swap proceeds | **Fixed** (`_swapping` flag), regression test |
| F-04 | Medium | Public `flushTerm` could be sandwiched with `minOut = 0` | **Fixed** (keeper/owner only + `minEthOut` balance-delta check) |
| F-05 | Low | ETH force-sent to the forwarder would be stuck | **Fixed** (`sync()`) |
| F-06 | Low | `HopperRedirectRouter` could send ETH to `address(0)` | **Fixed** (`ZeroAddress`) |
| F-07 | Medium | Owner can pause and withdraw Hopper ETH after 7 days; claims are blocked while paused | **Accepted** (owner decision, see below) |
| F-08 | Low | After a soft-failed swap the 250 TERM stays in Ignite as extra allotment | Accepted |
| F-09 | Low | Third-party `claimMany` with low gas can push a pet's stock-token leg to the plain-ETH fallback | Accepted |
| F-10 | Low | Single-step `Ownable` on HopperV2, PulseV2, forwarder | Accepted (verify `OWNER`) |
| F-11 | High (economic, not a bug) | Pool is so thin that Option B funds the Hopper with micro-ETH | **Open, owner decision** |
| F-12 | Medium (economic) | V1 Hopper keeps receiving royalties; unreachable beyond ~340 lit pets | **Mitigated** for OpenSea by RoyaltySplitterV2 + Studio payout (addendum); on-chain receiver still locked, optional step 10 |
| F-13 | Info | TermMarket is inactive and the V2 pair cannot call `onSwap` | Open, needs a pool/hook |
| F-14 | Info | Slither noise (reentrancy, arbitrary-send, unused-return, ...) | Triaged, no action |

### F-01 TermMarket fees land in the V1 Hopper (fixed)
`TermMarket._routeEth` calls `hopper.deposit` on an immutable V1 Hopper, and `_routeTerm` swaps to that same address. Only the router and treasury are owner-settable. Fix: `setFeeBps(0, burn, hopper+treasury)` and `setTreasury(TermMarketFeeForwarder)`. The forwarder splits 150/200 to HopperV2 and 50/200 to the real treasury. Total 3% and burn 1% are unchanged. Tests: `test_B_marketFees_afterSteps7and8_totalAndBurnPreserved_hopperGoesToV2`, `test_B_marketTermSkim_toForwarder_thenKeeperFlushFundsHopperV2`, fork test (ETH trade: 0.0075 ETH to HopperV2, 0.0025 ETH to treasury, V1 Hopper delta 0), fuzz conservation tests.

### F-02 Ignite DoS via swap failure (fixed)
`IgniteModule._swapTermToHopper` reverts `SwapFailed` if the router reverts. Anyone able to move the pool beyond the adapter's quote or slippage could revert every `ignite()`. `HopperRedirectRouter` now catches the inner failure and, only for its configured soft-fail caller (Ignite), returns the TERM and 0. Any other caller still reverts. Tests: `test_igniteSwapFailure_returnsTermAndZero`, `test_nonIgniteSwapFailure_reverts`, `test_noFundsStuck_afterAnyPath`.

### F-03, F-04, F-05, F-06
See the forwarder tests: `test_flushTerm_swapProceedsNotDoubleSplit`, `test_flushTerm_slippageRevertsAndKeepsTerm`, `test_flushTerm_ownerAllowed_strangerNot`, `test_sync_deliversForcedEth`, `test_zeroRecipient_reverts`.

### F-07 Emergency withdraw (accepted, owner decision)
`HopperV2`: owner `pause()` then `proposeEmergencyWithdraw(to, amount)`, 7-day delay, `executeEmergencyWithdraw()`. `unpause()` cancels. The timelock is correct (`readyAt = now + 7d`, executes only while still paused, `amount <= balance`, `reserved` is clamped to what remains; fuzzed in the invariant suite: it never executes early). Two honest caveats:
- This is an owner trust assumption: the owner can take reserved ETH. Use a multisig owner.
- While paused, `reserve` and `release` revert, so pets cannot claim during the 7-day window. A holder cannot "exit" in the notice period. If you want that guarantee, `release` could be allowed while paused (pause would then only stop new pulses). Not changed: you asked for "pause blocks payouts" as the incident-response behavior.

### F-08 / F-09 / F-10
- F-08: the 250 TERM that fails to swap stays on Ignite and becomes allotment for later igniters (not lost, not stealable by a third party). Its only cost is the Hopper's 3.6e-6 ETH.
- F-09: `try router.swapExactETHForToken` falls back to plain ETH on any failure including out-of-gas of the callee. A keeper batching other holders' pets with little gas can turn a stock leg into ETH. Value is preserved and delivered to the owner. The pet's own `claim` is unaffected.
- F-10: `transferOwnership` is single step. The script reads `OWNER` from env and `verifyState` checks the owners, but a wrong address is final. Double-check it before step 1 and 1b.

### F-11 Thin pool (open)
Live read-only: pool 0.010396 ETH / 712,452 TERM. Fork: 250 TERM sells for 3,635,866,570,269 wei (3.6e-6 ETH), 0.07% price impact; a second 250 TERM sells for 3,633,320,524,883 wei. At about 3.6e-6 ETH per Ignite, 4,441 more Ignites would raise about 0.016 ETH, and the pulse threshold is 0.1 ETH. Funding the Hopper now depends on manual deposits (`HopperV2` accepts plain ETH), a deeper pool, or royalties (which go to V1).

### F-12 Royalties (open)
Verified on mainnet and in source: `RoyaltySplitter.hopper` is immutable with no setter; `CollectionNFT.royaltyReceiver` is immutable and `setRoyaltyInfo` reverts `RoyaltyReceiverLocked`. The only lever is `setRoyaltyBps` (reduce or zero, which is an economics change and does not redirect). V1 Hopper ETH (0.0031665 ETH today) can only leave through V1 Pulse.

### F-13 TermMarket inactive (open)
`canonicalPool` and `swapRouter` are zero. The fork test impersonates a canonical pool to exercise the fee routing with the real router, treasury and `$TERM`. Before activation a pool or hook that calls `onSwap` is needed, and a keeper must call `forwarder.flushTerm`.

### F-14 Slither triage (in-scope contracts)
| Detector | Count | Verdict |
|---|---|---|
| reentrancy-eth (High) `_payout`, forwarder `_flush` | 3 | False positive for loss of funds. `claimedThrough` is written before any external call; `claim*` and `withdrawCredit` are `nonReentrant`; `creditOf` after the call is only readable via nonReentrant `withdrawCredit`. In `_flush` the owed amounts are zeroed before the call and restored on failure; a re-entrant `receive()` only adds new ETH. Conservation is tested with a re-entering recipient. |
| arbitrary-send-eth (High) | 2 | Intended: payout to the pet's owner/TBA, router swap with the claim's own ETH. |
| reentrancy-no-eth (Medium) `pulse()` | 1 | `hopper.reserve` is a trusted contract and `pulse` is `nonReentrant`. |
| divide-before-multiply | 1 | Intended: `share = avail / lit; amount = share * lit` leaves dust in the Hopper. |
| uninitialized-local | 2 | `paid` and `ethOut` start at 0 by design. |
| unused-return | 6 | `ownerOf` as an existence check; router return values are not trusted (balances are measured). |
| calls-loop, reentrancy-events, low-level-calls, costly-loop | 27 | Intended for batch claims. |
| return-bomb | 2 | Gas-capped calls whose returndata is not copied. Tested with a 200 KB returndata recipient (`test_returnBomb_doesNotInflateForwarderGas`). |
| missing-zero-check | 4 | `setKeeper(0)` disables the keeper (intended); TBA implementation is optional; router `dest` fixed in F-06. |
| timestamp | 2 | Day-scale timelocks only. |
| other informational | 3 | No action. |

## Test evidence

- Full suite: all tests pass (see the PR for the exact count), including stateful invariants (256 runs x 500 calls each) over a random mix of ignite, fund, pulse, claim, double-claim, pause, and emergency withdraw:
  - `reserved <= balance`
  - total claimable (sum of `pending`) `== hopper.reserved()` exactly
  - pulsed amount `== reserved + paid out`
  - no double claim
  - pause blocks pulse and every payout
  - emergency withdraw never executes before the delay
  - claim cursors never pass `epochCount`, `registeredCount <= litCount`, PulseV2 holds only credits.
  Mutation check: changing `cumShare[id+1] = cumShare[id] + share` to `+ share + 1` makes the invariant suite fail.
- Forwarder and router: split exactness (fuzz), rejecting and gas-bomb recipients, return-bomb, re-entry, keeper-only, slippage revert atomicity, router failing, dust, forced ETH.
- Gas at 4,444 pets: every batch under 15M (see design doc), well under the verified 32M per-tx cap.

## Mainnet fork results (block 99,302,024, nothing broadcast)

- Migration steps 1, 1b, 2-8 run as the owner `0xA71c…dC37` against the live contracts: `verify()` passes with Ignite still paused; step 9 then `verify(…, true)` passes.
- Real `ignite()` with `msg.value == 0` (allotment escrow): ~498.7k gas. 625 TERM leave Ignite (375 burn + 250 swapped); 3,635,866,570,269 wei land in HopperV2; V1 Hopper balance unchanged; the pet is registered in PulseV2.
- Simulated canonical pool trade through the real TermMarket: ETH side 0.5 ETH trade, 1.5% fee 0.015 ETH: 0.005 burn, 0.0075 to HopperV2, 0.0025 to the real treasury; V1 Hopper delta 0. TERM side: forwarder holds 2,000 TERM; `flushTerm` swaps 75% through the real router into HopperV2.
- `pulse()` ~178k gas. Claims through the real stock-token router for all 4 lit pets: 292k-483k gas each, every owner received tokens, `reserved` returns to 0.
- Sandwich: attacker dumping 200k TERM (28% of the pool) before the swap cuts the victim's 250 TERM output from 3,630,777,154,233 to 2,215,863,842,367 wei (loss 1.4e-6 ETH), but the attacker loses about 840 TERM on the round trip. Not profitable.
- `forge script dryRun()` against the live RPC: ok (simulation only).

## Residual risks (what this review cannot rule out)

1. Not an independent audit; the contracts are new and hold ETH.
2. The external DEX adapter and stock tokens are trusted. A malicious or buggy adapter could keep ETH sent to it. V2 measures balances rather than trusting return values and never reverts a claim on a failed swap.
3. Owner key or multisig compromise: can pause, withdraw after 7 days, change routers and keeper (F-07).
4. Funding is economically small with this pool (F-11), and the V1 Hopper stays stranded (F-12).
5. TermMarket integration is simulated (F-13). The first real trade through whatever pool is chosen should be checked.
6. Reorg and chain-specific behavior of Arbitrum Orbit are covered only by the fork run.

---

# Addendum: RoyaltySplitterV2 and migration steps 1c / 10

Scope: `src/RoyaltySplitterV2.sol` (new, no owner), migration steps 1c (deploy) and 10 (optional `setRoyaltyBps(0)`), `verifyRoyalty`.
Evidence: `test/RoyaltySplitterV2.t.sol` (30 tests incl. fuzz, 4 stateful invariants at 256 runs x 500 calls), `test/MigratePulseV2.t.sol` (5 new `test_R_*`), `test/fork/RoyaltyFork.t.sol` (5 fork tests with real Seaport 1.6 sales).

## Findings

| ID | Severity | Title | Status |
|---|---|---|---|
| R-01 | Info | Contract has no owner, pause, withdraw or setter for Hopper/WETH | By design, tested (selectors absent) |
| R-02 | Low | `treasury` is mutable by the treasury itself: a compromised treasury key can redirect its own 1/3 | Accepted. It is the same key that receives that 1/3 anyway; the Hopper 2/3 is immutable |
| R-03 | Low | Splitter does not push from `receive()`, so someone must call `distribute()` / `unwrapWeth()` | Accepted (needed for 2300-gas receive). Permissionless; funds accumulate safely |
| R-04 | Low | Non-WETH ERC20 royalties go 100% to the treasury, NFTs sent in are unrecoverable | Accepted, documented |
| R-05 | Info | Failure handling used assignment (`= h2`) instead of `+=` when restoring owed amounts | Hardened to `+=` (cannot differ today because `_distribute` is `nonReentrant`) |
| R-06 | Medium (economic / process) | OpenSea creator earnings on a non-ERC-721C contract are optional; unclear if OpenSea prefers the Studio value over `royaltyInfo` after step 10 | Open. Check with a test listing; step 10 is optional and reversible |
| R-07 | Info | Hopper royalty ETH is subject to HopperV2 owner pause / 7-day emergency withdraw | Accepted (F-07) |
| R-08 | Info | Slither noise (arbitrary-send-eth, reentrancy-eth, return-bomb, low-level-calls) | Triaged below |

No Critical or High finding. No fund-loss path found in the contract.

## Manual review notes
- **Reentrancy:** `distribute`, `unwrapWeth`, `sweepToken` are `nonReentrant`. Owed amounts are zeroed before each push and restored on failure. `receive()` is unguarded on purpose; it only emits an event, and accounting is `balance - owed`, so ETH sent back during a callback is simply counted in the next batch (tested). Re-entering `distribute` / `unwrapWeth` from the treasury callback is blocked (tested).
- **2300 gas receive:** one LOG1, no SSTORE. Tested with `transfer`, `send`, and a `gas: 0` value call (exact stipend); also verified against the real WETH `withdraw` and a real Seaport sale on the fork.
- **Accounting / rounding:** `hopper = floor(x * 2 / 3)`, treasury gets `x - hopper` so no wei is stranded. Fuzzed: Hopper plus treasury equals input exactly; Hopper within 1 wei per batch of 2/3. Invariants: funds conserved (Hopper + treasury + splitter ETH + unwrapped WETH == input), owed backed by balance, Hopper total within rounding of 2/3, nothing stuck once recipients are healthy.
- **DoS:** a reverting treasury, reverting Hopper, gas-bomb (1e6-iteration loop) and 200 KB return-bomb each only strand their own share, and gas is bounded (< 350k / < 450k). A permanently rejecting treasury contract can still call `setTreasury` (tested).
- **Forced ETH:** counted as pending and split.
- **HopperV2 accounting:** the plain ETH push emits `Deposited(splitter, amount)`; balance-based `available()` rises by exactly the Hopper share. Not blocked by `pause`.
- **WETH:** `withdraw` via the canonical proxy at `0x0Bd7…AD73` works into `receive()` (fork). A donor sending WETH or ETH simply adds to the split. `sweepToken(WETH)` reverts so WETH can't be diverted around the split.
- **Seaport:** consideration items pay ETH with a plain call and WETH with `transferFrom`; both verified on the fork with real Seaport 1.6 (`0x0000…B395`) and the real token (pre-validated order, no signature).
- **Migration:** step 1c refuses a WETH address with no code and copies the treasury from the live V1 RoyaltySplitter, so the 1/3 goes to the same address as today. Step 10 refuses to run unless `verifyRoyalty(false)` passes and is `onlyOwner` on CollectionNFT.

## Slither (RoyaltySplitterV2, 5 results)
| Detector | Verdict |
|---|---|
| arbitrary-send-eth (`treasury.call`) | Intended. `treasury` is the treasury's own address, changeable only by itself |
| reentrancy-eth (2) in `_distribute` | False positive. Owed is zeroed before the call and restored on failure; every writer is `nonReentrant`; `receive()` never touches owed |
| return-bomb | Gas-capped calls, returndata not copied; tested with 200 KB returndata |
| low-level-calls | Intended |

## Fork results (live Robinhood Chain fork, nothing broadcast)
Full stack (steps 1, 1b, 1c, 2-8) deployed as the owner, then:
- **Real Seaport sale, ETH-priced** (3 ETH, 7.5% creator item to the splitter): Seaport paid 0.225 ETH into the splitter; `receive()` pushed nothing; `distribute()` sent 0.15 ETH to HopperV2 and 0.075 ETH to the real treasury `0x0c82…`; V1 Hopper delta 0.
- **Real Seaport sale, WETH-priced**: 0.225 WETH landed in the splitter; `unwrapWeth()` through the real WETH proxy split it the same way; no WETH or ETH left.
- **Whole chain:** a 10 ETH sale gives 0.75 ETH royalties and 0.5 ETH to HopperV2 (`available()` exact), the 0.1 ETH pulse threshold is crossed, step 10 sets on-chain `royaltyInfo` to 0 without affecting the splitter, `pulse()` and real claims for all lit pets with the real routers pay out and leave only 2 wei of dust, `reserved` back to 0.
- Real WETH `deposit` -> transfer -> `unwrapWeth` -> split: exact.

## Residual risks (addendum)
1. OpenSea behavior is partly outside the chain: optional earnings (R-06), which address OpenSea uses after step 10, and whether OpenSea accepts a contract payout address (Seaport pays it either way). Confirm with a small real listing and sale before relying on it.
2. Splitter funds reach HopperV2 only after a `distribute()` / `unwrapWeth()` call (R-03). Suggest a keeper or a small routine.
3. Treasury key risk (R-02), and Hopper owner pause/withdraw (R-07).
4. Royalty volume is unknown and may be tiny; this does not replace funding the Hopper (F-11).
5. Internal review only, not an independent audit.
