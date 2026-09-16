// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {DialMath} from "../src/DialMath.sol";
import {INonFungibleSeaDropToken} from "../src/interfaces/seadrop/INonFungibleSeaDropToken.sol";
import {ISeaDropTokenContractMetadata} from "../src/interfaces/seadrop/ISeaDropTokenContractMetadata.sol";
import {
    AllowListData,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "../src/interfaces/seadrop/SeaDropStructs.sol";
import {MockSeaDrop} from "./mocks/MockSeaDrop.sol";
import {MockPulseRouter, MockStockToken} from "./mocks/MockPulseRouter.sol";

contract SeaDropMintTest is Test {
    uint256 internal constant SUPPLY = 20;
    uint256 internal constant TEAM = 2;
    uint256 internal constant PUBLIC = 18;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    bytes4 internal constant ERC4906 = 0x49064906;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    RoyaltySplitter internal splitter;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulse;
    TermToken internal term;
    TermFund internal fund;
    MockSeaDrop internal seaDrop;
    MockStockToken[8] internal stocks;

    function setUp() public {
        seaDrop = new MockSeaDrop();
        address[] memory allowed = new address[](1);
        allowed[0] = address(seaDrop);

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
            allowed
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
        term.mint(alice, 1_000 ether);

        pulse = new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner);
        pulse.setTerm(address(term));
        MockPulseRouter router = new MockPulseRouter(2);
        pulse.setRouter(address(router));
        ignite.setPulseDistributor(address(pulse));
        hopper.lockDistributor(address(pulse));

        address[8] memory pool;
        for (uint8 i; i < 8; ++i) {
            stocks[i] = new MockStockToken(string.concat("S", vm.toString(i)), string.concat("S", vm.toString(i)));
            pool[i] = address(stocks[i]);
        }
        pulse.setStockTokens(pool);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        term.approve(address(ignite), type(uint256).max);
    }

    function test_constructor_authorizesSeaDrop() public view {
        assertTrue(nft.isAllowedSeaDrop(address(seaDrop)));
        address[] memory listed = nft.getAllowedSeaDrop();
        assertEq(listed.length, 1);
        assertEq(listed[0], address(seaDrop));
        assertFalse(nft.isAllowedSeaDrop(alice));
    }

    function test_canonicalSeaDropAddress() public pure {
        assertEq(CollectionConfig.SEADROP, 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5);
    }

    function test_supportsSeaDropInterfaces() public view {
        assertTrue(nft.supportsInterface(type(INonFungibleSeaDropToken).interfaceId));
        assertTrue(nft.supportsInterface(type(ISeaDropTokenContractMetadata).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721Enumerable).interfaceId));
        assertTrue(nft.supportsInterface(ERC4906));
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId));
    }

    function test_mintSeaDrop_onlyAllowed() public {
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        nft.mintSeaDrop(alice, 1);

        vm.prank(alice);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        nft.mintSeaDrop(alice, 1);
    }

    function test_mintSeaDrop_mintsWhenMintClosed() public {
        assertFalse(nft.mintOpen());
        seaDrop.mintFor(address(nft), alice, 2);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.publicMinted(), 2);
        assertEq(nft.numberMinted(alice), 2);
        (uint256 minted, uint256 supply, uint256 cap) = nft.getMintStats(alice);
        assertEq(minted, 2);
        assertEq(supply, 2);
        assertEq(cap, PUBLIC);
    }

    function test_updateAllowedSeaDrop_onlyOwner_andRevokesOld() public {
        MockSeaDrop other = new MockSeaDrop();
        vm.prank(alice);
        vm.expectRevert();
        address[] memory next = new address[](1);
        next[0] = address(other);
        nft.updateAllowedSeaDrop(next);

        vm.prank(owner);
        nft.updateAllowedSeaDrop(next);
        assertTrue(nft.isAllowedSeaDrop(address(other)));
        assertFalse(nft.isAllowedSeaDrop(address(seaDrop)));

        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        seaDrop.mintFor(address(nft), alice, 1);

        other.mintFor(address(nft), alice, 1);
        assertEq(nft.ownerOf(1), alice);
    }

    function test_getMintStats_publicCapIgnoresTeamMint() public {
        vm.prank(owner);
        nft.teamMint(treasury, TEAM);
        (uint256 minted, uint256 supply, uint256 cap) = nft.getMintStats(treasury);
        assertEq(minted, 0);
        assertEq(supply, 0);
        assertEq(cap, PUBLIC);
        assertEq(nft.totalSupply(), TEAM);
        assertEq(nft.maxSupply(), SUPPLY);
        assertEq(nft.publicSupply(), PUBLIC);
    }

    function test_mintSeaDrop_capsAtPublicSupply() public {
        seaDrop.mintFor(address(nft), alice, PUBLIC);
        vm.expectRevert(CollectionNFT.PublicSupplyReached.selector);
        seaDrop.mintFor(address(nft), bob, 1);

        vm.prank(owner);
        nft.teamMint(treasury, TEAM);
        assertEq(nft.totalSupply(), SUPPLY);
        vm.prank(owner);
        vm.expectRevert(CollectionNFT.TeamReserveExceeded.selector);
        nft.teamMint(treasury, 1);
    }

    function test_teamMint_andSeaDropShareMaxSupply() public {
        vm.prank(owner);
        nft.teamMint(treasury, TEAM);
        seaDrop.mintFor(address(nft), alice, PUBLIC);
        assertEq(nft.totalSupply(), SUPPLY);
        assertEq(nft.publicMinted(), PUBLIC);
        assertEq(nft.teamMinted(), TEAM);
        uint256[] memory ids = nft.tokensOfOwner(alice);
        assertEq(ids.length, PUBLIC);
        assertEq(ids[0], TEAM + 1);
    }

    function test_dappMint_sharesPublicCapWithSeaDrop() public {
        vm.prank(owner);
        nft.setMintOpen(true);
        vm.prank(alice);
        nft.mint(3);
        seaDrop.mintFor(address(nft), bob, PUBLIC - 3);
        vm.expectRevert(CollectionNFT.PublicSupplyReached.selector);
        seaDrop.mintFor(address(nft), bob, 1);
        (uint256 aliceMinted,,) = nft.getMintStats(alice);
        (uint256 bobMinted, uint256 supply, uint256 cap) = nft.getMintStats(bob);
        assertEq(aliceMinted, 3);
        assertEq(bobMinted, PUBLIC - 3);
        assertEq(supply, PUBLIC);
        assertEq(cap, PUBLIC);
    }

    function test_updatePublicDrop_forwardsToSeaDrop() public {
        PublicDrop memory drop = PublicDrop({
            mintPrice: 0,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp + 1 days),
            maxTotalMintableByWallet: 1,
            feeBps: 1000,
            restrictFeeRecipients: true
        });
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.OnlyOwnerOrSelf.selector);
        nft.updatePublicDrop(address(seaDrop), drop);

        vm.prank(owner);
        nft.updatePublicDrop(address(seaDrop), drop);
        assertEq(seaDrop.lastCaller(), address(nft));
        (uint80 mintPrice, uint48 startTime, uint48 endTime, uint16 maxPerWallet, uint16 feeBps, bool restrict) =
            seaDrop.publicDrop();
        assertEq(mintPrice, 0);
        assertEq(startTime, uint48(block.timestamp));
        assertEq(endTime, uint48(block.timestamp + 1 days));
        assertEq(maxPerWallet, 1);
        assertEq(feeBps, 1000);
        assertTrue(restrict);
    }

    function test_updateDropConfig_forwardsAllowListUriPayoutFeePayerSigner() public {
        string[] memory keys = new string[](0);
        AllowListData memory allow =
            AllowListData({merkleRoot: keccak256("gtd"), publicKeyURIs: keys, allowListURI: "ipfs://allow"});
        vm.prank(owner);
        nft.updateAllowList(address(seaDrop), allow);
        assertEq(seaDrop.allowListMerkleRoot(), keccak256("gtd"));

        vm.prank(owner);
        nft.updateDropURI(address(seaDrop), "https://opensea.io/drop/terminal-pets");
        assertEq(seaDrop.dropURI(), "https://opensea.io/drop/terminal-pets");

        vm.prank(owner);
        nft.updateCreatorPayoutAddress(address(seaDrop), address(hopper));
        assertEq(seaDrop.creatorPayoutAddress(), address(hopper));

        vm.prank(owner);
        nft.updateAllowedFeeRecipient(address(seaDrop), address(0xfee), true);
        assertEq(seaDrop.lastFeeRecipient(), address(0xfee));
        assertTrue(seaDrop.lastFeeRecipientAllowed());

        vm.prank(owner);
        nft.updatePayer(address(seaDrop), bob, true);
        assertEq(seaDrop.lastPayer(), bob);
        assertTrue(seaDrop.lastPayerAllowed());

        SignedMintValidationParams memory params;
        params.maxFeeBps = 1000;
        vm.prank(owner);
        nft.updateSignedMintValidationParams(address(seaDrop), owner, params);
        assertEq(seaDrop.lastSigner(), owner);

        TokenGatedDropStage memory stage;
        stage.dropStageIndex = 1;
        vm.prank(owner);
        nft.updateTokenGatedDrop(address(seaDrop), address(nft), stage);
        assertEq(seaDrop.lastTokenGatedNft(), address(nft));
    }

    function test_updateMethods_revertIfSeaDropNotAllowed() public {
        PublicDrop memory drop;
        vm.prank(owner);
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        nft.updatePublicDrop(address(0xdead), drop);
    }

    function test_setMaxSupply_immutable() public {
        vm.prank(owner);
        nft.setMaxSupply(SUPPLY);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CollectionNFT.MaxSupplyImmutable.selector, SUPPLY, SUPPLY + 1));
        nft.setMaxSupply(SUPPLY + 1);
    }

    function test_setMetadataURIs_andSeaDropTokenURILifecycle() public {
        seaDrop.mintFor(address(nft), alice, 1);

        vm.prank(owner);
        nft.setMetadataURIs("ipfs://hidden.json", "ipfs://egg/", "ipfs://lit/");
        assertEq(nft.tokenURI(1), "ipfs://hidden.json");
        assertEq(nft.tokenTraits(1).state, "Sealed");

        vm.prank(owner);
        nft.reveal();
        assertEq(nft.tokenURI(1), "ipfs://egg/1.json");
        assertEq(nft.tokenTraits(1).state, "Dormant");

        vm.prank(owner);
        pulse.setShellClassOverride(1, DialMath.OMEGA);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        assertTrue(nft.isLit(1));
        assertEq(nft.tokenURI(1), "ipfs://lit/1.json");
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, 4);
        assertEq(d.shellClass, DialMath.OMEGA);
        assertEq(d.weight0, 2_500);
        assertEq(uint256(d.weight0) + d.weight1 + d.weight2 + d.weight3, 10_000);
        assertEq(hopper.hopperUnlockTime(), uint256(hopper.revealedAt()) + 7 days);
        assertFalse(hopper.hopperUnlocked());
        assertEq(CollectionConfig.IGNITE_FEE_ETH, 0.002 ether);
        assertEq(CollectionConfig.HOPPER_LOCK, 7 days);
    }

    function test_revealIgniteDial_afterSeaDropMint_fallbackRenderer() public {
        seaDrop.mintFor(address(nft), alice, 1);
        string memory sealedUri = nft.tokenURI(1);
        assertEq(sealedUri, nft.renderer().hiddenTokenURI(1));

        vm.prank(owner);
        nft.reveal();
        assertEq(nft.tokenURI(1), nft.renderer().tokenURI(1, false));

        PulseDistributor.Dial memory preview = pulse.previewDial(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(nft.tokenURI(1), nft.renderer().tokenURI(1, true));
        PulseDistributor.Dial memory assigned = pulse.getDial(1);
        assertEq(assigned.nLegs, preview.nLegs);
        assertEq(assigned.slot0, preview.slot0);
        assertEq(assigned.shellClass, preview.shellClass);
    }

    function test_royaltiesUnchanged() public view {
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, address(splitter));
        assertEq(amount, 750);
        assertEq(nft.royaltyAddress(), address(splitter));
        assertEq(nft.royaltyBasisPoints(), 750);
    }

    function test_setRoyaltyInfo_locksReceiver() public {
        ISeaDropTokenContractMetadata.RoyaltyInfo memory info =
            ISeaDropTokenContractMetadata.RoyaltyInfo({royaltyAddress: alice, royaltyBps: 500});
        vm.prank(owner);
        vm.expectRevert(CollectionNFT.RoyaltyReceiverLocked.selector);
        nft.setRoyaltyInfo(info);

        info.royaltyAddress = address(splitter);
        vm.prank(owner);
        nft.setRoyaltyInfo(info);
        assertEq(nft.royaltyBasisPoints(), 500);
    }

    function test_provenanceHash_revertsAfterMint() public {
        vm.prank(owner);
        nft.setProvenanceHash(bytes32(uint256(1)));
        assertEq(nft.provenanceHash(), bytes32(uint256(1)));
        seaDrop.mintFor(address(nft), alice, 1);
        vm.prank(owner);
        vm.expectRevert(ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterMintStarted.selector);
        nft.setProvenanceHash(bytes32(uint256(2)));
    }

    function test_setBaseURI_hiddenVsDormant() public {
        seaDrop.mintFor(address(nft), alice, 1);
        vm.prank(owner);
        nft.setBaseURI("ipfs://hidden.json");
        assertEq(nft.hiddenURI(), "ipfs://hidden.json");
        assertEq(nft.tokenURI(1), "ipfs://hidden.json");
        vm.prank(owner);
        nft.setBaseURI("ipfs://egg/");
        assertEq(nft.dormantBaseURI(), "ipfs://egg/");
        vm.prank(owner);
        nft.reveal();
        assertEq(nft.tokenURI(1), "ipfs://egg/1.json");
        assertEq(nft.baseURI(), "ipfs://egg/");
    }

    function test_mintSeaDrop_zeroQuantityReverts() public {
        vm.expectRevert(CollectionNFT.ZeroValue.selector);
        seaDrop.mintFor(address(nft), alice, 0);
    }
}
