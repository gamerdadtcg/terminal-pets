// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";

contract MetadataURITest is Test {
    uint256 internal constant SUPPLY = 8;
    uint256 internal constant TEAM = 1;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    RoyaltySplitter internal splitter;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    TermToken internal term;
    TermFund internal fund;

    function setUp() public {
        vm.startPrank(owner);
        hopper = new Hopper(owner, 0);
        splitter = new RoyaltySplitter(address(hopper), treasury, owner);
        nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            TEAM,
            address(hopper),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS,
            new address[](0)
        );
        term = new TermToken(owner);
        fund = new TermFund(owner, address(term), treasury);
        ignite = new IgniteModule(address(nft), address(term), address(hopper), owner, FEE, address(fund), ETH_FEE);
        fund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(fund), address(nft));
        term.setLauncher(address(nft));
        term.setTransferExempt(address(ignite), true);
        term.setTransferExempt(address(fund), true);
        nft.setTermToken(address(term));
        term.mint(address(ignite), SUPPLY * FEE);
        nft.setMintOpen(true);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        term.approve(address(ignite), type(uint256).max);
    }

    function test_unsetURIs_fallBackToRenderer() public {
        vm.prank(alice);
        nft.mint(1);
        assertEq(nft.tokenURI(1), nft.renderer().hiddenTokenURI(1));
        vm.prank(owner);
        nft.reveal();
        assertEq(nft.tokenURI(1), nft.renderer().tokenURI(1, false));
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(nft.tokenURI(1), nft.renderer().tokenURI(1, true));
    }

    function test_setMetadataURIs_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setMetadataURIs("ipfs://hidden.json", "ipfs://egg/", "ipfs://lit/");
    }

    function test_tokenURI_sealedDormantLit() public {
        vm.prank(alice);
        nft.mint(1);

        vm.prank(owner);
        nft.setMetadataURIs("ipfs://bafyHidden/hidden.json", "ipfs://bafyEgg/egg-metadata/", "ipfs://bafyLit/metadata/");

        assertEq(nft.tokenURI(1), "ipfs://bafyHidden/hidden.json");

        vm.prank(owner);
        nft.reveal();
        assertEq(nft.tokenURI(1), "ipfs://bafyEgg/egg-metadata/1.json");

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(nft.tokenURI(1), "ipfs://bafyLit/metadata/1.json");
    }

    function test_hiddenURI_trailingSlash_isPerToken() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(owner);
        nft.setMetadataURIs("ipfs://sealed/", "ipfs://egg/", "ipfs://lit/");
        assertEq(nft.tokenURI(1), "ipfs://sealed/1.json");
    }

    function test_setMetadataURIs_emitsBatchUpdateWhenMinted() public {
        vm.prank(alice);
        nft.mint(2);
        vm.expectEmit(false, false, false, true, address(nft));
        emit CollectionNFT.MetadataURIsUpdated("h", "d/", "l/");
        vm.expectEmit(false, false, false, true, address(nft));
        emit CollectionNFT.BatchMetadataUpdate(1, 2);
        vm.prank(owner);
        nft.setMetadataURIs("h", "d/", "l/");
        assertEq(nft.hiddenURI(), "h");
        assertEq(nft.dormantBaseURI(), "d/");
        assertEq(nft.litBaseURI(), "l/");
    }
}
