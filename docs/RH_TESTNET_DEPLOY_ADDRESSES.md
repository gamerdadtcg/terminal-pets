# Terminal Pets — Robinhood Chain TESTNET Deploy

This file is the **7-day** Hopper-lock stack (CollectionNFT `0xe1cC988CeC1C29764ba18523635De82d0C9B518F`). SHORT-LOCK 900s MICRO pulse/claim smoke: [`RH_TESTNET_MICRO_SMOKE.md`](RH_TESTNET_MICRO_SMOKE.md) / [`deployments/robinhood-testnet-micro.json`](../deployments/robinhood-testnet-micro.json).

- **chainId:** `46630` (testnet only; never mainnet `4663`)
- **RPC:** `https://rpc.testnet.chain.robinhood.com`
- **Explorer:** https://explorer.testnet.chain.robinhood.com
- **Deployer / Owner:** `0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37`
- **Treasury:** `0x0c821a853711bF03C4C6b776CfD657f2ee97733e`
- **SeaDrop:** `address(0)` (empty allowlist)
- **Balance before:** `0.010000000000000000` ETH
- **Balance after:** `0.007800643620000000` ETH

## Contracts

| Contract | Address | Explorer |
| --- | --- | --- |
| CollectionNFT | `0xe1cC988CeC1C29764ba18523635De82d0C9B518F` | [link](https://explorer.testnet.chain.robinhood.com/address/0xe1cC988CeC1C29764ba18523635De82d0C9B518F) |
| IgniteModule | `0x0C25076F1bF9f6187ed3b7D890F480a92837636F` | [link](https://explorer.testnet.chain.robinhood.com/address/0x0C25076F1bF9f6187ed3b7D890F480a92837636F) |
| PulseDistributor | `0xb8d8d9363a64dfD433E006bE43c2B150370Fc274` | [link](https://explorer.testnet.chain.robinhood.com/address/0xb8d8d9363a64dfD433E006bE43c2B150370Fc274) |
| Hopper | `0xD99319e6dd9A92DDb3D5D3991e5b99AD7C76a284` | [link](https://explorer.testnet.chain.robinhood.com/address/0xD99319e6dd9A92DDb3D5D3991e5b99AD7C76a284) |
| RoyaltySplitter | `0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2` | [link](https://explorer.testnet.chain.robinhood.com/address/0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2) |
| TermToken | `0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166` | [link](https://explorer.testnet.chain.robinhood.com/address/0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166) |
| TermFund | `0x6f5A98D16005e10be0733A3b5576B3059559afa8` | [link](https://explorer.testnet.chain.robinhood.com/address/0x6f5A98D16005e10be0733A3b5576B3059559afa8) |
| TermMarket | `0x44400280e8A2D5b6B403b6a2864E44A0f643441B` | [link](https://explorer.testnet.chain.robinhood.com/address/0x44400280e8A2D5b6B403b6a2864E44A0f643441B) |
| ERC6551Registry | `0x2fCDa1e47De01c4ACD3f2926BDD6128b4e93d1Cc` | [link](https://explorer.testnet.chain.robinhood.com/address/0x2fCDa1e47De01c4ACD3f2926BDD6128b4e93d1Cc) |
| ReceivableAccount | `0x3992160500FB69e88227436020B6600be1CeF023` | [link](https://explorer.testnet.chain.robinhood.com/address/0x3992160500FB69e88227436020B6600be1CeF023) |

## Deploy create txs

- **Hopper:** [`0x41301e0fd8142f6e337fa535b3d2f8bc4dfa87ec4bb6b56a2200944e0157ab5c`](https://explorer.testnet.chain.robinhood.com/tx/0x41301e0fd8142f6e337fa535b3d2f8bc4dfa87ec4bb6b56a2200944e0157ab5c)
- **RoyaltySplitter:** [`0x16a849c92b6f2cddb3470e7c78add26798d726382fdcad388ad1273676c7b667`](https://explorer.testnet.chain.robinhood.com/tx/0x16a849c92b6f2cddb3470e7c78add26798d726382fdcad388ad1273676c7b667)
- **CollectionNFT:** [`0x7da8a18356889f484e463118884866e6f2145fa56bfb59e9d1b26661192fdaaf`](https://explorer.testnet.chain.robinhood.com/tx/0x7da8a18356889f484e463118884866e6f2145fa56bfb59e9d1b26661192fdaaf)
- **TermToken:** [`0xa8715edf858e64786b70d9915716464ef7b30b0011210c1e0a4f1eec366580b4`](https://explorer.testnet.chain.robinhood.com/tx/0xa8715edf858e64786b70d9915716464ef7b30b0011210c1e0a4f1eec366580b4)
- **TermFund:** [`0xdb4863d53f054b176f5c41c222f08d4c313d49dbe3646a68d91b11c0732ca53c`](https://explorer.testnet.chain.robinhood.com/tx/0xdb4863d53f054b176f5c41c222f08d4c313d49dbe3646a68d91b11c0732ca53c)
- **IgniteModule:** [`0xdbd68a2049a7c5d1118622c7f6e049bbd117b3ad4166d029bab80a43c0a14af5`](https://explorer.testnet.chain.robinhood.com/tx/0xdbd68a2049a7c5d1118622c7f6e049bbd117b3ad4166d029bab80a43c0a14af5)
- **TermMarket:** [`0x319cb8573e963d8e28b2dac0df6743dc514ac6d0d40647bcb3656861388d835f`](https://explorer.testnet.chain.robinhood.com/tx/0x319cb8573e963d8e28b2dac0df6743dc514ac6d0d40647bcb3656861388d835f)
- **ERC6551Registry:** [`0xffa76c2558bd5c26e2cdddee8354c73181d114d1501130ac4829a1f4a7aea473`](https://explorer.testnet.chain.robinhood.com/tx/0xffa76c2558bd5c26e2cdddee8354c73181d114d1501130ac4829a1f4a7aea473)
- **ReceivableAccount:** [`0x8384d560e3cb5d56493b9907cce82579cb5e901140911f990594c18d3ace913a`](https://explorer.testnet.chain.robinhood.com/tx/0x8384d560e3cb5d56493b9907cce82579cb5e901140911f990594c18d3ace913a)
- **PulseDistributor:** [`0xdbf55b3e2c57dfc16d5c0fe3ada25402c2ce026cab6d85c61af7628fdb584909`](https://explorer.testnet.chain.robinhood.com/tx/0xdbf55b3e2c57dfc16d5c0fe3ada25402c2ce026cab6d85c61af7628fdb584909)

## Final deploy wiring (cast resume)

- nonce 22: already tx=`already`
- nonce 23: setPulseDistributor(address) tx=`0xcc9326ef4e1295de233741244fb96d29f589a7d8146d3e956d3cf41aee7d22d5`
- nonce 24: lockDistributor(address) tx=`0x21ba5931ab00c51051562b97dd791d0c4cd1f8c0336843f40f7e3a261be76af3`
## Post-deploy

- **setMetadataURIs:** ok — [`0x83052a2eb2a805c413579c536492bac602cc261ab01e13fe71b87a1a7c25ef27`](https://explorer.testnet.chain.robinhood.com/tx/0x83052a2eb2a805c413579c536492bac602cc261ab01e13fe71b87a1a7c25ef27)
- **setStockToken AMZN slot4:** ok — [`0xdc9dd084b50666c345c720d1d9f5855c0dbda808de475b19ef5737a881a406b1`](https://explorer.testnet.chain.robinhood.com/tx/0xdc9dd084b50666c345c720d1d9f5855c0dbda808de475b19ef5737a881a406b1)
- **setStockToken TSLA slot7:** ok — [`0xaa7caf86bbc877385f536ca96e78c2e2375b2aa11fa1c848969a0f901e9a57a6`](https://explorer.testnet.chain.robinhood.com/tx/0xaa7caf86bbc877385f536ca96e78c2e2375b2aa11fa1c848969a0f901e9a57a6)
- **teamMint(owner, 3):** ok — [`0x66be527291001e23c0cfdb12ec696a25b4973347298b5c7ce667093dd528c9c5`](https://explorer.testnet.chain.robinhood.com/tx/0x66be527291001e23c0cfdb12ec696a25b4973347298b5c7ce667093dd528c9c5)
- **reveal():** ok — [`0x61d4f9054ba78676b86d3ee964f0c1af6bfcfc0c3370a3dba2af63b1dc7c49de`](https://explorer.testnet.chain.robinhood.com/tx/0x61d4f9054ba78676b86d3ee964f0c1af6bfcfc0c3370a3dba2af63b1dc7c49de)
- **ignite(1) 0.002 ETH:** ok — [`0xd1a765fb3edc71da37356a1cb326271fb79098d5bfa968d96162dbf1831c0fec`](https://explorer.testnet.chain.robinhood.com/tx/0xd1a765fb3edc71da37356a1cb326271fb79098d5bfa968d96162dbf1831c0fec)

## Verification reads

- revealed: `true`
- tokenURI(1) after reveal (dormant): `https://terminal-pets.vercel.app/metadata/dormant/1.json` (historical recorded URI — that hub tree is gone)
- isLit(1): `true`
- tokenURI(1) after ignite: `https://terminal-pets.vercel.app/metadata/lit/1.json` (historical recorded URI — that hub tree is gone)

New deploys use canonical `https://terminalpets.xyz/metadata/hidden.json` until reveal (`https://terminal-pets.vercel.app/metadata/hidden.json` still resolves as a fallback alias). Do not republish tokenId lit/dormant JSON on the hub.
- previewDial(1): `(0x0000000000000000000000000000000000000000, 0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 5000, 5000, 0, 0, 0, 7, 0, 0, 2, 2)`
- stockTokens: slot4 AMZN `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02`, slot7 TSLA `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` (confirmed via setStockToken event logs; Dial preview shows TSLA on token 1)

## Blockers / notes

- Severe RPC 429 rate limits; deploy used forge `--resume` + manual cast for final wiring (setTerm / setPulseDistributor / lockDistributor).
- Ignite first attempt failed due to casting `igniteFeeEth` pretty-print; retried with `0.002ether` successfully.
- No mainnet (4663) broadcast.

