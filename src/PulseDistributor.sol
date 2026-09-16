// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {DialMath} from "./DialMath.sol";
import {IHopper} from "./interfaces/IHopper.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
import {IPulseDial} from "./interfaces/IPulseDial.sol";
import {IPulseRouter} from "./interfaces/IPulseRouter.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";

/// @title PulseDistributor
/// @notice When the Hopper (ETH) is at or above the current ladder threshold,
/// anyone can Pulse. Snapshots Lit membership and each Dial. Dial is assigned
/// automatically at Ignite: 1–4 Robinhood Chain Stock Tokens from an 8-token
/// owner allowlist, by shell class (ALPHA 1 / BETA 2 / DELTA 3 / OMEGA 4).
/// Holders do not pick. Dialed Lit claims swap that share to those stocks.
/// Undialed Lit (no assignment, or assigned slots still address(0)) buy `$TERM`
/// via the same router and credit the TBA (or owner). Hopper itself stays ETH.
/// Dormant earn 0.
///
/// Pulse ladder (ETH in Hopper `available()`):
///   Bootstrap (first time only): 0.1, 0.2, … 1.0 (step 0.1).
///   After a successful Pulse at 1.0 during bootstrap: 0.5, 0.6, … 1.0, then
///   back to 0.5 forever. Never returns to 0.1.
contract PulseDistributor is Ownable, ReentrancyGuard, IPulseDial {
    uint16 public constant DIAL_BPS = 10_000;
    uint8 public constant STOCK_POOL_SIZE = 8;
    uint8 public constant MAX_DIAL_LEGS = 4;
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

    /// @dev Up to 4 Stock Token legs. Empty / zero-address legs at snapshot → `$TERM`.
    struct Dial {
        address token0;
        address token1;
        address token2;
        address token3;
        uint16 weight0;
        uint16 weight1;
        uint16 weight2;
        uint16 weight3;
        uint8 slot0;
        uint8 slot1;
        uint8 slot2;
        uint8 slot3;
        uint8 nLegs;
        uint8 shellClass;
    }

    /// @notice Allowlisted Robinhood Chain Stock Tokens. Index order is hub order:
    /// HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA. Owner fills real ERC-20
    /// addresses when known. Unset slots stay `address(0)` — do not invent mainnet
    /// addresses. Optional Robinhood Chain **testnet** samples (not defaults):
    /// AMZN `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02`,
    /// TSLA `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E`
    /// (https://docs.robinhood.com/chain/contracts/).
    address[8] public stockPool;

    /// @notice Optional per-token class (1=ALPHA … 4=OMEGA). `0` → keccak derivation.
    mapping(uint256 tokenId => uint8) public shellClassOverride;

    mapping(uint256 tokenId => Dial) internal _dials;
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
    error NotLit();
    error BadDial();
    error SwapFailed();
    error TermRouterRequired();
    error BadStockSlot();
    error DuplicateStock();
    error BadShellClass();

    event PulseThresholdUpdated(uint256 threshold);
    event LadderAdvanced(bool bootstrapComplete, uint8 ladderIndex, uint256 nextThreshold);
    event DeliverToTbaUpdated(bool enabled);
    event RouterUpdated(address indexed router);
    event TermUpdated(address indexed term);
    event TbaConfigUpdated(address registry, address implementation, bytes32 salt);
    event StockTokenSet(uint8 indexed slot, address indexed token);
    event ShellClassOverrideSet(uint256 indexed tokenId, uint8 shellClass);
    event DialAssigned(uint256 indexed tokenId, uint8 shellClass, uint8 nLegs);
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

    /// @notice Set one allowlisted Stock Token. `token` may be `address(0)` (placeholder).
    function setStockToken(uint8 index, address token) external onlyOwner {
        if (index >= STOCK_POOL_SIZE) revert BadStockSlot();
        if (token != address(0)) {
            for (uint8 i; i < STOCK_POOL_SIZE; ++i) {
                if (i != index && stockPool[i] == token) revert DuplicateStock();
            }
        }
        stockPool[index] = token;
        emit StockTokenSet(index, token);
    }

    /// @notice Replace the full 8-token allowlist. Zero addresses are placeholders.
    function setStockTokens(address[8] calldata tokens) external onlyOwner {
        for (uint8 i; i < STOCK_POOL_SIZE; ++i) {
            if (tokens[i] != address(0)) {
                for (uint8 j; j < i; ++j) {
                    if (tokens[j] == tokens[i]) revert DuplicateStock();
                }
            }
            stockPool[i] = tokens[i];
            emit StockTokenSet(i, tokens[i]);
        }
    }

    /// @notice Pin generative-pack shell class so Dial count matches the PFP.
    /// `0` clears the override (keccak derivation). Call before Ignite.
    function setShellClassOverride(uint256 tokenId, uint8 shellClass) external onlyOwner {
        if (shellClass > DialMath.OMEGA) revert BadShellClass();
        collection.ownerOf(tokenId);
        shellClassOverride[tokenId] = shellClass;
        emit ShellClassOverrideSet(tokenId, shellClass);
    }

    function setShellClassOverrides(uint256[] calldata tokenIds, uint8[] calldata classes) external onlyOwner {
        if (tokenIds.length != classes.length) revert BadDial();
        for (uint256 i; i < tokenIds.length; ++i) {
            uint8 shellClass = classes[i];
            if (shellClass > DialMath.OMEGA) revert BadShellClass();
            collection.ownerOf(tokenIds[i]);
            shellClassOverride[tokenIds[i]] = shellClass;
            emit ShellClassOverrideSet(tokenIds[i], shellClass);
        }
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

    /// @notice Shell class used for Dial: override if set, else keccak(tokenId + salt).
    function shellClassOf(uint256 tokenId) public view returns (uint8) {
        uint8 over = shellClassOverride[tokenId];
        if (over != 0) return over;
        return DialMath.deriveShellClass(tokenId);
    }

    /// @notice Holder picker removed. Dial is computed from tokenId + shell class.
    function previewDial(uint256 tokenId) public view returns (Dial memory) {
        return _computeDial(tokenId);
    }

    function getDial(uint256 tokenId) external view returns (Dial memory) {
        return _dials[tokenId];
    }

    /// @notice Assign Dial once the pet is Lit. IgniteModule calls this; anyone
    /// may backfill a Lit token that missed the hook. Outcome is deterministic —
    /// callers cannot choose stocks.
    function assignDial(uint256 tokenId) public {
        if (!ignite.isLit(tokenId)) revert NotLit();
        if (_dials[tokenId].nLegs != 0) return;
        collection.ownerOf(tokenId);
        Dial memory d = _computeDial(tokenId);
        _dials[tokenId] = d;
        emit DialAssigned(tokenId, d.shellClass, d.nLegs);
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
                Dial memory d = _resolvedDial(_dials[tokenId]);
                if (_hasResolvedLeg(d)) {
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

    function _computeDial(uint256 tokenId) internal view returns (Dial memory d) {
        uint8 class_ = shellClassOf(tokenId);
        uint8 n = DialMath.legCount(class_);
        uint8[4] memory slots = DialMath.pickSlots(tokenId, n);
        uint16[4] memory weights = DialMath.splitWeights(n);
        d.nLegs = n;
        d.shellClass = class_;
        d.slot0 = slots[0];
        d.slot1 = n > 1 ? slots[1] : 0;
        d.slot2 = n > 2 ? slots[2] : 0;
        d.slot3 = n > 3 ? slots[3] : 0;
        d.weight0 = weights[0];
        d.weight1 = n > 1 ? weights[1] : 0;
        d.weight2 = n > 2 ? weights[2] : 0;
        d.weight3 = n > 3 ? weights[3] : 0;
        d.token0 = stockPool[slots[0]];
        d.token1 = n > 1 ? stockPool[slots[1]] : address(0);
        d.token2 = n > 2 ? stockPool[slots[2]] : address(0);
        d.token3 = n > 3 ? stockPool[slots[3]] : address(0);
    }

    /// @dev Re-resolve allowlist addresses from frozen slots (owner may fill tokens after Ignite).
    function _resolvedDial(Dial memory d) internal view returns (Dial memory) {
        if (d.nLegs == 0) return d;
        d.token0 = stockPool[d.slot0];
        d.token1 = d.nLegs > 1 ? stockPool[d.slot1] : address(0);
        d.token2 = d.nLegs > 2 ? stockPool[d.slot2] : address(0);
        d.token3 = d.nLegs > 3 ? stockPool[d.slot3] : address(0);
        return d;
    }

    function _hasResolvedLeg(Dial memory d) internal pure returns (bool) {
        if (d.weight0 == 0 || d.nLegs == 0) return false;
        return d.token0 != address(0) || d.token1 != address(0) || d.token2 != address(0) || d.token3 != address(0);
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
        Dial memory d = epochDial[epochId][tokenId];
        if (_hasResolvedLeg(d)) {
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
        uint256 lastIdx = type(uint256).max;
        for (uint256 i; i < MAX_DIAL_LEGS; ++i) {
            if (_tokenAt(d, i) != address(0) && _weightAt(d, i) != 0) lastIdx = i;
        }
        if (lastIdx == type(uint256).max) {
            _buyTerm(to, ethShare);
            return;
        }
        uint256 remain = ethShare;
        for (uint256 i; i <= lastIdx; ++i) {
            remain -= _swapLeg(_tokenAt(d, i), _weightAt(d, i), ethShare, remain, to, i == lastIdx);
        }
        if (remain > 0) {
            hopper.release(to, remain);
        }
    }

    function _tokenAt(Dial memory d, uint256 i) internal pure returns (address) {
        if (i == 0) return d.token0;
        if (i == 1) return d.token1;
        if (i == 2) return d.token2;
        return d.token3;
    }

    function _weightAt(Dial memory d, uint256 i) internal pure returns (uint16) {
        if (i == 0) return d.weight0;
        if (i == 1) return d.weight1;
        if (i == 2) return d.weight2;
        return d.weight3;
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
