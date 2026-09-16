// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
import {INonFungibleSeaDropToken} from "./interfaces/seadrop/INonFungibleSeaDropToken.sol";
import {ISeaDrop} from "./interfaces/seadrop/ISeaDrop.sol";
import {ISeaDropTokenContractMetadata} from "./interfaces/seadrop/ISeaDropTokenContractMetadata.sol";
import {
    AllowListData,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "./interfaces/seadrop/SeaDropStructs.sol";
import {TerminalRenderer} from "./TerminalRenderer.sol";
import {CollectionConfig} from "./CollectionConfig.sol";

interface IRoyaltyPhase {
    function setLive() external;
}

interface ITermTrading {
    function enableTrading() external;
}

interface IHopperClock {
    function bindCollection() external;
    function notifyReveal() external;
}

/// @title CollectionNFT
/// @notice Terminal Pets — ERC-721Enumerable + ERC-2981 + SeaDrop 1.0 token interface.
/// OpenSea Studio Drop mints through canonical SeaDrop into **this** contract
/// (`mintSeaDrop`). Same tokenId then reveal / Ignite / Hopper / Pulse / Dial.
/// Royalties go to the RoyaltySplitter. Pre-reveal: 7.5% → TermFund. Post-reveal:
/// 5% Hopper / 2.5% treasury. Tokens mint **Sealed**; `reveal()` flips metadata, enables
/// `$TERM` trading and Ignite (owner anytime, or anyone after 24h).
/// Public allocation is `maxSupply - teamReserve` (4244). SeaDrop and dapp `mint` /
/// `mintTo` share that cap. Team reserve is owner-only via `teamMint` / `ownerMint`
/// (not SeaDrop). Ignite spends `$TERM` (37.5% burn / 25% Hopper-as-ETH / 37.5%
/// allotment refill) plus 0.002 ETH (50% Hopper / 50% buy `$TERM` and burn).
/// Hopper payouts stay locked 7 days after `reveal()`.
/// Product art is off-chain generative PNG/GIF (Pocket Critter). `tokenURI`
/// serves sealed / dormant-egg / lit-pet JSON once metadata bases are set.
///
/// SeaDrop is implemented to match `INonFungibleSeaDropToken` on OZ ERC-721Enumerable
/// rather than inheriting `ERC721SeaDrop` (ERC721A + OZ 4.x + solc 0.8.17) or the
/// interface type itself (its `RoyaltyInfo` struct collides with OZ ERC2981).
contract CollectionNFT is ERC721Enumerable, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint256 public immutable maxSupply;
    uint256 public immutable teamReserve;
    address public immutable hopper;
    address public immutable royaltyReceiver;
    uint64 public immutable revealAfter;

    IIgniteModule public igniteModule;
    address public termToken;
    uint256 public mintPrice;
    bool public mintOpen;
    bool public revealed;
    uint256 public teamMinted;
    uint256 public publicMinted;
    bytes32 public provenanceHash;
    TerminalRenderer public immutable renderer;
    string private _contractURIOverride;
    /// @notice Pre-reveal metadata. No trailing slash → same URI for every token
    /// (typical `hidden.json`). Trailing slash → `{base}{id}.json`.
    string public hiddenURI;
    /// @notice Revealed + Dormant (egg rock GIF). Trailing slash → `{id}.json`.
    string public dormantBaseURI;
    /// @notice Revealed + Lit (awake pet GIF). Trailing slash → `{id}.json`.
    string public litBaseURI;
    uint256 private _nextTokenId = 1;

    mapping(address => bool) internal _allowedSeaDrop;
    address[] internal _enumeratedAllowedSeaDrop;
    /// @notice Tokens minted to an address via public / SeaDrop paths (not teamMint).
    mapping(address => uint256) internal _numberMinted;

    error ZeroAddress();
    error ZeroValue();
    error MintClosed();
    error MaxSupplyReached();
    error PublicSupplyReached();
    error TeamReserveExceeded();
    error InsufficientPayment();
    error IgniteAlreadySet();
    error RoyaltyReceiverLocked();
    error NotIgniteModule();
    error AlreadySet();
    error AlreadyRevealed();
    error RevealLocked();
    error OnlyOwnerOrSelf();
    error MaxSupplyImmutable(uint256 current, uint256 attempted);
    error OnlyAllowedSeaDrop();
    error ProvenanceHashCannotBeSetAfterMintStarted();
    error InvalidRoyaltyBasisPoints(uint256 basisPoints);
    error RoyaltyAddressCannotBeZeroAddress();

    /// @dev ERC-4906. OpenSea / indexers watch the collection for metadata refreshes.
    bytes4 private constant _INTERFACE_ID_ERC4906 = 0x49064906;

    event MintOpenUpdated(bool open);
    event MintPriceUpdated(uint256 price);
    event IgniteModuleSet(address indexed igniteModule);
    event TermTokenSet(address indexed termToken);
    event Revealed(uint256 timestamp);
    event MetadataURIsUpdated(string hiddenURI, string dormantBaseURI, string litBaseURI);
    event MetadataUpdate(uint256 _tokenId);
    event SeaDropTokenDeployed();
    event AllowedSeaDropUpdated(address[] allowedSeaDrop);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated(string newContractURI);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 teamReserve_,
        address hopper_,
        address royaltyReceiver_,
        address initialOwner,
        uint96 royaltyBps_,
        address[] memory allowedSeaDrop
    ) ERC721(name_, symbol_) Ownable(initialOwner) {
        if (maxSupply_ == 0 || teamReserve_ > maxSupply_) revert ZeroValue();
        if (hopper_ == address(0) || royaltyReceiver_ == address(0)) revert ZeroAddress();
        maxSupply = maxSupply_;
        teamReserve = teamReserve_;
        hopper = hopper_;
        royaltyReceiver = royaltyReceiver_;
        revealAfter = uint64(block.timestamp + CollectionConfig.REVEAL_DELAY);
        _setDefaultRoyalty(royaltyReceiver_, royaltyBps_);
        renderer = new TerminalRenderer();
        IHopperClock(hopper_).bindCollection();
        _updateAllowedSeaDrop(allowedSeaDrop);
        emit SeaDropTokenDeployed();
    }

    function publicSupply() public view returns (uint256) {
        return maxSupply - teamReserve;
    }

    function teamMintRemaining() public view returns (uint256) {
        return teamReserve - teamMinted;
    }

    function setIgniteModule(address igniteModule_) external onlyOwner {
        if (address(igniteModule) != address(0)) revert IgniteAlreadySet();
        if (igniteModule_ == address(0)) revert ZeroAddress();
        igniteModule = IIgniteModule(igniteModule_);
        emit IgniteModuleSet(igniteModule_);
    }

    function setTermToken(address termToken_) external onlyOwner {
        if (termToken != address(0)) revert AlreadySet();
        if (termToken_ == address(0)) revert ZeroAddress();
        termToken = termToken_;
        emit TermTokenSet(termToken_);
    }

    /// @notice Flip Sealed → dormant egg metadata, enable `$TERM` trading, enable Ignite, switch
    /// royalties to 5% Hopper / 2.5% treasury. Owner may call early; anyone after `revealAfter`.
    function reveal() external {
        if (revealed) revert AlreadyRevealed();
        if (msg.sender != owner() && block.timestamp < revealAfter) revert RevealLocked();
        revealed = true;
        IRoyaltyPhase(royaltyReceiver).setLive();
        if (address(igniteModule) != address(0)) {
            igniteModule.setIgniteEnabled(true);
        }
        if (termToken != address(0)) {
            ITermTrading(termToken).enableTrading();
        }
        IHopperClock(hopper).notifyReveal();
        emit Revealed(block.timestamp);
        uint256 last = _nextTokenId > 1 ? _nextTokenId - 1 : 1;
        emit BatchMetadataUpdate(1, last);
    }

    function revealDue() public view returns (bool) {
        return block.timestamp >= revealAfter;
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenUpdated(open);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
        emit MintPriceUpdated(price);
    }

    /// @notice Royalty bps can change; the receiver stays the RoyaltySplitter.
    function setRoyaltyBps(uint96 bps) external onlyOwner {
        _setDefaultRoyalty(royaltyReceiver, bps);
        emit RoyaltyInfoUpdated(royaltyReceiver, bps);
    }

    function setContractURI(string calldata uri) external onlyOwner {
        _contractURIOverride = uri;
        emit ContractURIUpdated(uri);
    }

    /// @notice Point tokenURI at hosted Pocket Critter JSON (IPFS or HTTP).
    /// Empty strings keep the on-chain fallback stub. Trailing `/` on a base
    /// appends `{tokenId}.json` (matches `art/generator/generate_collection.py`).
    function setMetadataURIs(string calldata hiddenURI_, string calldata dormantBaseURI_, string calldata litBaseURI_)
        external
        onlyOwner
    {
        hiddenURI = hiddenURI_;
        dormantBaseURI = dormantBaseURI_;
        litBaseURI = litBaseURI_;
        emit MetadataURIsUpdated(hiddenURI_, dormantBaseURI_, litBaseURI_);
        if (_nextTokenId > 1) {
            emit BatchMetadataUpdate(1, _nextTokenId - 1);
        }
    }

    /// @notice SeaDrop / Studio single-base setter. Prefer `setMetadataURIs`.
    /// Trailing `/` updates dormant (revealed) directory; otherwise hidden JSON.
    /// Does not clear `litBaseURI`.
    function setBaseURI(string calldata uri) external onlyOwner {
        bytes memory b = bytes(uri);
        if (b.length > 0 && b[b.length - 1] == "/") {
            dormantBaseURI = uri;
        } else {
            hiddenURI = uri;
        }
        if (_nextTokenId > 1) {
            emit BatchMetadataUpdate(1, _nextTokenId - 1);
        }
    }

    function baseURI() external view returns (string memory) {
        if (bytes(dormantBaseURI).length != 0) return dormantBaseURI;
        return hiddenURI;
    }

    /// @notice Max supply is fixed at deploy (4444). No-op if `newMaxSupply` matches.
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply != maxSupply) revert MaxSupplyImmutable(maxSupply, newMaxSupply);
        emit MaxSupplyUpdated(maxSupply);
    }

    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        if (_nextTokenId > 1) revert ProvenanceHashCannotBeSetAfterMintStarted();
        bytes32 prev = provenanceHash;
        provenanceHash = newProvenanceHash;
        emit ProvenanceHashUpdated(prev, newProvenanceHash);
    }

    function setRoyaltyInfo(ISeaDropTokenContractMetadata.RoyaltyInfo calldata newInfo) external onlyOwner {
        if (newInfo.royaltyAddress == address(0)) revert RoyaltyAddressCannotBeZeroAddress();
        if (newInfo.royaltyAddress != royaltyReceiver) revert RoyaltyReceiverLocked();
        if (newInfo.royaltyBps > 10_000) revert InvalidRoyaltyBasisPoints(newInfo.royaltyBps);
        _setDefaultRoyalty(royaltyReceiver, newInfo.royaltyBps);
        emit RoyaltyInfoUpdated(royaltyReceiver, newInfo.royaltyBps);
    }

    function royaltyAddress() external view returns (address) {
        return royaltyReceiver;
    }

    function royaltyBasisPoints() external view returns (uint256) {
        (, uint256 amount) = royaltyInfo(0, 10_000);
        return amount;
    }

    /// @notice OpenSea collection metadata.
    function contractURI() external view returns (string memory) {
        if (bytes(_contractURIOverride).length > 0) return _contractURIOverride;
        return renderer.contractURI();
    }

    /// @notice Mint `quantity` terminals to the caller (dapp path).
    function mint(uint256 quantity) external payable returns (uint256 firstTokenId) {
        return _mintTo(msg.sender, quantity);
    }

    /// @notice Dapp mint path: mint `quantity` terminals to `to` (shares public cap with SeaDrop).
    function mintTo(address to, uint256 quantity) external payable returns (uint256 firstTokenId) {
        return _mintTo(to, quantity);
    }

    /// @notice Single-recipient mint used by some marketplace mint adapters.
    function mint(address to) external payable returns (uint256 tokenId) {
        return _mintTo(to, 1);
    }

    /// @notice Owner/team reserve mint (up to `teamReserve`). Alias of `teamMint`.
    function ownerMint(address to, uint256 quantity) external onlyOwner returns (uint256 firstTokenId) {
        return _teamMint(to, quantity);
    }

    /// @notice Mint from the team reserve to `to` (treasury or any team wallet).
    function teamMint(address to, uint256 quantity) external onlyOwner returns (uint256 firstTokenId) {
        return _teamMint(to, quantity);
    }

    /// @notice SeaDrop-only mint. Payment is handled by SeaDrop (creator payout + fee).
    /// Independent of `mintOpen`. Counts against `publicSupply`, not the team reserve.
    function mintSeaDrop(address minter, uint256 quantity) external nonReentrant {
        _onlyAllowedSeaDrop(msg.sender);
        if (publicMinted + quantity > publicSupply()) revert PublicSupplyReached();
        unchecked {
            publicMinted += quantity;
            _numberMinted[minter] += quantity;
        }
        _mintQuantity(minter, quantity);
    }

    function getMintStats(address minter)
        external
        view
        returns (uint256 minterNumMinted, uint256 currentTotalSupply, uint256 maxSupply_)
    {
        minterNumMinted = _numberMinted[minter];
        // Public allocation only so teamMint cannot block SeaDrop stages or eat the 4244 cap.
        currentTotalSupply = publicMinted;
        maxSupply_ = publicSupply();
    }

    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop) external onlyOwner {
        _updateAllowedSeaDrop(allowedSeaDrop);
    }

    function getAllowedSeaDrop() external view returns (address[] memory) {
        return _enumeratedAllowedSeaDrop;
    }

    function isAllowedSeaDrop(address seaDrop) external view returns (bool) {
        return _allowedSeaDrop[seaDrop];
    }

    function numberMinted(address minter) external view returns (uint256) {
        return _numberMinted[minter];
    }

    function updatePublicDrop(address seaDropImpl, PublicDrop calldata publicDrop) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updatePublicDrop(publicDrop);
    }

    function updateAllowList(address seaDropImpl, AllowListData calldata allowListData) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateAllowList(allowListData);
    }

    function updateTokenGatedDrop(address seaDropImpl, address allowedNftToken, TokenGatedDropStage calldata dropStage)
        external
    {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(allowedNftToken, dropStage);
    }

    function updateDropURI(address seaDropImpl, string calldata dropURI) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateDropURI(dropURI);
    }

    function updateCreatorPayoutAddress(address seaDropImpl, address payoutAddress) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateCreatorPayoutAddress(payoutAddress);
    }

    function updateAllowedFeeRecipient(address seaDropImpl, address feeRecipient, bool allowed) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    function updateSignedMintValidationParams(
        address seaDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updateSignedMintValidationParams(signer, signedMintValidationParams);
    }

    function updatePayer(address seaDropImpl, address payer, bool allowed) external {
        _onlyOwnerOrSelf();
        _onlyAllowedSeaDrop(seaDropImpl);
        ISeaDrop(seaDropImpl).updatePayer(payer, allowed);
    }

    function _mintTo(address to, uint256 quantity) internal returns (uint256 firstTokenId) {
        if (!mintOpen) revert MintClosed();
        uint256 due = mintPrice * quantity;
        if (msg.value < due) revert InsufficientPayment();
        if (publicMinted + quantity > publicSupply()) revert PublicSupplyReached();
        unchecked {
            publicMinted += quantity;
            _numberMinted[to] += quantity;
        }
        firstTokenId = _mintQuantity(to, quantity);
        if (msg.value > 0) {
            (bool ok,) = hopper.call{value: msg.value}("");
            require(ok, "hopper deposit failed");
        }
    }

    function _teamMint(address to, uint256 quantity) internal returns (uint256 firstTokenId) {
        if (teamMinted + quantity > teamReserve) revert TeamReserveExceeded();
        unchecked {
            teamMinted += quantity;
        }
        return _mintQuantity(to, quantity);
    }

    function _mintQuantity(address to, uint256 quantity) internal returns (uint256 firstTokenId) {
        if (to == address(0) || quantity == 0) revert ZeroValue();
        if (totalSupply() + quantity > maxSupply) revert MaxSupplyReached();
        firstTokenId = _nextTokenId;
        for (uint256 i; i < quantity; ++i) {
            _mint(to, _nextTokenId);
            unchecked {
                _nextTokenId += 1;
            }
        }
    }

    function _onlyAllowedSeaDrop(address seaDrop) internal view {
        if (_allowedSeaDrop[seaDrop] != true) revert OnlyAllowedSeaDrop();
    }

    function _onlyOwnerOrSelf() internal view {
        if (msg.sender != owner() && msg.sender != address(this)) revert OnlyOwnerOrSelf();
    }

    function _updateAllowedSeaDrop(address[] memory allowedSeaDrop) internal {
        uint256 oldLen = _enumeratedAllowedSeaDrop.length;
        uint256 newLen = allowedSeaDrop.length;
        for (uint256 i; i < oldLen;) {
            _allowedSeaDrop[_enumeratedAllowedSeaDrop[i]] = false;
            unchecked {
                ++i;
            }
        }
        for (uint256 i; i < newLen;) {
            _allowedSeaDrop[allowedSeaDrop[i]] = true;
            unchecked {
                ++i;
            }
        }
        _enumeratedAllowedSeaDrop = allowedSeaDrop;
        emit AllowedSeaDropUpdated(allowedSeaDrop);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        if (!revealed) {
            if (bytes(hiddenURI).length != 0) return _metadataURI(hiddenURI, tokenId);
            return renderer.hiddenTokenURI(tokenId);
        }
        bool lit = address(igniteModule) != address(0) && igniteModule.isLit(tokenId);
        if (lit) {
            if (bytes(litBaseURI).length != 0) return _metadataURI(litBaseURI, tokenId);
        } else if (bytes(dormantBaseURI).length != 0) {
            return _metadataURI(dormantBaseURI, tokenId);
        }
        return renderer.tokenURI(tokenId, lit);
    }

    /// @notice Historical Track A rolls + Ignite state. Product traits live in
    /// off-chain Pocket Critter JSON (`art/schema/traits.json`), not this table.
    function tokenTraits(uint256 tokenId) external view returns (TerminalRenderer.Traits memory) {
        _requireOwned(tokenId);
        if (!revealed) return renderer.sealedTraits();
        bool lit = address(igniteModule) != address(0) && igniteModule.isLit(tokenId);
        return renderer.traits(tokenId, lit);
    }

    /// @notice Called by IgniteModule after a successful Ignite so marketplaces refresh tokenURI.
    function notifyMetadataUpdate(uint256 tokenId) external {
        if (msg.sender != address(igniteModule)) revert NotIgniteModule();
        emit MetadataUpdate(tokenId);
    }

    function isLit(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return address(igniteModule) != address(0) && igniteModule.isLit(tokenId);
    }

    function tokensOfOwner(address owner_) external view returns (uint256[] memory ids) {
        uint256 n = balanceOf(owner_);
        ids = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            ids[i] = tokenOfOwnerByIndex(owner_, i);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC2981) returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC4906 || interfaceId == type(INonFungibleSeaDropToken).interfaceId
            || interfaceId == type(ISeaDropTokenContractMetadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Royalty receiver is the RoyaltySplitter; per-token overrides are disabled.
    function _setTokenRoyalty(uint256, address, uint96) internal pure override {
        revert RoyaltyReceiverLocked();
    }

    /// @dev Trailing `/` → `{base}{tokenId}.json`. Otherwise return `base` as-is
    /// (single sealed JSON for every token).
    function _metadataURI(string memory base, uint256 tokenId) internal pure returns (string memory) {
        bytes memory b = bytes(base);
        if (b.length > 0 && b[b.length - 1] == "/") {
            return string.concat(base, tokenId.toString(), ".json");
        }
        return base;
    }
}
