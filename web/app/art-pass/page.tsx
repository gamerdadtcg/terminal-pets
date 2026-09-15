import { PetFrame } from "@/components/pet-frame";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SITE, SPECIES } from "@/lib/site";
import { sheetSrc, TRAIT_SHEETS } from "@/lib/trait-catalog";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `Art pass · ${SITE.name}`,
  description:
    "Per-species faces. Bird glasses sit on the eyes. Dino is a front-facing catalog pet with ridge, snout, and tail. Unrevealed teaser reel, spotted mystery egg, Ignite crack animation.",
};

const WAKE = [
  {
    name: "Cat",
    id: 3,
    dormant: "/art-pass/Cat-id3-dormant.svg",
    lit: "/art-pass/Cat-id3-lit.svg",
    wake: "/art-pass/Cat-id3-wake.svg",
    wakeGif: "/art-pass/Cat-id3-wake.gif",
    dormantPng: "/art-pass/Cat-id3-dormant.png",
    litPng: "/art-pass/Cat-id3-lit.png",
  },
  {
    name: "Dino",
    id: 12,
    dormant: "/art-pass/Dino-id12-dormant.svg",
    lit: "/art-pass/Dino-id12-lit.svg",
    wake: "/art-pass/Dino-id12-wake.svg",
    wakeGif: "/art-pass/Dino-id12-wake.gif",
    dormantPng: "/art-pass/Dino-id12-dormant.png",
    litPng: "/art-pass/Dino-id12-lit.png",
  },
  {
    name: "Ghost",
    id: 7,
    dormant: "/art-pass/Ghost-id7-dormant.svg",
    lit: "/art-pass/Ghost-id7-lit.svg",
    wake: "/art-pass/Ghost-id7-wake.svg",
    wakeGif: "/art-pass/Ghost-id7-wake.gif",
    dormantPng: "/art-pass/Ghost-id7-dormant.png",
    litPng: "/art-pass/Ghost-id7-lit.png",
  },
  {
    name: "Bird",
    id: 15,
    dormant: "/art-pass/Bird-id15-dormant.svg",
    lit: "/art-pass/Bird-id15-lit.svg",
    wake: "/art-pass/Bird-id15-wake.svg",
    wakeGif: "/art-pass/Bird-id15-wake.gif",
    dormantPng: "/art-pass/Bird-id15-dormant.png",
    litPng: "/art-pass/Bird-id15-lit.png",
  },
  {
    name: "Robot",
    id: 11,
    dormant: "/art-pass/Robot-id11-dormant.svg",
    lit: "/art-pass/Robot-id11-lit.svg",
    wake: "/art-pass/Robot-id11-wake.svg",
    wakeGif: "/art-pass/Robot-id11-wake.gif",
    dormantPng: "/art-pass/Robot-id11-dormant.png",
    litPng: "/art-pass/Robot-id11-lit.png",
  },
] as const;

const COMBOS = [
  {
    name: "Dino glasses",
    id: 49,
    src: "/art-pass/DinoGrin-id49-lit.svg",
    png: "/art-pass/DinoGrin-id49-lit.png",
    note: "Glasses on both eyes. Front-facing body with ridge spikes and a bubbly tail.",
  },
  {
    name: "Bird glasses",
    id: 29,
    src: "/art-pass/BirdGlasses-id29-lit.svg",
    png: "/art-pass/BirdGlasses-id29-lit.png",
    note: "Thin rims on the two pupils, short arch above the eyes. Translucent lenses — accessory, not a second pair of eyes.",
  },
  {
    name: "Bird glasses (tall)",
    id: 224,
    src: "/art-pass/BirdGlasses2-id224-lit.svg",
    png: "/art-pass/BirdGlasses2-id224-lit.png",
    note: "Same wire rims on a different Bird (tall eyes, open beak). Arch stays above the beak; no temple through it.",
  },
  {
    name: "Frog glasses",
    id: 77,
    src: "/art-pass/FrogGlasses-id77-lit.svg",
    png: "/art-pass/FrogGlasses-id77-lit.png",
    note: "Wide gap 24 lands each filled lens in an eye bump.",
  },
  {
    name: "Cat glasses",
    id: 219,
    src: "/art-pass/CatGlasses-id219-lit.svg",
    png: "/art-pass/CatGlasses-id219-lit.png",
    note: "Cat ears stay on the head; rims sit over both eyes with a visible bridge.",
  },
  {
    name: "Fox glasses",
    id: 42,
    src: "/art-pass/FoxGlasses-id42-lit.svg",
    png: "/art-pass/FoxGlasses-id42-lit.png",
    note: "Fox muzzle stays below. Tall-rect eyes plus filled lenses.",
  },
  {
    name: "Robot glasses",
    id: 40,
    src: "/art-pass/RobotGlasses-id40-lit.svg",
    png: "/art-pass/RobotGlasses-id40-lit.png",
    note: "Visor is the face. Glasses overlay the LED ring visor instead of being skipped.",
  },
] as const;

const DINO_FACES = [
  {
    name: "Dino smile + cap",
    id: 12,
    src: "/art-pass/Dino-id12-lit.svg",
    png: "/art-pass/Dino-id12-lit.png",
    note: "Spark eyes, smile, blush, cap. Round body, ridge, snout bump, bubbly tail.",
  },
  {
    name: "Dino oh + glasses",
    id: 49,
    src: "/art-pass/DinoGrin-id49-lit.svg",
    png: "/art-pass/DinoGrin-id49-lit.png",
    note: "Spark eyes, grin, glasses on both pupils. Floppy brow.",
  },
  {
    name: "Dino closed",
    id: 99,
    src: "/art-pass/DinoClosed-id99-lit.svg",
    png: "/art-pass/DinoClosed-id99-lit.png",
    note: "Wide almond eyes, closed mouth, horn brow, cap.",
  },
  {
    name: "Dino grin",
    id: 179,
    src: "/art-pass/DinoOh-id179-lit.svg",
    png: "/art-pass/DinoOh-id179-lit.png",
    note: "Dot eyes, open-O mouth, star. Front-facing catalog body.",
  },
  {
    name: "Dino teeth",
    id: 25,
    src: "/art-pass/DinoTeeth-id25-lit.svg",
    png: "/art-pass/DinoTeeth-id25-lit.png",
    note: "Zigzag teeth, tuft brow, star.",
  },
  {
    name: "Dino tall eye",
    id: 267,
    src: "/art-pass/DinoTall-id267-lit.svg",
    png: "/art-pass/DinoTall-id267-lit.png",
    note: "Tall lid-heavy eyes, grin, glasses on both pupils.",
  },
] as const;

function Raster({ src, alt }: { src: string; alt: string }) {
  return (
    <div className="hub-scan overflow-hidden rounded-xl bg-[#07080b]">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} className="aspect-square w-full object-contain" />
    </div>
  );
}

export default function ArtPassPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            Art pass
          </Badge>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Faces, expressions, and glasses that actually show.
          </h1>
          <p className="text-muted-foreground">
            Eyes, mouth, brows, and blush follow trait rolls and sit on that
            species’ face — Dino ridge and tail, Bird beak, Frog bumps, Robot
            visor. Bird glasses are thin rims on the pupils with a short arch
            above the eyes, not a second pair of discs. Dino Lit is a
            front-facing catalog pet like Cat: round body, snout bump, ridge
            spikes, bubbly tail. The handheld still does not change
            from Dormant to Lit. OpenSea Lit metadata is the hatched pet.
          </p>
          <p className="text-muted-foreground">
            Need every option, not a random combo? The{" "}
            <Link className="underline" href="/art-pass/traits">
              trait catalog
            </Link>{" "}
            shows each rolled value on a frozen Cat (and on Dino / Bird / Frog
            / Robot / Ghost when the face is species-specific). The{" "}
            <Link className="underline" href="/art-pass/sample-100">
              100-pet sheet
            </Link>{" "}
            is token ids 1–100 Lit, for combo review.
          </p>
        </section>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Trait catalog · every option
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Link href="/art-pass/traits" className="block overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/traits/traits-index.png"
                alt="Index of every trait category sheet"
                className="w-full"
              />
            </Link>
            <p className="text-sm text-muted-foreground">
              Neutral Cat base unless a sheet names another species. Labels are
              on-chain names plus index (0-based).
            </p>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {TRAIT_SHEETS.map((sheet) => (
                <Link
                  key={sheet.id}
                  href={`/art-pass/traits#${sheet.id}`}
                  className="rounded-lg border border-border/60 px-3 py-2 hover:bg-muted"
                >
                  <p className="text-sm font-medium">{sheet.title}</p>
                  <p className="font-mono text-[11px] text-muted-foreground">
                    {sheet.options} · {sheetSrc(sheet.id)}
                  </p>
                </Link>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              100 Lit pets · token ids 1–100
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Link href="/art-pass/sample-100" className="block overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/sample-100.png"
                alt="10 by 10 grid of the first 100 Lit pets"
                className="w-full"
              />
            </Link>
            <p className="text-sm text-muted-foreground">
              Real{" "}
              <span className="font-mono">{SITE.artDomain}</span> rolls. Mixed
              species, eyes, and Bird beak colors.
            </p>
            <p className="font-mono text-xs text-muted-foreground">
              <Link className="underline" href="/art-pass/sample-100">
                /art-pass/sample-100
              </Link>
              {" · "}
              <a className="underline" href="/art-pass/sample-100.png">
                PNG
              </a>
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              All 12 species · Lit stills
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/species-lit-sheet.png"
                alt="Blob Cat Dino Fox Ghost Bunny Bird Frog Bear Robot Owl Bug, each Lit on its handheld"
                className="w-full"
              />
            </div>
            <p className="font-mono text-xs text-muted-foreground">
              <a className="underline" href="/art-pass/species-lit-sheet.png">
                /art-pass/species-lit-sheet.png
              </a>
            </p>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {SPECIES.map((pet) => (
                <div key={pet.id}>
                  <PetFrame
                    src={`/art-pass/${pet.name}-id${pet.id}-lit.svg`}
                    label={`${pet.name} #${pet.id} Lit`}
                  />
                  <p className="mt-2 font-mono text-xs text-muted-foreground">
                    {pet.name} #{pet.id} ·{" "}
                    <a
                      className="underline"
                      href={`/art-pass/${pet.name}-id${pet.id}-lit.png`}
                    >
                      PNG
                    </a>
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Dino · ridge, tail, and trait faces
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/dino-faces-sheet.png"
                alt="Six Dino Lit stills: front-facing catalog body plus different eyes, mouths, brows, and accessories"
                className="w-full"
              />
            </div>
            <p className="font-mono text-xs text-muted-foreground">
              <a className="underline" href="/art-pass/dino-faces-sheet.png">
                /art-pass/dino-faces-sheet.png
              </a>
            </p>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {DINO_FACES.map((pet) => (
                <div key={pet.id + pet.name}>
                  <PetFrame src={pet.src} label={`${pet.name} #${pet.id}`} />
                  <p className="mt-2 text-sm text-muted-foreground">{pet.note}</p>
                  <p className="mt-1 font-mono text-xs text-muted-foreground">
                    <a className="underline" href={pet.png}>
                      PNG
                    </a>
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Bird glasses · accessory, not extra eyes
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/bird-glasses-sheet.png"
                alt="Bird without glasses beside two Birds wearing thin on-eye rims"
                className="w-full"
              />
            </div>
            <p className="font-mono text-xs text-muted-foreground">
              <a className="underline" href="/art-pass/bird-glasses-sheet.png">
                /art-pass/bird-glasses-sheet.png
              </a>
              {" "}
              · #15 none · #29 glasses · #48 glasses
            </p>
            <div className="grid gap-4 sm:grid-cols-3">
              <div>
                <PetFrame
                  src="/art-pass/Bird-id15-lit.svg"
                  label="Bird #15 no glasses"
                />
                <p className="mt-2 text-sm text-muted-foreground">
                  Bare Bird. Compact pupils on the round head, left of the
                  beak.
                </p>
                <p className="mt-1 font-mono text-xs text-muted-foreground">
                  <a className="underline" href="/art-pass/Bird-id15-lit.png">
                    PNG
                  </a>
                </p>
              </div>
              <div>
                <PetFrame
                  src="/art-pass/BirdGlasses-id29-lit.svg"
                  label="Bird #29 glasses"
                />
                <p className="mt-2 text-sm text-muted-foreground">
                  Thin rims on the pupils. You can still see the eyes through
                  the tint. Short arch above, no bar, no temple through the
                  beak.
                </p>
                <p className="mt-1 font-mono text-xs text-muted-foreground">
                  <a
                    className="underline"
                    href="/art-pass/BirdGlasses-id29-lit.png"
                  >
                    PNG
                  </a>
                </p>
              </div>
              <div>
                <PetFrame
                  src="/art-pass/BirdGlasses2-id224-lit.svg"
                  label="Bird #224 glasses"
                />
                <p className="mt-2 text-sm text-muted-foreground">
                  Same frames on tall eyes and an open beak. Glasses still
                  read as an accessory.
                </p>
                <p className="mt-1 font-mono text-xs text-muted-foreground">
                  <a
                    className="underline"
                    href="/art-pass/BirdGlasses2-id224-lit.png"
                  >
                    PNG
                  </a>
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Accessory combos · glasses on face
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/glasses-sheet.png"
                alt="Dino, two Birds, Frog, Cat, Fox, and Robot Lit stills with glasses on the face"
                className="w-full"
              />
            </div>
            <p className="font-mono text-xs text-muted-foreground">
              <a className="underline" href="/art-pass/glasses-sheet.png">
                /art-pass/glasses-sheet.png
              </a>
            </p>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {COMBOS.map((pet) => (
              <div key={pet.id + pet.name}>
                <PetFrame src={pet.src} label={`${pet.name} #${pet.id}`} />
                <p className="mt-2 text-sm text-muted-foreground">{pet.note}</p>
                <p className="mt-1 font-mono text-xs text-muted-foreground">
                  <a className="underline" href={pet.png}>
                    PNG
                  </a>
                </p>
              </div>
            ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Contrast — egg Dormant | Lit
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/contrast-sheet.png"
                alt="Cat, Dino, Ghost, Bird, and Robot: spotted egg dormant beside the hatched lit pet on identical handhelds"
                className="w-full"
              />
            </div>
            <p className="font-mono text-xs text-muted-foreground">
              <a className="underline" href="/art-pass/contrast-sheet.png">
                /art-pass/contrast-sheet.png
              </a>
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Unrevealed teaser reel</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div>
              <PetFrame
                src="/art-pass/sealed-id3.svg"
                label="Unrevealed PET#3 SMIL teaser"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                SVG · possible lit outcomes · one gold device
              </p>
            </div>
            <div>
              <Raster
                src="/art-pass/sealed-id3.gif"
                alt="Baked GIF of the unrevealed teaser reel for PET#3"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                GIF · OpenSea-style cycle · same chrome every frame
              </p>
            </div>
          </CardContent>
        </Card>

        {WAKE.map((pet) => (
          <Card key={pet.id}>
            <CardHeader>
              <CardTitle className="text-base">
                {pet.name} #{pet.id} — egg, wake, Lit
              </CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <div>
                <PetFrame
                  src={pet.dormant}
                  label={`${pet.name} #${pet.id} Dormant egg`}
                />
                <p className="mt-2 font-mono text-xs text-muted-foreground">
                  Dormant · spotted egg ·{" "}
                  <a className="underline" href={pet.dormantPng}>
                    PNG
                  </a>
                </p>
              </div>
              <div>
                <PetFrame
                  src={pet.wake}
                  label={`${pet.name} #${pet.id} wake`}
                />
                <p className="mt-2 font-mono text-xs text-muted-foreground">
                  Wake SMIL · egg → crack → flash → pet
                </p>
              </div>
              <div>
                <Raster
                  src={pet.wakeGif}
                  alt={`${pet.name} #${pet.id} baked wake GIF`}
                />
                <p className="mt-2 font-mono text-xs text-muted-foreground">
                  Wake GIF
                </p>
              </div>
              <div>
                <PetFrame src={pet.lit} label={`${pet.name} #${pet.id} Lit`} />
                <p className="mt-2 font-mono text-xs text-muted-foreground">
                  Lit metadata still ·{" "}
                  <a className="underline" href={pet.litPng}>
                    PNG
                  </a>
                </p>
              </div>
            </CardContent>
          </Card>
        ))}
      </main>
      <SiteFooter />
    </>
  );
}
