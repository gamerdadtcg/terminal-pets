// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AllowListData, PublicDrop, TokenGatedDropStage, SignedMintValidationParams} from "./SeaDropStructs.sol";

/// @notice Subset of SeaDrop 1.0 (`ISeaDrop`) that a compatible token must call
/// when the owner configures Drop stages. Mint functions live on SeaDrop itself.
interface ISeaDrop {
    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    function updateAllowList(AllowListData calldata allowListData) external;

    function updateTokenGatedDrop(address allowedNftToken, TokenGatedDropStage calldata dropStage) external;

    function updateDropURI(string calldata dropURI) external;

    function updateCreatorPayoutAddress(address payoutAddress) external;

    function updateAllowedFeeRecipient(address feeRecipient, bool allowed) external;

    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams
    ) external;

    function updatePayer(address payer, bool allowed) external;
}
