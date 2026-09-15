// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

/// @notice Finds one real AWAKEN_PET_V2 tokenId per species and dumps Lit SVGs.
contract ExportSpecies is Script {
    using Strings for uint256;

    uint256 internal constant SCAN_MAX = 20_000;
    uint8 internal constant SPECIES_N = 12;

    function run() external {
        uint256[12] memory found;
        uint256 remaining = SPECIES_N;

        for (uint256 id = 1; id <= SCAN_MAX && remaining > 0; ++id) {
            TerminalRenderer.Roll memory roll = TerminalRenderer.roll(id);
            if (found[roll.species] == 0) {
                found[roll.species] = id;
                unchecked {
                    --remaining;
                }
            }
        }

        require(remaining == 0, "missing species in scan");

        string memory outDir = "deployments/samples/species/";
        string memory table = "# Species art-check (Lit, real AWAKEN_PET_V2 tokenIds)\n\n";
        table = string.concat(
            table,
            "| Species | Token ID | Shell | Shell Color | Buttons | Antenna | Wallpaper | Body | Belly | Eyes | Mouth | Cheeks | Ears | Accessory | Generation |\n",
            "| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
        );

        for (uint256 s; s < SPECIES_N; ++s) {
            uint256 id = found[s];
            TerminalRenderer.Roll memory roll = TerminalRenderer.roll(id);
            TerminalRenderer.Traits memory t = TerminalRenderer.traits(id, true);
            string memory lit = TerminalRenderer.svg(id, true);
            string memory name = t.species;
            string memory file = string.concat("species-", name, "-id", id.toString(), "-lit.svg");

            vm.writeFile(string.concat(outDir, file), lit);
            vm.writeFile(string.concat(outDir, "species-", name, ".svg"), lit);

            table = string.concat(
                table,
                "| ",
                name,
                " | ",
                id.toString(),
                " | ",
                t.shell,
                " | ",
                t.shellColor,
                " | ",
                t.buttonColor,
                " | ",
                t.antenna,
                " | ",
                t.wallpaper,
                " | ",
                t.bodyColor,
                " | ",
                _bellyName(roll.belly),
                " | ",
                t.eyes,
                " | ",
                _mouthName(roll.mouth),
                " | ",
                _cheekName(roll.cheeks),
                " | ",
                _earName(roll.ears),
                " | ",
                t.accessory,
                " | ",
                t.generation,
                " |\n"
            );

            console.log("species", name, "id", id);
        }

        vm.writeFile(string.concat(outDir, "species_traits.md"), table);
        console.log(table);
    }

    function _bellyName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Cream";
        if (i == 1) return "White";
        if (i == 2) return "Peach";
        return "Match";
    }

    function _mouthName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Flat";
        if (i == 1) return "Smile";
        if (i == 2) return "W";
        if (i == 3) return "Oh";
        if (i == 4) return "Grin";
        return "Tongue";
    }

    function _cheekName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "None";
        if (i == 1) return "Blush";
        return "Freckle";
    }

    function _earName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Round";
        if (i == 1) return "Point";
        if (i == 2) return "Horn";
        if (i == 3) return "Floppy";
        return "Tuft";
    }
}
