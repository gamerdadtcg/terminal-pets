// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {RoyaltySplitterV2} from "../src/RoyaltySplitterV2.sol";

/// WETH9 behaviour: `withdraw` pays with `transfer` (2300 gas stipend).
contract WETH9Mock is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    receive() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}

contract Tok is ERC20 {
    constructor() ERC20("Tok", "TOK") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract RevertingTok is ERC20 {
    constructor() ERC20("Bad", "BAD") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("nope");
    }
}

contract Sink {
    bool public reject;
    uint256 public received;

    function setReject(bool r) external {
        reject = r;
    }

    receive() external payable {
        require(!reject, "no");
        received += msg.value;
    }

    function callSetTreasury(RoyaltySplitterV2 s, address t) external {
        s.setTreasury(t);
    }
}

contract Bomb {
    uint256 public sink;
    bool public ret;

    function set(bool r) external {
        ret = r;
    }

    receive() external payable {
        if (ret) {
            assembly {
                return(0, 200000)
            }
        }
        for (uint256 i; i < 1e6; ++i) sink += i;
    }
}

contract Reenter {
    RoyaltySplitterV2 public s;
    bytes public data;
    bool public done;
    bool public ok;
    uint256 public received;

    function set(RoyaltySplitterV2 s_, bytes calldata d) external {
        s = s_;
        data = d;
    }

    receive() external payable {
        received += msg.value;
        if (!done) {
            done = true;
            (ok,) = address(s).call(data);
        }
    }
}

/// Payers the way marketplaces pay: transfer (2300), send, call with all gas.
contract Payer {
    function viaTransfer(address to) external payable {
        payable(to).transfer(msg.value);
    }

    function viaSend(address to) external payable returns (bool ok) {
        ok = payable(to).send(msg.value);
    }

    function viaCall(address to) external payable returns (bool ok) {
        (ok,) = to.call{value: msg.value}("");
    }
}

contract RoyaltySplitterV2Test is Test {
    HopperV2 internal hopper;
    WETH9Mock internal weth;
    Sink internal treasury;
    RoyaltySplitterV2 internal s;
    Payer internal payer;

    function setUp() public {
        hopper = new HopperV2(address(this), 0, address(this));
        weth = new WETH9Mock();
        treasury = new Sink();
        s = new RoyaltySplitterV2(address(hopper), address(treasury), address(weth));
        payer = new Payer();
        vm.deal(address(this), 1_000 ether);
    }

    // ------------------------------------------------------------ receive gas

    function test_receive_worksWith2300GasStipend_transfer() public {
        payer.viaTransfer{value: 1 ether}(address(s));
        assertEq(address(s).balance, 1 ether);
    }

    function test_receive_worksWith2300GasStipend_send() public {
        assertTrue(payer.viaSend{value: 1 ether}(address(s)));
        assertEq(address(s).balance, 1 ether);
    }

    /// A value call with `gas: 0` gives the callee exactly the 2300 stipend.
    function test_receive_exactly2300gas_viaGasZeroCall() public {
        (bool ok,) = address(s).call{value: 1 ether, gas: 0}("");
        assertTrue(ok);
        assertEq(address(s).balance, 1 ether);
    }

    function test_receive_doesNotPushOrWriteStorage() public {
        payer.viaCall{value: 3 ether}(address(s));
        assertEq(address(hopper).balance, 0);
        assertEq(address(treasury).balance, 0);
        assertEq(s.owedHopper() + s.owedTreasury(), 0);
        assertEq(s.pending(), 3 ether);
    }

    // ------------------------------------------------------------------ split

    function test_distribute_splitsTwoThirdsOneThird() public {
        payer.viaCall{value: 3 ether}(address(s));
        s.distribute();
        assertEq(address(hopper).balance, 2 ether);
        assertEq(address(treasury).balance, 1 ether);
        assertEq(address(s).balance, 0);
    }

    function test_distribute_remainderToTreasury() public {
        payer.viaCall{value: 10}(address(s)); // 6 / 4
        s.distribute();
        assertEq(address(hopper).balance, 6);
        assertEq(address(treasury).balance, 4);
        (uint256 h, uint256 t) = s.preview(10);
        assertEq(h, 6);
        assertEq(t, 4);
    }

    function test_distribute_matchesV1Math_twoThirds() public {
        // V1 RoyaltySplitter: hopper = amount*2/3 (floor), treasury = amount/3 (floor), dust stays.
        // V2 sends the dust to the treasury instead of leaving it stuck. Hopper side is identical.
        uint256 amt = 7 ether + 5;
        payer.viaCall{value: amt}(address(s));
        s.distribute();
        assertEq(address(hopper).balance, (amt * 2) / 3);
        assertEq(address(treasury).balance, amt - (amt * 2) / 3);
    }

    function testFuzz_distribute_conservedAndExact(uint96 a, uint96 b, uint96 c) public {
        uint256 total;
        uint96[3] memory xs = [a, b, c];
        for (uint256 i; i < 3; ++i) {
            if (xs[i] == 0) continue;
            vm.deal(address(this), xs[i]);
            payer.viaCall{value: xs[i]}(address(s));
            total += xs[i];
            if (i == 1) s.distribute(); // distribute mid-way
        }
        s.distribute();
        assertEq(address(hopper).balance + address(treasury).balance, total, "conserved");
        assertEq(address(s).balance, 0, "no stuck funds");
        // exact within rounding: hopper lies within 1 wei per distribution of 2/3
        uint256 exact = (total * 2) / 3;
        assertLe(address(hopper).balance, exact);
        assertGe(address(hopper).balance + 2, exact);
    }

    function test_distribute_noOpWhenEmpty() public {
        s.distribute();
        assertEq(address(s).balance, 0);
    }

    function test_distribute_isPermissionless() public {
        payer.viaCall{value: 3 ether}(address(s));
        vm.prank(makeAddr("rando"));
        s.distribute();
        assertEq(address(hopper).balance, 2 ether);
    }

    function test_forcedEth_selfdestructStyle_isDistributed() public {
        vm.deal(address(s), 6 ether); // bypasses receive()
        s.distribute();
        assertEq(address(hopper).balance, 4 ether);
        assertEq(address(treasury).balance, 2 ether);
    }

    function test_hopperV2Accounting_depositEvent_andAvailable() public {
        payer.viaCall{value: 3 ether}(address(s));
        vm.expectEmit(true, false, false, true, address(hopper));
        emit HopperV2.Deposited(address(s), 2 ether);
        s.distribute();
        assertEq(hopper.available(), 2 ether);
    }

    // ------------------------------------------------------- failing recipients

    function test_rejectingTreasury_hopperStillPaid_thenRetry() public {
        treasury.setReject(true);
        payer.viaCall{value: 3 ether}(address(s));
        s.distribute();
        assertEq(address(hopper).balance, 2 ether);
        assertEq(s.owedTreasury(), 1 ether);
        assertEq(address(s).balance, 1 ether);

        // more royalties keep arriving and keep being paid to the Hopper
        payer.viaCall{value: 3 ether}(address(s));
        s.distribute();
        assertEq(address(hopper).balance, 4 ether);
        assertEq(s.owedTreasury(), 2 ether);

        treasury.setReject(false);
        s.distribute();
        assertEq(address(treasury).balance, 2 ether);
        assertEq(s.owedTreasury(), 0);
        assertEq(address(s).balance, 0);
    }

    function test_permanentlyRejectingTreasury_canBeReplacedByTreasury() public {
        Sink bad = new Sink();
        bad.setReject(true);
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(bad), address(weth));
        payer.viaCall{value: 3 ether}(address(s2));
        s2.distribute();
        assertEq(s2.owedTreasury(), 1 ether);
        // the (rejecting) treasury contract can still call setTreasury
        address fresh = makeAddr("fresh");
        bad.callSetTreasury(s2, fresh);
        s2.distribute();
        assertEq(fresh.balance, 1 ether);
    }

    function test_rejectingHopper_treasuryStillPaid() public {
        Sink badHopper = new Sink();
        badHopper.setReject(true);
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(badHopper), address(treasury), address(weth));
        payer.viaCall{value: 3 ether}(address(s2));
        s2.distribute();
        assertEq(address(treasury).balance, 1 ether);
        assertEq(s2.owedHopper(), 2 ether);
        badHopper.setReject(false);
        s2.distribute();
        assertEq(address(badHopper).balance, 2 ether);
    }

    function test_gasBombTreasury_distributeGasBounded() public {
        Bomb b = new Bomb();
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(b), address(weth));
        payer.viaCall{value: 3 ether}(address(s2));
        uint256 g = gasleft();
        s2.distribute();
        uint256 used = g - gasleft();
        assertLt(used, 350_000);
        assertEq(address(hopper).balance, 2 ether);
        assertEq(s2.owedTreasury(), 1 ether);
    }

    function test_returnBombTreasury_doesNotInflateGas() public {
        Bomb b = new Bomb();
        b.set(true);
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(b), address(weth));
        payer.viaCall{value: 3 ether}(address(s2));
        uint256 g = gasleft();
        s2.distribute();
        assertLt(g - gasleft(), 450_000);
        assertEq(address(b).balance, 1 ether);
    }

    // ------------------------------------------------------------ reentrancy

    function test_reentrancy_fromTreasury_distribute_blocked_fundsConserved() public {
        Reenter r = new Reenter();
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(r), address(weth));
        r.set(s2, abi.encodeCall(RoyaltySplitterV2.distribute, ()));
        payer.viaCall{value: 3 ether}(address(s2));
        s2.distribute();
        assertFalse(r.ok(), "reentry blocked");
        assertEq(address(r).balance, 1 ether);
        assertEq(address(hopper).balance, 2 ether);
        assertEq(address(s2).balance, 0);
    }

    function test_reentrancy_fromTreasury_unwrapAndSweep_blocked() public {
        Reenter r = new Reenter();
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(r), address(weth));
        r.set(s2, abi.encodeCall(RoyaltySplitterV2.unwrapWeth, ()));
        payer.viaCall{value: 3 ether}(address(s2));
        s2.distribute();
        assertFalse(r.ok());
    }

    function test_reentrancy_ethSentBackInsideCallback_isAccountedNotLost() public {
        // Recipient sends ETH back to the splitter from inside its callback (allowed: receive is guard-free).
        Reenter r = new Reenter();
        RoyaltySplitterV2 s2 = new RoyaltySplitterV2(address(hopper), address(r), address(weth));
        vm.deal(address(r), 0);
        r.set(s2, ""); // data ignored
        payer.viaCall{value: 3 ether}(address(s2));
        s2.distribute();
        // now r holds 1 ether; send it back as a royalty and distribute again
        vm.prank(address(r));
        (bool ok,) = address(s2).call{value: 1 ether}("");
        assertTrue(ok);
        s2.distribute();
        assertEq(address(s2).balance, 0);
        assertEq(address(hopper).balance + address(r).balance, 3 ether);
    }

    // ------------------------------------------------------------------- WETH

    function test_unwrapWeth_splitsLikeEth_with2300StipendReceive() public {
        weth.deposit{value: 9 ether}();
        weth.transfer(address(s), 9 ether);
        assertEq(address(s).balance, 0);
        s.unwrapWeth();
        assertEq(weth.balanceOf(address(s)), 0);
        assertEq(address(hopper).balance, 6 ether);
        assertEq(address(treasury).balance, 3 ether);
    }

    function test_unwrapWeth_alsoDistributesPendingEth() public {
        payer.viaCall{value: 3 ether}(address(s));
        weth.deposit{value: 3 ether}();
        weth.transfer(address(s), 3 ether);
        s.unwrapWeth();
        assertEq(address(hopper).balance, 4 ether);
        assertEq(address(treasury).balance, 2 ether);
    }

    function test_unwrapWeth_noWeth_isNoop() public {
        s.unwrapWeth();
    }

    function testFuzz_unwrapWeth_conserved(uint96 amt) public {
        vm.assume(amt > 0);
        vm.deal(address(this), amt);
        weth.deposit{value: amt}();
        weth.transfer(address(s), amt);
        s.unwrapWeth();
        assertEq(address(hopper).balance + address(treasury).balance, amt);
        assertEq(address(s).balance, 0);
    }

    function test_sweepToken_toTreasury_notWeth() public {
        Tok t = new Tok();
        t.mint(address(s), 500);
        s.sweepToken(address(t));
        assertEq(t.balanceOf(address(treasury)), 500);
        vm.expectRevert(RoyaltySplitterV2.CannotSweepWeth.selector);
        s.sweepToken(address(weth));
    }

    function test_sweepToken_badTokenOnlyBlocksItself() public {
        RevertingTok bad = new RevertingTok();
        bad.mint(address(s), 5);
        vm.expectRevert();
        s.sweepToken(address(bad));
        payer.viaCall{value: 3 ether}(address(s));
        s.distribute(); // ETH path unaffected
        assertEq(address(hopper).balance, 2 ether);
    }

    // ----------------------------------------------------------------- powers

    function test_setTreasury_onlyTreasury() public {
        address n = makeAddr("n");
        vm.expectRevert(RoyaltySplitterV2.NotTreasury.selector);
        s.setTreasury(n);
        vm.prank(address(treasury));
        s.setTreasury(n);
        assertEq(s.treasury(), n);
        vm.prank(n);
        vm.expectRevert(RoyaltySplitterV2.ZeroAddress.selector);
        s.setTreasury(address(0));
    }

    function test_noOwnerNoAdmin_hopperAndWethImmutable() public {
        // there is no owner(), pause, withdraw or setHopper selector at all
        bytes4[5] memory sels = [
            bytes4(keccak256("owner()")),
            bytes4(keccak256("pause()")),
            bytes4(keccak256("withdraw(address,uint256)")),
            bytes4(keccak256("setHopper(address)")),
            bytes4(keccak256("transferOwnership(address)"))
        ];
        for (uint256 i; i < sels.length; ++i) {
            (bool ok,) = address(s).call(abi.encodeWithSelector(sels[i]));
            assertFalse(ok);
        }
        assertEq(s.hopperV2(), address(hopper));
    }

    function test_treasuryChange_doesNotAffectOwedHopperShare() public {
        treasury.setReject(true);
        payer.viaCall{value: 3 ether}(address(s));
        s.distribute();
        address n = makeAddr("n");
        treasury.callSetTreasury(s, n);
        s.distribute();
        assertEq(n.balance, 1 ether); // treasury's owed share follows the new address
        assertEq(address(hopper).balance, 2 ether);
    }

    function test_constructor_zeroChecks() public {
        vm.expectRevert(RoyaltySplitterV2.ZeroAddress.selector);
        new RoyaltySplitterV2(address(0), address(1), address(2));
        vm.expectRevert(RoyaltySplitterV2.ZeroAddress.selector);
        new RoyaltySplitterV2(address(1), address(0), address(2));
        vm.expectRevert(RoyaltySplitterV2.ZeroAddress.selector);
        new RoyaltySplitterV2(address(1), address(2), address(0));
    }
}

// ============================================================ invariants

contract SplitterHandler is Test {
    RoyaltySplitterV2 public s;
    HopperV2 public hopper;
    WETH9Mock public weth;
    Sink public treasury;
    Payer public payer;

    uint256 public totalIn;
    uint256 public distributions;

    constructor(RoyaltySplitterV2 s_, HopperV2 h, WETH9Mock w, Sink t, Payer p) {
        s = s_;
        hopper = h;
        weth = w;
        treasury = t;
        payer = p;
    }

    function h_pay(uint96 amt, uint8 how) external {
        amt = uint96(bound(amt, 1, 50 ether));
        vm.deal(address(payer), amt);
        if (how % 3 == 0) payer.viaTransfer{value: amt}(address(s));
        else if (how % 3 == 1) payer.viaSend{value: amt}(address(s));
        else payer.viaCall{value: amt}(address(s));
        totalIn += amt;
    }

    function h_payWeth(uint96 amt) external {
        amt = uint96(bound(amt, 1, 50 ether));
        vm.deal(address(this), amt);
        weth.deposit{value: amt}();
        weth.transfer(address(s), amt);
        totalIn += amt;
    }

    function h_force(uint96 amt) external {
        amt = uint96(bound(amt, 1, 5 ether));
        vm.deal(address(s), address(s).balance + amt);
        totalIn += amt;
    }

    function h_distribute() external {
        s.distribute();
        ++distributions;
    }

    function h_unwrap() external {
        s.unwrapWeth();
        ++distributions;
    }

    function h_toggleTreasury(bool rejectIt) external {
        treasury.setReject(rejectIt);
    }
}

contract RoyaltySplitterV2InvariantTest is StdInvariant, Test {
    HopperV2 internal hopper;
    WETH9Mock internal weth;
    Sink internal treasury;
    RoyaltySplitterV2 internal s;
    SplitterHandler internal h;

    function setUp() public {
        hopper = new HopperV2(address(this), 0, address(this));
        weth = new WETH9Mock();
        treasury = new Sink();
        s = new RoyaltySplitterV2(address(hopper), address(treasury), address(weth));
        h = new SplitterHandler(s, hopper, weth, treasury, new Payer());
        targetContract(address(h));
    }

    /// every wei that came in is at the Hopper, the treasury, owed, or still pending in the splitter
    function invariant_fundsConserved() public view {
        uint256 wethBal = weth.balanceOf(address(s)); // not yet unwrapped (still counted in totalIn)
        assertEq(address(hopper).balance + treasury.received() + address(s).balance + wethBal, h.totalIn());
    }

    function invariant_owedBackedByBalance() public view {
        assertLe(s.owedHopper() + s.owedTreasury(), address(s).balance);
    }

    /// Hopper never receives more than 2/3 of the money in, and never less than 2/3 minus rounding dust
    /// (1 wei per accounted batch), counting what is still owed.
    function invariant_hopperShareExactWithinRounding() public view {
        uint256 settledIn = h.totalIn() - weth.balanceOf(address(s)) - s.pending();
        uint256 hopperTotal = address(hopper).balance + s.owedHopper();
        uint256 exact = (settledIn * 2) / 3;
        assertLe(hopperTotal, exact + 1);
        assertGe(hopperTotal + 1 + h.distributions() * 1, exact);
    }

    function invariant_afterDistributeNothingStuckWhenRecipientsHealthy() public {
        treasury.setReject(false);
        s.unwrapWeth();
        assertEq(address(s).balance, 0);
        assertEq(s.owedHopper() + s.owedTreasury(), 0);
    }
}
