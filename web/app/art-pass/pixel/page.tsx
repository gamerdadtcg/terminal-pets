import { PetFrame } from "@/components/pet-frame";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SITE, SPECIES } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `Pixel preview · ${SITE.name}`,
  description:
    "Preview-only: creature and traits as 128×128 nearest-neighbor pixels inside the same handheld chrome. On-chain Lit art stays vector.",
};

const COMPARE = [
  { name: "Cat", id: 3, stem: "Cat-id3" },
  { name: "Dino", id: 12, stem: "Dino-id12" },
  { name: "Bird glasses", id: 29, stem: "BirdGlasses-id29" },
  { name: "Ghost", id: 7, stem: "Ghost-id7" },
  { name: "Robot", id: 11, stem: "Robot-id11" },
  { name: "Frog glasses", id: 77, stem: "FrogGlasses-id77" },
] as const;

const TRAITS = [
  { name: "Dino monocle", id: 49, stem: "DinoGrin-id49" },
  { name: "Cat glasses", id: 219, stem: "CatGlasses-id219" },
  { name: "Bird glasses", id: 29, stem: "BirdGlasses-id29" },
  { name: "Fox glasses", id: 42, stem: "FoxGlasses-id42" },
  { name: "Robot glasses", id: 40, stem: "RobotGlasses-id40" },
  { name: "Dino teeth + star", id: 25, stem: "DinoTeeth-id25" },
] as const;

function Raster({ src, alt }: { src: string; alt: string }) {
  return (
    <div className="hub-scan overflow-hidden rounded-xl bg-[#07080b]">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={alt}
        className="aspect-square w-full object-contain"
        style={{ imageRendering: "pixelated" }}
      />
    </div>
  );
}

export default function PixelPreviewPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            Preview · not on-chain
          </Badge>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Same pets, 128×128 pixel creatures.
          </h1>
          <p className="text-muted-foreground">
            Hub-only post-process. The creature and its traits (body, eyes,
            mouth/beak, brows, cheeks, bow/cap/star/glasses/halo) are snapped
            to a <span className="font-mono">128×128</span> nearest-neighbor
            canvas, then placed back on the unchanged handheld — shell, bezel,
            buttons, antenna, wallpaper, and PET# labels stay vector. Dormant
            eggs are not pixelized. Scarf and Pack stay gone. On-chain Lit SVG
            is still the smooth renderer.
          </p>
          <p className="font-mono text-xs text-muted-foreground">
            <Link className="underline" href="/art-pass">
              ← Art pass
            </Link>
            {" · "}
            <a className="underline" href="/art-pass/pixel/pixel-vs-vector-sheet.png">
              /art-pass/pixel/pixel-vs-vector-sheet.png
            </a>
          </p>
        </section>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Vector vs 128px · same tokens</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/pixel/pixel-vs-vector-sheet.png"
                alt="Side by side: current vector Lit pets versus 128 pixel creature preview"
                className="w-full"
              />
            </div>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {COMPARE.map((pet) => (
                <div key={pet.stem} className="space-y-2">
                  <p className="font-mono text-xs text-muted-foreground">
                    {pet.name} #{pet.id}
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <PetFrame
                        src={`/art-pass/${pet.stem}-lit.svg`}
                        label={`${pet.name} #${pet.id} vector`}
                      />
                      <p className="mt-1 font-mono text-[10px] text-muted-foreground">
                        vector
                      </p>
                    </div>
                    <div>
                      <Raster
                        src={`/art-pass/pixel/${pet.stem}-pixel.png`}
                        alt={`${pet.name} #${pet.id} 128 pixel pet`}
                      />
                      <p className="mt-1 font-mono text-[10px] text-muted-foreground">
                        128px pet
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">All 12 species · pixel pets</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/pixel/pixel-species-sheet.png"
                alt="Twelve species with pixelated creatures on vector handhelds"
                className="w-full"
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {SPECIES.map((pet) => (
                <div key={pet.id}>
                  <Raster
                    src={`/art-pass/pixel/${pet.name}-id${pet.id}-pixel.png`}
                    alt={`${pet.name} #${pet.id} pixel preview`}
                  />
                  <p className="mt-2 font-mono text-xs text-muted-foreground">
                    {pet.name} #{pet.id} ·{" "}
                    <a
                      className="underline"
                      href={`/art-pass/pixel/${pet.name}-id${pet.id}-pixel.svg`}
                    >
                      SVG
                    </a>
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Traits still land · glasses and faces</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/pixel/pixel-traits-sheet.png"
                alt="Pixel pets with glasses, monocle, and snout traits"
                className="w-full"
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {TRAITS.map((pet) => (
                <div key={pet.stem}>
                  <Raster
                    src={`/art-pass/pixel/${pet.stem}-pixel.png`}
                    alt={`${pet.name} pixel preview`}
                  />
                  <p className="mt-2 text-sm text-muted-foreground">{pet.name}</p>
                  <p className="font-mono text-xs text-muted-foreground">#{pet.id}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">128×128 creature canvas · 4× zoom</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <p className="text-sm text-muted-foreground">
              Just the pet bitmap, nearest-neighbor scaled, so you can see the
              pixel grid without the handheld.
            </p>
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/pixel/pixel-pet-canvas-sheet.png"
                alt="Zoomed 128 by 128 pixel pet canvases"
                className="w-full"
                style={{ imageRendering: "pixelated" }}
              />
            </div>
          </CardContent>
        </Card>
      </main>
      <SiteFooter />
    </>
  );
}
