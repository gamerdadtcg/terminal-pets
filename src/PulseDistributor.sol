// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {IHopper} from "./interfaces/IHopper.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
import {IPulseRouter} from "./interfaces/IPulseRouter.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";

/// @title PulseDistributor
/// @notice When the Hopper (ETH) is at or above the current ladder threshold,
/// anyone can Pulse. Snapshots Lit membership and each Dial. Dialed Lit claims
/// swap that share to Stock Tokens. Undialed Lit buy `$TERM` via the same
/// router and credit the TBA (or owner). Hopper itself stays ETH. Dormant earn 0.
///
/// Pulse ladder (ETH in Hopper `available()`):
///   Bootstrap (first time only): 0.1, 0.2, … 1.0 (step 0.1).
///   After a successful Pulse at 1.0 during bootstrap: 0.5, 0.6, … 1.0, then
///   back to 0.5 forever. Never returns to 0.1.
contract PulseDistributor is Ownable, ReentrancyGuard {
    uint16 public constant DIAL_BPS = 10_000;
    uint8 public constant BOOTSTRAP_LAST_INDEX = 9; // 0.1 + 9*0.1 = 1.0
    uint8 public constant CYCLE_LAST_INDEX = 5; // 0.5 + 5*0.1 = 1.0

    IHopper public immutable hopper;
    IERC721 public immutable collection;
    IIgniteModule public immutable ignite;
    uint256 public immutable maxSupply;

    /// @notice False until the bootstrap Pulse at 1.0 ETH succeeds.
    bool public bootstrapComplete;
    /// @notice Index within the current phase (bootstrap 0–9, cycle 0–5).
    uint8 public ladderIndex;

    bool public deliverToTba;
    IPulseRouter public router;
    /// @notice `$TERM` bought for undialed Lit Pulse shares. Required with `router`.
    address public term;

    IERC6551Registry public tbaRegistry;
    address public tbaImplementation;
    bytes32 public tbaSalt;

    uint256 public epochCount;

    struct EpochMeta {
        uint128 share;
        uint128 litCount;
        uint128 amount;
        bool toTba;
        bool routed;
    }

    /// @dev Up to 3 Stock Token legs. Empty / zero weights = buy `$TERM` instead.
    struct Dial {
        address token0;
        address token1;
        address token2;
        uint16 weight0;
        uint16 weight1;
        uint16 weight2;
    }

    mapping(uint256 tokenId => Dial) public dials;
    mapping(uint256 epochId => EpochMeta) public epochs;
    mapping(uint256 epochId => mapping(uint256 word => uint256)) public epochBitmap;
    mapping(uint256 epochId => mapping(uint256 word => uint256)) public claimedBitmap;
    mapping(uint256 epochId => mapping(uint256 tokenId => Dial)) public epochDial;

    error ZeroAddress();
    error HopperNotFull();
    error NoLitTerminals();
    error DustHopper();
    error NothingToClaim();
    error TbaNotConfigured();
    error NotTokenOwner();
    error NotLit();
    error BadDial();
    error SwapFailed();
    error TermRouterRequired();

    event PulseThresholdUpdated(uint256 threshold);
    event LadderAdvanced(bool bootstrapComplete, uint8 ladderIndex, uint256 nextThreshold);
    event DeliverToTbaUpdated(bool enabled);
    event RouterUpdated(address indexed router);
    event TermUpdated(address indexed term);
    event TbaConfigUpdated(address registry, address implementation, bytes32 salt);
    event DialSet(uint256 indexed tokenId, address indexed owner);
    event DialCleared(uint256 indexed tokenId);
    event Pulsed(uint256 indexed epochId, uint256 amount, uint256 share, uint256 litCount, address indexed caller);

    event Claimed(uint256 indexed tokenId, uint256 indexed epochId, address indexed to, uint256 ethAmount);

    constructor(address hopper_, address collection_, address ignite_, uint256 maxSupply_, address initialOwner)
        Ownable(initialOwner)
    {
        if (hopper_ == address(0) || collection_ == address(0) || ignite_ == address(0)) {
            revert ZeroAddress();
        }
        hopper = IHopper(hopper_);
        collection = IERC721(collection_);
        ignite = IIgniteModule(ignite_);
        maxSupply = maxSupply_;
    }

    receive() external payable {}

    function setDeliverToTba(bool enabled) external onlyOwner {
        deliverToTba = enabled;
        emit DeliverToTbaUpdated(enabled);
    }

    /// @notice Robinhood Chain DEX adapter. Required to claim undialed Lit (`$TERM`) or Dialed stocks.
    function setRouter(address router_) external onlyOwner {
        router = IPulseRouter(router_);
        emit RouterUpdated(router_);
    }

    function setTerm(address term_) external onlyOwner {
        if (term_ == address(0)) revert ZeroAddress();
        term = term_;
        emit TermUpdated(term_);
    }

    function setTbaConfig(address registry, address implementation, bytes32 salt) external onlyOwner {
        tbaRegistry = IERC6551Registry(registry);
        tbaImplementation = implementation;
        tbaSalt = salt;
        emit TbaConfigUpdated(registry, implementation, salt);
    }

    /// @notice Current Hopper `available()` required to Pulse.
    function pulseThreshold() public view returns (uint256) {
        if (!bootstrapComplete) {
            return
                CollectionConfig.PULSE_BOOTSTRAP_START_WEI + uint256(ladderIndex)
                    * CollectionConfig.PULSE_LADDER_STEP_WEI;
        }
        return CollectionConfig.PULSE_CYCLE_START_WEI + uint256(ladderIndex) * CollectionConfig.PULSE_LADDER_STEP_WEI;
    }

    /// @notice Lit owner: up to 3 Stock Token addresses, weights in bps summing to 10_000 (100%).
    function setDial(uint256 tokenId, address[] calldata tokens, uint16[] calldata weightsBps) external {
        if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (!ignite.isLit(tokenId)) revert NotLit();
        uint256 n = tokens.length;
        if (n == 0 || n > 3 || n != weightsBps.length) revert BadDial();

        uint256 sum;
        Dial memory d;
        for (uint256 i; i < n; ++i) {
            if (tokens[i] == address(0) || weightsBps[i] == 0) revert BadDial();
            for (uint256 j; j < i; ++j) {
                if (tokens[j] == tokens[i]) revert BadDial();
            }
            sum += weightsBps[i];
            if (i == 0) {
                d.token0 = tokens[i];
                d.weight0 = weightsBps[i];
            } else if (i == 1) {
                d.token1 = tokens[i];
                d.weight1 = weightsBps[i];
            } else {
                d.token2 = tokens[i];
                d.weight2 = weightsBps[i];
            }
        }
        if (sum != DIAL_BPS) revert BadDial();
        dials[tokenId] = d;
        emit DialSet(tokenId, msg.sender);
    }

    function clearDial(uint256 tokenId) external {
        if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        delete dials[tokenId];
        emit DialCleared(tokenId);
    }

    function getDial(uint256 tokenId) external view returns (Dial memory) {
        return dials[tokenId];
    }

    function canPulse() public view returns (bool) {
        uint256 lit = ignite.litCount();
        if (lit == 0) return false;
        if (!hopper.hopperUnlocked()) return false;
        uint256 avail = hopper.available();
        return avail >= pulseThreshold() && avail / lit > 0;
    }

    /// @notice Anyone may Pulse once the Hopper is full enough. Snapshots Lit + Dial.
    function pulse() external nonReentrant {
        uint256 threshold = pulseThreshold();
        uint256 avail = hopper.available();
        if (avail < threshold || avail == 0) revert HopperNotFull();

        uint256 lit = ignite.litCount();
        if (lit == 0) revert NoLitTerminals();

        uint256 share = avail / lit;
        if (share == 0) revert DustHopper();
        uint256 amount = share * lit;

        if (deliverToTba && address(tbaRegistry) == address(0)) revert TbaNotConfigured();

        uint256 id = epochCount;
        unchecked {
            epochCount = id + 1;
        }

        epochs[id] = EpochMeta({
            share: uint128(share),
            litCount: uint128(lit),
            amount: uint128(amount),
            toTba: deliverToTba,
            routed: address(router) != address(0)
        });

        uint256 words = (maxSupply >> 8) + 1;
        for (uint256 w; w < words; ++w) {
            uint256 bits = ignite.litBitmap(w);
            if (bits == 0) continue;
            epochBitmap[id][w] = bits;
            for (uint256 b; b < 256; ++b) {
                if ((bits & (1 << b)) == 0) continue;
                uint256 tokenId = (w << 8) | b;
                if (tokenId == 0 || tokenId > maxSupply) continue;
                Dial memory d = dials[tokenId];
                if (d.weight0 != 0) {
                    epochDial[id][tokenId] = d;
                }
            }
        }

        hopper.reserve(amount);
        emit Pulsed(id, amount, share, lit, msg.sender);
        _advanceLadder();
    }

    function claim(uint256 tokenId) external nonReentrant {
        if (_claim(tokenId) == 0) revert NothingToClaim();
    }

    function claimMany(uint256[] calldata tokenIds) external nonReentrant {
        uint256 paid;
        for (uint256 i; i < tokenIds.length; ++i) {
            paid += _claim(tokenIds[i]);
        }
        if (paid == 0) revert NothingToClaim();
    }

    function pending(uint256 tokenId) public view returns (uint256 amount) {
        uint256 n = epochCount;
        for (uint256 e; e < n; ++e) {
            if (_wasLit(e, tokenId) && !_wasClaimed(e, tokenId)) {
                amount += epochs[e].share;
            }
        }
    }

    function wasLitInEpoch(uint256 epochId, uint256 tokenId) external view returns (bool) {
        return _wasLit(epochId, tokenId);
    }

    function isClaimed(uint256 epochId, uint256 tokenId) external view returns (bool) {
        return _wasClaimed(epochId, tokenId);
    }

    function tbaAddress(uint256 tokenId) public view returns (address) {
        if (address(tbaRegistry) == address(0)) return address(0);
        return tbaRegistry.account(tbaImplementation, tbaSalt, block.chainid, address(collection), tokenId);
    }

    function _advanceLadder() internal {
        if (!bootstrapComplete) {
            if (ladderIndex == BOOTSTRAP_LAST_INDEX) {
                bootstrapComplete = true;
                ladderIndex = 0;
            } else {
                unchecked {
                    ladderIndex += 1;
                }
            }
        } else if (ladderIndex == CYCLE_LAST_INDEX) {
            ladderIndex = 0;
        } else {
            unchecked {
                ladderIndex += 1;
            }
        }
        uint256 next = pulseThreshold();
        emit PulseThresholdUpdated(next);
        emit LadderAdvanced(bootstrapComplete, ladderIndex, next);
    }

    function _claim(uint256 tokenId) internal returns (uint256 paid) {
        collection.ownerOf(tokenId);
        uint256 n = epochCount;
        for (uint256 e; e < n; ++e) {
            if (!_wasLit(e, tokenId) || _wasClaimed(e, tokenId)) continue;
            _markClaimed(e, tokenId);
            uint256 share = epochs[e].share;
            address to = _recipient(e, tokenId);
            _payout(e, tokenId, to, share);
            paid += share;
            emit Claimed(tokenId, e, to, share);
        }
    }

    function _payout(uint256 epochId, uint256 tokenId, address to, uint256 ethShare) internal {
        if (epochDial[epochId][tokenId].weight0 != 0) {
            _payoutDialed(epochId, tokenId, to, ethShare);
        } else {
            _buyTerm(to, ethShare);
        }
    }

    function _payoutDialed(uint256 epochId, uint256 tokenId, address to, uint256 ethShare) internal {
        if (!epochs[epochId].routed || address(router) == address(0)) {
            hopper.release(to, ethShare);
            return;
        }
        Dial memory d = epochDial[epochId][tokenId];
        uint256 remain = ethShare;
        remain -= _swapLeg(d.token0, d.weight0, ethShare, remain, to, d.weight1 == 0 && d.weight2 == 0);
        remain -= _swapLeg(d.token1, d.weight1, ethShare, remain, to, d.weight2 == 0);
        remain -= _swapLeg(d.token2, d.weight2, ethShare, remain, to, true);
        if (remain > 0) {
            hopper.release(to, remain);
        }
    }

    function _buyTerm(address to, uint256 ethShare) internal {
        if (address(router) == address(0) || term == address(0)) revert TermRouterRequired();
        hopper.release(address(this), ethShare);
        try router.swapExactETHForToken{value: ethShare}(term, to) returns (uint256) {}
        catch {
            revert SwapFailed();
        }
    }

    function _swapLeg(address token, uint16 weight, uint256 ethShare, uint256 remain, address to, bool last)
        internal
        returns (uint256 spent)
    {
        if (weight == 0 || token == address(0) || remain == 0) return 0;
        spent = last ? remain : (ethShare * weight) / DIAL_BPS;
        if (spent > remain) spent = remain;
        hopper.release(address(this), spent);
        try router.swapExactETHForToken{value: spent}(token, to) returns (uint256) {}
        catch {
            revert SwapFailed();
        }
    }

    function _recipient(uint256 epochId, uint256 tokenId) internal view returns (address) {
        if (epochs[epochId].toTba) {
            return tbaRegistry.account(tbaImplementation, tbaSalt, block.chainid, address(collection), tokenId);
        }
        return collection.ownerOf(tokenId);
    }

    function _wasLit(uint256 epochId, uint256 tokenId) internal view returns (bool) {
        return (epochBitmap[epochId][tokenId >> 8] & (1 << (tokenId & 0xff))) != 0;
    }

    function _wasClaimed(uint256 epochId, uint256 tokenId) internal view returns (bool) {
        return (claimedBitmap[epochId][tokenId >> 8] & (1 << (tokenId & 0xff))) != 0;
    }

    function _markClaimed(uint256 epochId, uint256 tokenId) internal {
        claimedBitmap[epochId][tokenId >> 8] |= (1 << (tokenId & 0xff));
    }
}
