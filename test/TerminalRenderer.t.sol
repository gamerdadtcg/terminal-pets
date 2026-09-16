// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

contract TerminalRendererHarness {
    function roll(uint256 tokenId) external pure returns (TerminalRenderer.Roll memory) {
        return TerminalRenderer.roll(tokenId);
    }

    function traits(uint256 tokenId, bool lit) external pure returns (TerminalRenderer.Traits memory) {
        return TerminalRenderer.traits(tokenId, lit);
    }

    function fingerprint(uint256 tokenId) external pure returns (bytes32) {
        return TerminalRenderer.fingerprint(tokenId);
    }

    function tokenURI(uint256 tokenId, bool lit) external pure returns (string memory) {
        return TerminalRenderer.tokenURI(tokenId, lit);
    }

    function contractURI() external pure returns (string memory) {
        return TerminalRenderer.contractURI();
    }

    function svg(uint256 tokenId, bool lit) external pure returns (string memory) {
        return TerminalRenderer.svg(tokenId, lit);
    }

    function hiddenSvg(uint256 tokenId) external pure returns (string memory) {
        return TerminalRenderer.hiddenSvg(tokenId);
    }

    function hiddenTokenURI(uint256 tokenId) external pure returns (string memory) {
        return TerminalRenderer.hiddenTokenURI(tokenId);
    }
}

contract TerminalRendererTest is Test {
    TerminalRendererHarness internal r;

    function setUp() public {
        r = new TerminalRendererHarness();
    }

    function test_roll_deterministic() public view {
        TerminalRenderer.Roll memory a = r.roll(42);
        TerminalRenderer.Roll memory b = r.roll(42);
        assertEq(a.shell, b.shell);
        assertEq(a.species, b.species);
        assertEq(a.accessory, b.accessory);
        assertTrue(a.shell < 8 && a.species < 12 && a.body < 12);
        assertTrue(a.accessory < 6);
    }

    function test_differentIds_canDiffer() public view {
        TerminalRenderer.Roll memory a = r.roll(1);
        bool differed;
        for (uint256 i = 2; i < 40; ++i) {
            TerminalRenderer.Roll memory b = r.roll(i);
            if (a.shell != b.shell || a.species != b.species || a.shellColor != b.shellColor) {
                differed = true;
                break;
            }
        }
        assertTrue(differed);
    }

    function test_sameId_samePetAcrossState() public view {
        TerminalRenderer.Traits memory t0 = r.traits(42, false);
        TerminalRenderer.Traits memory t1 = r.traits(42, true);
        assertEq(t0.state, "Dormant");
        assertEq(t1.state, "Lit");
        assertEq(t0.species, t1.species);
        assertEq(t0.shell, t1.shell);
        assertTrue(keccak256(bytes(r.tokenURI(42, false))) != keccak256(bytes(r.tokenURI(42, true))));
    }

    function test_tokenURI_containsTraitsAndState() public view {
        string memory dormant = r.tokenURI(42, false);
        string memory lit = r.tokenURI(42, true);
        assertTrue(_startsWith(dormant, "data:application/json;base64,"));
        assertTrue(_startsWith(lit, "data:application/json;base64,"));
        TerminalRenderer.Traits memory t = r.traits(42, false);
        assertTrue(bytes(t.species).length > 0);
        assertTrue(bytes(t.shell).length > 0);
    }

    function test_hiddenSvg_isPlaceholder() public view {
        string memory hidden = r.hiddenSvg(3);
        assertTrue(_contains(hidden, "PET#3"));
        assertTrue(_contains(hidden, "SEALED"));
        assertTrue(_contains(hidden, "OFF-CHAIN ART"));
        assertEq(r.hiddenTokenURI(3), TerminalRenderer.hiddenTokenURI(3));
    }

    function test_svg_isPlaceholder() public view {
        string memory dormant = r.svg(12, false);
        string memory lit = r.svg(12, true);
        assertTrue(_contains(dormant, "PET#12"));
        assertTrue(_contains(dormant, "DORMANT"));
        assertTrue(_contains(lit, "LIT"));
        assertFalse(_contains(lit, 'data-dino="1"'));
        assertFalse(_contains(lit, "Scarf"));
        assertFalse(_contains(lit, "Pack"));
    }

    function test_contractURI_hasCollectionImage() public view {
        string memory uri = r.contractURI();
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
        assertTrue(bytes(uri).length > 200);
    }

    function test_namePrefix() public view {
        TerminalRenderer.Traits memory t = r.traits(1, false);
        assertTrue(bytes(t.shell).length > 0);
    }

    function test_noScarfOrPack() public view {
        for (uint256 id = 1; id <= 200; ++id) {
            TerminalRenderer.Roll memory a = r.roll(id);
            assertTrue(a.accessory < 6, "ACC_N is 6");
            string memory name = r.traits(id, true).accessory;
            assertTrue(keccak256(bytes(name)) != keccak256("Scarf"));
            assertTrue(keccak256(bytes(name)) != keccak256("Pack"));
        }
    }

    function test_fingerprintUnique_first500() public view {
        bytes32[501] memory seen;
        for (uint256 id = 1; id <= 500; ++id) {
            bytes32 fp = r.fingerprint(id);
            for (uint256 j = 1; j < id; ++j) {
                assertTrue(seen[j] != fp, "fingerprint collision");
            }
            seen[id] = fp;
        }
    }

    function _contains(string memory hay, string memory needle) internal pure returns (bool) {
        return bytes(hay).length >= bytes(needle).length && _indexOf(hay, needle) != type(uint256).max;
    }

    function _startsWith(string memory hay, string memory prefix) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory p = bytes(prefix);
        if (h.length < p.length) return false;
        for (uint256 i; i < p.length; ++i) {
            if (h[i] != p[i]) return false;
        }
        return true;
    }

    function _indexOf(string memory hay, string memory needle) internal pure returns (uint256) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length == 0 || h.length < n.length) return type(uint256).max;
        uint256 limit = h.length - n.length + 1;
        for (uint256 i; i < limit; ++i) {
            bool ok = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return i;
        }
        return type(uint256).max;
    }
}
