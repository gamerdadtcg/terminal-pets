// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {DialMath} from "./DialMath.sol";
import {IHopperV2} from "./interfaces/IHopperV2.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
import {IPulseDial} from "./interfaces/IPulseDial.sol";
import {IPulseRouter} from "./interfaces/IPulseRouter.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";

/// @title PulseDistributorV2
/// @notice Replacement for `PulseDistributor`. Same product (Pulse ladder, Dial
/// stocks, `$TERM` for undialed Lit, Dormant earn 0) with the scaling and
/// liveness bugs removed.
///
/// What changed vs V1 (see docs/PULSE_V2_DESIGN.md)
/// -------------------------------------------------
/// 1. `pulse()` is O(1). V1 looped the whole lit bitmap and copied every Dial
///    into per-epoch storage (~94k gas per Lit pet, unusable past ~340 Lit
///    under a ~32M tx gas cap). V2 never snapshots the set. Instead each pet
///    records the epoch at which it became eligible (`assignDial`, called by
///    IgniteModule at Ignite time, or permissionlessly via `registerLit`
///    for pets lit before this contract was wired). An epoch's payee set is
///    exactly "pets with `litFrom <= epoch`", and `pulse()` reverts unless
///    `registeredCount == ignite.litCount()`, so the set size used for the
///    share is always exact.
/// 2. Claims cost O(1) in the number of epochs. `cumShare[e]` is the per-pet
///    ETH paid by epochs `< e`; a claim pays `cumShare[end] - cumShare[start]`.
///    `claimUpTo` lets a pet claim a prefix of its unpaid epochs.
/// 3. A failed swap never reverts a claim. The leg's ETH is sent to the
///    recipient as plain ETH (`SwapSkipped`); if the recipient cannot take ETH
///    it is credited to the pet (`creditOf`) for `withdrawCredit`.
/// 4. Stock tokens are resolved at claim time from the pet's frozen slots (one
///    packed storage word per pet). Router / TBA / `deliverToTba` settings are
///    likewise read at claim time. No router (or no `$TERM` for undialed)
///    pays ETH instead of reverting.
/// 5. Funds live in `HopperV2`, which can pause and has a timelocked
///    emergency withdraw.
///
/// Pulse ladder (ETH in Hopper `available()`), constructor immutables
/// (`0` → CollectionConfig defaults 0.1 / 0.5 / 0.1) — unchanged from V1:
///   Bootstrap (first time only): start, start+step, … start+9*step (0.1→1.0).
///   Then cycle: cycle, cycle+step, … cycle+5*step (0.5→1.0), repeat forever.
contract PulseDistributorV2 is Ownable, ReentrancyGuard, IPulseDial {
    uint16 public constant DIAL_BPS = 10_000;
    uint8 public constant STOCK_POOL_SIZE = 8;
    uint8 public constant MAX_DIAL_LEGS = 4;
    uint8 public constant BOOTSTRAP_LAST_INDEX = 9; // 0.1 + 9*0.1 = 1.0
    uint8 public constant CYCLE_LAST_INDEX = 5; // 0.5 + 5*0.1 = 1.0
    /// @dev Gas forwarded to a recipient on the plain-ETH fallback path.
    uint256 public constant SEND_GAS = 100_000;

    IHopperV2 public immutable hopper;
    IERC721 public immutable collection;
    IIgniteModule public immutable ignite;
    uint256 public immutable maxSupply;
    uint256 public immutable bootstrapStart;
    uint256 public immutable cycleStart;
    uint256 public immutable ladderStep;

    bool public bootstrapComplete;
    uint8 public ladderIndex;

    bool public deliverToTba;
    IPulseRouter public router;
    address public term;

    IERC6551Registry public tbaRegistry;
    address public tbaImplementation;
    bytes32 public tbaSalt;

    uint256 public epochCount;
    /// @notice Pets whose Dial / `litFrom` are recorded. Must equal `ignite.litCount()` to Pulse.
    uint256 public registeredCount;

    struct EpochMeta {
        uint128 share; // ETH per Lit pet
        uint128 litCount;
        uint128 amount; // share * litCount, reserved in the Hopper
        uint64 timestamp;
    }

    /// @dev One packed storage word. Token addresses are resolved from `stockPool` at claim time.
    struct Dial {
        uint8 slot0;
        uint8 slot1;
        uint8 slot2;
        uint8 slot3;
        uint16 weight0;
        uint16 weight1;
        uint16 weight2;
        uint16 weight3;
        uint8 nLegs;
        uint8 shellClass;
    }

    /// @notice Allowlisted Robinhood Chain Stock Tokens. Slot 0 unused; slots 1–7:
    /// AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA.
    address[8] public stockPool;
    mapping(uint256 tokenId => uint8) public shellClassOverride;

    mapping(uint256 tokenId => Dial) internal _dials;
    mapping(uint256 epochId => EpochMeta) public epochs;
    /// @notice Sum of per-pet shares of all epochs `< e`. `cumShare[0] == 0`.
    mapping(uint256 e => uint256) public cumShare;
    /// @notice `epoch + 1` at which the pet became eligible. 0 = not registered.
    mapping(uint256 tokenId => uint256) public litFromPlus1;
    /// @notice Next epoch the pet has NOT been paid for (cursor). Effective start is `max(this, litFrom)`.
    mapping(uint256 tokenId => uint256) public claimedThrough;
    /// @notice ETH owed to a pet that the recipient could not receive. Pull with `withdrawCredit`.
    mapping(uint256 tokenId => uint256) public creditOf;

    error ZeroAddress();
    error HopperNotFull();
    error NoLitTerminals();
    error DustHopper();
    error NothingToClaim();
    error TbaNotConfigured();
    error NotLit();
    error BadDial();
    error BadStockSlot();
    error DuplicateStock();
    error BadShellClass();
    error UnregisteredLit(uint256 registered, uint256 lit);
    error BadTokenId();
    error NotTokenOwner();
    error NoCredit();
    error TransferFailed();

    event PulseThresholdUpdated(uint256 threshold);
    event LadderAdvanced(bool bootstrapComplete, uint8 ladderIndex, uint256 nextThreshold);
    event DeliverToTbaUpdated(bool enabled);
    event RouterUpdated(address indexed router);
    event TermUpdated(address indexed term);
    event TbaConfigUpdated(address registry, address implementation, bytes32 salt);
    event StockTokenSet(uint8 indexed slot, address indexed token);
    event ShellClassOverrideSet(uint256 indexed tokenId, uint8 shellClass);
    event DialAssigned(uint256 indexed tokenId, uint8 shellClass, uint8 nLegs, uint256 litFromEpoch);
    event Pulsed(uint256 indexed epochId, uint256 amount, uint256 share, uint256 litCount, address indexed caller);
    /// @dev Pays epochs `[fromEpoch, toEpoch)` for the pet.
    event Claimed(
        uint256 indexed tokenId, uint256 fromEpoch, uint256 toEpoch, address indexed to, uint256 ethAmount
    );
    event SwapSkipped(uint256 indexed tokenId, address indexed token, uint256 ethAmount);
    event CreditAccrued(uint256 indexed tokenId, uint256 ethAmount);
    event CreditWithdrawn(uint256 indexed tokenId, address indexed to, uint256 ethAmount);

    constructor(
        address hopper_,
        address collection_,
        address ignite_,
        uint256 maxSupply_,
        address initialOwner,
        uint256 bootstrapStart_,
        uint256 cycleStart_,
        uint256 ladderStep_
    ) Ownable(initialOwner) {
        if (hopper_ == address(0) || collection_ == address(0) || ignite_ == address(0)) {
            revert ZeroAddress();
        }
        hopper = IHopperV2(hopper_);
        collection = IERC721(collection_);
        ignite = IIgniteModule(ignite_);
        maxSupply = maxSupply_;
        bootstrapStart = bootstrapStart_ == 0 ? CollectionConfig.PULSE_BOOTSTRAP_START_WEI : bootstrapStart_;
        cycleStart = cycleStart_ == 0 ? CollectionConfig.PULSE_CYCLE_START_WEI : cycleStart_;
        ladderStep = ladderStep_ == 0 ? CollectionConfig.PULSE_LADDER_STEP_WEI : ladderStep_;
    }

    receive() external payable {}

    // ------------------------------------------------------------------- owner

    function setDeliverToTba(bool enabled) external onlyOwner {
        if (enabled && address(tbaRegistry) == address(0)) revert TbaNotConfigured();
        deliverToTba = enabled;
        emit DeliverToTbaUpdated(enabled);
    }

    /// @notice DEX adapter. Unset → every claim pays plain ETH.
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
        if (registry == address(0)) deliverToTba = false;
        emit TbaConfigUpdated(registry, implementation, salt);
    }

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

    /// @notice Pin generative-pack shell class. Only affects pets not yet registered.
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

    // ------------------------------------------------------------------- views

    function pulseThreshold() public view returns (uint256) {
        if (!bootstrapComplete) {
            return bootstrapStart + uint256(ladderIndex) * ladderStep;
        }
        return cycleStart + uint256(ladderIndex) * ladderStep;
    }

    function shellClassOf(uint256 tokenId) public view returns (uint8) {
        uint8 over = shellClassOverride[tokenId];
        if (over != 0) return over;
        return DialMath.deriveShellClass(tokenId);
    }

    function previewDial(uint256 tokenId) public view returns (Dial memory) {
        return _computeDial(tokenId);
    }

    function getDial(uint256 tokenId) external view returns (Dial memory) {
        return _dials[tokenId];
    }

    /// @notice A registered pet's legs with token addresses resolved from the current allowlist.
    function resolvedLegs(uint256 tokenId)
        external
        view
        returns (address[4] memory tokens, uint16[4] memory weights, uint8 nLegs, uint8 shellClass)
    {
        Dial memory d = _dials[tokenId];
        nLegs = d.nLegs;
        shellClass = d.shellClass;
        for (uint256 i; i < MAX_DIAL_LEGS; ++i) {
            (tokens[i], weights[i]) = _leg(d, i);
        }
    }

    function canPulse() public view returns (bool) {
        uint256 lit = ignite.litCount();
        if (lit == 0 || lit != registeredCount) return false;
        if (!hopper.hopperUnlocked() || hopper.paused()) return false;
        uint256 avail = hopper.available();
        return avail >= pulseThreshold() && avail / lit > 0;
    }

    /// @notice First epoch the pet is eligible for. Reverts nothing: returns `type(uint256).max` if unregistered.
    function litFromEpoch(uint256 tokenId) public view returns (uint256) {
        uint256 lf = litFromPlus1[tokenId];
        return lf == 0 ? type(uint256).max : lf - 1;
    }

    /// @notice ETH the pet can claim across all closed epochs.
    function pending(uint256 tokenId) public view returns (uint256) {
        return pendingUpTo(tokenId, epochCount);
    }

    function pendingUpTo(uint256 tokenId, uint256 endEpoch) public view returns (uint256) {
        (uint256 start, uint256 end) = _range(tokenId, endEpoch);
        if (end <= start) return 0;
        return cumShare[end] - cumShare[start];
    }

    function wasLitInEpoch(uint256 epochId, uint256 tokenId) external view returns (bool) {
        uint256 lf = litFromPlus1[tokenId];
        return lf != 0 && epochId < epochCount && epochId >= lf - 1;
    }

    function isClaimed(uint256 epochId, uint256 tokenId) external view returns (bool) {
        uint256 lf = litFromPlus1[tokenId];
        return lf != 0 && epochId >= lf - 1 && epochId < claimedThrough[tokenId];
    }

    function tbaAddress(uint256 tokenId) public view returns (address) {
        if (address(tbaRegistry) == address(0)) return address(0);
        return tbaRegistry.account(tbaImplementation, tbaSalt, block.chainid, address(collection), tokenId);
    }

    // -------------------------------------------------------------------- Dial

    /// @notice Register a Lit pet: record its Dial and the epoch it becomes eligible for.
    /// IgniteModule calls this at Ignite. Anyone may backfill a Lit pet that missed the hook
    /// (`registerLit`). Outcome is deterministic; callers cannot choose stocks.
    function assignDial(uint256 tokenId) public {
        _register(tokenId);
    }

    /// @notice Batch backfill. Skips already-registered pets. Reverts on a pet that is not Lit.
    function registerLit(uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; ++i) {
            _register(tokenIds[i]);
        }
    }

    function _register(uint256 tokenId) internal {
        if (tokenId == 0 || tokenId > maxSupply) revert BadTokenId();
        if (!ignite.isLit(tokenId)) revert NotLit();
        if (litFromPlus1[tokenId] != 0) return;
        collection.ownerOf(tokenId);
        Dial memory d = _computeDial(tokenId);
        _dials[tokenId] = d;
        uint256 e = epochCount;
        litFromPlus1[tokenId] = e + 1;
        unchecked {
            registeredCount += 1;
        }
        emit DialAssigned(tokenId, d.shellClass, d.nLegs, e);
    }

    // ------------------------------------------------------------------- Pulse

    /// @notice Anyone may Pulse once the Hopper is full enough. O(1) in the Lit set.
    function pulse() external nonReentrant {
        uint256 threshold = pulseThreshold();
        uint256 avail = hopper.available();
        if (avail < threshold || avail == 0) revert HopperNotFull();

        uint256 lit = ignite.litCount();
        if (lit == 0) revert NoLitTerminals();
        if (lit != registeredCount) revert UnregisteredLit(registeredCount, lit);

        uint256 share = avail / lit;
        if (share == 0) revert DustHopper();
        uint256 amount = share * lit;

        uint256 id = epochCount;
        unchecked {
            epochCount = id + 1;
        }
        epochs[id] = EpochMeta({
            share: uint128(share),
            litCount: uint128(lit),
            amount: uint128(amount),
            timestamp: uint64(block.timestamp)
        });
        cumShare[id + 1] = cumShare[id] + share;

        hopper.reserve(amount);
        emit Pulsed(id, amount, share, lit, msg.sender);
        _advanceLadder();
    }

    // ------------------------------------------------------------------ Claims

    /// @notice Pay all closed, unpaid epochs for one pet.
    function claim(uint256 tokenId) external nonReentrant {
        if (_claim(tokenId, epochCount) == 0) revert NothingToClaim();
    }

    /// @notice Pay unpaid epochs `< endEpoch` (epoch-range claim). `endEpoch` clamps to `epochCount`.
    function claimUpTo(uint256 tokenId, uint256 endEpoch) external nonReentrant {
        if (_claim(tokenId, endEpoch) == 0) revert NothingToClaim();
    }

    /// @notice Claim many pets. Pets with nothing to claim are skipped; reverts only if nothing was paid.
    /// Caller sizes the batch (see docs/PULSE_V2_DESIGN.md for measured gas per pet).
    function claimMany(uint256[] calldata tokenIds) external nonReentrant {
        uint256 paid;
        uint256 n = epochCount;
        for (uint256 i; i < tokenIds.length; ++i) {
            paid += _claim(tokenIds[i], n);
        }
        if (paid == 0) revert NothingToClaim();
    }

    /// @notice Keeper-friendly batch: stops as soon as `gasleft() < minGasLeft` and returns how many
    /// entries of `tokenIds` were processed (resume from that index). Never reverts for "nothing paid".
    function claimManyBounded(uint256[] calldata tokenIds, uint256 minGasLeft)
        external
        nonReentrant
        returns (uint256 processed)
    {
        uint256 n = epochCount;
        for (processed; processed < tokenIds.length; ++processed) {
            if (gasleft() < minGasLeft) break;
            _claim(tokenIds[processed], n);
        }
    }

    /// @notice Withdraw ETH credited because the recipient could not receive it. Caller must own the pet.
    function withdrawCredit(uint256 tokenId, address to) external nonReentrant {
        if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = creditOf[tokenId];
        if (amount == 0) revert NoCredit();
        creditOf[tokenId] = 0;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit CreditWithdrawn(tokenId, to, amount);
    }

    // --------------------------------------------------------------- internals

    function _range(uint256 tokenId, uint256 endEpoch) internal view returns (uint256 start, uint256 end) {
        uint256 lf = litFromPlus1[tokenId];
        if (lf == 0) return (0, 0);
        start = claimedThrough[tokenId];
        if (start < lf - 1) start = lf - 1;
        end = endEpoch > epochCount ? epochCount : endEpoch;
    }

    function _claim(uint256 tokenId, uint256 endEpoch) internal returns (uint256 paid) {
        (uint256 start, uint256 end) = _range(tokenId, endEpoch);
        if (end <= start) return 0;
        paid = cumShare[end] - cumShare[start];
        claimedThrough[tokenId] = end;

        address to = _recipient(tokenId);
        _payout(tokenId, to, paid);
        emit Claimed(tokenId, start, end, to, paid);
    }

    function _payout(uint256 tokenId, address to, uint256 amount) internal {
        hopper.release(address(this), amount);
        if (address(router) == address(0)) {
            _sendEth(tokenId, to, amount);
            return;
        }

        Dial memory d = _dials[tokenId];
        uint256 lastIdx = type(uint256).max;
        for (uint256 i; i < MAX_DIAL_LEGS; ++i) {
            (address token, uint16 weight) = _leg(d, i);
            if (token != address(0) && weight != 0) lastIdx = i;
        }
        if (lastIdx == type(uint256).max) {
            // Undialed (or no allowlist address filled yet): buy `$TERM`.
            if (term == address(0)) {
                _sendEth(tokenId, to, amount);
            } else {
                _swapOrEth(tokenId, term, amount, to);
            }
            return;
        }

        uint256 remain = amount;
        for (uint256 i; i <= lastIdx; ++i) {
            (address token, uint16 weight) = _leg(d, i);
            if (token == address(0) || weight == 0) continue;
            uint256 spend = i == lastIdx ? remain : (amount * weight) / DIAL_BPS;
            if (spend > remain) spend = remain;
            if (spend == 0) continue;
            remain -= spend;
            _swapOrEth(tokenId, token, spend, to);
        }
        if (remain > 0) _sendEth(tokenId, to, remain);
    }

    /// @dev Swap `ethIn` for `token` delivered to `to`. A failing router never reverts the claim.
    function _swapOrEth(uint256 tokenId, address token, uint256 ethIn, address to) internal {
        try router.swapExactETHForToken{value: ethIn}(token, to) returns (uint256) {}
        catch {
            emit SwapSkipped(tokenId, token, ethIn);
            _sendEth(tokenId, to, ethIn);
        }
    }

    /// @dev Plain ETH to the recipient; on failure credit the pet. Never reverts.
    function _sendEth(uint256 tokenId, address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount, gas: SEND_GAS}("");
        if (!ok) {
            creditOf[tokenId] += amount;
            emit CreditAccrued(tokenId, amount);
        }
    }

    function _recipient(uint256 tokenId) internal view returns (address) {
        if (deliverToTba) {
            return tbaRegistry.account(tbaImplementation, tbaSalt, block.chainid, address(collection), tokenId);
        }
        return collection.ownerOf(tokenId);
    }

    function _leg(Dial memory d, uint256 i) internal view returns (address token, uint16 weight) {
        if (i >= d.nLegs) return (address(0), 0);
        if (i == 0) return (stockPool[d.slot0], d.weight0);
        if (i == 1) return (stockPool[d.slot1], d.weight1);
        if (i == 2) return (stockPool[d.slot2], d.weight2);
        return (stockPool[d.slot3], d.weight3);
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
}
