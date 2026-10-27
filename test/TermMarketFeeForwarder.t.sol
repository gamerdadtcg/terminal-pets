// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TermMarketFeeForwarder} from "../src/TermMarketFeeForwarder.sol";
import {HopperRedirectRouter} from "../src/HopperRedirectRouter.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {ITermSwapRouter} from "../src/interfaces/ITermSwapRouter.sol";

contract T20 is ERC20 {
    constructor() ERC20("T", "T") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

/// @dev Router with a settable rate (bps of 1:1), a revert toggle, and an optional re-entrancy hook.
contract RateRouter is ITermSwapRouter {
    uint256 public rateBps = 10_000;
    bool public failing;
    address public hook; // called with `hookData` mid-swap
    bytes public hookData;

    receive() external payable {}

    function setRate(uint256 r) external {
        rateBps = r;
    }

    function setFailing(bool f) external {
        failing = f;
    }

    function setHook(address h, bytes calldata d) external {
        hook = h;
        hookData = d;
    }

    function swapExactETHForToken(address, address) external payable returns (uint256) {
        revert("unused");
    }

    function swapExactTokenForETH(address token, uint256 amountIn, address to) external returns (uint256 ethOut) {
        require(!failing, "swap failing");
        IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        if (hook != address(0)) {
            (bool ok,) = hook.call(hookData); // result intentionally ignored: attempts are expected to revert
            ok;
        }
        ethOut = (amountIn * rateBps) / 10_000;
        (bool ok2,) = to.call{value: ethOut}("");
        require(ok2, "eth out");
    }
}

contract Rejecter {
    receive() external payable {
        revert("no");
    }
}

contract GasBomb {
    uint256 public sink;

    receive() external payable {
        for (uint256 i; i < 1e6; ++i) sink += i;
    }
}

/// @dev Recipient that re-enters the forwarder on receipt.
contract ReenterOnReceive {
    TermMarketFeeForwarder public f;
    bool public reentered;
    bool public reenterSucceeded;
    bytes public data;

    function set(TermMarketFeeForwarder f_, bytes calldata d) external {
        f = f_;
        data = d;
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            (bool ok,) = address(f).call(data);
            reenterSucceeded = ok;
        }
    }
}

contract ForwarderTest is Test {
    address internal owner = makeAddr("owner");
    address internal keeper = makeAddr("keeper");
    address internal stranger = makeAddr("stranger");
    address internal treasury = makeAddr("treasury");

    T20 internal term;
    RateRouter internal router;
    HopperV2 internal hopper;
    TermMarketFeeForwarder internal fwd;

    function setUp() public {
        term = new T20();
        router = new RateRouter();
        vm.deal(address(router), 1_000_000 ether);
        hopper = new HopperV2(owner, 0, address(this)); // reveal clock unused here (address(this) just non-zero)
        fwd = new TermMarketFeeForwarder(owner, address(hopper), treasury, address(term), address(router), 150, 200);
        vm.prank(owner);
        fwd.setKeeper(keeper);
    }

    // ------------------------------------------------------------------ constructor

    function test_constructor_validations() public {
        vm.expectRevert(TermMarketFeeForwarder.BadParts.selector);
        new TermMarketFeeForwarder(owner, address(hopper), treasury, address(term), address(router), 0, 200);
        vm.expectRevert(TermMarketFeeForwarder.BadParts.selector);
        new TermMarketFeeForwarder(owner, address(hopper), treasury, address(term), address(router), 201, 200);
        vm.expectRevert(TermMarketFeeForwarder.ZeroAddress.selector);
        new TermMarketFeeForwarder(owner, address(0), treasury, address(term), address(router), 150, 200);
        vm.expectRevert(TermMarketFeeForwarder.ZeroAddress.selector);
        new TermMarketFeeForwarder(owner, address(hopper), address(0), address(term), address(router), 150, 200);
    }

    // ------------------------------------------------------------------ ETH

    function test_eth_splits75_25() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(hopper).balance, 0.75 ether);
        assertEq(treasury.balance, 0.25 ether);
        assertEq(address(fwd).balance, 0);
    }

    /// @dev Conservation: every wei in is either delivered or tracked as owed. Rounding favours the treasury.
    function testFuzz_eth_conservation(uint96 amt) public {
        vm.assume(amt > 0);
        vm.deal(address(this), amt);
        (bool ok,) = address(fwd).call{value: amt}("");
        assertTrue(ok);
        uint256 h = (uint256(amt) * 150) / 200;
        assertEq(address(hopper).balance, h);
        assertEq(treasury.balance, uint256(amt) - h);
        assertEq(address(fwd).balance, 0);
    }

    function test_eth_rejectingTreasury_doesNotRevert_andRetryDelivers() public {
        Rejecter r = new Rejecter();
        vm.prank(owner);
        fwd.setTreasury(address(r));
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        assertTrue(ok, "market trade must not be blockable by treasury");
        assertEq(address(hopper).balance, 0.75 ether);
        assertEq(fwd.owedTreasury(), 0.25 ether);
        assertEq(address(fwd).balance, 0.25 ether);

        vm.prank(owner);
        fwd.setTreasury(treasury);
        vm.prank(stranger);
        fwd.retry();
        assertEq(treasury.balance, 0.25 ether);
        assertEq(fwd.owedTreasury(), 0);
        assertEq(address(fwd).balance, 0);
    }

    function test_eth_gasBombTreasury_boundedGas() public {
        GasBomb g = new GasBomb();
        vm.prank(owner);
        fwd.setTreasury(address(g));
        vm.deal(address(this), 1 ether);
        uint256 gasBefore = gasleft();
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        uint256 used = gasBefore - gasleft();
        assertTrue(ok);
        assertLt(used, 250_000, "push gas is capped");
        assertEq(fwd.owedTreasury(), 0.25 ether);
    }

    function test_eth_pausedHopperStillReceives() public {
        vm.prank(owner);
        hopper.pause();
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(hopper).balance, 0.75 ether);
    }

    function test_eth_zeroValueIsNoop() public {
        (bool ok,) = address(fwd).call("");
        assertTrue(ok);
        assertEq(fwd.owedHopper(), 0);
    }

    function test_sync_deliversForcedEth() public {
        vm.deal(address(this), 1 ether);
        // forced send via selfdestruct-like path: deal directly to the contract's balance
        vm.deal(address(fwd), 1 ether);
        vm.prank(stranger);
        fwd.sync();
        assertEq(address(hopper).balance, 0.75 ether);
        assertEq(treasury.balance, 0.25 ether);
        assertEq(address(fwd).balance, 0);
    }

    function test_sync_doesNotDoubleCountOwed() public {
        Rejecter r = new Rejecter();
        vm.prank(owner);
        fwd.setTreasury(address(r));
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        assertTrue(ok);
        fwd.sync(); // balance == owed, nothing extra
        assertEq(fwd.owedTreasury(), 0.25 ether);
        assertEq(address(hopper).balance, 0.75 ether);
    }

    function test_reentrancy_viaRecipient_retryBlockedOrHarmless() public {
        ReenterOnReceive r = new ReenterOnReceive();
        r.set(fwd, abi.encodeCall(TermMarketFeeForwarder.retry, ()));
        vm.prank(owner);
        fwd.setTreasury(address(r));
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(fwd).call{value: 1 ether}("");
        assertTrue(ok);
        // Whatever the re-entry did, no ETH is created or lost.
        assertEq(address(hopper).balance + address(r).balance + address(fwd).balance, 1 ether);
        assertEq(address(fwd).balance, fwd.owedHopper() + fwd.owedTreasury());
    }

    // ------------------------------------------------------------------ $TERM

    function test_flushTerm_splitsAndSwaps() public {
        term.mint(address(fwd), 1_000 ether);
        vm.prank(keeper);
        fwd.flushTerm(750 ether);
        assertEq(address(hopper).balance, 750 ether);
        assertEq(term.balanceOf(treasury), 250 ether);
        assertEq(term.balanceOf(address(fwd)), 0);
        assertEq(address(fwd).balance, 0);
        assertEq(term.allowance(address(fwd), address(router)), 0);
    }

    function test_flushTerm_ownerAllowed_strangerNot() public {
        term.mint(address(fwd), 100 ether);
        vm.prank(stranger);
        vm.expectRevert(TermMarketFeeForwarder.NotKeeper.selector);
        fwd.flushTerm(0);
        vm.prank(owner);
        fwd.flushTerm(0);
    }

    function test_flushTerm_slippageRevertsAndKeepsTerm() public {
        term.mint(address(fwd), 1_000 ether);
        router.setRate(5_000); // pool got sandwiched: 50%
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(TermMarketFeeForwarder.Slippage.selector, 375 ether, 700 ether));
        fwd.flushTerm(700 ether);
        assertEq(term.balanceOf(address(fwd)), 1_000 ether, "revert is atomic: nothing moved");
        assertEq(term.balanceOf(treasury), 0);
    }

    function test_flushTerm_routerFailingRevertsAtomically() public {
        term.mint(address(fwd), 1_000 ether);
        router.setFailing(true);
        vm.prank(keeper);
        vm.expectRevert();
        fwd.flushTerm(0);
        assertEq(term.balanceOf(address(fwd)), 1_000 ether);
    }

    function test_flushTerm_routerUnset() public {
        vm.prank(owner);
        fwd.setSwapRouter(address(0));
        vm.prank(keeper);
        vm.expectRevert(TermMarketFeeForwarder.RouterUnset.selector);
        fwd.flushTerm(0);
    }

    function test_flushTerm_swapProceedsNotDoubleSplit() public {
        // swap proceeds arrive via receive() while `_swapping`; they must all go to the Hopper, not 75/25 again.
        term.mint(address(fwd), 400 ether);
        vm.prank(keeper);
        fwd.flushTerm(0);
        assertEq(address(hopper).balance, 300 ether);
        assertEq(treasury.balance, 0);
    }

    function test_flushTerm_reenterFlushDuringSwap_reverts() public {
        term.mint(address(fwd), 400 ether);
        router.setHook(address(fwd), abi.encodeCall(TermMarketFeeForwarder.flushTerm, (0)));
        vm.prank(keeper);
        fwd.flushTerm(0); // hook's inner call fails (nonReentrant + not keeper), outer completes
        assertEq(address(hopper).balance, 300 ether);
        assertEq(term.balanceOf(treasury), 100 ether);
    }

    function test_flushTerm_dust_noRevertWithZeroMin() public {
        term.mint(address(fwd), 1); // toSwap = 0, toTreasury = 1
        vm.prank(keeper);
        fwd.flushTerm(0);
        assertEq(term.balanceOf(treasury), 1);
    }

    function test_flushTerm_emptyBalanceWithMinReverts() public {
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(TermMarketFeeForwarder.Slippage.selector, 0, 1));
        fwd.flushTerm(1);
    }

    function testFuzz_flushTerm_conservation(uint96 bal, uint16 rate) public {
        bal = uint96(bound(bal, 1, 1e24));
        rate = uint16(bound(rate, 1, 10_000));
        router.setRate(rate);
        term.mint(address(fwd), bal);
        vm.prank(keeper);
        fwd.flushTerm(0);
        uint256 toSwap = (uint256(bal) * 150) / 200;
        assertEq(term.balanceOf(treasury), uint256(bal) - toSwap);
        assertEq(address(hopper).balance, (toSwap * rate) / 10_000);
        assertEq(term.balanceOf(address(fwd)), 0);
        assertEq(address(fwd).balance, 0);
    }

    // ------------------------------------------------------------------ admin

    function test_admin_onlyOwner() public {
        vm.startPrank(stranger);
        vm.expectRevert();
        fwd.setTreasury(stranger);
        vm.expectRevert();
        fwd.setSwapRouter(stranger);
        vm.expectRevert();
        fwd.setKeeper(stranger);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(TermMarketFeeForwarder.ZeroAddress.selector);
        fwd.setTreasury(address(0));
    }
}

/// @dev Soft-fail behaviour of the redirect router.
contract RedirectSoftFailTest is Test {
    T20 internal term;
    RateRouter internal inner;
    HopperRedirectRouter internal redirect;
    address internal legacy = makeAddr("legacyHopper");
    address internal v2 = makeAddr("hopperV2");
    address internal ignite = makeAddr("ignite");
    address internal market = makeAddr("market");

    function setUp() public {
        term = new T20();
        inner = new RateRouter();
        vm.deal(address(inner), 10_000 ether);
        redirect = new HopperRedirectRouter(address(inner), legacy, v2, ignite);
    }

    function _swap(address who, uint256 amt, address to) internal returns (uint256) {
        term.mint(who, amt);
        vm.startPrank(who);
        term.approve(address(redirect), amt);
        uint256 out = redirect.swapExactTokenForETH(address(term), amt, to);
        vm.stopPrank();
        return out;
    }

    function test_success_redirectsLegacyHopperToV2() public {
        _swap(ignite, 250 ether, legacy);
        assertEq(v2.balance, 250 ether);
        assertEq(legacy.balance, 0);
        assertEq(address(redirect).balance, 0);
        assertEq(term.balanceOf(address(redirect)), 0);
    }

    function test_success_otherRecipientUntouched() public {
        address other = makeAddr("other");
        _swap(market, 10 ether, other);
        assertEq(other.balance, 10 ether);
    }

    function test_igniteSwapFailure_returnsTermAndZero() public {
        inner.setFailing(true);
        term.mint(ignite, 250 ether);
        vm.startPrank(ignite);
        term.approve(address(redirect), 250 ether);
        uint256 out = redirect.swapExactTokenForETH(address(term), 250 ether, legacy);
        vm.stopPrank();
        assertEq(out, 0);
        assertEq(term.balanceOf(ignite), 250 ether, "TERM returned to Ignite escrow");
        assertEq(term.balanceOf(address(redirect)), 0);
        assertEq(term.allowance(address(redirect), address(inner)), 0);
        assertEq(v2.balance, 0);
    }

    function test_zeroRecipient_reverts() public {
        term.mint(market, 1 ether);
        vm.startPrank(market);
        term.approve(address(redirect), 1 ether);
        vm.expectRevert(HopperRedirectRouter.ZeroAddress.selector);
        redirect.swapExactTokenForETH(address(term), 1 ether, address(0));
        vm.stopPrank();
    }

    function test_nonIgniteSwapFailure_reverts() public {
        inner.setFailing(true);
        term.mint(market, 10 ether);
        vm.startPrank(market);
        term.approve(address(redirect), 10 ether);
        vm.expectRevert(HopperRedirectRouter.SwapFailed.selector);
        redirect.swapExactTokenForETH(address(term), 10 ether, legacy);
        vm.stopPrank();
        assertEq(term.balanceOf(market), 10 ether, "atomic");
    }

    function test_noFundsStuck_afterAnyPath() public {
        _swap(ignite, 5 ether, legacy);
        inner.setFailing(true);
        _swap(ignite, 5 ether, legacy);
        assertEq(address(redirect).balance, 0);
        assertEq(term.balanceOf(address(redirect)), 0);
    }
}

/// @dev Returns 200 KB of returndata. Solidity must not copy it for `(bool ok,) = to.call(...)`.
contract ReturnBomb {
    receive() external payable {
        assembly {
            return(0, 200000)
        }
    }
}

contract ReturnBombTest is Test {
    function test_returnBomb_doesNotInflateForwarderGas() public {
        T20 term = new T20();
        HopperV2 hopper = new HopperV2(address(this), 0, address(this));
        ReturnBomb b = new ReturnBomb();
        TermMarketFeeForwarder f = new TermMarketFeeForwarder(
            address(this), address(hopper), address(b), address(term), address(0), 150, 200
        );
        vm.deal(address(this), 1 ether);
        uint256 g = gasleft();
        (bool ok,) = address(f).call{value: 1 ether}("");
        uint256 used = g - gasleft();
        assertTrue(ok);
        // 200KB of memory expansion would add > 1M gas if copied.
        assertLt(used, 450_000);
    }
}
