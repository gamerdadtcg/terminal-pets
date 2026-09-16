// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title TerminalRenderer
/// @notice Mechanics-only placeholder. Pet drawing is removed; art will be
/// reconnected separately. Seed domain `AWAKEN_PET_V2` is unchanged.
/// Accessories stay `ACC_N = 6` (None, Bow, Cap, Star, Glasses, Halo).
library TerminalRenderer {
    using Strings for uint256;

    uint8 internal constant ACC_N = 6;

    struct Roll {
        uint8 shell;
        uint8 shellColor;
        uint8 button;
        uint8 antenna;
        uint8 wallpaper;
        uint8 species;
        uint8 body;
        uint8 belly;
        uint8 eyes;
        uint8 pupil;
        uint8 mouth;
        uint8 cheeks;
        uint8 ears;
        uint8 accessory;
        uint8 generation;
        uint8 jx;
    }

    struct Traits {
        string shell;
        string shellColor;
        string buttonColor;
        string antenna;
        string wallpaper;
        string species;
        string bodyColor;
        string belly;
        string eyes;
        string pupil;
        string mouth;
        string cheeks;
        string ears;
        string accessory;
        string generation;
        string state;
    }

    function roll(uint256 tokenId) internal pure returns (Roll memory a) {
        uint256 s = uint256(keccak256(abi.encodePacked(keccak256("AWAKEN_PET_V2"), tokenId)));
        a.shell = uint8(s % 8);
        a.shellColor = uint8((s >> 8) % 12);
        a.button = uint8((s >> 16) % 8);
        a.antenna = uint8((s >> 24) % 6);
        a.wallpaper = uint8((s >> 32) % 8);
        a.species = uint8((s >> 40) % 12);
        a.body = uint8((s >> 48) % 12);
        a.belly = uint8((s >> 56) % 4);
        a.eyes = uint8((s >> 64) % 6);
        a.pupil = uint8((s >> 72) % 3);
        a.mouth = uint8((s >> 80) % 6);
        a.cheeks = uint8((s >> 88) % 3);
        a.ears = uint8((s >> 96) % 5);
        a.accessory = uint8((s >> 104) % ACC_N);
        a.generation = uint8((s >> 112) % 4);
        a.jx = uint8((s >> 120) % 7);
    }

    function fingerprint(uint256 tokenId) internal pure returns (bytes32) {
        Roll memory a = roll(tokenId);
        return keccak256(
            abi.encodePacked(
                a.shell,
                a.shellColor,
                a.button,
                a.antenna,
                a.wallpaper,
                a.species,
                a.body,
                a.belly,
                a.eyes,
                a.pupil,
                a.mouth,
                a.cheeks,
                a.ears,
                a.accessory,
                a.generation
            )
        );
    }

    function traits(uint256 tokenId, bool lit) internal pure returns (Traits memory t) {
        return traitsFromRoll(roll(tokenId), lit);
    }

    function traitsFromRoll(Roll memory a, bool lit) internal pure returns (Traits memory t) {
        t.shell = _shellName(a.shell);
        t.shellColor = _shellColorName(a.shellColor);
        t.buttonColor = _buttonName(a.button);
        t.antenna = _antennaName(a.antenna);
        t.wallpaper = _wallpaperName(a.wallpaper);
        t.species = _speciesName(a.species);
        t.bodyColor = _bodyName(a.body);
        t.belly = _bellyName(a.belly);
        t.eyes = _eyeName(a.eyes);
        t.pupil = _pupilName(a.pupil);
        t.mouth = a.species == 6 ? _beakName(a.mouth) : _mouthName(a.mouth);
        t.cheeks = _cheekName(a.cheeks);
        t.ears = _earName(a.ears);
        t.accessory = _accName(a.accessory);
        t.generation = _genName(a.generation);
        t.state = lit ? "Lit" : "Dormant";
    }

    function sealedTraits() internal pure returns (Traits memory t) {
        t.shell = "Sealed";
        t.shellColor = "Sealed";
        t.buttonColor = "Sealed";
        t.antenna = "Sealed";
        t.wallpaper = "Sealed";
        t.species = "Sealed";
        t.bodyColor = "Sealed";
        t.belly = "Sealed";
        t.eyes = "Sealed";
        t.pupil = "Sealed";
        t.mouth = "Sealed";
        t.cheeks = "Sealed";
        t.ears = "Sealed";
        t.accessory = "Sealed";
        t.generation = "Sealed";
        t.state = "Sealed";
    }

    function svg(uint256 tokenId, bool lit) internal pure returns (string memory) {
        return _placeholder(tokenId, lit ? "LIT" : "DORMANT");
    }

    function svgFromRoll(uint256 tokenId, Roll memory, bool lit) internal pure returns (string memory) {
        return svg(tokenId, lit);
    }

    function hiddenSvg(uint256 tokenId) internal pure returns (string memory) {
        return _placeholder(tokenId, "SEALED");
    }

    function wakeSvg(uint256 tokenId) internal pure returns (string memory) {
        return _placeholder(tokenId, "WAKE");
    }

    function tokenURI(uint256 tokenId, bool lit) internal pure returns (string memory) {
        return _jsonURI(tokenId, svg(tokenId, lit), traits(tokenId, lit));
    }

    function hiddenTokenURI(uint256 tokenId) internal pure returns (string memory) {
        return _jsonURI(tokenId, hiddenSvg(tokenId), sealedTraits());
    }

    function contractURI() internal pure returns (string memory) {
        string memory image = hiddenSvg(0);
        string memory json = string.concat(
            '{"name":"Terminal Pets","description":"Handheld pets on Robinhood Chain. Art removed pending reconnect. Mint Sealed, Ignite to Lit.","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(image)),
            '","external_link":"https://terminalpets.xyz"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function _placeholder(uint256 tokenId, string memory state) private pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<rect width="400" height="400" fill="#141018"/>',
            '<rect x="80" y="90" width="240" height="220" rx="16" fill="#1e293b" stroke="#64748b" stroke-width="4"/>',
            '<text x="200" y="190" text-anchor="middle" fill="#e2e8f0" font-size="28" font-family="monospace">PET#',
            tokenId.toString(),
            "</text>",
            '<text x="200" y="230" text-anchor="middle" fill="#94a3b8" font-size="16" font-family="monospace">',
            state,
            "</text>",
            '<text x="200" y="270" text-anchor="middle" fill="#64748b" font-size="11" font-family="monospace">ART REMOVED</text>',
            "</svg>"
        );
    }

    function _jsonURI(uint256 tokenId, string memory image, Traits memory t) private pure returns (string memory) {
        string memory attrs = string.concat(
            _attr("Shell", t.shell),
            ",",
            _attr("Shell Color", t.shellColor),
            ",",
            _attr("Buttons", t.buttonColor),
            ",",
            _attr("Antenna", t.antenna),
            ",",
            _attr("Wallpaper", t.wallpaper),
            ",",
            _attr("Species", t.species),
            ",",
            _attr("Body", t.bodyColor),
            ",",
            _attr("Belly", t.belly),
            ",",
            _attr("Eyes", t.eyes),
            ",",
            _attr("Accessory", t.accessory),
            ",",
            _attr("Generation", t.generation),
            ",",
            _attr("State", t.state)
        );
        string memory json = string.concat(
            '{"name":"Terminal Pet #',
            tokenId.toString(),
            '","description":"A handheld Terminal Pet. Art pending reconnect. Dormant until Ignite.","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(image)),
            '","attributes":[',
            attrs,
            "]}"
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function _attr(string memory k, string memory v) private pure returns (string memory) {
        return string.concat('{"trait_type":"', k, '","value":"', v, '"}');
    }

    function _shellName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Egg";
        if (i == 1) return "Round";
        if (i == 2) return "Square";
        if (i == 3) return "Wave";
        if (i == 4) return "Slim";
        if (i == 5) return "Wide";
        if (i == 6) return "Octagon";
        return "Clam";
    }

    function _shellColorName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Pink";
        if (i == 1) return "Sky";
        if (i == 2) return "Gold";
        if (i == 3) return "Lime";
        if (i == 4) return "Lilac";
        if (i == 5) return "Orange";
        if (i == 6) return "Slate";
        if (i == 7) return "Coral";
        if (i == 8) return "Mint";
        if (i == 9) return "Navy";
        if (i == 10) return "Cherry";
        return "Sand";
    }

    function _buttonName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Red";
        if (i == 1) return "Blue";
        if (i == 2) return "Yellow";
        if (i == 3) return "White";
        if (i == 4) return "Ink";
        if (i == 5) return "Teal";
        if (i == 6) return "Green";
        return "Pink";
    }

    function _antennaName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "None";
        if (i == 1) return "Stub";
        if (i == 2) return "Ball";
        if (i == 3) return "Fork";
        if (i == 4) return "Spike";
        return "Dish";
    }

    function _wallpaperName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Solid";
        if (i == 1) return "Dots";
        if (i == 2) return "Stripes";
        if (i == 3) return "Grid";
        if (i == 4) return "Hearts";
        if (i == 5) return "Stars";
        if (i == 6) return "Check";
        return "Dawn";
    }

    function _speciesName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Blob";
        if (i == 1) return "Cat";
        if (i == 2) return "Dino";
        if (i == 3) return "Fox";
        if (i == 4) return "Ghost";
        if (i == 5) return "Bunny";
        if (i == 6) return "Bird";
        if (i == 7) return "Frog";
        if (i == 8) return "Bear";
        if (i == 9) return "Robot";
        if (i == 10) return "Owl";
        return "Bug";
    }

    function _bodyName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Cream";
        if (i == 1) return "Mint";
        if (i == 2) return "Rose";
        if (i == 3) return "Blue";
        if (i == 4) return "Violet";
        if (i == 5) return "Yellow";
        if (i == 6) return "Peach";
        if (i == 7) return "Aqua";
        if (i == 8) return "Ember";
        if (i == 9) return "Ice";
        if (i == 10) return "Forest";
        return "Grape";
    }

    function _bellyName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Cream";
        if (i == 1) return "White";
        if (i == 2) return "Peach";
        return "Match";
    }

    function _eyeName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Dot";
        if (i == 1) return "Oval";
        if (i == 2) return "Wide";
        if (i == 3) return "Spark";
        if (i == 4) return "Tall";
        return "Ring";
    }

    function _pupilName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Center";
        if (i == 1) return "Slate";
        return "Glance";
    }

    function _mouthName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Flat";
        if (i == 1) return "Smile";
        if (i == 2) return "W";
        if (i == 3) return "Oh";
        if (i == 4) return "Grin";
        return "Tongue";
    }

    function _beakName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Amber";
        if (i == 1) return "Coral";
        if (i == 2) return "Sky";
        if (i == 3) return "Gold";
        if (i == 4) return "Rose";
        return "Ink";
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

    function _accName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "None";
        if (i == 1) return "Bow";
        if (i == 2) return "Cap";
        if (i == 3) return "Star";
        if (i == 4) return "Glasses";
        return "Halo";
    }

    function _genName(uint8 i) private pure returns (string memory) {
        if (i == 0) return "Alpha";
        if (i == 1) return "Beta";
        if (i == 2) return "Gamma";
        return "Delta";
    }
}
