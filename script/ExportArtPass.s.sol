// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

/// @notice Dumps Sealed / Dormant / Lit / Wake SVGs for the art-pass preview (no broadcast).
contract ExportArtPass is Script {
    using Strings for uint256;

    function run() external {
        string memory art = "artifacts/art-pass/";
        string memory webPets = "web/public/pets/";
        string memory webPass = "web/public/art-pass/";

        uint256[12] memory ids = [uint256(2), 3, 12, 16, 7, 28, 15, 5, 1, 11, 4, 6];
        string[12] memory names =
            ["Blob", "Cat", "Dino", "Fox", "Ghost", "Bunny", "Bird", "Frog", "Bear", "Robot", "Owl", "Bug"];

        for (uint256 i; i < ids.length; ++i) {
            _dumpPet(art, webPass, webPets, ids[i], names[i], true);
        }

        // Wake sequences stay on the five reworked silhouettes.
        uint256[5] memory wakeIds = [uint256(3), 12, 7, 15, 11];
        string[5] memory wakeNames = ["Cat", "Dino", "Ghost", "Bird", "Robot"];
        for (uint256 i; i < wakeIds.length; ++i) {
            string memory wake = TerminalRenderer.wakeSvg(wakeIds[i]);
            string memory stem = string.concat(wakeNames[i], "-id", wakeIds[i].toString(), "-wake.svg");
            vm.writeFile(string.concat(art, stem), wake);
            vm.writeFile(string.concat(webPass, stem), wake);
            vm.writeFile(
                string.concat(webPets, "species-", wakeNames[i], "-id", wakeIds[i].toString(), "-wake.svg"), wake
            );
        }

        string memory mystery = TerminalRenderer.hiddenSvg(3);
        vm.writeFile(string.concat(art, "sealed-id3.svg"), mystery);
        vm.writeFile(string.concat(webPass, "sealed-id3.svg"), mystery);
        vm.writeFile(string.concat(webPets, "sealed-id3.svg"), mystery);

        // Accessory combos: glasses after ACC_N=6 remap (s % 6).
        _dumpPet(art, webPass, webPets, 29, "BirdGlasses", false);
        _dumpPet(art, webPass, webPets, 224, "BirdGlasses2", false);
        _dumpPet(art, webPass, webPets, 77, "FrogGlasses", false);
        _dumpPet(art, webPass, webPets, 219, "CatGlasses", false);
        _dumpPet(art, webPass, webPets, 42, "FoxGlasses", false);
        _dumpPet(art, webPass, webPets, 40, "RobotGlasses", false);

        // Dino face trait sample (distinct mouths / eyes / accessories).
        _dumpPet(art, webPass, webPets, 49, "DinoGrin", false);
        _dumpPet(art, webPass, webPets, 99, "DinoClosed", false);
        _dumpPet(art, webPass, webPets, 179, "DinoOh", false);
        _dumpPet(art, webPass, webPets, 25, "DinoTeeth", false);
        _dumpPet(art, webPass, webPets, 267, "DinoTall", false);

        vm.writeFile(string.concat(webPets, "id-1-dormant.svg"), TerminalRenderer.svg(1, false));
        vm.writeFile(string.concat(webPets, "id-1-sealed.svg"), TerminalRenderer.hiddenSvg(1));
        console.log("art-pass svgs written");
    }

    function _dumpPet(
        string memory art,
        string memory webPass,
        string memory webPets,
        uint256 id,
        string memory name,
        bool canonical
    ) private {
        string memory dormant = TerminalRenderer.svg(id, false);
        string memory lit = TerminalRenderer.svg(id, true);
        string memory idStr = id.toString();

        vm.writeFile(string.concat(art, name, "-id", idStr, "-dormant.svg"), dormant);
        vm.writeFile(string.concat(art, name, "-id", idStr, "-lit.svg"), lit);
        vm.writeFile(string.concat(webPass, name, "-id", idStr, "-dormant.svg"), dormant);
        vm.writeFile(string.concat(webPass, name, "-id", idStr, "-lit.svg"), lit);

        if (canonical) {
            vm.writeFile(string.concat(webPets, "species-", name, "-id", idStr, "-dormant.svg"), dormant);
            vm.writeFile(string.concat(webPets, "species-", name, "-id", idStr, "-lit.svg"), lit);
            vm.writeFile(string.concat(webPets, "species-", name, ".svg"), lit);
        }
        console.log(name, id);
    }
}
