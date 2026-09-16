/** Public sealed metadata only. Dormant/lit 4444 JSON is not on this hub until after reveal. */
export const SEALED_METADATA_URI =
  "https://terminal-pets.vercel.app/metadata/hidden.json";

export const DEMO_LABEL = "examples / not mint supply";

export const EXAMPLE_COUNT = 25;

/** Demo GIFs only — not CollectionNFT tokenIds and not the live mint supply. */
export const EXAMPLE_PETS = Array.from({ length: EXAMPLE_COUNT }, (_, i) => {
  const n = i + 1;
  const pad = String(n).padStart(2, "0");
  return {
    n,
    pad,
    dormantSrc: `/art/examples/egg/${n}.gif`,
    awakeSrc: `/art/examples/awake/${n}.gif`,
    caption: `Demo ${pad} · ${DEMO_LABEL}`,
  };
});

/** Composed Ignite hatch GIFs (crack → split → flash → awake). Native <img> only. */
export const HATCH_PRIMARY = {
  src: "/art/hatch/snag_hatch.gif",
  pet: "SNAG",
  petId: "P02",
  alt: "Example SNAG Ignite hatch GIF (not mint supply): egg cracks, splits, flashes, and the pet wakes",
  caption: `SNAG · example hatch · ${DEMO_LABEL}`,
} as const;

export const HATCH_OTHERS = [
  {
    src: "/art/hatch/P01_pudd_hatch.gif",
    pet: "PUDD",
    petId: "P01",
    alt: "Example PUDD Ignite hatch GIF (not mint supply)",
    caption: `PUDD · example · ${DEMO_LABEL}`,
  },
  {
    src: "/art/hatch/P04_puppo_hatch.gif",
    pet: "PUPPO",
    petId: "P04",
    alt: "Example PUPPO Ignite hatch GIF (not mint supply)",
    caption: `PUPPO · example · ${DEMO_LABEL}`,
  },
  {
    src: "/art/hatch/P08_blop_hatch.gif",
    pet: "BLOP",
    petId: "P08",
    alt: "Example BLOP Ignite hatch GIF (not mint supply)",
    caption: `BLOP · example · ${DEMO_LABEL}`,
  },
  {
    src: "/art/hatch/P12_bolt_hatch.gif",
    pet: "BOLT",
    petId: "P12",
    alt: "Example BOLT Ignite hatch GIF (not mint supply)",
    caption: `BOLT · example · ${DEMO_LABEL}`,
  },
  {
    src: "/art/hatch/anim_hatch.gif",
    pet: "Full device",
    petId: "anim",
    alt: "Example full-device Ignite hatch GIF (not mint supply)",
    caption: `Full device · example · ${DEMO_LABEL}`,
  },
] as const;

export const ART_SAMPLES = [
  {
    n: 1,
    pet: "BLOP",
    petId: "P08",
    egg: "E08",
    handheld: "H08 Large Rounded",
    dormantSrc: "/art/examples/egg/1.gif",
    awakeSrc: "/art/examples/awake/1.gif",
  },
  {
    n: 2,
    pet: "SNAG",
    petId: "P02",
    egg: "E02",
    handheld: "H01 Classic",
    dormantSrc: "/art/examples/egg/2.gif",
    awakeSrc: "/art/examples/awake/2.gif",
  },
  {
    n: 3,
    pet: "PUDD",
    petId: "P01",
    egg: "E01",
    handheld: "H05 Egg-shaped",
    dormantSrc: "/art/examples/egg/3.gif",
    awakeSrc: "/art/examples/awake/3.gif",
  },
] as const;

export const ART_SHEETS = [
  {
    src: "/art/sheets/15-sample-pfps.png",
    alt: "Example awakened Pocket Critter PFPs (not mint supply)",
    label: `Awake sheet · ${DEMO_LABEL}`,
  },
  {
    src: "/art/sheets/sample-dormant-01.png",
    alt: "Example dormant egg on a handheld (not mint supply)",
    label: `Dormant egg · ${DEMO_LABEL}`,
  },
  {
    src: "/art/sheets/traits-eggs.png",
    alt: "Egg trait sheet E01–E12 (examples, not mint supply)",
    label: `Eggs · ${DEMO_LABEL}`,
  },
  {
    src: "/art/sheets/handheld-family.png",
    alt: "Handheld device family H01–H10 (examples, not mint supply)",
    label: `Handhelds · ${DEMO_LABEL}`,
  },
] as const;
