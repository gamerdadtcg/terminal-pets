/** HTTPS bases for CollectionNFT.setMetadataURIs after the hub deploys. */
export const TEST_METADATA_URIS = {
  hiddenURI: "https://terminal-pets.vercel.app/metadata/hidden.json",
  dormantBaseURI: "https://terminal-pets.vercel.app/metadata/dormant/",
  litBaseURI: "https://terminal-pets.vercel.app/metadata/lit/",
} as const;

export const TEST_TOKEN_COUNT = 25;

export const TEST_HOST_TOKENS = Array.from(
  { length: TEST_TOKEN_COUNT },
  (_, i) => {
    const id = i + 1;
    return {
      id,
      dormantSrc: `/art/test-egg/${id}.gif`,
      awakeSrc: `/art/test/${id}.gif`,
    };
  },
);

/** Composed Ignite hatch GIFs (crack → split → flash → awake). Native <img> only. */
export const HATCH_PRIMARY = {
  src: "/art/hatch/snag_hatch.gif",
  pet: "SNAG",
  petId: "P02",
  alt: "SNAG Ignite hatch GIF: egg cracks, splits, flashes, and the pet wakes",
  caption: "SNAG · Ignite hatch · crack → split → flash → awake",
} as const;

export const HATCH_OTHERS = [
  {
    src: "/art/hatch/P01_pudd_hatch.gif",
    pet: "PUDD",
    petId: "P01",
    alt: "PUDD Ignite hatch GIF: egg cracks open and the pet wakes",
    caption: "PUDD · P01",
  },
  {
    src: "/art/hatch/P04_puppo_hatch.gif",
    pet: "PUPPO",
    petId: "P04",
    alt: "PUPPO Ignite hatch GIF: egg cracks open and the pet wakes",
    caption: "PUPPO · P04",
  },
  {
    src: "/art/hatch/P08_blop_hatch.gif",
    pet: "BLOP",
    petId: "P08",
    alt: "BLOP Ignite hatch GIF: egg cracks open and the pet wakes",
    caption: "BLOP · P08",
  },
  {
    src: "/art/hatch/P12_bolt_hatch.gif",
    pet: "BOLT",
    petId: "P12",
    alt: "BOLT Ignite hatch GIF: egg cracks open and the pet wakes",
    caption: "BOLT · P12",
  },
  {
    src: "/art/hatch/anim_hatch.gif",
    pet: "Full device",
    petId: "anim",
    alt: "Full-device Ignite hatch GIF: egg cracks, splits, flashes, pet wakes",
    caption: "Full device · anim_hatch",
  },
] as const;

export const ART_SAMPLES = [
  {
    id: 1,
    pet: "BLOP",
    petId: "P08",
    egg: "E08",
    handheld: "H08 Large Rounded",
    dormantSrc: "/art/test-egg/1.gif",
    awakeSrc: "/art/test/1.gif",
  },
  {
    id: 2,
    pet: "SNAG",
    petId: "P02",
    egg: "E02",
    handheld: "H01 Classic",
    dormantSrc: "/art/test-egg/2.gif",
    awakeSrc: "/art/test/2.gif",
  },
  {
    id: 3,
    pet: "PUDD",
    petId: "P01",
    egg: "E01",
    handheld: "H05 Egg-shaped",
    dormantSrc: "/art/test-egg/3.gif",
    awakeSrc: "/art/test/3.gif",
  },
] as const;

export const ART_SHEETS = [
  {
    src: "/art/sheets/15-sample-pfps.png",
    alt: "Sample awakened Pocket Critter PFPs",
    label: "Awake sheet",
  },
  {
    src: "/art/sheets/sample-dormant-01.png",
    alt: "Dormant egg on a handheld",
    label: "Dormant egg",
  },
  {
    src: "/art/sheets/traits-eggs.png",
    alt: "Egg trait sheet E01–E12",
    label: "Eggs",
  },
  {
    src: "/art/sheets/handheld-family.png",
    alt: "Handheld device family H01–H10",
    label: "Handhelds",
  },
] as const;
