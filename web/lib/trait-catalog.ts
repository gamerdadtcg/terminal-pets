export type TraitSheet = {
  id: string;
  title: string;
  blurb: string;
  group: "chassis" | "pet" | "face" | "accessory" | "state";
  options: number;
};

export const TRAIT_SHEETS: TraitSheet[] = [
  {
    id: "species",
    title: "Species",
    blurb: "All 12 silhouettes. Same Round/Sky chassis, Mint body, smile, no accessory.",
    group: "pet",
    options: 12,
  },
  {
    id: "shell",
    title: "Shell / chassis",
    blurb: "Handheld outline. Pet inside is the same Cat.",
    group: "chassis",
    options: 8,
  },
  {
    id: "shell-color",
    title: "Shell color",
    blurb: "Chassis pigment on a Round shell.",
    group: "chassis",
    options: 12,
  },
  {
    id: "buttons",
    title: "Buttons",
    blurb: "Three bezel buttons under the screen.",
    group: "chassis",
    options: 8,
  },
  {
    id: "antenna",
    title: "Antenna",
    blurb: "Top nub. None is a valid roll.",
    group: "chassis",
    options: 6,
  },
  {
    id: "wallpaper",
    title: "Screen / wallpaper",
    blurb: "Lit screen fill + pattern. Solid is the default catalog base.",
    group: "chassis",
    options: 8,
  },
  {
    id: "generation",
    title: "Generation",
    blurb: "Footer label only. Pet art does not change.",
    group: "chassis",
    options: 4,
  },
  {
    id: "body",
    title: "Body color",
    blurb: "Pet fill on the Cat silhouette.",
    group: "pet",
    options: 12,
  },
  {
    id: "belly",
    title: "Belly",
    blurb: "Belly patch on most species. Not drawn for Ghost or Robot (OpenSea value is n/a). Match uses the body color.",
    group: "pet",
    options: 4,
  },
  {
    id: "eyes",
    title: "Eyes · Cat (neutral)",
    blurb: "Front-facing eye types on Cat. Each kind is a different shape (bead, sleepy lid, oversized, sparkle, vertical slit, target rings).",
    group: "face",
    options: 6,
  },
  {
    id: "eyes-dino",
    title: "Eyes · Dino",
    blurb: "Each eye type on the front-facing Dino head.",
    group: "face",
    options: 6,
  },
  {
    id: "eyes-bird",
    title: "Eyes · Bird",
    blurb: "Compact pupils on the round Bird head.",
    group: "face",
    options: 6,
  },
  {
    id: "eyes-frog",
    title: "Eyes · Frog",
    blurb: "Wide-gap eyes in the Frog bumps.",
    group: "face",
    options: 6,
  },
  {
    id: "eyes-robot",
    title: "Eyes · Robot",
    blurb: "LED visor variants. Eyes live in the visor.",
    group: "face",
    options: 6,
  },
  {
    id: "eyes-ghost",
    title: "Eyes · Ghost",
    blurb: "Hollow-eye Ghost variants.",
    group: "face",
    options: 6,
  },
  {
    id: "pupil",
    title: "Pupils",
    blurb: "Center, slate fill, or downward glance.",
    group: "face",
    options: 3,
  },
  {
    id: "mouth",
    title: "Mouth · Cat (neutral)",
    blurb: "Front-facing mouth / expression.",
    group: "face",
    options: 6,
  },
  {
    id: "mouth-dino",
    title: "Mouth · Dino snout",
    blurb: "Each mouth type on the front-facing Dino.",
    group: "face",
    options: 6,
  },
  {
    id: "mouth-bird",
    title: "Mouth · Bird beak",
    blurb: "Mouth roll picks beak color (Amber, Coral, Sky, Gold, Rose, Ink). Same beak shape.",
    group: "face",
    options: 6,
  },
  {
    id: "cheeks",
    title: "Cheeks · Cat",
    blurb: "None, blush, or freckles.",
    group: "face",
    options: 3,
  },
  {
    id: "cheeks-dino",
    title: "Cheeks · Dino",
    blurb: "Blush and freckles on the snout.",
    group: "face",
    options: 3,
  },
  {
    id: "brows",
    title: "Brows (ears roll) · Cat",
    blurb: "On-chain trait is Ears. Round draws no brow.",
    group: "face",
    options: 5,
  },
  {
    id: "brows-dino",
    title: "Brows (ears roll) · Dino",
    blurb: "Same ears roll as brows on the Dino head.",
    group: "face",
    options: 5,
  },
  {
    id: "accessory",
    title: "Accessories · Cat",
    blurb: "Bow, cap, star, glasses, halo — plus None.",
    group: "accessory",
    options: 6,
  },
  {
    id: "accessory-dino",
    title: "Accessories · Dino",
    blurb: "Hats, glasses, and halo on the front-facing Dino.",
    group: "accessory",
    options: 6,
  },
  {
    id: "accessory-bird",
    title: "Accessories · Bird",
    blurb: "Same list on the small Bird head. Glasses are wire rims.",
    group: "accessory",
    options: 6,
  },
  {
    id: "glasses",
    title: "Glasses on every species",
    blurb: "Accessory = Glasses. One still per species.",
    group: "accessory",
    options: 12,
  },
  {
    id: "dormant",
    title: "Dormant egg",
    blurb: "Spotted mystery egg on each shell. Species hidden until Ignite.",
    group: "state",
    options: 8,
  },
] as const satisfies TraitSheet[];

export const TRAIT_GROUPS = [
  { id: "chassis", label: "Handheld" },
  { id: "pet", label: "Pet body" },
  { id: "face", label: "Face" },
  { id: "accessory", label: "Accessories" },
  { id: "state", label: "Dormant" },
] as const;

export function sheetSrc(id: string) {
  return `/art-pass/traits/traits-${id}.png`;
}
