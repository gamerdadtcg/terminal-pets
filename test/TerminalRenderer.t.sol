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

    function wakeSvg(uint256 tokenId) external pure returns (string memory) {
        return TerminalRenderer.wakeSvg(tokenId);
    }
}

contract TerminalRendererTest is Test {
    TerminalRendererHarness internal r;

    function setUp() public {
        r = new TerminalRendererHarness();
    }

    function test_hiddenSvg_teaserReel() public view {
        string memory hidden = r.hiddenSvg(3);
        assertTrue(_contains(hidden, "TERMINAL PETS"), "branding");
        assertTrue(_contains(hidden, "SEALED"), "sealed label");
        assertTrue(_contains(hidden, "UNREVEALED"), "watermark");
        assertTrue(_contains(hidden, ">?</text>"), "poster question mark");
        assertTrue(_contains(hidden, 'data-f="0"'), "poster frame");
        assertTrue(_contains(hidden, 'data-f="6"'), "last lit teaser");
        assertTrue(_contains(hidden, 'opacity="1" data-f="0"'), "poster is first / OpenSea still");
        assertTrue(_contains(hidden, 'values="1;1;1;1;0;0;0;0;0;0"'), "poster held long");
        assertTrue(_contains(hidden, 'calcMode="discrete"'), "stepped cycle");
        assertTrue(_contains(hidden, 'clip-path="url(#scr)"'), "screen clip");
        assertTrue(_contains(hidden, "PET#3"), "id on bezel");
        assertTrue(_contains(hidden, "#c9a227"), "gold mystery trim");
        assertTrue(_contains(hidden, "#1a2030"), "gunmetal shell");
        assertTrue(_contains(hidden, "#86efac"), "lit cat teaser");
        assertTrue(_contains(hidden, "#d8b4fe"), "lit dino teaser");
        assertFalse(_contains(hidden, "#3a4454"), "teaser is lit pets only");
        assertTrue(keccak256(bytes(r.hiddenSvg(1))) != keccak256(bytes(r.hiddenSvg(3))));
        assertTrue(keccak256(bytes(hidden)) != keccak256(bytes(r.svg(3, false))));
        assertTrue(keccak256(bytes(hidden)) != keccak256(bytes(r.svg(3, true))));
        assertTrue(_startsWith(r.hiddenTokenURI(3), "data:application/json;base64,"));
    }

    function test_svgFromRoll_matchesTokenSvg() public view {
        uint256[6] memory ids = [uint256(1), 3, 12, 15, 11, 29];
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            TerminalRenderer.Roll memory rolled = r.roll(id);
            assertEq(
                keccak256(bytes(r.svg(id, true))),
                keccak256(bytes(TerminalRenderer.svgFromRoll(id, rolled, true))),
                "lit catalog path must match token svg"
            );
            assertEq(
                keccak256(bytes(r.svg(id, false))),
                keccak256(bytes(TerminalRenderer.svgFromRoll(id, rolled, false))),
                "dormant catalog path must match token svg"
            );
        }
    }

    function test_svgFromRoll_isolatesOneTrait() public view {
        TerminalRenderer.Roll memory a = r.roll(3);
        a.eyes = 0;
        a.accessory = 0;
        string memory dot = TerminalRenderer.svgFromRoll(0, a, true);
        a.eyes = 4;
        string memory tall = TerminalRenderer.svgFromRoll(4, a, true);
        assertTrue(_contains(dot, 'data-eyes="0"'), "dot eyes tagged");
        assertTrue(_contains(tall, 'data-eyes="4"'), "tall eyes tagged");
        assertTrue(keccak256(bytes(dot)) != keccak256(bytes(tall)), "changing one trait must change art");
    }

    function test_handheldIdentical_dormantAndLit() public view {
        uint256[4] memory ids = [uint256(1), 3, 12, 42];
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            string memory d = r.svg(id, false);
            string memory l = r.svg(id, true);
            TerminalRenderer.Roll memory a = r.roll(id);
            string memory shell = _brightShell(a.shellColor);
            string memory btn = _btnHex(a.button);
            assertTrue(_contains(d, shell), "dormant shell color");
            assertTrue(_contains(l, shell), "lit shell color");
            assertEq(_count(d, shell), _count(l, shell), "shell fill count");
            assertEq(_count(d, btn), _count(l, btn), "button count");
            assertTrue(_contains(d, 'stroke="#2a2430"'), "dormant edge");
            assertTrue(_contains(l, 'stroke="#2a2430"'), "lit edge");
            assertFalse(_contains(d, 'stroke="#16141a"'), "old dormant edge");
            assertFalse(_contains(d, 'fill="#0a0c10"'), "old dormant canvas");
            assertTrue(_contains(d, 'fill="#141018"'), "shared canvas");
            assertTrue(_contains(l, 'fill="#141018"'), "shared canvas");
            assertTrue(_contains(d, 'data-egg="1"'), "mystery egg");
            assertTrue(_contains(d, "#e8e0d4"), "egg shell");
            assertFalse(_contains(l, 'data-egg="1"'), "lit is not the egg");
        }
    }

    function test_dormant_dropsAccessoriesFrecklesBelly() public view {
        string memory d1 = r.svg(1, false);
        string memory l1 = r.svg(1, true);
        assertFalse(_contains(d1, 'data-acc="'), "dormant accessory");
        assertFalse(_contains(d1, "#7a3a58"), "dormant bow fill");
        assertFalse(_contains(d1, "#c9897a"), "dormant lit freckles");
        assertFalse(_contains(d1, "#5a4038"), "dormant muted freckles");
        assertFalse(_contains(d1, "#fff4d6"), "dormant wallpaper");
        assertTrue(_contains(d1, 'data-egg="1"'), "dormant egg");
        assertTrue(_contains(d1, "#e8e0d4"), "egg fill");
        assertTrue(_contains(d1, 'y="120"'), "zzz stays");
        assertTrue(
            _contains(l1, 'data-acc="') || _contains(l1, "#86efac") || _contains(l1, "<ellipse"), "lit still rich"
        );
        string memory d2 = r.svg(2, false);
        string memory l2 = r.svg(2, true);
        assertFalse(_contains(d2, 'r="2"'), "dormant freckle dots");
        assertTrue(_contains(l2, 'r="2"'), "lit keeps freckles");
        assertTrue(_contains(l2, "#c9897a"), "lit freckle color");
    }

    function test_dormant_genericEggNoSpecies() public view {
        string memory catD = r.svg(3, false);
        string memory catL = r.svg(3, true);
        string memory bearD = r.svg(1, false);
        string memory dinoD = r.svg(12, false);
        string memory dinoL = r.svg(12, true);
        assertTrue(_contains(catD, 'data-egg="1"'), "egg");
        assertTrue(_contains(bearD, 'data-egg="1"'), "egg");
        assertTrue(_contains(dinoD, 'data-egg="1"'), "egg");
        assertTrue(_contains(catD, 'rx="38" ry="50"'), "same egg shape");
        assertTrue(_contains(dinoD, 'rx="38" ry="50"'), "same egg shape");
        assertFalse(_contains(catD, "164,122"), "dormant must not show cat ears");
        assertTrue(_contains(catL, "164,122"), "lit cat still has ears");
        assertFalse(_contains(dinoD, 'data-dino-body="1"'), "dormant must not show dino body");
        assertTrue(_contains(dinoL, 'data-dino-body="1"'), "lit dino still has body");
        assertTrue(_contains(dinoL, 'data-tail="1"'), "lit dino still has tail");
        assertFalse(_contains(bearD, 'cx="174" cy="142"'), "dormant must not show bear ears");
    }

    function test_wakeSvg_crackSequence() public view {
        string memory w = r.wakeSvg(3);
        assertTrue(_contains(w, 'data-w="0"'), "egg stage");
        assertTrue(_contains(w, 'data-w="1"'), "crack stage");
        assertTrue(_contains(w, 'data-w="2"'), "flash stage");
        assertTrue(_contains(w, 'data-w="3"'), "lit stage");
        assertTrue(_contains(w, 'data-egg="1"'), "starts as egg");
        assertTrue(_contains(w, 'clipPath id="egL"'), "left shell clip");
        assertTrue(_contains(w, 'fill="#fff"'), "screen flash");
        assertTrue(_contains(w, "164,122"), "ends on cat");
        assertTrue(_contains(w, 'stroke="#2a2430"'), "same handheld edge");
        assertTrue(_contains(w, "#f4a6c8") || _contains(w, "#7ec8e3") || _contains(w, "#fb923c"), "token shell");
    }

    function test_faceAnchors_allTwelveSpecies() public view {
        _assertFace(2, 0, "200", "168", "16");
        _assertFace(3, 1, "200", "170", "15");
        _assertFace(12, 2, "158", "152", "8");
        _assertFace(16, 3, "200", "166", "15");
        _assertFace(7, 4, "200", "168", "16");
        _assertFace(28, 5, "200", "172", "14");
        _assertFace(15, 6, "196", "148", "8");
        _assertFace(5, 7, "200", "156", "24");
        _assertFace(1, 8, "200", "174", "16");
        _assertFace(11, 9, "200", "155", "14");
        _assertFace(4, 10, "200", "172", "14");
        _assertFace(6, 11, "200", "168", "12");
    }

    function test_dinoAndBirdFacesSitOnHead() public view {
        string memory dino = r.svg(12, true);
        assertTrue(_contains(dino, 'data-cx="158"'), "dino face on left head");
        assertTrue(_contains(dino, 'data-ey="152"'), "dino eyes on head");
        assertTrue(_contains(dino, 'data-gap="8"'), "dino tight eye gap");
        assertTrue(_contains(dino, 'data-dino="1"'), "connected dino group");
        assertTrue(_contains(dino, 'data-dino-eye="1"'), "profile eye on head");
        assertTrue(_contains(dino, 'data-snout="1"'), "mouth sits on snout");
        assertTrue(_contains(dino, 'data-dino-body="1"'), "one torso-hip-tail path");
        assertTrue(_contains(dino, 'data-dino-head="1"'), "round head for face");
        assertTrue(_contains(dino, 'data-ridge="1"'), "dorsal ridge on the back");
        assertTrue(_contains(dino, 'fill="#fff"'), "sclera so expressions read");
        assertFalse(_contains(dino, 'cx="216" cy="168"'), "old centered glasses");
        string memory bird = r.svg(15, true);
        assertTrue(_contains(bird, 'data-cx="196"'), "bird face on head");
        assertTrue(_contains(bird, 'data-ey="148"'), "bird eye height");
        assertTrue(_contains(bird, 'data-gap="8"'), "bird tight eye gap");
        assertTrue(_contains(bird, 'cx="188"'), "bird left eye on head");
        assertTrue(_contains(bird, 'cx="204"'), "bird right eye on head, left of beak");
        assertTrue(_contains(bird, "246,"), "beak still present");
    }

    function test_accessoriesUseFaceAnchors() public view {
        string memory dino = r.svg(12, true);
        TerminalRenderer.Roll memory d = r.roll(12);
        if (d.accessory == 4) {
            assertTrue(_contains(dino, 'data-acc="4"'), "dino glasses tagged");
            assertTrue(_contains(dino, 'data-lens="1"'), "glasses have visible lenses");
            assertTrue(_contains(dino, 'fill="#dbeafe"'), "lens fill contrast");
        }
        string memory lit;
        bool sawAcc;
        bool sawLens;
        bool[6] memory eyeSeen;
        bool[6] memory mouthSeen;
        uint256 eyeN;
        uint256 mouthN;
        for (uint256 id = 1; id <= 96; ++id) {
            TerminalRenderer.Roll memory a = r.roll(id);
            lit = r.svg(id, true);
            if (!eyeSeen[a.eyes]) {
                eyeSeen[a.eyes] = true;
                unchecked {
                    ++eyeN;
                }
            }
            if (!mouthSeen[a.mouth]) {
                mouthSeen[a.mouth] = true;
                unchecked {
                    ++mouthN;
                }
            }
            assertTrue(_contains(lit, 'data-eyes="'), "eyes tagged");
            if (a.accessory == 0) continue;
            if (a.accessory == 4) {
                assertTrue(_contains(lit, 'data-acc="4"'), "glasses tagged");
                assertTrue(_contains(lit, 'data-lens="1"'), "glasses draw lenses");
                sawLens = true;
            }
            assertTrue(_contains(lit, 'data-acc="'), "accessory tagged");
            sawAcc = true;
            assertFalse(_contains(r.svg(id, false), 'data-acc="'), "dormant has no acc");
        }
        assertTrue(sawAcc, "need accessories in first 96");
        assertTrue(sawLens, "need visible glasses in first 96");
        assertTrue(eyeN >= 5, "eye types should vary");
        assertTrue(mouthN >= 5, "mouth types should vary");
    }

    function test_birdGlassesHaveNoBridge() public view {
        TerminalRenderer.Roll memory b = r.roll(29);
        assertEq(b.species, 6, "canonical bird glasses id");
        assertEq(b.accessory, 4, "token 29 is glasses");
        string memory bird = r.svg(29, true);
        assertTrue(_contains(bird, 'data-acc="4"'), "glasses tagged");
        assertTrue(_contains(bird, 'data-lens="1"'), "lenses draw");
        assertTrue(_contains(bird, 'fill="#dbeafe"'), "lens fill");
        assertTrue(_contains(bird, 'fill-opacity=".22"'), "translucent so eyes show through");
        assertTrue(_contains(bird, 'data-wire="1"'), "thin on-eye rims");
        assertTrue(_contains(bird, 'data-arch="1"'), "short arch above the eyes");
        assertFalse(_contains(bird, 'data-bridge="1"'), "no bar between bird lenses");
        assertTrue(_contains(bird, 'r="7"'), "rims sized to the small head");
        TerminalRenderer.Roll memory b224 = r.roll(224);
        assertEq(b224.species, 6, "id 224 is also a bird");
        assertEq(b224.accessory, 4, "id 224 wears glasses");
        string memory bird2 = r.svg(224, true);
        assertTrue(_contains(bird2, 'data-wire="1"'), "second bird glasses use wire rims");
        assertTrue(_contains(bird2, 'data-arch="1"'), "second bird glasses have an arch");
        assertFalse(_contains(bird2, 'data-bridge="1"'), "no bar on second bird");
    }

    function test_dinoFaceTraitsVary() public view {
        string memory a = r.svg(12, true);
        assertTrue(_contains(a, 'data-dino-eye="1"'), "dino eye");
        assertTrue(_contains(a, 'data-snout="1"'), "snout mouth");
        TerminalRenderer.Roll memory d12 = r.roll(12);
        if (d12.accessory == 4) {
            assertTrue(_contains(a, 'data-mono="1"'), "profile monocle");
            assertFalse(_contains(a, 'data-bridge="1"'), "profile has no dual-lens bar");
        }
        bool[6] memory mouthSeen;
        bool[6] memory eyeSeen;
        uint256 mouthN;
        uint256 eyeN;
        uint256 dinoN;
        for (uint256 id = 1; id <= 400; ++id) {
            TerminalRenderer.Roll memory roll = r.roll(id);
            if (roll.species != 2) continue;
            unchecked {
                ++dinoN;
            }
            string memory lit = r.svg(id, true);
            assertTrue(_contains(lit, 'data-dino-eye="1"'), "every dino has profile eye");
            assertTrue(_contains(lit, 'data-snout="1"'), "every dino has snout mouth");
            assertTrue(_contains(lit, 'data-cx="158"'), "face locked to head");
            if (!eyeSeen[roll.eyes]) {
                eyeSeen[roll.eyes] = true;
                unchecked {
                    ++eyeN;
                }
            }
            if (!mouthSeen[roll.mouth]) {
                mouthSeen[roll.mouth] = true;
                unchecked {
                    ++mouthN;
                }
            }
            if (roll.accessory == 4) {
                assertTrue(_contains(lit, 'data-mono="1"'), "dino glasses are monocle");
                assertFalse(_contains(lit, 'data-bridge="1"'), "no dual bridge on dino");
            }
        }
        assertTrue(dinoN >= 8, "need several dinos in sample");
        assertTrue(eyeN >= 4, "dino eye traits should differ");
        assertTrue(mouthN >= 4, "dino mouth traits should differ");
    }

    function test_bellySkipped_dinoAndGhost() public view {
        string memory dino = r.svg(12, true);
        string memory ghost = r.svg(7, true);
        string memory cat = r.svg(3, true);
        string memory robot = r.svg(11, true);
        assertFalse(_contains(dino, 'data-belly="1"'), "dino must not draw a belly patch");
        assertFalse(_contains(ghost, 'data-belly="1"'), "ghost must not draw a belly patch");
        assertFalse(_contains(robot, 'data-belly="1"'), "robot already skips belly");
        assertTrue(_contains(cat, 'data-belly="1"'), "cat still draws belly");
        assertEq(r.traits(12, true).belly, "n/a");
        assertEq(r.traits(7, true).belly, "n/a");
        assertTrue(keccak256(bytes(r.traits(3, true).belly)) != keccak256(bytes("n/a")), "cat belly is a color");
    }

    function test_birdMouthIsBeakColor() public view {
        string memory bird = r.svg(15, true);
        assertTrue(_contains(bird, 'data-beak="1"'), "bird draws a beak");
        assertTrue(_contains(bird, "246,"), "beak still reaches 246");
        string memory m = r.traits(15, true).mouth;
        bool colorName =
            _eq(m, "Amber") || _eq(m, "Coral") || _eq(m, "Sky") || _eq(m, "Gold") || _eq(m, "Rose") || _eq(m, "Ink");
        assertTrue(colorName, "bird mouth attr is a beak color");
        string memory catMouth = r.traits(3, true).mouth;
        bool expr = _eq(catMouth, "Flat") || _eq(catMouth, "Smile") || _eq(catMouth, "W") || _eq(catMouth, "Oh")
            || _eq(catMouth, "Grin") || _eq(catMouth, "Tongue");
        assertTrue(expr, "cat mouth is still an expression");
    }

    function test_noScarfOrPack() public view {
        for (uint256 id = 1; id <= 120; ++id) {
            TerminalRenderer.Roll memory a = r.roll(id);
            assertTrue(a.accessory < 6, "ACC_N is 6");
            string memory lit = r.svg(id, true);
            assertFalse(_contains(lit, "data-scarf"), "scarf gone");
            assertFalse(_contains(lit, "data-pack"), "pack gone");
            assertFalse(_contains(lit, 'data-acc="6"'), "no pack acc id");
            if (a.accessory == 5) {
                assertTrue(_contains(lit, 'data-acc="5"'), "halo is accessory 5");
                assertTrue(_contains(lit, 'r="8"'), "halo ring");
            }
        }
    }

    function test_eyeKindsAreDistinct() public view {
        TerminalRenderer.Roll memory a = r.roll(3);
        a.accessory = 0;
        bytes32[6] memory hashes;
        for (uint8 i; i < 6; ++i) {
            a.eyes = i;
            string memory svg = TerminalRenderer.svgFromRoll(i, a, true);
            assertTrue(_contains(svg, string.concat('data-kind="', _u8(i), '"')), "kind tag");
            hashes[i] = keccak256(bytes(svg));
            for (uint8 j; j < i; ++j) {
                assertTrue(hashes[i] != hashes[j], "each eye type must draw differently");
            }
        }
    }

    function test_reworkedSpeciesReadAsNames() public view {
        string memory dino = r.svg(12, true);
        assertTrue(_contains(dino, 'cx="134"'), "dino snout");
        assertTrue(_contains(dino, 'data-tail="1"'), "dino tail");
        assertTrue(_contains(dino, "180,126"), "dino spikes");
        assertFalse(_contains(dino, "292,188"), "old spear tail");
        string memory ghost = r.svg(7, true);
        assertTrue(_contains(ghost, 'data-ghost="1"'), "sheet ghost");
        assertTrue(_contains(ghost, "Q228 200"), "wavy hem");
        assertTrue(_contains(ghost, 'fill="#1e1930"'), "hollow eyes");
        string memory bird = r.svg(15, true);
        assertTrue(_contains(bird, "246,"), "beak");
        assertTrue(_contains(bird, "204,112"), "crest");
        string memory robot = r.svg(11, true);
        assertTrue(_contains(robot, 'data-visor="1"'), "visor");
        assertTrue(_contains(robot, "#5eead4"), "led eyes");
        assertTrue(_contains(robot, 'cx="200" cy="114"'), "antenna ball");
    }

    function test_sameId_samePetAcrossState() public view {
        TerminalRenderer.Traits memory t0 = r.traits(42, false);
        TerminalRenderer.Traits memory t1 = r.traits(42, true);
        assertEq(t0.state, "Dormant");
        assertEq(t1.state, "Lit");
        assertEq(t0.shell, t1.shell);
        assertEq(t0.shellColor, t1.shellColor);
        assertEq(t0.species, t1.species);
        assertEq(t0.bodyColor, t1.bodyColor);
        assertEq(t0.accessory, t1.accessory);
        assertEq(t0.generation, t1.generation);
        assertTrue(keccak256(bytes(r.tokenURI(42, false))) != keccak256(bytes(r.tokenURI(42, true))));
    }

    function test_roll_deterministic() public view {
        TerminalRenderer.Roll memory a = r.roll(42);
        TerminalRenderer.Roll memory b = r.roll(42);
        assertEq(a.shell, b.shell);
        assertEq(a.species, b.species);
        assertEq(a.jx, b.jx);
        assertTrue(a.shell < 8 && a.species < 12 && a.body < 12);
    }

    function test_differentIds_canDiffer() public view {
        TerminalRenderer.Roll memory a = r.roll(1);
        bool differed;
        for (uint256 i = 2; i <= 64; ++i) {
            TerminalRenderer.Roll memory b = r.roll(i);
            if (a.shell != b.shell || a.species != b.species || a.shellColor != b.shellColor) {
                differed = true;
                break;
            }
        }
        assertTrue(differed);
    }

    function test_tokenURI_containsTraitsAndState() public view {
        string memory dormant = r.tokenURI(42, false);
        string memory lit = r.tokenURI(42, true);
        assertTrue(_startsWith(dormant, "data:application/json;base64,"));
        assertTrue(_startsWith(lit, "data:application/json;base64,"));
        TerminalRenderer.Traits memory t = r.traits(42, false);
        assertTrue(bytes(t.shell).length > 0);
        assertTrue(bytes(t.species).length > 0);
        assertTrue(bytes(t.bodyColor).length > 0);
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

    function test_smilByState() public view {
        for (uint256 id = 1; id <= 16; ++id) {
            string memory dormant = r.svg(id, false);
            string memory lit = r.svg(id, true);
            assertTrue(_contains(dormant, "<animate"), "dormant zzz should pulse");
            assertTrue(_contains(dormant, "<animateTransform"), "dormant zzz should float");
            assertFalse(_contains(dormant, ".04;.12;.04"), "dormant must not glow");
            assertFalse(_contains(dormant, "1;1;1;.2;1"), "dormant must not blink");
            assertTrue(_contains(lit, ".04;.12;.04"), "lit glow");
            assertTrue(_contains(lit, "1;1;1;.2;1"), "lit blink");
            assertTrue(_contains(lit, "<animateTransform"), "lit idle jitter");
            assertTrue(_contains(lit, 'type="translate"'), "lit translate nudge");
        }
    }

    function test_speciesAndShellsDiverge() public view {
        bool[12] memory speciesSeen;
        bool[8] memory shellSeen;
        uint256 sN;
        uint256 hN;
        for (uint256 id = 1; id <= 96; ++id) {
            TerminalRenderer.Roll memory a = r.roll(id);
            if (!speciesSeen[a.species]) {
                speciesSeen[a.species] = true;
                unchecked {
                    ++sN;
                }
            }
            if (!shellSeen[a.shell]) {
                shellSeen[a.shell] = true;
                unchecked {
                    ++hN;
                }
            }
        }
        assertTrue(sN >= 8, "need many species in first 96");
        assertTrue(hN >= 5, "need many shells in first 96");
    }

    function test_petClippedToInnerScreen() public view {
        for (uint256 id = 1; id <= 28; ++id) {
            string memory lit = r.svg(id, true);
            string memory dormant = r.svg(id, false);
            assertTrue(_contains(lit, "<clipPath"), "missing clipPath");
            assertTrue(_contains(lit, 'id="scr"'), "missing screen clip id");
            assertTrue(_contains(lit, 'clip-path="url(#scr)"'), "pet not clipped");
            assertTrue(_contains(lit, 'x="116" y="94" width="168" height="160" rx="12"'), "clip rect mismatch");
            assertTrue(_contains(dormant, 'clip-path="url(#scr)"'), "dormant pet not clipped");
        }
    }

    function test_dinoTailSoft_andFrecklesOnCheeks() public view {
        string memory dino = r.svg(12, true);
        assertFalse(_contains(dino, "292,188"), "old spear tail");
        assertTrue(_contains(dino, 'data-tail="1"'), "tapered tail on the body path");
        assertFalse(_contains(dino, 'cx="266" cy="168"'), "old bubbly tail tip gone");
        assertFalse(_contains(dino, 'cx="248" cy="180"'), "old mid-tail bubble gone");
        string memory freckled = r.svg(2, true);
        assertTrue(_contains(freckled, 'r="2"'), "tiny freckle dots");
        assertTrue(_contains(freckled, "#c9897a"), "muted freckle color");
        assertFalse(_contains(freckled, 'r="3" fill="#000"'), "old torso spots");
        assertFalse(_contains(dino, 'r="3" fill="#000"'), "old torso spots");
    }

    function test_footerAndZzzStayInSafeBoxes() public view {
        uint256[8] memory ids = [uint256(1), 42, 100, 777, 1337, 2500, 4444, 88];
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            string memory lit = r.svg(id, true);
            string memory dormant = r.svg(id, false);
            assertTrue(_contains(lit, 'text-anchor="middle"'), "footer not centered");
            assertTrue(_contains(lit, "PET#"), "missing PET#");
            assertFalse(_contains(lit, "PET //"), "old footer leaked");
            assertTrue(_contains(lit, 'y="324"'), "footer not in safe band");
            assertTrue(_contains(dormant, 'y="120"'), "zzz not in screen");
            assertTrue(_contains(dormant, 'y="110"'), "zzz not in screen");
        }
        assertTrue(_contains(r.svg(1337, true), "PET#1337"));
        assertTrue(_contains(r.svg(2500, true), "PET#2500"));
        assertTrue(_contains(r.svg(4444, true), "PET#4444"));
    }

    function test_fingerprintUnique_first500() public {
        for (uint256 id = 1; id <= 500; ++id) {
            bytes32 fp = r.fingerprint(id);
            uint256 prev = scratchMap[fp];
            assertEq(prev, 0, "trait fingerprint collision");
            scratchMap[fp] = id;
        }
    }

    function test_svgHashUnique_first80_andPairs() public view {
        bytes32[] memory hashes = new bytes32[](80);
        for (uint256 id = 1; id <= 80; ++id) {
            hashes[id - 1] = keccak256(bytes(r.svg(id, false)));
            assertTrue(hashes[id - 1] != keccak256(bytes(r.svg(id, true))), "dormant equals lit");
        }
        for (uint256 i = 1; i < 80; ++i) {
            for (uint256 j; j < i; ++j) {
                assertTrue(hashes[i] != hashes[j], "dormant svg collision");
            }
        }
        for (uint256 n; n < 50; ++n) {
            uint256 a = uint256(keccak256(abi.encodePacked("pair", n))) % 2000 + 1;
            uint256 b = uint256(keccak256(abi.encodePacked("pairb", n))) % 2000 + 1;
            if (a == b) continue;
            assertTrue(keccak256(bytes(r.svg(a, true))) != keccak256(bytes(r.svg(b, true))));
        }
    }

    mapping(bytes32 => uint256) private scratchMap;

    function _assertFace(uint256 id, uint8 species, string memory cx, string memory ey, string memory gap)
        private
        view
    {
        TerminalRenderer.Roll memory a = r.roll(id);
        assertEq(a.species, species, "canonical species id drifted");
        string memory lit = r.svg(id, true);
        assertTrue(_contains(lit, 'data-face="1"'), "face group");
        assertTrue(_contains(lit, string.concat('data-sp="', _u8(species), '"')), "species on face");
        assertTrue(_contains(lit, string.concat('data-cx="', cx, '"')), "face cx");
        assertTrue(_contains(lit, string.concat('data-ey="', ey, '"')), "face eyeY");
        assertTrue(_contains(lit, string.concat('data-gap="', gap, '"')), "face gap");
        assertFalse(_contains(r.svg(id, false), 'data-face="1"'), "dormant has no face overlay");
    }

    function _u8(uint8 n) private pure returns (string memory) {
        if (n >= 10) {
            bytes memory two = new bytes(2);
            two[0] = bytes1(uint8(48 + n / 10));
            two[1] = bytes1(uint8(48 + n % 10));
            return string(two);
        }
        bytes memory one = new bytes(1);
        one[0] = bytes1(uint8(48 + n));
        return string(one);
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _contains(string memory value, string memory needle) private pure returns (bool) {
        bytes memory a = bytes(value);
        bytes memory b = bytes(needle);
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

    function _startsWith(string memory value, string memory prefix) private pure returns (bool) {
        bytes memory a = bytes(value);
        bytes memory b = bytes(prefix);
        if (a.length < b.length) return false;
        for (uint256 i; i < b.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    function _count(string memory value, string memory needle) private pure returns (uint256 n) {
        bytes memory a = bytes(value);
        bytes memory b = bytes(needle);
        if (a.length < b.length) return 0;
        for (uint256 i; i + b.length <= a.length; ++i) {
            bool ok = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) {
                unchecked {
                    ++n;
                    i += b.length - 1;
                }
            }
        }
    }

    function _brightShell(uint8 i) private pure returns (string memory) {
        if (i == 0) return "#f4a6c8";
        if (i == 1) return "#7ec8e3";
        if (i == 2) return "#f6d365";
        if (i == 3) return "#a3e635";
        if (i == 4) return "#c4b5fd";
        if (i == 5) return "#fb923c";
        if (i == 6) return "#94a3b8";
        if (i == 7) return "#fca5a5";
        if (i == 8) return "#6ee7b7";
        if (i == 9) return "#60a5fa";
        if (i == 10) return "#fb7185";
        return "#e7d3a8";
    }

    function _btnHex(uint8 i) private pure returns (string memory) {
        if (i == 0) return "#ef4444";
        if (i == 1) return "#3b82f6";
        if (i == 2) return "#facc15";
        if (i == 3) return "#f8fafc";
        if (i == 4) return "#1e293b";
        if (i == 5) return "#14b8a6";
        if (i == 6) return "#22c55e";
        return "#ec4899";
    }
}
