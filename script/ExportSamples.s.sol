// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

/// @notice Dumps real TerminalRenderer pet SVG + traits for sample token IDs.
contract ExportSamples is Script {
    using Strings for uint256;

    function run() external {
        uint256[7] memory ids = [uint256(1), 42, 100, 777, 1337, 2500, 4444];
        string memory outA = "deployments/samples/";

        string memory table = "# Terminal Pets - sample traits (from TerminalRenderer)\n\n";
        table = string.concat(
            table,
            "| Token ID | Shell | Color | Species | Body | Eyes | Accessory | Gen |\n",
            "| --- | --- | --- | --- | --- | --- | --- | --- |\n"
        );

        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            TerminalRenderer.Traits memory t = TerminalRenderer.traits(id, false);

            string memory dormant = TerminalRenderer.svg(id, false);
            string memory lit = TerminalRenderer.svg(id, true);

            vm.writeFile(string.concat(outA, "dormant-", id.toString(), ".svg"), dormant);
            vm.writeFile(string.concat(outA, "lit-", id.toString(), ".svg"), lit);

            table = string.concat(
                table,
                "| ",
                id.toString(),
                " | ",
                t.shell,
                " | ",
                t.shellColor,
                " | ",
                t.species,
                " | ",
                t.bodyColor,
                " | ",
                t.eyes,
                " | ",
                t.accessory,
                " | ",
                t.generation,
                " |\n"
            );

            console.log("ID", id);
            console.log("  Shell", t.shell, t.shellColor);
            console.log("  Species", t.species, t.bodyColor);
            console.log("  Acc", t.accessory, t.generation);
            console.log("  Dormant animate", _hasAnimate(dormant) ? "YES" : "no");
            console.log("  Lit animate", _hasAnimate(lit) ? "YES" : "no");
        }

        vm.writeFile(string.concat(outA, "sample_traits.md"), table);
        console.log(table);
    }

    function _hasAnimate(string memory s) private pure returns (bool) {
        bytes memory a = bytes(s);
        bytes memory b = bytes("<animate");
        if (a.length < b.length) return false;
        for (uint256 i; i + b.length <= a.length; ++i) {
            bool ok = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }
}
