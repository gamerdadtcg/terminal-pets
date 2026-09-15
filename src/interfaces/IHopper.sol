// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHopper {
    function deposit() external payable;
    function available() external view returns (uint256);
    function reserved() external view returns (uint256);
    function reserve(uint256 amount) external;
    function release(address to, uint256 amount) external;
    function distributor() external view returns (address);
    function hopperUnlocked() external view returns (bool);
    function hopperUnlockTime() external view returns (uint256);
}
