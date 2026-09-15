// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

/// @notice Dumps Lit SVGs for tokenIds 1–100 for the art-pass sample sheet.
contract ExportSample100 is Script {
    using Strings for uint256;

    function run() external {
        string memory art = "artifacts/art-pass/sample-100/";
        string memory web = "web/public/art-pass/sample-100/";
        for (uint256 id = 1; id <= 100; ++id) {
            string memory svg = TerminalRenderer.svg(id, true);
            string memory file = string.concat(id.toString(), ".svg");
            vm.writeFile(string.concat(art, file), svg);
            vm.writeFile(string.concat(web, file), svg);
        }
        console.log("sample-100 lit svgs written");
    }
}
