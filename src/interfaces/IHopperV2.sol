// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHopper} from "./IHopper.sol";

/// @notice HopperV2 surface used by PulseDistributorV2: V1 `IHopper` plus a pause flag.
interface IHopperV2 is IHopper {
    function paused() external view returns (bool);
}
