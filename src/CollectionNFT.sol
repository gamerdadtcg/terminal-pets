// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IIgniteModule} from "./interfaces/IIgniteModule.sol";
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
/// @notice Terminal Pets — ERC-721Enumerable + ERC-2981.
/// Royalties go to the RoyaltySplitter. Pre-reveal: 7.5% → TermFund. Post-reveal:
/// 5% Hopper / 2.5% treasury. Tokens mint **Sealed**; `reveal()` flips metadata, enables
/// `$TERM` trading and Ignite (owner anytime, or anyone after 24h).
/// Public `mintTo` is the OpenSea-friendly mint path (up to publicSupply).
/// Team reserve is owner-only via `teamMint` / `ownerMint`. Ignite spends `$TERM`
/// (37.5% burn / 25% Hopper-as-ETH / 37.5% allotment refill) plus 0.002 ETH
/// (50% Hopper / 50% buy `$TERM` and burn). Hopper payouts stay locked 7 days
/// after `reveal()`; Ignite during that week still accrues ETH in the pot.
contract CollectionNFT is ERC721Enumerable, ERC2981, Ownable {
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
    string private _contractURIOverride;
    uint256 private _nextTokenId = 1;

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

    /// @dev ERC-4906. OpenSea / indexers watch the collection for metadata refreshes.
    bytes4 private constant _INTERFACE_ID_ERC4906 = 0x49064906;

    event MintOpenUpdated(bool open);
    event MintPriceUpdated(uint256 price);
    event IgniteModuleSet(address indexed igniteModule);
    event TermTokenSet(address indexed termToken);
    event Revealed(uint256 timestamp);
    event ContractURIUpdated();
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 teamReserve_,
        address hopper_,
        address royaltyReceiver_,
        address initialOwner,
        uint96 royaltyBps_
    ) ERC721(name_, symbol_) Ownable(initialOwner) {
        if (maxSupply_ == 0 || teamReserve_ > maxSupply_) revert ZeroValue();
        if (hopper_ == address(0) || royaltyReceiver_ == address(0)) revert ZeroAddress();
        maxSupply = maxSupply_;
        teamReserve = teamReserve_;
        hopper = hopper_;
        royaltyReceiver = royaltyReceiver_;
        revealAfter = uint64(block.timestamp + CollectionConfig.REVEAL_DELAY);
        _setDefaultRoyalty(royaltyReceiver_, royaltyBps_);
        IHopperClock(hopper_).bindCollection();
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

    /// @notice Flip Sealed → live art, enable `$TERM` trading, enable Ignite, switch
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
    }

    function setContractURI(string calldata uri) external onlyOwner {
        _contractURIOverride = uri;
        emit ContractURIUpdated();
    }

    /// @notice OpenSea collection metadata.
    function contractURI() external view returns (string memory) {
        if (bytes(_contractURIOverride).length > 0) return _contractURIOverride;
        return TerminalRenderer.contractURI();
    }

    /// @notice Mint `quantity` terminals to the caller (dapp path).
    function mint(uint256 quantity) external payable returns (uint256 firstTokenId) {
        return _mintTo(msg.sender, quantity);
    }

    /// @notice OpenSea-friendly mint path: mint `quantity` terminals to `to`.
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

    function _mintTo(address to, uint256 quantity) internal returns (uint256 firstTokenId) {
        if (!mintOpen) revert MintClosed();
        uint256 due = mintPrice * quantity;
        if (msg.value < due) revert InsufficientPayment();
        if (publicMinted + quantity > publicSupply()) revert PublicSupplyReached();
        unchecked {
            publicMinted += quantity;
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        if (!revealed) return TerminalRenderer.hiddenTokenURI(tokenId);
        bool lit = address(igniteModule) != address(0) && igniteModule.isLit(tokenId);
        return TerminalRenderer.tokenURI(tokenId, lit);
    }

    /// @notice Handheld pet traits rolled from tokenId; State follows Ignite. Sealed until reveal.
    function tokenTraits(uint256 tokenId) external view returns (TerminalRenderer.Traits memory) {
        _requireOwned(tokenId);
        if (!revealed) return TerminalRenderer.sealedTraits();
        bool lit = address(igniteModule) != address(0) && igniteModule.isLit(tokenId);
        return TerminalRenderer.traits(tokenId, lit);
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
        return interfaceId == _INTERFACE_ID_ERC4906 || super.supportsInterface(interfaceId);
    }

    /// @dev Royalty receiver is the RoyaltySplitter; per-token overrides are disabled.
    function _setTokenRoyalty(uint256, address, uint96) internal pure override {
        revert RoyaltyReceiverLocked();
    }
}
