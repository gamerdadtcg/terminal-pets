// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITermFund {
    function deposit() external payable;

    function depositTerm(uint256 amount) external;

    function available() external view returns (uint256);

    function termAvailable() external view returns (uint256);
}
