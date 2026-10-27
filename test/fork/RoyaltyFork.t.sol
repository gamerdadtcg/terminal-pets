// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PulseV2Config, PulseV2Migration} from "../../script/MigratePulseV2.s.sol";
import {HopperV2} from "../../src/HopperV2.sol";
import {HopperRedirectRouter} from "../../src/HopperRedirectRouter.sol";
import {PulseDistributorV2} from "../../src/PulseDistributorV2.sol";
import {IgniteModule} from "../../src/IgniteModule.sol";
import {TermMarketFeeForwarder} from "../../src/TermMarketFeeForwarder.sol";
import {RoyaltySplitterV2} from "../../src/RoyaltySplitterV2.sol";
import {CollectionNFT} from "../../src/CollectionNFT.sol";

// ---- minimal Seaport 1.6 ABI (only what the rehearsal uses)
struct OfferItem {
    uint8 itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

struct ConsiderationItem {
    uint8 itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}

struct OrderParameters {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    uint8 orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 totalOriginalConsiderationItems;
}

struct Order {
    OrderParameters parameters;
    bytes signature;
}

interface ISeaport {
    function validate(Order[] calldata orders) external returns (bool);
    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool);
}

interface IWETHLike is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

/// @notice Rehearses the royalty re-route on the LIVE Robinhood Chain (4663) fork. A real Seaport 1.6 sale of a real
/// token (ETH and WETH priced) pays the 7.5% creator earnings to a freshly deployed RoyaltySplitterV2, exactly as
/// OpenSea does once Studio is pointed at it. Nothing is broadcast.
///
///   FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-path test/fork/RoyaltyFork.t.sol -vv
contract RoyaltyForkTest is Test {
    address constant OWNER = 0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37;
    address constant V1_HOPPER = 0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2;
    address constant V1_PULSE = 0x7326F7D277610288FBeA373712c89E47AF9AC61E;
    address constant V1_SPLITTER = 0xe1cC988CeC1C29764ba18523635De82d0C9B518F;
    address constant COLLECTION = 0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166;
    address constant IGNITE = 0x29e8dB2073583720C3CBf741d278d942B65cb92B;
    address constant MARKET = 0x78f2c0577321053722Daa1f5eE31E5071a7D9F30;
    address constant TREASURY = 0x0c821a853711bF03C4C6b776CfD657f2ee97733e;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    ISeaport constant SEAPORT = ISeaport(0x0000000000000068F116a894984e2DB1123eB395);

    PulseV2Config internal c;
    HopperV2 internal hopper;
    PulseDistributorV2 internal pulse;
    HopperRedirectRouter internal redirect;
    TermMarketFeeForwarder internal fwd;
    RoyaltySplitterV2 internal splitter;
    IgniteModule internal ignite = IgniteModule(IGNITE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) vm.skip(true);
        uint256 blk = vm.envOr("FORK_BLOCK", uint256(0));
        if (blk == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, blk);
        require(block.chainid == 4663, "wrong chain");
        c = PulseV2Config({
            deployer: OWNER,
            owner: OWNER,
            v1Hopper: V1_HOPPER,
            v1Pulse: V1_PULSE,
            collection: COLLECTION,
            ignite: IGNITE,
            termMarket: MARKET,
            maxSupply: 4444
        });
        // full stack + splitter (steps 1, 1b, 1c, 2-8)
        vm.startPrank(OWNER);
        (hopper, pulse, redirect) = PulseV2Migration.step1_deploy(c);
        fwd = PulseV2Migration.step1b_deployForwarder(c, hopper);
        splitter = PulseV2Migration.step1c_deployRoyaltySplitter(c, hopper, WETH);
        PulseV2Migration.step2_registerLit(c, pulse);
        PulseV2Migration.step3_pointDialHook(c, pulse);
        PulseV2Migration.step4_igniteRouter(c, redirect);
        PulseV2Migration.step5_marketRouter(c, redirect);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        PulseV2Migration.step7_marketTreasury(c, fwd);
        PulseV2Migration.step8_marketFeeBps(c, fwd);
        vm.stopPrank();
        PulseV2Migration.verify(c, hopper, pulse, redirect, fwd, false);
        PulseV2Migration.verifyRoyalty(c, hopper, splitter, false);
    }

    function test_fork_liveRoyaltyAssumptions() public view {
        (address recv, uint256 amt) = CollectionNFT(COLLECTION).royaltyInfo(1, 10_000);
        assertEq(recv, V1_SPLITTER);
        assertEq(amt, 750);
        assertEq(splitter.treasury(), TREASURY, "same treasury as the live V1 splitter");
        assertEq(splitter.weth(), WETH);
        assertEq(splitter.hopperV2(), address(hopper));
        assertGt(WETH.code.length, 0);
        assertGt(address(SEAPORT).code.length, 0);
    }

    /// Real WETH `withdraw` must work into our receive (what the contract relies on for unwrapping).
    function test_fork_realWeth_unwrap_intoSplitter() public {
        vm.deal(address(this), 3 ether);
        IWETHLike(WETH).deposit{value: 3 ether}();
        IERC20(WETH).transfer(address(splitter), 3 ether);
        uint256 v2 = address(hopper).balance;
        uint256 tre = TREASURY.balance;
        splitter.unwrapWeth();
        assertEq(address(hopper).balance - v2, 2 ether);
        assertEq(TREASURY.balance - tre, 1 ether);
        assertEq(address(splitter).balance, 0);
        assertEq(IERC20(WETH).balanceOf(address(splitter)), 0);
    }

    /// A real Seaport sale paying in ETH: creator earnings go to the new splitter by Seaport's own payout path.
    function test_fork_seaportSale_eth_royaltyToSplitter_thenDistribute() public {
        (uint256 tokenId, address seller) = _someToken();
        address buyer = makeAddr("buyer");
        uint256 price = 3 ether;
        uint256 royalty = (price * 750) / 10_000;
        uint256 fee = price / 100; // OpenSea-style 1% protocol fee
        vm.deal(buyer, price);
        Order memory o = _order(seller, tokenId, address(0), price, fee, royalty);
        _list(seller, tokenId, o);

        uint256 v1 = V1_HOPPER.balance;
        uint256 v2 = address(hopper).balance;
        uint256 tre = TREASURY.balance;
        vm.prank(buyer);
        SEAPORT.fulfillOrder{value: price}(o, bytes32(0));

        assertEq(IERC721(COLLECTION).ownerOf(tokenId), buyer);
        assertEq(address(splitter).balance, royalty, "Seaport paid the creator earnings to the splitter");
        assertEq(address(hopper).balance, v2, "receive() does not push");
        console.log("royalty paid by Seaport (wei)", royalty);

        splitter.distribute();
        assertEq(address(hopper).balance - v2, (royalty * 2) / 3);
        assertEq(TREASURY.balance - tre, royalty - (royalty * 2) / 3);
        assertEq(V1_HOPPER.balance, v1, "V1 Hopper receives nothing");
        assertEq(address(splitter).balance, 0);
    }

    /// A real Seaport sale paying in WETH (accepted offer): WETH lands in the splitter, `unwrapWeth` splits it.
    function test_fork_seaportSale_weth_royaltyToSplitter_thenUnwrap() public {
        (uint256 tokenId, address seller) = _someToken();
        address buyer = makeAddr("buyerW");
        uint256 price = 3 ether;
        uint256 royalty = (price * 750) / 10_000;
        uint256 fee = price / 100;
        vm.deal(buyer, price);
        vm.startPrank(buyer);
        IWETHLike(WETH).deposit{value: price}();
        IERC20(WETH).approve(address(SEAPORT), price);
        vm.stopPrank();
        Order memory o = _order(seller, tokenId, WETH, price, fee, royalty);
        _list(seller, tokenId, o);
        vm.prank(buyer);
        SEAPORT.fulfillOrder(o, bytes32(0));

        assertEq(IERC721(COLLECTION).ownerOf(tokenId), buyer);
        assertEq(IERC20(WETH).balanceOf(address(splitter)), royalty);
        uint256 v2 = address(hopper).balance;
        uint256 tre = TREASURY.balance;
        splitter.unwrapWeth();
        assertEq(address(hopper).balance - v2, (royalty * 2) / 3);
        assertEq(TREASURY.balance - tre, royalty - (royalty * 2) / 3);
        assertEq(IERC20(WETH).balanceOf(address(splitter)), 0);
        assertEq(address(splitter).balance, 0);
    }

    /// Whole chain: Seaport royalty -> splitter -> HopperV2 accounting -> Ignite -> pulse -> claim with real routers,
    /// then optional step 10 does not disturb any of it.
    function test_fork_royaltiesFundPulse_andClaim_step10Optional() public {
        (uint256 tokenId, address seller) = _someToken();
        address buyer = makeAddr("buyer2");
        uint256 price = 10 ether; // 0.75 ETH creator earnings => 0.5 ETH to HopperV2
        uint256 royalty = (price * 750) / 10_000;
        vm.deal(buyer, price);
        Order memory o = _order(seller, tokenId, address(0), price, price / 100, royalty);
        _list(seller, tokenId, o);
        vm.prank(buyer);
        SEAPORT.fulfillOrder{value: price}(o, bytes32(0));
        splitter.distribute();
        uint256 funded = address(hopper).balance;
        assertEq(funded, (royalty * 2) / 3);
        assertEq(hopper.available(), funded);

        // optional step 10 (collection owner): on-chain royaltyInfo -> 0, splitter unaffected
        vm.prank(OWNER);
        PulseV2Migration.step10_zeroOnchainRoyalty(c);
        PulseV2Migration.verifyRoyalty(c, hopper, splitter, true);
        (, uint256 amt) = CollectionNFT(COLLECTION).royaltyInfo(1, 10_000);
        assertEq(amt, 0);

        // pulse + real claims
        uint256 unlock = hopper.hopperUnlockTime();
        if (block.timestamp <= unlock) vm.warp(unlock + 1);
        assertTrue(pulse.canPulse(), "royalty ETH alone crosses the pulse threshold");
        pulse.pulse();
        uint256 hopperBeforeClaims = address(hopper).balance;
        uint256[] memory ids = _litIds();
        for (uint256 i; i < ids.length; ++i) {
            address owner_ = IERC721(COLLECTION).ownerOf(ids[i]);
            uint256 b = owner_.balance;
            uint256 pend = pulse.pending(ids[i]);
            assertGt(pend, 0);
            pulse.claim(ids[i]);
            assertEq(pulse.pending(ids[i]), 0);
            assertTrue(owner_.balance > b || _stock(owner_) > 0, "owner paid in ETH or stock tokens");
        }
        assertEq(hopper.reserved(), 0);
        console.log("HopperV2 funded by royalties (wei)", funded);
        console.log("balance left after all claims (dust)", address(hopper).balance);
        assertLe(address(hopper).balance, hopperBeforeClaims);
    }

    // ------------------------------------------------------------------ helpers

    function _someToken() internal view returns (uint256 id, address holder) {
        for (id = 1; id <= 4444; ++id) {
            try IERC721(COLLECTION).ownerOf(id) returns (address o) {
                if (o != address(0) && o.code.length == 0 && o != OWNER) return (id, o);
            } catch {}
        }
        revert("no token");
    }

    function _order(address seller, uint256 tokenId, address payToken, uint256 price, uint256 fee, uint256 royalty)
        internal
        view
        returns (Order memory o)
    {
        uint8 it = payToken == address(0) ? 0 : 1;
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(2, COLLECTION, tokenId, 1, 1);
        ConsiderationItem[] memory cons = new ConsiderationItem[](3);
        cons[0] = ConsiderationItem(it, payToken, 0, price - fee - royalty, price - fee - royalty, payable(seller));
        cons[1] = ConsiderationItem(it, payToken, 0, fee, fee, payable(address(0xFEE)));
        cons[2] = ConsiderationItem(it, payToken, 0, royalty, royalty, payable(address(splitter)));
        o.parameters = OrderParameters({
            offerer: seller,
            zone: address(0),
            offer: offer,
            consideration: cons,
            orderType: 0, // FULL_OPEN
            startTime: block.timestamp - 1,
            endTime: block.timestamp + 1 days,
            zoneHash: bytes32(0),
            salt: uint256(keccak256(abi.encode(tokenId, price, payToken))),
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: 3
        });
        o.signature = ""; // pre-validated on-chain by the offerer
    }

    function _list(address seller, uint256 tokenId, Order memory o) internal {
        vm.startPrank(seller);
        IERC721(COLLECTION).approve(address(SEAPORT), tokenId);
        Order[] memory os = new Order[](1);
        os[0] = o;
        assertTrue(SEAPORT.validate(os));
        vm.stopPrank();
    }

    function _litIds() internal view returns (uint256[] memory ids) {
        uint256 n = ignite.litCount();
        ids = new uint256[](n);
        uint256 k;
        for (uint256 w; w <= 17 && k < n; ++w) {
            uint256 bm = ignite.litBitmap(w);
            for (uint256 b; b < 256 && bm != 0; ++b) {
                if ((bm >> b) & 1 == 1) {
                    ids[k++] = w * 256 + b;
                    bm &= ~(uint256(1) << b);
                }
            }
        }
        require(k == n, "lit scan mismatch");
    }

    function _stock(address o) internal view returns (uint256 s) {
        for (uint8 i = 1; i < 8; ++i) {
            address t = pulse.stockPool(i);
            if (t != address(0)) s += IERC20(t).balanceOf(o);
        }
    }

    receive() external payable {}
}
