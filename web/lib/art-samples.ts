/** Demo GIFs on the hub. Not the mint supply. Do not use as CollectionNFT tokenURI. */
export { EXAMPLES_LABEL } from "@/lib/site";

export const EXAMPLE_ART = {
  awake: (id: number) => `/art/examples/awake/${id}.gif`,
  egg: (id: number) => `/art/examples/eggs/${id}.gif`,
  hatch: (file: string) => `/art/examples/hatch/${file}`,
  sheet: (file: string) => `/art/examples/sheets/${file}`,
  sealed: "/art/examples/sealed.png",
} as const;

export const EXAMPLE_COUNT = 25;

export const EXAMPLE_TOKENS = Array.from({ length: EXAMPLE_COUNT }, (_, i) => {
  const id = i + 1;
  return {
    id,
    dormantSrc: EXAMPLE_ART.egg(id),
    awakeSrc: EXAMPLE_ART.awake(id),
  };
});

/** Composed Ignite hatch GIFs (crack → split → flash → awake). Native <img> only. */
export const HATCH_PRIMARY = {
  src: EXAMPLE_ART.hatch("snag_hatch.gif"),
  pet: "SNAG",
  petId: "P02",
  alt: "Example SNAG Ignite hatch GIF: egg cracks, splits, flashes, and the pet wakes",
  caption: "SNAG · Ignite hatch · crack → split → flash → awake",
} as const;

export const HATCH_OTHERS = [
  {
    src: EXAMPLE_ART.hatch("P01_pudd_hatch.gif"),
    pet: "PUDD",
    petId: "P01",
    alt: "Example PUDD Ignite hatch GIF",
    caption: "PUDD · P01",
  },
  {
    src: EXAMPLE_ART.hatch("P04_puppo_hatch.gif"),
    pet: "PUPPO",
    petId: "P04",
    alt: "Example PUPPO Ignite hatch GIF",
    caption: "PUPPO · P04",
  },
  {
    src: EXAMPLE_ART.hatch("P08_blop_hatch.gif"),
    pet: "BLOP",
    petId: "P08",
    alt: "Example BLOP Ignite hatch GIF",
    caption: "BLOP · P08",
  },
  {
    src: EXAMPLE_ART.hatch("P12_bolt_hatch.gif"),
    pet: "BOLT",
    petId: "P12",
    alt: "Example BOLT Ignite hatch GIF",
    caption: "BOLT · P12",
  },
  {
    src: EXAMPLE_ART.hatch("anim_hatch.gif"),
    pet: "Full device",
    petId: "anim",
    alt: "Example full-device Ignite hatch GIF",
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
    dormantSrc: EXAMPLE_ART.egg(1),
    awakeSrc: EXAMPLE_ART.awake(1),
  },
  {
    id: 2,
    pet: "SNAG",
    petId: "P02",
    egg: "E02",
    handheld: "H01 Classic",
    dormantSrc: EXAMPLE_ART.egg(2),
    awakeSrc: EXAMPLE_ART.awake(2),
  },
  {
    id: 3,
    pet: "PUDD",
    petId: "P01",
    egg: "E01",
    handheld: "H05 Egg-shaped",
    dormantSrc: EXAMPLE_ART.egg(3),
    awakeSrc: EXAMPLE_ART.awake(3),
  },
] as const;

export const ART_SHEETS = [
  {
    src: EXAMPLE_ART.sheet("15-sample-pfps.png"),
    alt: "Example awakened Pocket Critter PFPs",
    label: "Awake sheet",
  },
  {
    src: EXAMPLE_ART.sheet("sample-dormant-01.png"),
    alt: "Example dormant egg on a handheld",
    label: "Dormant egg",
  },
  {
    src: EXAMPLE_ART.sheet("traits-eggs.png"),
    alt: "Example egg trait sheet",
    label: "Eggs",
  },
  {
    src: EXAMPLE_ART.sheet("handheld-family.png"),
    alt: "Example handheld device family",
    label: "Handhelds",
  },
] as const;
