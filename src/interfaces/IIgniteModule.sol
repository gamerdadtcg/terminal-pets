// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IIgniteModule {
    function isLit(uint256 tokenId) external view returns (bool);
    function litCount() external view returns (uint256);
    function litBitmap(uint256 word) external view returns (uint256);
    function igniteFee() external view returns (uint256);
    function igniteFeeEth() external view returns (uint256);
    function igniteEnabled() external view returns (bool);
    function setIgniteEnabled(bool enabled) external;
    function ignite(uint256 tokenId) external payable;
    function allotmentConsumed(uint256 tokenId) external view returns (bool);
    function claimIgniteAllotment(uint256 tokenId) external;
}
