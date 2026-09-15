// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title TerminalRenderer
/// @notice On-chain SVG for Terminal Pets. Seed domain `AWAKEN_PET_V2` is locked.
/// Accessories are None, Bow, Cap, Star, Glasses, Halo (ACC_N = 6). Scarf and Pack
/// were removed; old 8-way rolls remap via `s % 6` (Halo is index 5).
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

    struct FaceAnchor {
        uint256 cx;
        uint256 ey;
        uint256 gap;
        uint256 mouthY;
        uint256 hatY;
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
        t.belly = _skipBelly(a.species) ? "n/a" : _bellyName(a.belly);
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
        return svgFromRoll(tokenId, roll(tokenId), lit);
    }

    function svgFromRoll(uint256 tokenId, Roll memory a, bool lit) internal pure returns (string memory) {
        return _doc(tokenId, a, lit, 255);
    }

    function hiddenSvg(uint256 tokenId) internal pure returns (string memory) {
        Roll memory mystery;
        mystery.shell = 1;
        mystery.antenna = 2;
        mystery.button = 2;
        return _mysteryDoc(tokenId, mystery);
    }

    function wakeSvg(uint256 tokenId) internal pure returns (string memory) {
        return _doc(tokenId, roll(tokenId), true, 1);
    }

    function tokenURI(uint256 tokenId, bool lit) internal pure returns (string memory) {
        return _jsonURI(tokenId, svg(tokenId, lit), traits(tokenId, lit));
    }

    function hiddenTokenURI(uint256 tokenId) internal pure returns (string memory) {
        Traits memory t = sealedTraits();
        return _jsonURI(tokenId, hiddenSvg(tokenId), t);
    }

    function contractURI() internal pure returns (string memory) {
        string memory image = hiddenSvg(0);
        string memory json = string.concat(
            '{"name":"Terminal Pets","description":"Handheld pets on Robinhood Chain. Mint Sealed, Ignite to Lit.","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(image)),
            '","external_link":"https://terminalpets.xyz"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
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
            '","description":"A handheld Terminal Pet. Dormant until Ignite.","image":"data:image/svg+xml;base64,',
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

    /// @dev stage 255 = still (dormant or lit). stage 1 = wake SMIL.
    function _doc(uint256 tokenId, Roll memory a, bool lit, uint8 stage) private pure returns (string memory) {
        string memory chrome = _chrome(tokenId, a, false);
        string memory inner;
        if (stage == 1) {
            inner = _wakeInner(tokenId, a);
        } else if (!lit) {
            inner = _dormantInner(a);
        } else {
            inner = _litInner(a);
        }
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            "<defs>",
            '<clipPath id="scr"><rect x="116" y="94" width="168" height="160" rx="12"/></clipPath>',
            "</defs>",
            '<rect width="400" height="400" fill="#141018"/>',
            chrome,
            inner,
            "</svg>"
        );
    }

    function _mysteryDoc(uint256 tokenId, Roll memory a) private pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            "<defs>",
            '<clipPath id="scr"><rect x="116" y="94" width="168" height="160" rx="12"/></clipPath>',
            "</defs>",
            '<rect width="400" height="400" fill="#141018"/>',
            _chrome(tokenId, a, true),
            _teaserInner(),
            '<text x="200" y="84" text-anchor="middle" fill="#c9a227" font-size="11" font-family="monospace">TERMINAL PETS</text>',
            '<text x="200" y="348" text-anchor="middle" fill="#c9a227" font-size="10" font-family="monospace">SEALED</text>',
            '<text x="200" y="188" text-anchor="middle" fill="#94a3b8" font-size="9" font-family="monospace" opacity=".35">UNREVEALED</text>',
            "</svg>"
        );
    }

    function _chrome(uint256 tokenId, Roll memory a, bool mystery) private pure returns (string memory) {
        string memory fill = mystery ? "#1a2030" : _shellHex(a.shellColor);
        string memory stroke = mystery ? "#c9a227" : "#2a2430";
        string memory btn = mystery ? "#c9a227" : _btnHex(a.button);
        return string.concat(
            _shellShape(a.shell, fill, stroke),
            _antenna(a.antenna, mystery ? "#c9a227" : fill, stroke),
            '<rect x="116" y="94" width="168" height="160" rx="12" fill="#0c0a10" stroke="',
            stroke,
            '" stroke-width="3"/>',
            '<circle cx="168" cy="272" r="9" fill="',
            btn,
            '" stroke="#2a2430" stroke-width="2"/>',
            '<circle cx="200" cy="272" r="9" fill="',
            btn,
            '" stroke="#2a2430" stroke-width="2"/>',
            '<circle cx="232" cy="272" r="9" fill="',
            btn,
            '" stroke="#2a2430" stroke-width="2"/>',
            '<text x="200" y="324" text-anchor="middle" fill="#e8e4f0" font-size="13" font-family="monospace">PET#',
            tokenId.toString(),
            "</text>",
            '<text x="200" y="342" text-anchor="middle" fill="#94a3b8" font-size="10" font-family="monospace">',
            mystery ? "SEALED" : _genName(a.generation),
            "</text>"
        );
    }

    function _shellShape(uint8 shell, string memory fill, string memory stroke) private pure returns (string memory) {
        string memory open = string.concat('<path fill="', fill, '" stroke="', stroke, '" stroke-width="5" ');
        if (shell == 0) {
            return string.concat(
                open,
                'd="M200 48 C132 52 86 96 84 168 C82 248 118 338 200 352 C282 338 318 248 316 168 C314 96 268 52 200 48 Z"/>'
            );
        }
        if (shell == 2) {
            return string.concat(
                open, 'd="M108 64 H292 Q312 64 312 84 V316 Q312 336 292 336 H108 Q88 336 88 316 V84 Q88 64 108 64 Z"/>'
            );
        }
        if (shell == 3) {
            return string.concat(
                open,
                'd="M118 70 C90 110 96 150 88 190 C80 250 110 330 200 344 C290 330 320 250 312 190 C304 150 310 110 282 70 C248 50 152 50 118 70 Z"/>'
            );
        }
        if (shell == 4) {
            return string.concat(
                open,
                'd="M128 58 H272 Q292 58 292 78 V322 Q292 342 272 342 H128 Q108 342 108 322 V78 Q108 58 128 58 Z"/>'
            );
        }
        if (shell == 5) {
            return string.concat(
                open, 'd="M78 70 H322 Q342 70 342 90 V310 Q342 330 322 330 H78 Q58 330 58 310 V90 Q58 70 78 70 Z"/>'
            );
        }
        if (shell == 6) {
            return string.concat(open, 'd="M140 58 L260 58 L312 110 L312 290 L260 342 L140 342 L88 290 L88 110 Z"/>');
        }
        if (shell == 7) {
            return string.concat(
                open,
                'd="M200 56 C130 70 90 120 92 188 C94 250 130 320 200 348 C270 320 306 250 308 188 C310 120 270 70 200 56 Z"/>'
            );
        }
        return string.concat(
            open,
            'd="M112 72 Q200 44 288 72 Q318 110 312 200 Q318 300 288 336 Q200 360 112 336 Q82 300 88 200 Q82 110 112 72 Z"/>'
        );
    }

    function _antenna(uint8 kind, string memory fill, string memory stroke) private pure returns (string memory) {
        if (kind == 0) return "";
        if (kind == 1) {
            return string.concat(
                '<rect x="194" y="42" width="12" height="22" rx="4" fill="',
                fill,
                '" stroke="',
                stroke,
                '" stroke-width="2"/>'
            );
        }
        if (kind == 2) {
            return string.concat(
                '<line x1="200" y1="58" x2="200" y2="40" stroke="',
                stroke,
                '" stroke-width="3"/>',
                '<circle cx="200" cy="32" r="8" fill="',
                fill,
                '" stroke="',
                stroke,
                '" stroke-width="2"/>'
            );
        }
        if (kind == 3) {
            return string.concat(
                '<line x1="200" y1="58" x2="188" y2="28" stroke="',
                stroke,
                '" stroke-width="3"/>',
                '<line x1="200" y1="58" x2="212" y2="28" stroke="',
                stroke,
                '" stroke-width="3"/>'
            );
        }
        if (kind == 4) {
            return string.concat(
                '<polygon points="200,24 208,58 192,58" fill="', fill, '" stroke="', stroke, '" stroke-width="2"/>'
            );
        }
        return string.concat(
            '<line x1="200" y1="58" x2="200" y2="36" stroke="',
            stroke,
            '" stroke-width="3"/>',
            '<ellipse cx="200" cy="28" rx="14" ry="8" fill="',
            fill,
            '" stroke="',
            stroke,
            '" stroke-width="2"/>'
        );
    }

    function _dormantInner(Roll memory a) private pure returns (string memory) {
        uint256 j = 124 + uint256(a.jx);
        return string.concat(
            '<g clip-path="url(#scr)"><g>',
            '<rect x="116" y="94" width="168" height="160" fill="#16141c"/>',
            '<g data-egg="1">',
            '<ellipse cx="200" cy="174" rx="38" ry="50" fill="#e8e0d4" stroke="#2a2430" stroke-width="3"/>',
            '<ellipse cx="188" cy="160" rx="4" ry="5" fill="#d4c4a8"/>',
            '<ellipse cx="212" cy="178" rx="5" ry="4" fill="#d4c4a8"/>',
            '<ellipse cx="196" cy="196" rx="4" ry="4" fill="#d4c4a8"/>',
            '<animateTransform attributeName="transform" type="translate" values="0 0;0 -1;0 0" dur="',
            (18 + uint256(a.jx)).toString(),
            's" repeatCount="indefinite"/>',
            "</g>",
            '<g><text x="230" y="120" fill="#e2e8f0" font-size="14" font-family="monospace">Z</text>',
            '<text x="244" y="110" fill="#e2e8f0" font-size="18" font-family="monospace">z</text>',
            '<animate attributeName="opacity" values="0.35;0.95;0.55;0.35" dur="2.4s" repeatCount="indefinite"/>',
            '<animateTransform attributeName="transform" type="translate" values="0 0;0 -4;0 0" dur="2.4s" repeatCount="indefinite"/>',
            "</g>",
            '<animateTransform attributeName="transform" type="translate" values="0 0;1 -1;-1 1;0 0" dur="',
            j.toString(),
            's" repeatCount="indefinite"/>',
            "</g></g>"
        );
    }

    function _litInner(Roll memory a) private pure returns (string memory) {
        return string.concat(
            '<g clip-path="url(#scr)"><g>',
            _wallpaper(a.wallpaper),
            '<ellipse cx="200" cy="174" rx="70" ry="64" fill="#fff" fill-opacity=".04">',
            '<animate attributeName="fill-opacity" values=".04;.12;.04" dur="2.8s" repeatCount="indefinite"/>',
            "</ellipse>",
            _pet(a, true),
            '<animateTransform attributeName="transform" type="translate" values="0 0;1 -1;-1 1;0 0" dur="',
            (9 + uint256(a.jx)).toString(),
            's" repeatCount="indefinite"/>',
            "</g></g>"
        );
    }

    function _wakeInner(uint256 tokenId, Roll memory a) private pure returns (string memory) {
        tokenId;
        string memory egg = string.concat(
            '<g data-egg="1">',
            '<ellipse cx="200" cy="174" rx="38" ry="50" fill="#e8e0d4" stroke="#2a2430" stroke-width="3"/>',
            '<ellipse cx="188" cy="160" rx="4" ry="5" fill="#d4c4a8"/>',
            "</g>"
        );
        return string.concat(
            "<defs>",
            '<clipPath id="egL"><rect x="116" y="94" width="84" height="160"/></clipPath>',
            "</defs>",
            '<g clip-path="url(#scr)">',
            '<g opacity="1" data-w="0">',
            '<rect x="116" y="94" width="168" height="160" fill="#16141c"/>',
            egg,
            '<animate attributeName="opacity" values="1;1;0;0;0" dur="4s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>",
            '<g opacity="0" data-w="1">',
            '<rect x="116" y="94" width="168" height="160" fill="#16141c"/>',
            '<g clip-path="url(#egL)">',
            egg,
            "</g>",
            '<path d="M200 130 L194 160 L206 180 L198 210" fill="none" stroke="#2a2430" stroke-width="2"/>',
            '<animate attributeName="opacity" values="0;0;1;0;0" dur="4s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>",
            '<g opacity="0" data-w="2">',
            '<rect x="116" y="94" width="168" height="160" fill="#fff"/>',
            '<animate attributeName="opacity" values="0;0;0;1;0" dur="4s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>",
            '<g opacity="0" data-w="3">',
            _wallpaper(a.wallpaper),
            _pet(a, true),
            '<animate attributeName="opacity" values="0;0;0;0;1" dur="4s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>",
            "</g>"
        );
    }

    function _teaserInner() private pure returns (string memory) {
        return string.concat(
            '<g clip-path="url(#scr)">',
            '<g opacity="1" data-f="0">',
            '<rect x="116" y="94" width="168" height="160" fill="#0c0a10"/>',
            '<text x="200" y="180" text-anchor="middle" fill="#c9a227" font-size="54" font-family="monospace">?</text>',
            '<animate attributeName="opacity" values="1;1;1;1;0;0;0;0;0;0" dur="8s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>",
            _teaserFrame(
                1,
                "#86efac",
                '<polygon points="164,122 176,150 152,148" fill="#86efac" stroke="#2a2430" stroke-width="3"/>',
                "1;0;0;0;1;0;0;0;0;0"
            ),
            _teaserFrame(2, "#d8b4fe", "", "0;0;0;0;0;1;0;0;0;0"),
            _teaserFrame(3, "#fda4af", "", "0;0;0;0;0;0;1;0;0;0"),
            _teaserFrame(4, "#7dd3fc", "", "0;0;0;0;0;0;0;1;0;0"),
            _teaserFrame(5, "#fdba74", "", "0;0;0;0;0;0;0;0;1;0"),
            _teaserFrame(6, "#86efac", "", "0;0;0;0;0;0;0;0;0;1"),
            "</g>"
        );
    }

    function _teaserFrame(uint256 i, string memory body, string memory extra, string memory values)
        private
        pure
        returns (string memory)
    {
        string memory pet = i == 2
            ? string.concat(
                '<g fill="',
                body,
                '" stroke="#2a2430" stroke-width="3">',
                '<ellipse cx="158" cy="150" rx="18" ry="16"/>',
                '<ellipse cx="134" cy="158" rx="14" ry="9"/>',
                '<ellipse cx="200" cy="180" rx="36" ry="28"/>',
                "</g>"
            )
            : string.concat(
                '<ellipse cx="200" cy="178" rx="44" ry="40" fill="',
                body,
                '" stroke="#2a2430" stroke-width="3"/>',
                extra
            );
        return string.concat(
            '<g opacity="0" data-f="',
            i.toString(),
            '">',
            '<rect x="116" y="94" width="168" height="160" fill="#fff4d6"/>',
            pet,
            '<animate attributeName="opacity" values="',
            values,
            '" dur="8s" calcMode="discrete" repeatCount="indefinite"/>',
            "</g>"
        );
    }

    function _wallpaper(uint8 w) private pure returns (string memory) {
        string memory base = '<rect x="116" y="94" width="168" height="160" fill="#fff4d6"/>';
        if (w == 0) return base;
        if (w == 1) {
            return string.concat(
                base,
                '<circle cx="140" cy="120" r="4" fill="#f9a8d4" opacity=".5"/>',
                '<circle cx="180" cy="150" r="4" fill="#f9a8d4" opacity=".5"/>',
                '<circle cx="230" cy="130" r="4" fill="#f9a8d4" opacity=".5"/>',
                '<circle cx="250" cy="200" r="4" fill="#f9a8d4" opacity=".5"/>'
            );
        }
        if (w == 2) {
            return string.concat(
                base,
                '<rect x="116" y="110" width="168" height="10" fill="#fde68a" opacity=".45"/>',
                '<rect x="116" y="150" width="168" height="10" fill="#fde68a" opacity=".45"/>',
                '<rect x="116" y="190" width="168" height="10" fill="#fde68a" opacity=".45"/>'
            );
        }
        if (w == 3) {
            return string.concat(
                base,
                '<path d="M148 94 V254 M180 94 V254 M212 94 V254 M244 94 V254 M116 126 H284 M116 158 H284 M116 190 H284 M116 222 H284" stroke="#fdba74" stroke-width="1" opacity=".4"/>'
            );
        }
        if (w == 4) {
            return string.concat(
                base,
                '<text x="150" y="140" font-size="16" fill="#fb7185" opacity=".45">&#9829;</text>',
                '<text x="220" y="180" font-size="16" fill="#fb7185" opacity=".45">&#9829;</text>',
                '<text x="170" y="220" font-size="16" fill="#fb7185" opacity=".45">&#9829;</text>'
            );
        }
        if (w == 5) {
            return string.concat(
                base,
                '<polygon points="160,120 164,130 176,130 166,136 170,148 160,140 150,148 154,136 144,130 156,130" fill="#fbbf24" opacity=".4"/>',
                '<polygon points="230,170 234,180 246,180 236,186 240,198 230,190 220,198 224,186 214,180 226,180" fill="#fbbf24" opacity=".4"/>'
            );
        }
        if (w == 6) {
            return string.concat(
                base,
                '<rect x="116" y="94" width="42" height="40" fill="#bbf7d0" opacity=".35"/>',
                '<rect x="200" y="94" width="42" height="40" fill="#bbf7d0" opacity=".35"/>',
                '<rect x="158" y="134" width="42" height="40" fill="#bbf7d0" opacity=".35"/>',
                '<rect x="242" y="134" width="42" height="40" fill="#bbf7d0" opacity=".35"/>'
            );
        }
        return string.concat(
            base,
            '<rect x="116" y="94" width="168" height="70" fill="#fda4af" opacity=".25"/>',
            '<rect x="116" y="164" width="168" height="90" fill="#7dd3fc" opacity=".2"/>'
        );
    }

    function _pet(Roll memory a, bool lit) private pure returns (string memory) {
        string memory body = _bodyHex(a.body);
        string memory sil = _silhouette(a.species, body);
        if (!lit) return sil;
        string memory belly = _bellySvg(a, body);
        string memory face = _face(a);
        string memory acc = _accessory(a);
        return string.concat(sil, belly, face, acc);
    }

    function _silhouette(uint8 sp, string memory body) private pure returns (string memory) {
        string memory st = string.concat(' fill="', body, '" stroke="#2a2430" stroke-width="3" stroke-linejoin="round"');
        if (sp == 0) {
            return string.concat("<g>", '<ellipse cx="200" cy="180" rx="48" ry="46"', st, "/></g>");
        }
        if (sp == 1) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="186" rx="46" ry="40"',
                st,
                "/>",
                '<polygon points="164,122 176,152 150,150"',
                st,
                "/>",
                '<polygon points="236,122 250,150 224,150"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 2) return _dinoParts(body);
        if (sp == 3) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="186" rx="42" ry="38"',
                st,
                "/>",
                '<polygon points="168,124 178,154 154,150"',
                st,
                "/>",
                '<polygon points="232,124 246,150 222,150"',
                st,
                "/>",
                '<ellipse cx="200" cy="196" rx="18" ry="12"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 4) {
            return string.concat(
                '<g data-ghost="1">',
                '<path d="M160 150 Q160 118 200 118 Q240 118 240 150 L240 210 Q228 200 216 210 Q204 200 200 210 Q196 200 184 210 Q172 200 160 210 Z"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 5) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="190" rx="40" ry="36"',
                st,
                "/>",
                '<ellipse cx="176" cy="128" rx="8" ry="28"',
                st,
                "/>",
                '<ellipse cx="224" cy="128" rx="8" ry="28"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 6) {
            return string.concat(
                "<g>",
                '<ellipse cx="196" cy="176" rx="36" ry="34"',
                st,
                "/>",
                '<polygon points="196,128 204,112 212,128"',
                st,
                "/>",
                '<ellipse cx="176" cy="190" rx="14" ry="8"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 7) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="190" rx="52" ry="32"',
                st,
                "/>",
                '<ellipse cx="176" cy="150" rx="16" ry="14"',
                st,
                "/>",
                '<ellipse cx="224" cy="150" rx="16" ry="14"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 8) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="188" rx="48" ry="42"',
                st,
                "/>",
                '<circle cx="174" cy="142" r="14"',
                st,
                "/>",
                '<circle cx="226" cy="142" r="14"',
                st,
                "/>",
                "</g>"
            );
        }
        if (sp == 9) {
            return string.concat(
                "<g>",
                '<rect x="166" y="138" width="68" height="78" rx="10"',
                st,
                "/>",
                '<rect x="176" y="150" width="48" height="22" rx="6" data-visor="1" fill="#1e293b" stroke="#2a2430" stroke-width="2"/>',
                '<line x1="200" y1="138" x2="200" y2="118" stroke="#2a2430" stroke-width="3"/>',
                '<circle cx="200" cy="114" r="6" fill="',
                body,
                '" stroke="#2a2430" stroke-width="2"/>',
                "</g>"
            );
        }
        if (sp == 10) {
            return string.concat(
                "<g>",
                '<ellipse cx="200" cy="184" rx="42" ry="40"',
                st,
                "/>",
                '<polygon points="170,132 176,154 158,150"',
                st,
                "/>",
                '<polygon points="230,132 242,150 224,154"',
                st,
                "/>",
                "</g>"
            );
        }
        return string.concat(
            "<g>",
            '<ellipse cx="200" cy="186" rx="40" ry="30"',
            st,
            "/>",
            '<line x1="176" y1="150" x2="168" y2="128" stroke="#2a2430" stroke-width="3"/>',
            '<line x1="224" y1="150" x2="232" y2="128" stroke="#2a2430" stroke-width="3"/>',
            "</g>"
        );
    }

    /// @dev Front-facing dino in the same family as Cat/Blob: round body, ridge,
    /// snout bump, bubbly tail with a spear tip, and torso spots.
    function _dinoParts(string memory body) private pure returns (string memory) {
        string memory st = string.concat(' fill="', body, '" stroke="#2a2430" stroke-width="3" stroke-linejoin="round"');
        return string.concat(
            '<g data-dino="1">',
            '<ellipse data-dino-body="1" data-dino-head="1" cx="200" cy="186" rx="46" ry="40"',
            st,
            "/>",
            '<polygon data-ridge="1" points="176,152 180,126 184,128 192,152"',
            st,
            "/>",
            '<polygon points="192,148 200,124 208,148"',
            st,
            "/>",
            '<polygon points="208,152 216,130 224,152"',
            st,
            "/>",
            '<ellipse data-snout="1" cx="200" cy="204" rx="14" ry="8"',
            st,
            "/>",
            '<ellipse data-tail="1" cx="248" cy="180" rx="16" ry="13"',
            st,
            "/>",
            '<ellipse cx="266" cy="168" rx="11" ry="10"',
            st,
            "/>",
            '<polygon points="274,164 292,188 268,176"',
            st,
            "/>",
            '<circle cx="186" cy="196" r="3" fill="#000"/>',
            '<circle cx="210" cy="202" r="3" fill="#000"/>',
            '<circle cx="198" cy="210" r="3" fill="#000"/>',
            "</g>"
        );
    }

    function _skipBelly(uint8 sp) private pure returns (bool) {
        return sp == 4 || sp == 9;
    }

    function _bellySvg(Roll memory a, string memory body) private pure returns (string memory) {
        if (_skipBelly(a.species)) return "";
        string memory fill = a.belly == 3 ? body : _bellyHex(a.belly);
        uint256 cy = a.species == 7 ? 200 : 198;
        uint256 rx = a.species == 7 ? 22 : 18;
        return string.concat(
            '<ellipse data-belly="1" cx="200" cy="',
            cy.toString(),
            '" rx="',
            rx.toString(),
            '" ry="16" fill="',
            fill,
            '" stroke="#2a2430" stroke-width="2"/>'
        );
    }

    function _faceOf(uint8 sp) private pure returns (FaceAnchor memory f) {
        if (sp == 0) return FaceAnchor(200, 168, 16, 186, 122);
        if (sp == 1) return FaceAnchor(200, 170, 15, 188, 118);
        if (sp == 2) return FaceAnchor(200, 168, 16, 186, 122);
        if (sp == 3) return FaceAnchor(200, 166, 15, 186, 118);
        if (sp == 4) return FaceAnchor(200, 168, 16, 188, 120);
        if (sp == 5) return FaceAnchor(200, 172, 14, 190, 108);
        if (sp == 6) return FaceAnchor(196, 148, 8, 168, 118);
        if (sp == 7) return FaceAnchor(200, 156, 24, 196, 128);
        if (sp == 8) return FaceAnchor(200, 174, 16, 194, 128);
        if (sp == 9) return FaceAnchor(200, 155, 14, 186, 118);
        if (sp == 10) return FaceAnchor(200, 172, 14, 190, 124);
        return FaceAnchor(200, 168, 12, 186, 128);
    }

    function _face(Roll memory a) private pure returns (string memory) {
        FaceAnchor memory f = _faceOf(a.species);
        return string.concat(
            '<g data-face="1" data-sp="',
            uint256(a.species).toString(),
            '" data-cx="',
            f.cx.toString(),
            '" data-ey="',
            f.ey.toString(),
            '" data-gap="',
            f.gap.toString(),
            '">',
            _cheeks(a, f),
            _brows(a, f),
            _eyes(a, f),
            _mouth(a, f),
            "</g>"
        );
    }

    function _cheeks(Roll memory a, FaceAnchor memory f) private pure returns (string memory) {
        if (a.cheeks == 0) return "";
        uint256 y = f.ey + 10;
        uint256 lx = f.cx - f.gap - 2;
        uint256 rx = f.cx + f.gap + 2;
        if (a.cheeks == 1) {
            return string.concat(
                '<ellipse cx="',
                lx.toString(),
                '" cy="',
                y.toString(),
                '" rx="6" ry="4" fill="#f9a8d4" opacity=".8"/>',
                '<ellipse cx="',
                rx.toString(),
                '" cy="',
                y.toString(),
                '" rx="6" ry="4" fill="#f9a8d4" opacity=".8"/>'
            );
        }
        return string.concat(_dot(lx, y), _dot(lx + 6, y + 4), _dot(rx, y), _dot(rx - 6, y + 4));
    }

    function _dot(uint256 x, uint256 y) private pure returns (string memory) {
        return string.concat('<circle cx="', x.toString(), '" cy="', y.toString(), '" r="2" fill="#c9897a"/>');
    }

    function _brows(Roll memory a, FaceAnchor memory f) private pure returns (string memory) {
        if (a.ears == 0) return "";
        uint256 y = f.ey - 14;
        uint256 x = a.species == 2 ? f.cx : f.cx;
        if (a.ears == 1) {
            return string.concat(
                '<path d="M',
                (x - 8).toString(),
                " ",
                y.toString(),
                " L",
                x.toString(),
                " ",
                (y - 6).toString(),
                " L",
                (x + 8).toString(),
                " ",
                y.toString(),
                '" fill="none" stroke="#2a2430" stroke-width="3"/>'
            );
        }
        if (a.ears == 2) {
            return string.concat(
                '<polygon points="',
                (x - 4).toString(),
                ",",
                y.toString(),
                " ",
                x.toString(),
                ",",
                (y - 12).toString(),
                " ",
                (x + 4).toString(),
                ",",
                y.toString(),
                '" fill="#2a2430"/>'
            );
        }
        if (a.ears == 3) {
            return string.concat(
                '<path d="M',
                (x - 10).toString(),
                " ",
                y.toString(),
                " Q",
                x.toString(),
                " ",
                (y + 8).toString(),
                " ",
                (x + 10).toString(),
                " ",
                y.toString(),
                '" fill="none" stroke="#2a2430" stroke-width="3"/>'
            );
        }
        return string.concat(
            '<circle cx="',
            (x - 6).toString(),
            '" cy="',
            (y - 2).toString(),
            '" r="3" fill="#2a2430"/>',
            '<circle cx="',
            (x + 6).toString(),
            '" cy="',
            (y - 2).toString(),
            '" r="3" fill="#2a2430"/>'
        );
    }

    function _eyes(Roll memory a, FaceAnchor memory f) private pure returns (string memory) {
        string memory tag = string.concat(
            '<g data-eyes="', uint256(a.eyes).toString(), '" data-kind="', uint256(a.eyes).toString(), '">'
        );
        if (a.species == 2) {
            return
                string.concat(tag, _oneEye(a, f.cx - f.gap, f.ey, true), _oneEye(a, f.cx + f.gap, f.ey, true), "</g>");
        }
        if (a.species == 9) {
            return string.concat(
                tag,
                '<rect x="180" y="152" width="40" height="16" rx="4" fill="#1e293b"/>',
                _led(a, f.cx - f.gap, f.ey),
                _led(a, f.cx + f.gap, f.ey),
                "</g>"
            );
        }
        if (a.species == 6) {
            return
                string.concat(tag, _oneEye(a, f.cx - f.gap, f.ey, false), _oneEye(a, f.cx + f.gap, f.ey, false), "</g>");
        }
        if (a.species == 4) {
            return
                string.concat(tag, _ghostEye(f.cx - f.gap, f.ey, a.eyes), _ghostEye(f.cx + f.gap, f.ey, a.eyes), "</g>");
        }
        return string.concat(tag, _oneEye(a, f.cx - f.gap, f.ey, false), _oneEye(a, f.cx + f.gap, f.ey, false), "</g>");
    }

    function _led(Roll memory a, uint256 x, uint256 y) private pure returns (string memory) {
        a;
        return string.concat(
            '<circle cx="',
            x.toString(),
            '" cy="',
            y.toString(),
            '" r="5" fill="#5eead4">',
            '<animate attributeName="opacity" values="1;1;1;.2;1" dur="3.2s" repeatCount="indefinite"/>',
            "</circle>"
        );
    }

    function _ghostEye(uint256 x, uint256 y, uint8 kind) private pure returns (string memory) {
        uint256 rx = kind == 2 ? 10 : kind == 4 ? 5 : 7;
        uint256 ry = kind == 4 ? 11 : kind == 1 ? 5 : 7;
        return string.concat(
            '<ellipse cx="',
            x.toString(),
            '" cy="',
            y.toString(),
            '" rx="',
            rx.toString(),
            '" ry="',
            ry.toString(),
            '" fill="#1e1930">',
            '<animate attributeName="opacity" values="1;1;1;.2;1" dur="3.2s" repeatCount="indefinite"/>',
            "</ellipse>"
        );
    }

    function _oneEye(Roll memory a, uint256 x, uint256 y, bool dino) private pure returns (string memory) {
        string memory extra = dino ? ' data-dino-eye="1"' : "";
        string memory sclera = _eyeShape(a.eyes, x, y, extra);
        string memory pupil = _pupil(a, x, y);
        return string.concat(sclera, pupil);
    }

    function _eyeShape(uint8 kind, uint256 x, uint256 y, string memory extra) private pure returns (string memory) {
        string memory at = string.concat(' cx="', x.toString(), '" cy="', y.toString(), '"', extra);
        if (kind == 0) {
            return string.concat("<circle", at, ' r="5" fill="#fff" stroke="#2a2430" stroke-width="2"/>');
        }
        if (kind == 1) {
            return string.concat("<ellipse", at, ' rx="8" ry="5" fill="#fff" stroke="#2a2430" stroke-width="2"/>');
        }
        if (kind == 2) {
            return string.concat("<ellipse", at, ' rx="11" ry="7" fill="#fff" stroke="#2a2430" stroke-width="2"/>');
        }
        if (kind == 3) {
            return string.concat(
                "<circle",
                at,
                ' r="7" fill="#fff" stroke="#2a2430" stroke-width="2"/>',
                '<path d="M',
                (x + 6).toString(),
                " ",
                (y - 8).toString(),
                " L",
                (x + 10).toString(),
                " ",
                (y - 14).toString(),
                '" stroke="#2a2430" stroke-width="2"/>'
            );
        }
        if (kind == 4) {
            return string.concat("<ellipse", at, ' rx="5" ry="11" fill="#fff" stroke="#2a2430" stroke-width="2"/>');
        }
        return string.concat(
            "<circle",
            at,
            ' r="9" fill="none" stroke="#2a2430" stroke-width="2"/>',
            '<circle cx="',
            x.toString(),
            '" cy="',
            y.toString(),
            '" r="5" fill="#fff" stroke="#2a2430" stroke-width="2"/>'
        );
    }

    function _pupil(Roll memory a, uint256 x, uint256 y) private pure returns (string memory) {
        uint256 py = a.pupil == 2 ? y + 2 : y;
        string memory fill = a.pupil == 1 ? "#64748b" : "#1e1930";
        return string.concat(
            '<circle cx="',
            x.toString(),
            '" cy="',
            py.toString(),
            '" r="3" fill="',
            fill,
            '">',
            '<animate attributeName="opacity" values="1;1;1;.2;1" dur="3.2s" repeatCount="indefinite"/>',
            "</circle>"
        );
    }

    function _mouth(Roll memory a, FaceAnchor memory f) private pure returns (string memory) {
        if (a.species == 6) return _beak(a.mouth);
        uint256 x = f.cx;
        uint256 y = f.mouthY;
        if (a.mouth == 0) {
            return string.concat(
                '<path d="M',
                (x - 8).toString(),
                " ",
                y.toString(),
                " H",
                (x + 8).toString(),
                '" fill="none" stroke="#2a2430" stroke-width="2.5"/>'
            );
        }
        if (a.mouth == 1) {
            return string.concat(
                '<path d="M',
                (x - 10).toString(),
                " ",
                y.toString(),
                " Q",
                x.toString(),
                " ",
                (y + 10).toString(),
                " ",
                (x + 10).toString(),
                " ",
                y.toString(),
                '" fill="none" stroke="#2a2430" stroke-width="2.5"/>'
            );
        }
        if (a.mouth == 2) {
            return string.concat(
                '<path d="M',
                (x - 10).toString(),
                " ",
                y.toString(),
                " L",
                (x - 4).toString(),
                " ",
                (y + 6).toString(),
                " L",
                x.toString(),
                " ",
                y.toString(),
                " L",
                (x + 4).toString(),
                " ",
                (y + 6).toString(),
                " L",
                (x + 10).toString(),
                " ",
                y.toString(),
                '" fill="none" stroke="#2a2430" stroke-width="2.5"/>'
            );
        }
        if (a.mouth == 3) {
            return string.concat('<circle cx="', x.toString(), '" cy="', (y + 2).toString(), '" r="5" fill="#1e1930"/>');
        }
        if (a.mouth == 4) {
            return string.concat(
                '<path d="M',
                (x - 10).toString(),
                " ",
                y.toString(),
                " Q",
                x.toString(),
                " ",
                (y + 12).toString(),
                " ",
                (x + 10).toString(),
                " ",
                y.toString(),
                ' Z" fill="#1e1930"/>'
            );
        }
        return string.concat(
            '<path d="M',
            (x - 8).toString(),
            " ",
            y.toString(),
            " Q",
            x.toString(),
            " ",
            (y + 8).toString(),
            " ",
            (x + 8).toString(),
            " ",
            y.toString(),
            '" fill="none" stroke="#2a2430" stroke-width="2.5"/>',
            '<ellipse cx="',
            (x + 4).toString(),
            '" cy="',
            (y + 10).toString(),
            '" rx="4" ry="5" fill="#fb7185"/>'
        );
    }

    function _beak(uint8 kind) private pure returns (string memory) {
        return string.concat(
            '<polygon data-beak="1" points="218,146 246,154 218,166" fill="',
            _beakHex(kind),
            '" stroke="#2a2430" stroke-width="2"/>'
        );
    }

    function _accessory(Roll memory a) private pure returns (string memory) {
        if (a.accessory == 0) return "";
        FaceAnchor memory f = _faceOf(a.species);
        if (a.accessory == 1) return _bow(f);
        if (a.accessory == 2) return _cap(f);
        if (a.accessory == 3) return _star(f);
        if (a.accessory == 4) return _glasses(a, f);
        return _halo(f);
    }

    function _bow(FaceAnchor memory f) private pure returns (string memory) {
        return string.concat(
            '<g data-acc="1" fill="#7a3a58" stroke="#2a2430" stroke-width="1.5">',
            '<ellipse cx="',
            (f.cx - 8).toString(),
            '" cy="',
            (f.hatY + 8).toString(),
            '" rx="8" ry="6"/>',
            '<ellipse cx="',
            (f.cx + 8).toString(),
            '" cy="',
            (f.hatY + 8).toString(),
            '" rx="8" ry="6"/>',
            '<circle cx="',
            f.cx.toString(),
            '" cy="',
            (f.hatY + 8).toString(),
            '" r="3"/>',
            "</g>"
        );
    }

    function _cap(FaceAnchor memory f) private pure returns (string memory) {
        return string.concat(
            '<g data-acc="2" fill="#1d4ed8" stroke="#2a2430" stroke-width="2">',
            '<path d="M',
            (f.cx - 22).toString(),
            " ",
            (f.hatY + 6).toString(),
            " Q",
            f.cx.toString(),
            " ",
            (f.hatY - 16).toString(),
            " ",
            (f.cx + 22).toString(),
            " ",
            (f.hatY + 6).toString(),
            ' Z"/>',
            '<rect x="',
            (f.cx - 28).toString(),
            '" y="',
            (f.hatY + 4).toString(),
            '" width="36" height="6" rx="2"/>',
            "</g>"
        );
    }

    function _star(FaceAnchor memory f) private pure returns (string memory) {
        uint256 x = f.cx + 18;
        uint256 y = f.hatY;
        return string.concat(
            '<polygon data-acc="3" points="',
            x.toString(),
            ",",
            y.toString(),
            " ",
            (x + 4).toString(),
            ",",
            (y + 10).toString(),
            " ",
            (x + 16).toString(),
            ",",
            (y + 10).toString(),
            " ",
            (x + 6).toString(),
            ",",
            (y + 16).toString(),
            " ",
            (x + 10).toString(),
            ",",
            (y + 28).toString(),
            " ",
            x.toString(),
            ",",
            (y + 20).toString(),
            " ",
            (x - 10).toString(),
            ",",
            (y + 28).toString(),
            " ",
            (x - 6).toString(),
            ",",
            (y + 16).toString(),
            " ",
            (x - 16).toString(),
            ",",
            (y + 10).toString(),
            " ",
            (x - 4).toString(),
            ",",
            (y + 10).toString(),
            '" fill="#fbbf24" stroke="#2a2430" stroke-width="2"/>'
        );
    }

    function _glasses(Roll memory a, FaceAnchor memory f) private pure returns (string memory) {
        if (a.species == 6) {
            uint256 lx = f.cx - f.gap;
            uint256 rx = f.cx + f.gap;
            return string.concat(
                '<g data-acc="4">',
                '<circle data-lens="1" data-wire="1" cx="',
                lx.toString(),
                '" cy="',
                f.ey.toString(),
                '" r="7" fill="#dbeafe" fill-opacity=".22" stroke="#1e293b" stroke-width="1.6"/>',
                '<circle data-lens="1" data-wire="1" cx="',
                rx.toString(),
                '" cy="',
                f.ey.toString(),
                '" r="7" fill="#dbeafe" fill-opacity=".22" stroke="#1e293b" stroke-width="1.6"/>',
                '<path data-arch="1" d="M',
                (lx - 2).toString(),
                " ",
                (f.ey - 8).toString(),
                " Q",
                f.cx.toString(),
                " ",
                (f.ey - 16).toString(),
                " ",
                (rx + 2).toString(),
                " ",
                (f.ey - 8).toString(),
                '" fill="none" stroke="#1e293b" stroke-width="1.6"/>',
                "</g>"
            );
        }
        uint256 l = f.cx - f.gap;
        uint256 r = f.cx + f.gap;
        uint256 rad = a.species == 7 ? 12 : 10;
        return string.concat(
            '<g data-acc="4">',
            '<circle data-lens="1" cx="',
            l.toString(),
            '" cy="',
            f.ey.toString(),
            '" r="',
            rad.toString(),
            '" fill="#dbeafe" fill-opacity=".22" stroke="#1e293b" stroke-width="2"/>',
            '<circle data-lens="1" cx="',
            r.toString(),
            '" cy="',
            f.ey.toString(),
            '" r="',
            rad.toString(),
            '" fill="#dbeafe" fill-opacity=".22" stroke="#1e293b" stroke-width="2"/>',
            '<path data-bridge="1" d="M',
            (l + rad).toString(),
            " ",
            f.ey.toString(),
            " H",
            (r - rad).toString(),
            '" stroke="#1e293b" stroke-width="2"/>',
            "</g>"
        );
    }

    function _halo(FaceAnchor memory f) private pure returns (string memory) {
        return string.concat(
            '<g data-acc="5">',
            '<ellipse cx="',
            f.cx.toString(),
            '" cy="',
            (f.hatY - 4).toString(),
            '" rx="18" ry="6" fill="none" stroke="#fbbf24" stroke-width="3"/>',
            '<circle cx="',
            (f.cx + 14).toString(),
            '" cy="',
            (f.hatY - 8).toString(),
            '" r="8" fill="#fde68a" stroke="#fbbf24" stroke-width="2"/>',
            "</g>"
        );
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

    function _shellHex(uint8 i) private pure returns (string memory) {
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

    function _bodyHex(uint8 i) private pure returns (string memory) {
        if (i == 0) return "#f5e6c8";
        if (i == 1) return "#86efac";
        if (i == 2) return "#fda4af";
        if (i == 3) return "#7dd3fc";
        if (i == 4) return "#d8b4fe";
        if (i == 5) return "#fde047";
        if (i == 6) return "#fdba74";
        if (i == 7) return "#5eead4";
        if (i == 8) return "#fb7185";
        if (i == 9) return "#e0f2fe";
        if (i == 10) return "#4ade80";
        return "#c084fc";
    }

    function _bellyHex(uint8 i) private pure returns (string memory) {
        if (i == 0) return "#f5e6c8";
        if (i == 1) return "#ffffff";
        if (i == 2) return "#fdba74";
        return "#f5e6c8";
    }

    function _beakHex(uint8 i) private pure returns (string memory) {
        if (i == 0) return "#f59e0b";
        if (i == 1) return "#fb7185";
        if (i == 2) return "#38bdf8";
        if (i == 3) return "#fbbf24";
        if (i == 4) return "#f9a8d4";
        return "#1e293b";
    }
}
