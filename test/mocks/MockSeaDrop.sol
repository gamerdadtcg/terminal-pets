// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISeaDrop} from "../../src/interfaces/seadrop/ISeaDrop.sol";
import {
    AllowListData,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "../../src/interfaces/seadrop/SeaDropStructs.sol";

/// @notice Minimal SeaDrop 1.0 stand-in. Records owner-forwarded config and mints via `mintSeaDrop`.
contract MockSeaDrop is ISeaDrop {
    PublicDrop public publicDrop;
    bytes32 public allowListMerkleRoot;
    string public dropURI;
    address public creatorPayoutAddress;
    address public lastFeeRecipient;
    bool public lastFeeRecipientAllowed;
    address public lastSigner;
    SignedMintValidationParams public lastSignedParams;
    address public lastPayer;
    bool public lastPayerAllowed;
    address public lastTokenGatedNft;
    TokenGatedDropStage public lastTokenGatedStage;
    address public lastCaller;

    function mintFor(address nft, address minter, uint256 quantity) external {
        (bool ok, bytes memory err) =
            nft.call(abi.encodeWithSignature("mintSeaDrop(address,uint256)", minter, quantity));
        if (!ok) {
            assembly {
                revert(add(err, 0x20), mload(err))
            }
        }
    }

    function updatePublicDrop(PublicDrop calldata publicDrop_) external override {
        lastCaller = msg.sender;
        publicDrop = publicDrop_;
    }

    function updateAllowList(AllowListData calldata allowListData_) external override {
        lastCaller = msg.sender;
        allowListMerkleRoot = allowListData_.merkleRoot;
    }

    function updateTokenGatedDrop(address allowedNftToken, TokenGatedDropStage calldata dropStage) external override {
        lastCaller = msg.sender;
        lastTokenGatedNft = allowedNftToken;
        lastTokenGatedStage = dropStage;
    }

    function updateDropURI(string calldata dropURI_) external override {
        lastCaller = msg.sender;
        dropURI = dropURI_;
    }

    function updateCreatorPayoutAddress(address payoutAddress) external override {
        lastCaller = msg.sender;
        creatorPayoutAddress = payoutAddress;
    }

    function updateAllowedFeeRecipient(address feeRecipient, bool allowed) external override {
        lastCaller = msg.sender;
        lastFeeRecipient = feeRecipient;
        lastFeeRecipientAllowed = allowed;
    }

    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams
    ) external override {
        lastCaller = msg.sender;
        lastSigner = signer;
        lastSignedParams = signedMintValidationParams;
    }

    function updatePayer(address payer, bool allowed) external override {
        lastCaller = msg.sender;
        lastPayer = payer;
        lastPayerAllowed = allowed;
    }
}
