// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

/// @notice Dumps one Lit (or Dormant) SVG per trait option on a frozen base pet.
/// Does not change `AWAKEN_PET_V2` rolls. Art-pass catalog only.
contract ExportTraitCatalog is Script {
    using Strings for uint256;

    function run() external {
        _shells();
        _shellColors();
        _buttons();
        _antennas();
        _wallpapers();
        _species();
        _bodies();
        _bellies();
        _eyesCat();
        _eyesSpecial();
        _pupils();
        _mouthsCat();
        _mouthsSpecial();
        _cheeks();
        _brows();
        _accessories();
        _glassesSpecies();
        _generations();
        _dormant();
    }

    function _base() internal pure returns (TerminalRenderer.Roll memory r) {
        r.shell = 1;
        r.shellColor = 1;
        r.button = 1;
        r.antenna = 1;
        r.wallpaper = 0;
        r.species = 1;
        r.body = 1;
        r.belly = 1;
        r.eyes = 0;
        r.pupil = 0;
        r.mouth = 1;
        r.cheeks = 0;
        r.ears = 0;
        r.accessory = 0;
        r.generation = 0;
    }

    function _write(string memory axis, uint256 i, string memory name, TerminalRenderer.Roll memory r, bool lit)
        internal
    {
        string memory stem = string.concat(axis, "-", i.toString(), "-", name);
        string memory svg = TerminalRenderer.svgFromRoll(i, r, lit);
        vm.writeFile(string.concat("artifacts/art-pass/traits/", stem, ".svg"), svg);
        vm.writeFile(string.concat("web/public/art-pass/traits/", stem, ".svg"), svg);
    }

    function _shells() internal {
        string[8] memory names = ["Egg", "Round", "Square", "Wave", "Slim", "Wide", "Octagon", "Clam"];
        for (uint256 i; i < 8; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.shell = uint8(i);
            _write("shell", i, names[i], r, true);
        }
    }

    function _shellColors() internal {
        string[12] memory names =
            ["Pink", "Sky", "Gold", "Lime", "Lilac", "Orange", "Slate", "Coral", "Mint", "Navy", "Cherry", "Sand"];
        for (uint256 i; i < 12; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.shellColor = uint8(i);
            _write("shell-color", i, names[i], r, true);
        }
    }

    function _buttons() internal {
        string[8] memory names = ["Red", "Blue", "Yellow", "White", "Ink", "Teal", "Green", "Pink"];
        for (uint256 i; i < 8; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.button = uint8(i);
            _write("buttons", i, names[i], r, true);
        }
    }

    function _antennas() internal {
        string[6] memory names = ["None", "Stub", "Ball", "Fork", "Spike", "Dish"];
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.antenna = uint8(i);
            _write("antenna", i, names[i], r, true);
        }
    }

    function _wallpapers() internal {
        string[8] memory names = ["Solid", "Dots", "Stripes", "Grid", "Hearts", "Stars", "Check", "Dawn"];
        for (uint256 i; i < 8; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.wallpaper = uint8(i);
            _write("wallpaper", i, names[i], r, true);
        }
    }

    function _species() internal {
        string[12] memory names =
            ["Blob", "Cat", "Dino", "Fox", "Ghost", "Bunny", "Bird", "Frog", "Bear", "Robot", "Owl", "Bug"];
        for (uint256 i; i < 12; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = uint8(i);
            _write("species", i, names[i], r, true);
        }
    }

    function _bodies() internal {
        string[12] memory names =
            ["Cream", "Mint", "Rose", "Blue", "Violet", "Yellow", "Peach", "Aqua", "Ember", "Ice", "Forest", "Grape"];
        for (uint256 i; i < 12; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.body = uint8(i);
            _write("body", i, names[i], r, true);
        }
    }

    function _bellies() internal {
        string[4] memory names = ["Cream", "White", "Peach", "Match"];
        for (uint256 i; i < 4; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.belly = uint8(i);
            _write("belly", i, names[i], r, true);
        }
    }

    function _eyesCat() internal {
        string[6] memory names = ["Dot", "Oval", "Wide", "Spark", "Tall", "Ring"];
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.eyes = uint8(i);
            _write("eyes", i, names[i], r, true);
        }
    }

    function _eyesSpecial() internal {
        string[6] memory names = ["Dot", "Oval", "Wide", "Spark", "Tall", "Ring"];
        uint8[5] memory species = [uint8(2), 6, 7, 9, 4];
        string[5] memory tags = ["dino", "bird", "frog", "robot", "ghost"];
        for (uint256 s; s < 5; ++s) {
            for (uint256 i; i < 6; ++i) {
                TerminalRenderer.Roll memory r = _base();
                r.species = species[s];
                r.eyes = uint8(i);
                _write(string.concat("eyes-", tags[s]), i, names[i], r, true);
            }
        }
    }

    function _pupils() internal {
        string[3] memory names = ["Center", "Slate", "Glance"];
        for (uint256 i; i < 3; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.pupil = uint8(i);
            _write("pupil", i, names[i], r, true);
        }
    }

    function _mouthsCat() internal {
        string[6] memory names = ["Flat", "Smile", "W", "Oh", "Grin", "Tongue"];
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.mouth = uint8(i);
            _write("mouth", i, names[i], r, true);
        }
    }

    function _mouthsSpecial() internal {
        string[6] memory dinoNames = ["Flat", "Smile", "W", "Oh", "Grin", "Tongue"];
        string[6] memory birdNames = ["Amber", "Coral", "Sky", "Gold", "Rose", "Ink"];
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory d = _base();
            d.species = 2;
            d.mouth = uint8(i);
            _write("mouth-dino", i, dinoNames[i], d, true);
        }
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory b = _base();
            b.species = 6;
            b.mouth = uint8(i);
            _write("mouth-bird", i, birdNames[i], b, true);
        }
    }

    function _cheeks() internal {
        string[3] memory names = ["None", "Blush", "Freckle"];
        for (uint256 i; i < 3; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.cheeks = uint8(i);
            _write("cheeks", i, names[i], r, true);
        }
        for (uint256 i; i < 3; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = 2;
            r.cheeks = uint8(i);
            _write("cheeks-dino", i, names[i], r, true);
        }
    }

    function _brows() internal {
        string[5] memory names = ["Round", "Point", "Horn", "Floppy", "Tuft"];
        for (uint256 i; i < 5; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.ears = uint8(i);
            _write("brows", i, names[i], r, true);
        }
        for (uint256 i; i < 5; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = 2;
            r.ears = uint8(i);
            _write("brows-dino", i, names[i], r, true);
        }
    }

    function _accessories() internal {
        string[6] memory names = ["None", "Bow", "Cap", "Star", "Glasses", "Halo"];
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.accessory = uint8(i);
            _write("accessory", i, names[i], r, true);
        }
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = 2;
            r.accessory = uint8(i);
            _write("accessory-dino", i, names[i], r, true);
        }
        for (uint256 i; i < 6; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = 6;
            r.accessory = uint8(i);
            _write("accessory-bird", i, names[i], r, true);
        }
    }

    function _glassesSpecies() internal {
        string[12] memory names =
            ["Blob", "Cat", "Dino", "Fox", "Ghost", "Bunny", "Bird", "Frog", "Bear", "Robot", "Owl", "Bug"];
        for (uint256 i; i < 12; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.species = uint8(i);
            r.accessory = 4;
            _write("glasses", i, names[i], r, true);
        }
    }

    function _generations() internal {
        string[4] memory names = ["Alpha", "Beta", "Gamma", "Delta"];
        for (uint256 i; i < 4; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.generation = uint8(i);
            _write("generation", i, names[i], r, true);
        }
    }

    function _dormant() internal {
        string[8] memory names = ["Egg", "Round", "Square", "Wave", "Slim", "Wide", "Octagon", "Clam"];
        for (uint256 i; i < 8; ++i) {
            TerminalRenderer.Roll memory r = _base();
            r.shell = uint8(i);
            _write("dormant", i, names[i], r, false);
        }
    }
}
