// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {IERC20Burnable} from "./interfaces/IERC20Burnable.sol";
import {IHopper} from "./interfaces/IHopper.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
import {ITermFund} from "./interfaces/ITermFund.sol";
import {ITermSwapRouter} from "./interfaces/ITermSwapRouter.sol";

interface IMetadataNotify {
    function notifyMetadataUpdate(uint256 tokenId) external;
}

/// @title IgniteModule
/// @notice One-way Dormant → Lit. Hybrid payment:
///   1. `$TERM` allotment or `transferFrom` (`igniteFee`), split:
///        25% → ETH → Hopper (or `pendingHopperTerm` until a swap router is set)
///        37.5% → burn
///        37.5% → stays in this module as allotment-escrow refill (not treasury)
///   2. Exact `igniteFeeEth` ETH, split:
///        50% → Hopper (ETH)
///        50% → buy `$TERM` via `swapRouter` → burn
///      Not TermFund. Not treasury. Collectors do not earn this leg.
///      Production should set `swapRouter` before collectors Ignite. If unset,
///      the burn half parks as `pendingIgniteEthBurn` until `flushIgniteEthBurn`.
///
/// Per-token first-wake allotment: `MAX_SUPPLY * igniteFee` is minted into this
/// module at deploy. Each tokenId may spend that once. The 37.5% refill returns
/// tokens to the pool for other pets' first wakes — it does not un-consume this id.
contract IgniteModule is Ownable, ReentrancyGuard, IIgniteModule {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;

    IERC721 public immutable collection;
    IERC20 public immutable term;
    ITermFund public immutable termFund;
    IHopper public immutable hopper;

    uint256 public igniteFee;
    uint256 public igniteFeeEth;
    uint16 public hopperBps;
    uint16 public burnBps;
    uint16 public allotmentBps;
    uint256 public litCount;
    uint256 public pendingHopperTerm;
    /// @notice Ignite ETH burn-half parked until `swapRouter` can buy `$TERM`.
    uint256 public pendingIgniteEthBurn;

    ITermSwapRouter public swapRouter;
    bool public igniteEnabled;

    mapping(uint256 tokenId => bool) private _ignited;
    mapping(uint256 word => uint256) private _litWord;
    mapping(uint256 tokenId => bool) private _allotmentConsumed;

    error ZeroAddress();
    error NotTokenOwner();
    error AlreadyLit();
    error InsufficientFee();
    error InsufficientAllotment();
    error AllotmentConsumed();
    error WrongEthFee();
    error BadBps();
    error RouterUnset();
    error NothingPending();
    error SwapFailed();
    error IgniteClosed();
    error NotLauncher();

    event IgniteFeeUpdated(uint256 fee);
    event IgniteFeeEthUpdated(uint256 fee);
    event FeeBpsUpdated(uint16 hopperBps, uint16 burnBps, uint16 allotmentBps);
    event SwapRouterUpdated(address indexed router);
    event IgniteEnabled(uint256 timestamp);
    event IgniteAllotmentClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event HopperTermFlushed(uint256 termIn, uint256 ethOut);
    event IgniteEthBurnFlushed(uint256 ethIn, uint256 termBurned);
    event IgniteEthRouted(uint256 toHopper, uint256 ethForBurn, uint256 termBurned, bool burnedNow);
    event Ignited(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 termFee,
        uint256 burned,
        uint256 toAllotment,
        uint256 hopperTerm,
        uint256 ethFee
    );

    constructor(
        address collection_,
        address term_,
        address hopper_,
        address initialOwner,
        uint256 igniteFee_,
        address termFund_,
        uint256 igniteFeeEth_
    ) Ownable(initialOwner) {
        if (collection_ == address(0) || term_ == address(0) || hopper_ == address(0) || termFund_ == address(0)) {
            revert ZeroAddress();
        }
        collection = IERC721(collection_);
        term = IERC20(term_);
        hopper = IHopper(hopper_);
        igniteFee = igniteFee_;
        hopperBps = CollectionConfig.IGNITE_HOPPER_BPS;
        burnBps = CollectionConfig.IGNITE_BURN_BPS;
        allotmentBps = CollectionConfig.IGNITE_ALLOTMENT_REFILL_BPS;
        termFund = ITermFund(termFund_);
        igniteFeeEth = igniteFeeEth_;
    }

    function setIgniteFee(uint256 fee) external onlyOwner {
        igniteFee = fee;
        emit IgniteFeeUpdated(fee);
    }

    function setIgniteFeeEth(uint256 fee) external onlyOwner {
        igniteFeeEth = fee;
        emit IgniteFeeEthUpdated(fee);
    }

    /// @notice Retune Ignite `$TERM` cuts. Must sum to 10_000 bps.
    function setFeeBps(uint16 hopperBps_, uint16 burnBps_, uint16 allotmentBps_) external onlyOwner {
        if (uint256(hopperBps_) + burnBps_ + allotmentBps_ != BPS) revert BadBps();
        hopperBps = hopperBps_;
        burnBps = burnBps_;
        allotmentBps = allotmentBps_;
        emit FeeBpsUpdated(hopperBps_, burnBps_, allotmentBps_);
    }

    function setSwapRouter(address router_) external onlyOwner {
        swapRouter = ITermSwapRouter(router_);
        emit SwapRouterUpdated(router_);
    }

    /// @notice Owner or CollectionNFT.reveal(). Starts false (pre-reveal).
    function setIgniteEnabled(bool enabled) external {
        if (msg.sender != owner() && msg.sender != address(collection)) revert NotLauncher();
        igniteEnabled = enabled;
        if (enabled) emit IgniteEnabled(block.timestamp);
    }

    function quote(uint256 fee) public view returns (uint256 hopperCut, uint256 burnCut, uint256 allotmentCut) {
        hopperCut = (fee * hopperBps) / BPS;
        burnCut = (fee * burnBps) / BPS;
        allotmentCut = fee - hopperCut - burnCut;
    }

    /// @notice Split of the Ignite ETH fee: Hopper vs buy-and-burn `$TERM`.
    function quoteEth(uint256 fee) public pure returns (uint256 hopperCut, uint256 burnCut) {
        hopperCut = (fee * CollectionConfig.IGNITE_ETH_HOPPER_BPS) / BPS;
        burnCut = fee - hopperCut;
    }

    /// @notice `$TERM` still reserved for unspent first-wake allotments.
    /// Excludes the Hopper cut parked here until a swap router can convert it.
    function allotmentBalance() public view returns (uint256) {
        uint256 bal = term.balanceOf(address(this));
        return bal > pendingHopperTerm ? bal - pendingHopperTerm : 0;
    }

    /// @notice Pull one Ignite's worth of `$TERM` to the owner while Dormant.
    /// After this, `ignite` requires `transferFrom` (approve this module).
    function claimIgniteAllotment(uint256 tokenId) external nonReentrant {
        if (!igniteEnabled) revert IgniteClosed();
        if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_ignited[tokenId]) revert AlreadyLit();
        if (_allotmentConsumed[tokenId]) revert AllotmentConsumed();

        uint256 fee = igniteFee;
        if (fee == 0) revert InsufficientFee();
        if (allotmentBalance() < fee) revert InsufficientAllotment();

        _allotmentConsumed[tokenId] = true;
        term.safeTransfer(msg.sender, fee);
        emit IgniteAllotmentClaimed(tokenId, msg.sender, fee);
    }

    /// @notice Convert parked Hopper `$TERM` to ETH once `swapRouter` is set.
    /// Does not touch allotment escrow.
    function flushHopperTerm() external nonReentrant {
        uint256 amount = pendingHopperTerm;
        if (amount == 0) revert NothingPending();
        if (address(swapRouter) == address(0)) revert RouterUnset();
        pendingHopperTerm = 0;
        uint256 ethOut = _swapTermToHopper(amount);
        emit HopperTermFlushed(amount, ethOut);
    }

    /// @notice Convert parked Ignite-ETH burn-half to `$TERM` and burn.
    /// Requires `swapRouter`. Does not touch allotment escrow or Hopper ETH.
    function flushIgniteEthBurn() external nonReentrant {
        uint256 amount = pendingIgniteEthBurn;
        if (amount == 0) revert NothingPending();
        if (address(swapRouter) == address(0)) revert RouterUnset();
        pendingIgniteEthBurn = 0;
        uint256 termBurned = _buyTermAndBurn(amount);
        emit IgniteEthBurnFlushed(amount, termBurned);
    }

    /// @notice One-way Dormant → Lit. Requires exact `igniteFeeEth` plus `$TERM`
    /// (allotment escrow or allowance). ETH: 50% Hopper / 50% buy `$TERM` and burn.
    /// 25% of `$TERM` becomes Hopper ETH when a swap router is set.
    function ignite(uint256 tokenId) external payable nonReentrant {
        if (!igniteEnabled) revert IgniteClosed();
        if (msg.value != igniteFeeEth) revert WrongEthFee();
        if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_ignited[tokenId]) revert AlreadyLit();

        uint256 fee = igniteFee;
        if (fee == 0) revert InsufficientFee();

        if (!_allotmentConsumed[tokenId]) {
            if (allotmentBalance() < fee) revert InsufficientAllotment();
            _allotmentConsumed[tokenId] = true;
        } else {
            term.safeTransferFrom(msg.sender, address(this), fee);
        }

        (uint256 hopperCut, uint256 burnCut, uint256 allotmentCut) = quote(fee);
        if (burnCut > 0) {
            IERC20Burnable(address(term)).burn(burnCut);
        }
        // allotmentCut stays on this contract (escrow refill). Not treasury. Not TermFund.
        if (hopperCut > 0) {
            if (address(swapRouter) == address(0)) {
                pendingHopperTerm += hopperCut;
            } else {
                _swapTermToHopper(hopperCut);
            }
        }

        uint256 ethFee = msg.value;
        if (ethFee > 0) {
            _routeIgniteEth(ethFee);
        }

        _ignited[tokenId] = true;
        _litWord[tokenId >> 8] |= (1 << (tokenId & 0xff));
        unchecked {
            litCount += 1;
        }

        emit Ignited(tokenId, msg.sender, fee, burnCut, allotmentCut, hopperCut, ethFee);
        IMetadataNotify(address(collection)).notifyMetadataUpdate(tokenId);
    }

    function isLit(uint256 tokenId) public view returns (bool) {
        return _ignited[tokenId];
    }

    function litBitmap(uint256 word) external view returns (uint256) {
        return _litWord[word];
    }

    function allotmentConsumed(uint256 tokenId) public view returns (bool) {
        return _allotmentConsumed[tokenId];
    }

    function _routeIgniteEth(uint256 ethFee) internal {
        (uint256 toHopper, uint256 toBurn) = quoteEth(ethFee);
        if (toHopper > 0) {
            hopper.deposit{value: toHopper}();
        }
        uint256 termBurned;
        bool burnedNow;
        if (toBurn > 0) {
            if (address(swapRouter) == address(0)) {
                pendingIgniteEthBurn += toBurn;
            } else {
                termBurned = _buyTermAndBurn(toBurn);
                burnedNow = true;
            }
        }
        emit IgniteEthRouted(toHopper, toBurn, termBurned, burnedNow);
    }

    function _buyTermAndBurn(uint256 ethIn) internal returns (uint256 termBurned) {
        uint256 termBefore = term.balanceOf(address(this));
        try swapRouter.swapExactETHForToken{value: ethIn}(address(term), address(this)) returns (uint256) {}
        catch {
            revert SwapFailed();
        }
        termBurned = term.balanceOf(address(this)) - termBefore;
        if (termBurned > 0) {
            IERC20Burnable(address(term)).burn(termBurned);
        }
    }

    function _swapTermToHopper(uint256 termIn) internal returns (uint256 ethOut) {
        uint256 hopBefore = address(hopper).balance;
        term.forceApprove(address(swapRouter), termIn);
        try swapRouter.swapExactTokenForETH(address(term), termIn, address(hopper)) returns (uint256) {}
        catch {
            revert SwapFailed();
        }
        term.forceApprove(address(swapRouter), 0);
        ethOut = address(hopper).balance - hopBefore;
    }
}
