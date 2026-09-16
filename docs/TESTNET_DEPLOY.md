# Robinhood Chain testnet deploy plan (46630)

Prep and mechanics smoke on **Robinhood Chain testnet**. This is not a live collection launch.

**Do not broadcast to mainnet `4663` from this document.** `script/Deploy.s.sol` does not check chain id; the RPC you pass is the network you hit. Use `--rpc-url testnet` / `--rpc-url robinhood_testnet` only.

**Studio Drop is separate.** Canonical SeaDrop 1.0 (`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`) is **not** listed on Robinhood testnet. RH testnet is for Ignite / Dial / `tokenURI` / Hopper-lock smoke, not an OpenSea Studio Drop. See [`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md).

This file is a checklist. **This repo does not broadcast from CI or from this plan.**

## Network

| | Mainnet (do not use here) | Testnet (this plan) |
| --- | --- | --- |
| Chain ID | `4663` | `46630` |
| RPC | `https://rpc.mainnet.chain.robinhood.com` | `https://rpc.testnet.chain.robinhood.com` |
| Explorer | `https://robinhoodchain.blockscout.com` | `https://explorer.testnet.chain.robinhood.com` |
| Blockscout API | `https://robinhoodchain.blockscout.com/api` | `https://explorer.testnet.chain.robinhood.com/api/` |
| Faucet | — | `https://faucet.testnet.chain.robinhood.com` |
| Foundry RPC alias | `robinhood` | `testnet` or `robinhood_testnet` |

Gas token is ETH on both. `CollectionConfig.CHAIN_ID` stays `4663` (mainnet constant). It is not a deploy-time gate.

## 1. Prerequisites

1. **Throwaway deployer key.** Use a key you are willing to leak on a public testnet. Never reuse a mainnet or funded-production key. Put it only in a local `.env` (gitignored).
2. **Faucet ETH** on `46630` from [the testnet faucet](https://faucet.testnet.chain.robinhood.com). Deploy + `teamMint` + `reveal` + one Ignite (`0.002 ETH`) needs a small amount; keep extra for verify txs and mistakes.
3. **`TREASURY_ADDRESS`.** Must accept ETH (EOA or a contract with `receive`). Same role as mainnet: 2.5% post-reveal royalties + TermFund `$TERM` source / LP recipient. Can be the throwaway deployer or a second throwaway wallet.
4. Copy env: `cp .env.example .env` and fill the testnet block below. Do not point `ROBINHOOD_RPC_URL` at testnet; that alias is mainnet.

## 2. Env vars (testnet)

Required for `script/Deploy.s.sol`:

| Var | Testnet value |
| --- | --- |
| `PRIVATE_KEY` | Throwaway hex key (no `0x` prefix or with — Foundry accepts both) |
| `TREASURY_ADDRESS` | Wallet that can receive ETH |
| `ROBINHOOD_TESTNET_RPC_URL` | `https://rpc.testnet.chain.robinhood.com` |

Recommended:

| Var | Why |
| --- | --- |
| `SEADROP_ADDRESS=0x0000000000000000000000000000000000000000` | Authorizes **no** SeaDrop. Canonical 1.0 is not listed on RH testnet. Unset would default to `CollectionConfig.SEADROP` and whitelist an address that is not a Studio Drop on this chain. |
| `MINT_OPEN=false` | Keep dapp mint closed; smoke uses `teamMint`. |
| `OWNER` | Defaults to the deployer. Leave blank unless a different owner EOA should own the stack. |

Leave DEX adapters blank (`TERM_LP_ROUTER`, `TERM_POOL`, `TERM_SWAP_ROUTER`, `PULSE_ROUTER`). Testnet smoke does not need a live pool. Ignite will park the `$TERM` Hopper cut and the ETH burn-half until a router exists — that is expected.

Leave stock tokens unset at deploy. Owner `setStockToken` after, using only the [documented AMZN + TSLA samples](DIAL.md). **Do not invent** HOOD / AAPL / MSFT / GOOGL / META / NVDA addresses.

`CollectionConfig` defaults still apply: free mint **4444** total, **200** team reserve / **4244** public, Ignite **0.002 ETH** + **1,000 `$TERM`**, Hopper lock **7 days after `reveal()`**.

## 3. Dry-run (no `--broadcast`)

Simulates `Deploy.s.sol` against testnet RPC. Does **not** send transactions. Still reads `PRIVATE_KEY` (Foundry signs the simulated txs).

```bash
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url testnet
```

Equivalent alias:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url robinhood_testnet
```

Confirm the simulated chain id is **46630**, `TREASURY_ADDRESS` is yours, `SeaDrop` logs as `0x0000…0000` if you zeroed it, and the console prints Hopper / CollectionNFT / Ignite / Pulse addresses. **Stop here until you intend to deploy to testnet.**

Wrong RPC (`robinhood` / mainnet URL) would simulate **4663**. Abort if `cast chain-id --rpc-url testnet` is not `46630`:

```bash
cast chain-id --rpc-url testnet
# expect 46630
```

## 4. Broadcast to testnet only

**Do not add `--rpc-url robinhood`. Do not use chain `4663`.**

```bash
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url testnet --broadcast
```

Optional verify-on-deploy (Blockscout; API key often unused):

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url testnet \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://explorer.testnet.chain.robinhood.com/api/ \
  --chain 46630
```

Copy the console-logged addresses into `deployments/robinhood-testnet.json` (shape below). Foundry also writes `broadcast/Deploy.s.sol/46630/`.

## 5. Post-deploy smoke (owner txs)

Replace `$COLLECTION`, `$PULSE`, `$IGNITE`, `$HOPPER`, `$TREASURY` from the deploy logs. Hub test metadata covers tokens **1–25** only.

Read-only `cast call` examples (no keys): [`script/smoke-testnet.md`](../script/smoke-testnet.md).

### 5.1 `setMetadataURIs` (hub HTTPS)

```bash
cast send "$COLLECTION" \
  "setMetadataURIs(string,string,string)" \
  "https://terminal-pets.vercel.app/metadata/hidden.json" \
  "https://terminal-pets.vercel.app/metadata/dormant/" \
  "https://terminal-pets.vercel.app/metadata/lit/" \
  --rpc-url testnet
```

Trailing `/` on the bases appends `{tokenId}.json`.

### 5.2 `setStockToken` — AMZN + TSLA only

Slots from [`docs/DIAL.md`](DIAL.md). **Do not invent other addresses.**

| Slot | Symbol | Testnet ERC-20 |
| --- | --- | --- |
| 4 | AMZN | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` |
| 7 | TSLA | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` |

```bash
cast send "$PULSE" "setStockToken(uint8,address)" 4 0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02 --rpc-url testnet
cast send "$PULSE" "setStockToken(uint8,address)" 7 0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E --rpc-url testnet
```

Leave slots 0–3 and 5–6 at `address(0)`.

### 5.3 `teamMint` a small qty

Do **not** mint the full 200 reserve for smoke. One or two tokens is enough (ids start at `1`).

```bash
cast send "$COLLECTION" "teamMint(address,uint256)" "$TREASURY" 2 --rpc-url testnet
```

Public cap is still 4244; team mint does not consume it. Leave `mintOpen` false.

### 5.4 `reveal`

Owner may call immediately (24h delay is for *anyone else*).

```bash
cast send "$COLLECTION" "reveal()" --rpc-url testnet
```

This enables Ignite, `$TERM` transfers, dormant-egg metadata, and the 5/2.5 royalty split. It also **starts** the Hopper 7-day payout lock (`hopperUnlockTime = revealedAt + 7 days`).

### 5.5 Ignite one token

Exact **0.002 ETH**. First wake spends the `$TERM` allotment on IgniteModule (no DEX required). Without `TERM_SWAP_ROUTER`, 25% `$TERM` parks as `pendingHopperTerm` and 50% of the ETH parks as `pendingIgniteEthBurn`. Hopper still receives **50% of the 0.002 ETH**.

Minted token must be owned by the sender (`$TREASURY` if you team-minted there).

```bash
cast send "$IGNITE" "ignite(uint256)" 1 --value 0.002ether --rpc-url testnet
```

### 5.6 Verify `tokenURI` + Dial

```bash
cast call "$COLLECTION" "tokenURI(uint256)(string)" 1 --rpc-url testnet
cast call "$COLLECTION" "isLit(uint256)(bool)" 1 --rpc-url testnet
cast call "$PULSE" "getDial(uint256)" 1 --rpc-url testnet
```

Expect Lit `tokenURI` → `https://terminal-pets.vercel.app/metadata/lit/1.json`. Dial `nLegs` is 1–4 by shell class. Assigned slots may still be `address(0)` if the keccak draw hit an unset pool index — that is correct; only AMZN/TSLA are wired. `previewDial` matches `getDial` (holders cannot pick).

### 5.7 Hopper lock

```bash
cast call "$HOPPER" "hopperUnlockTime()(uint256)" --rpc-url testnet
cast call "$HOPPER" "hopperUnlocked()(bool)" --rpc-url testnet
```

`hopperUnlocked()` must be **false** until seven days after reveal. Pulse / `reserve` / `release` stay locked. Ignite deposits during that week still accrue. Do not wait this out for smoke; just confirm the timestamp is `revealedAt + 604800`.

## 6. Verify on Blockscout (46630)

`foundry.toml` `[etherscan.robinhood_testnet]` points at the testnet Blockscout API with `chain = 46630`. If the alias is ignored, pass flags explicitly:

```bash
forge verify-contract \
  --chain 46630 \
  --rpc-url testnet \
  --verifier blockscout \
  --verifier-url https://explorer.testnet.chain.robinhood.com/api/ \
  --watch \
  <ADDRESS> \
  src/CollectionNFT.sol:CollectionNFT
```

Repeat for Hopper, RoyaltySplitter, IgniteModule, PulseDistributor, TermToken, TermFund, TermMarket as needed.

Notes:

- Compiler settings must match `foundry.toml`: solc `0.8.24`, optimizer 200 runs, `via_ir = true`, `evm_version = "cancun"`.
- Constructor args: copy from `broadcast/Deploy.s.sol/46630/run-latest.json` (`arguments` / ABI-encoded `constructorArguments`). CollectionNFT’s last arg is `address[] allowedSeaDrop` (empty if you zeroed SeaDrop).
- Blockscout often does not need a real API key. Empty `BLOCKSCOUT_API_KEY` or a dummy `x` is typical. Do not use a mainnet Etherscan key against this URL.
- `--etherscan` / Sourcify will not verify this chain. Use `--verifier blockscout`.
- Manual UI: [testnet explorer](https://explorer.testnet.chain.robinhood.com) → contract → Verify & publish.

## 7. Record addresses

`deployments/` is gitignored except `.gitkeep` (Foundry also has write permission there). After a real testnet broadcast, write **`deployments/robinhood-testnet.json`** locally (do not commit secrets):

```json
{
  "network": "robinhood-testnet",
  "chainId": 46630,
  "rpc": "https://rpc.testnet.chain.robinhood.com",
  "explorer": "https://explorer.testnet.chain.robinhood.com",
  "broadcast": "broadcast/Deploy.s.sol/46630/run-latest.json",
  "Hopper": "",
  "RoyaltySplitter": "",
  "Treasury": "",
  "TermToken": "",
  "TermFund": "",
  "TermMarket": "",
  "CollectionNFT": "",
  "IgniteModule": "",
  "PulseDistributor": "",
  "TbaRegistry": "",
  "TbaImplementation": "",
  "Owner": "",
  "SeaDrop": "0x0000000000000000000000000000000000000000",
  "stockPool": {
    "4_AMZN": "0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02",
    "7_TSLA": "0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E"
  },
  "metadata": {
    "hiddenURI": "https://terminal-pets.vercel.app/metadata/hidden.json",
    "dormantBaseURI": "https://terminal-pets.vercel.app/metadata/dormant/",
    "litBaseURI": "https://terminal-pets.vercel.app/metadata/lit/"
  }
}
```

Do not invent a `deployments/robinhood-mainnet.json` from this plan.

## Explicit do-nots

- **Do not broadcast to `4663`.** No `--rpc-url robinhood`, no mainnet RPC, no `--chain 4663` on these commands.
- **Do not treat this as Studio Drop.** SeaDrop may be absent on RH testnet. Canonical `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the OpenSea CREATE2 address on listed chains, not a RH-testnet fact. Studio Drop QA belongs on a chain Studio actually supports ([`OPENSEA_STUDIO_SEADROP.md`](OPENSEA_STUDIO_SEADROP.md) § Testnet).
- **Do not invent stock-token or SeaDrop addresses.** AMZN/TSLA samples above are the only testnet Dial fills in this repo.
- **Do not `teamMint(200)`** just to smoke; **do not** open public mint unless you mean to.
- **Do not** put private keys in git, PR comments, or this markdown.

## References

- `script/Deploy.s.sol` — deploy script (`PRIVATE_KEY`, `TREASURY_ADDRESS`, optional `SEADROP_ADDRESS`)
- `script/smoke-testnet.md` — read-only `cast call` cheatsheet
- `docs/DIAL.md` — Dial slots and testnet AMZN/TSLA
- `docs/OPENSEA_STUDIO_SEADROP.md` — Studio Drop (not this network)
- `docs/MAIN_ART_LOCK.md` — metadata URI rules
