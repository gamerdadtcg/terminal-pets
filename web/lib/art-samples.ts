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
