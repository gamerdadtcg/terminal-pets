// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {ReceivableAccount} from "./ReceivableAccount.sol";

/// @notice Test mock: deterministic TBA addresses without CREATE2 proxy bytecode.
/// `account()` is view-pure from inputs; `createAccount` deploys a receivable wallet
/// at a documented mapping so tests can assert balances.
contract MockERC6551Registry is IERC6551Registry {
    mapping(bytes32 => address) public deployed;

    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account_) {
        bytes32 key = _key(implementation, salt, chainId, tokenContract, tokenId);
        account_ = deployed[key];
        if (account_ == address(0)) {
            account_ = address(new ReceivableAccount());
            deployed[key] = account_;
            emit ERC6551AccountCreated(account_, implementation, salt, chainId, tokenContract, tokenId);
        }
    }

    function account(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        external
        view
        returns (address)
    {
        address deployed_ = deployed[_key(implementation, salt, chainId, tokenContract, tokenId)];
        if (deployed_ != address(0)) return deployed_;
        return _predict(implementation, salt, chainId, tokenContract, tokenId);
    }

    function _key(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(implementation, salt, chainId, tokenContract, tokenId));
    }

    function _predict(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(_key(implementation, salt, chainId, tokenContract, tokenId))));
    }
}
