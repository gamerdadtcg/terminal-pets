// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {TermMarket} from "../src/TermMarket.sol";
import {ERC6551Registry} from "../src/tba/ERC6551Registry.sol";
import {ReceivableAccount} from "../src/tba/ReceivableAccount.sol";

/// @notice Deploy Terminal Pets. **Do not broadcast to Robinhood Chain until the user says go.**
///
/// Environment (optional overrides):
///   PRIVATE_KEY            deployer key
///   OWNER                  owner (defaults to deployer)
///   COLLECTION_NAME        default "Terminal Pets"
///   COLLECTION_SYMBOL      default "TERM"
///   MAX_SUPPLY             default 4444
///   MINT_PRICE_WEI         default 0
///   IGNITE_FEE_TERM        default 1000e18 (1,000 $TERM)
///   IGNITE_FEE_ETH         default 0.002 ether → 50% Hopper / 50% buy-$TERM-and-burn
///   TERM_INITIAL_SUPPLY    default 1_000_000_000e18 minted to treasury (LP $TERM)
///   TERM_TOKEN             existing `$TERM` (else deploys TermToken)
///   TERM_LP_ROUTER         optional TermFund DEX adapter (else ETH+$TERM custody until set)
///   TERM_POOL              optional canonical TERM/ETH pool (activates TermMarket skim)
///   TERM_SWAP_ROUTER       optional adapter for TermMarket skim + Ignite 25% Hopper conversion
///   PULSE_ROUTER           DEX adapter for Dialed stocks + undialed $TERM buys
///                          (unset: Dialed falls back to ETH; undialed claim reverts)
///   ROYALTY_BPS            default 750
///   TEAM_RESERVE           default 200
///   TREASURY_ADDRESS       required — 2.5% royalties + TermFund extra `$TERM` source / LP recipient
///   TBA_REGISTRY / TBA_IMPLEMENTATION / TBA_SALT
///   MINT_OPEN              "true" to open public mint at deploy
///
/// Pulse thresholds are a ladder in PulseDistributor (not a deploy env).
/// Ignite allotment: MAX_SUPPLY × IGNITE_FEE_TERM minted to IgniteModule.
contract Deploy is Script {
    struct Params {
        address owner;
        string name;
        string symbol;
        uint256 maxSupply;
        uint256 teamReserve;
        uint256 mintPrice;
        uint256 igniteFeeTerm;
        uint256 igniteFeeEth;
        uint256 termSupply;
        address termToken;
        address termLpRouter;
        address termPool;
        address termSwapRouter;
        address pulseRouter;
        uint96 royaltyBps;
        address treasury;
        bool mintOpen;
        address tbaRegistry;
        address tbaImplementation;
        bytes32 tbaSalt;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Params memory p = _params(vm.addr(pk));

        vm.startBroadcast(pk);
        _deploy(p);
        vm.stopBroadcast();
    }

    function _params(address deployer) internal view returns (Params memory p) {
        p.owner = vm.envOr("OWNER", deployer);
        p.name = vm.envOr("COLLECTION_NAME", CollectionConfig.NAME);
        p.symbol = vm.envOr("COLLECTION_SYMBOL", CollectionConfig.SYMBOL);
        p.maxSupply = vm.envOr("MAX_SUPPLY", CollectionConfig.MAX_SUPPLY);
        p.teamReserve = vm.envOr("TEAM_RESERVE", CollectionConfig.TEAM_RESERVE);
        p.mintPrice = vm.envOr("MINT_PRICE_WEI", CollectionConfig.MINT_PRICE_WEI);
        p.igniteFeeTerm = vm.envOr("IGNITE_FEE_TERM", CollectionConfig.IGNITE_FEE_TERM);
        p.igniteFeeEth = vm.envOr("IGNITE_FEE_ETH", CollectionConfig.IGNITE_FEE_ETH);
        p.termSupply = vm.envOr("TERM_INITIAL_SUPPLY", CollectionConfig.TERM_INITIAL_SUPPLY);
        p.termToken = vm.envOr("TERM_TOKEN", address(0));
        p.termLpRouter = vm.envOr("TERM_LP_ROUTER", address(0));
        p.termPool = vm.envOr("TERM_POOL", address(0));
        p.termSwapRouter = vm.envOr("TERM_SWAP_ROUTER", address(0));
        p.pulseRouter = vm.envOr("PULSE_ROUTER", address(0));
        p.royaltyBps = uint96(vm.envOr("ROYALTY_BPS", uint256(CollectionConfig.ROYALTY_BPS)));
        p.treasury = vm.envAddress("TREASURY_ADDRESS");
        p.mintOpen = vm.envOr("MINT_OPEN", false);
        p.tbaRegistry = vm.envOr("TBA_REGISTRY", address(0));
        p.tbaImplementation = vm.envOr("TBA_IMPLEMENTATION", address(0));
        p.tbaSalt = vm.envOr("TBA_SALT", bytes32(0));
    }

    function _deploy(Params memory p) internal {
        Hopper hopper = new Hopper(p.owner);
        RoyaltySplitter splitter = new RoyaltySplitter(address(hopper), p.treasury, p.owner);
        CollectionNFT nft = new CollectionNFT(
            p.name, p.symbol, p.maxSupply, p.teamReserve, address(hopper), address(splitter), p.owner, p.royaltyBps
        );

        uint256 allotment = p.maxSupply * p.igniteFeeTerm;

        TermToken term;
        if (p.termToken == address(0)) {
            term = new TermToken(msg.sender);
            term.mint(p.treasury, p.termSupply);
        } else {
            term = TermToken(p.termToken);
        }

        TermFund fund = new TermFund(p.owner, address(term), p.treasury);
        IgniteModule ignite = new IgniteModule(
            address(nft), address(term), address(hopper), p.owner, p.igniteFeeTerm, address(fund), p.igniteFeeEth
        );
        fund.lockIgnite(address(ignite));
        if (p.termLpRouter != address(0)) fund.setRouter(p.termLpRouter);
        if (p.termSwapRouter != address(0)) ignite.setSwapRouter(p.termSwapRouter);

        TermMarket market = new TermMarket(p.owner, address(term), address(hopper), p.treasury);
        if (p.termPool != address(0)) market.setCanonicalPool(p.termPool);
        if (p.termSwapRouter != address(0)) market.setSwapRouter(p.termSwapRouter);

        if (p.termToken == address(0)) {
            term.mint(address(ignite), allotment);
            term.setLauncher(address(nft));
            term.setTransferExempt(address(ignite), true);
            term.setTransferExempt(address(fund), true);
            term.setTransferExempt(address(market), true);
            if (p.owner != msg.sender) term.transferOwnership(p.owner);
        } else {
            console.log("TERM_TOKEN provided - fund IgniteModule allotment yourself:", allotment);
        }

        nft.setIgniteModule(address(ignite));
        nft.setTermToken(address(term));
        splitter.arm(address(fund), address(nft));
        nft.setMintPrice(p.mintPrice);

        address tbaRegistry = p.tbaRegistry;
        address tbaImplementation = p.tbaImplementation;
        if (tbaRegistry == address(0)) tbaRegistry = address(new ERC6551Registry());
        if (tbaImplementation == address(0)) tbaImplementation = address(new ReceivableAccount());

        PulseDistributor pulse =
            new PulseDistributor(address(hopper), address(nft), address(ignite), p.maxSupply, p.owner);
        pulse.setTbaConfig(tbaRegistry, tbaImplementation, p.tbaSalt);
        pulse.setTerm(address(term));
        if (p.pulseRouter != address(0)) pulse.setRouter(p.pulseRouter);
        hopper.lockDistributor(address(pulse));
        if (p.mintOpen) nft.setMintOpen(true);

        console.log("Hopper", address(hopper));
        console.log("RoyaltySplitter", address(splitter));
        console.log("Treasury", p.treasury);
        console.log("TermToken", address(term));
        console.log("TermFund", address(fund));
        console.log("TermMarket", address(market));
        console.log("TermPool", p.termPool);
        console.log("TermSwapRouter", p.termSwapRouter);
        console.log("TermLpRouter", p.termLpRouter);
        console.log("CollectionNFT", address(nft));
        console.log("IgniteModule", address(ignite));
        console.log("IgniteAllotmentTERM", allotment);
        console.log("PulseDistributor", address(pulse));
        console.log("PulseRouter", p.pulseRouter);
        console.log("TbaRegistry", tbaRegistry);
        console.log("TbaImplementation", tbaImplementation);
        console.log("Owner", p.owner);
        console.log("IgniteFeeTERM", p.igniteFeeTerm);
        console.log("IgniteFeeETH", p.igniteFeeEth);
        console.log("TeamReserve", p.teamReserve);
        console.log("PublicSupply", p.maxSupply - p.teamReserve);
        console.log("RevealAfter", nft.revealAfter());
        console.log("Pre-reveal: sealed metadata, Ignite off, $TERM trading off, 7.5% royalties -> TermFund");
        console.log("Reveal: owner anytime, or anyone after 24h. Then art + Ignite + trading + 5/2.5 royalty split");
        console.log("Do NOT auto-reveal at deploy. CollectionNFT.reveal() is the activation.");
        console.log("Team mint: CollectionNFT.teamMint(TREASURY_ADDRESS or TEAM_WALLET, qty)");
        console.log("READY TO DEPLOY - do not broadcast to 4663 until the user says go.");
    }
}
