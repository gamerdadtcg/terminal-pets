# Terminal Pets — Robinhood TESTNET MICRO smoke stack (900s lock)

**This is the SHORT-LOCK 900s MICRO stack — NOT the 7-day CollectionNFT `0xe1cC988CeC1C29764ba18523635De82d0C9B518F`.**

Addresses: [`deployments/robinhood-testnet-micro.json`](../deployments/robinhood-testnet-micro.json). The 7-day stack stays in [`RH_TESTNET_DEPLOY_ADDRESSES.md`](RH_TESTNET_DEPLOY_ADDRESSES.md) / [`deployments/robinhood-testnet.json`](../deployments/robinhood-testnet.json).

**Label:** SHORT-LOCK MICRO STACK — **not** the 7-day CollectionNFT (`0xe1cC988…518F`).

| Field | Value |
| --- | --- |
| chainId | **46630** only (never mainnet **4663**) |
| branch | `cursor/pulse-ladder-env-b870` (PR #13) |
| Deployer / Owner | `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37` |
| Treasury | `0x0c821a853711bF03C4C6b776CfD657f2ee97733e` |
| Balance before | `0.001694313990` ETH |
| Balance after | `0.001465849270` ETH |
| Result | **SUCCESS** — deploy + mint/reveal/deposit/ignite + pulse + claim |

## Micro params (verified)

| Param | Value |
| --- | --- |
| Hopper `payoutLock` | `900` (15m) |
| Ignite `igniteFeeEth` | `5e13` (0.00005 ETH) |
| Pulse bootstrap / first threshold | `1e14` (0.0001 ETH) |
| After pulse threshold / ladderIndex | `1.1e14` / `1` |

## Contracts

| Contract | Address |
| --- | --- |
| Hopper | `0x7329D15266c3fD8315779b5F5FF24C42CA005BAD` |
| RoyaltySplitter | `0x5a15Eba73d42dB76CCCF00dC62291D7eC3C5518C` |
| CollectionNFT | `0xA6aF17571a2CdB542C656E207e57d8b17A69CF27` |
| TermToken | `0x49Ecc4D6e36c4c3D6f4A218fb015231E4a7b5733` |
| TermFund | `0x54A54CBd96DEc065737f0d358D42196F1e7b1C7d` |
| TermMarket | `0x165d624e7Fec0f6a9dced06ff7CB7B89aC43e36c` |
| IgniteModule | `0x190C05B3733Dd94E14AD94296AF105FED47f7a8b` |
| PulseDistributor | `0x32B52DAFcC68cBB34202e67E402DD0A54EC8815C` |
| ERC6551Registry | `0xb5588164545ae5D5cf156Bebdb3E1beacb7bB8F2` |
| ReceivableAccount | `0x022f32c67a9cd722986f39aEF09B465790B65437` |

## Smoke path

| Step | Result | Tx |
| --- | --- | --- |
| setStockToken(0, AMZN) | ok (token1 ALPHA dials slot0) | `0x8ff45aa6…528f` |
| setStockToken(4, AMZN) | DuplicateStock skip | — |
| setStockToken(7, TSLA) | ok | `0xc2ee7b52…69fb` |
| teamMint(owner, 1) | ok | `0x1ed6131b…54ea` |
| reveal() | ok | `0x898ec9a2…c4a2` |
| Hopper deposit 0.0001 | ok | `0x53be1f66…84b9` |
| setShellClassOverride(1, ALPHA) | ok | `0x573cf4e2…4080` |
| ignite(1) @ 0.00005 | ok (Hopper avail 0.000125) | `0x196cac08…fe14` |
| Unlock | **12:32:11 PT** (`1789587131`) | — |
| pulse() | ok epoch 0 amount 0.000125 | `0xab876fed…c31a` |
| claim(1) | ok ETH payout 0.000125 | `0xcf2b392d…8fee` |

setMetadataURIs: **skipped** (optional; gas conserved).

## Notes

- Deploy used `--sender` + micro env overrides; forge broadcast succeeded in one run (~0.00019 ETH deploy cost).
- Severe RPC 429s during post-unlock; pulse landed (epochCount=1); this agent completed claim.
- Dial path: unrouted → `hopper.release` ETH (AMZN on slot0 for ALPHA token 1).
