export const ART_SAMPLES = [
  {
    id: 1,
    pet: "BLOP",
    petId: "P08",
    egg: "E08",
    handheld: "H08 Large Rounded",
    dormantSrc: "/art/dormant/1.gif",
    awakeSrc: "/art/awake/1.gif",
  },
  {
    id: 2,
    pet: "SNAG",
    petId: "P02",
    egg: "E02",
    handheld: "H01 Classic",
    dormantSrc: "/art/dormant/2.gif",
    awakeSrc: "/art/awake/2.gif",
  },
  {
    id: 3,
    pet: "PUDD",
    petId: "P01",
    egg: "E01",
    handheld: "H05 Egg-shaped",
    dormantSrc: "/art/dormant/3.gif",
    awakeSrc: "/art/awake/3.gif",
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
