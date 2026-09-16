# Robinhood testnet smoke (`cast call`)

Read-only checks after a **46630** deploy. No private keys. No `--broadcast`.

RPC alias `testnet` / `robinhood_testnet` is `https://rpc.testnet.chain.robinhood.com` (chain id **46630**). See [`docs/TESTNET_DEPLOY.md`](../docs/TESTNET_DEPLOY.md) for the ordered deploy checklist.

```bash
cast chain-id --rpc-url testnet
# expect 46630
```

Set addresses from `deployments/robinhood-testnet.json` or the forge console log (do not paste keys):

```bash
RPC=testnet
COLLECTION=0x
IGNITE=0x
HOPPER=0x
PULSE=0x
TERM=0x
SPLITTER=0x
```

## Collection / lifecycle

```bash
cast call "$COLLECTION" "revealed()(bool)" --rpc-url "$RPC"
cast call "$COLLECTION" "revealAfter()(uint64)" --rpc-url "$RPC"
cast call "$COLLECTION" "maxSupply()(uint256)" --rpc-url "$RPC"
cast call "$COLLECTION" "teamReserve()(uint256)" --rpc-url "$RPC"
cast call "$COLLECTION" "teamMinted()(uint256)" --rpc-url "$RPC"
cast call "$COLLECTION" "publicMinted()(uint256)" --rpc-url "$RPC"
cast call "$COLLECTION" "mintOpen()(bool)" --rpc-url "$RPC"
cast call "$COLLECTION" "hiddenURI()(string)" --rpc-url "$RPC"
cast call "$COLLECTION" "dormantBaseURI()(string)" --rpc-url "$RPC"
cast call "$COLLECTION" "litBaseURI()(string)" --rpc-url "$RPC"
cast call "$COLLECTION" "tokenURI(uint256)(string)" 1 --rpc-url "$RPC"
cast call "$COLLECTION" "isLit(uint256)(bool)" 1 --rpc-url "$RPC"
cast call "$COLLECTION" "isAllowedSeaDrop(address)(bool)" \
  0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 --rpc-url "$RPC"
```

Expect `maxSupply = 4444`, `teamReserve = 200`. Canonical SeaDrop should be **false** if you deployed with `SEADROP_ADDRESS=0x0`. After `setMetadataURIs(hidden.json, "", "")` and before `reveal()`, `tokenURI(1)` is `https://terminal-pets.vercel.app/metadata/hidden.json` for every token. The recorded 46630 7-day stack used hub `/metadata/lit/1.json` after Ignite; that JSON tree is no longer hosted.

## Ignite

```bash
cast call "$IGNITE" "igniteEnabled()(bool)" --rpc-url "$RPC"
cast call "$IGNITE" "igniteFeeEth()(uint256)" --rpc-url "$RPC"
cast call "$IGNITE" "igniteFee()(uint256)" --rpc-url "$RPC"
cast call "$IGNITE" "isLit(uint256)(bool)" 1 --rpc-url "$RPC"
cast call "$IGNITE" "litCount()(uint256)" --rpc-url "$RPC"
cast call "$IGNITE" "pendingHopperTerm()(uint256)" --rpc-url "$RPC"
cast call "$IGNITE" "pendingIgniteEthBurn()(uint256)" --rpc-url "$RPC"
```

`igniteFeeEth` is `2000000000000000` (0.002 ETH). With no swap router, pending Hopper `$TERM` and pending ETH burn-half after Ignite are expected.

## Dial (AMZN slot 4, TSLA slot 7 only)

```bash
cast call "$PULSE" "stockPool(uint256)(address)" 4 --rpc-url "$RPC"
cast call "$PULSE" "stockPool(uint256)(address)" 7 --rpc-url "$RPC"
cast call "$PULSE" "previewDial(uint256)" 1 --rpc-url "$RPC"
cast call "$PULSE" "getDial(uint256)" 1 --rpc-url "$RPC"
```

AMZN `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02`, TSLA `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E`. Do not invent other slot addresses. `getDial` is empty until the token is Lit.

## Hopper lock (7 days after reveal)

```bash
cast call "$HOPPER" "revealedAt()(uint64)" --rpc-url "$RPC"
cast call "$HOPPER" "hopperUnlockTime()(uint256)" --rpc-url "$RPC"
cast call "$HOPPER" "hopperUnlocked()(bool)" --rpc-url "$RPC"
cast call "$HOPPER" "available()(uint256)" --rpc-url "$RPC"
```

Until `hopperUnlockTime`, `hopperUnlocked()` is false. Pulse cannot run. `available()` may be non-zero from the Ignite ETH hopper half.

## `$TERM` / royalties

```bash
cast call "$TERM" "tradingEnabled()(bool)" --rpc-url "$RPC"
cast call "$SPLITTER" "live()(bool)" --rpc-url "$RPC"
```

Both flip true in `CollectionNFT.reveal()`.
