import { PetFrame } from "@/components/pet-frame";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SITE, SPECIES } from "@/lib/site";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: `Gallery · ${SITE.name}`,
  description:
    "Live on-chain SVG. Unrevealed teases possible pets. Dormant is a spotted egg; Ignite cracks it to Lit.",
};

export default function GalleryPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            SMIL in the browser
          </Badge>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Blink, idle, and Zzz only play here.
          </h1>
          <p className="text-muted-foreground">
            Chat images, exported PNGs, and OpenSea thumbs are a single frozen
            frame. The on-chain art is SVG with SMIL. Unrevealed cycles possible
            lit pets inside one handheld. After reveal, Dormant is a spotted
            mystery egg — no species — until Ignite. The hub plays egg → crack
            → flash → Lit. OpenSea Lit metadata is the hatched pet. Same shell
            the whole time.
          </p>
          <p className="text-sm text-muted-foreground">
            Watch for about three seconds. Shell and footer stay still. Stills
            and the contrast sheet live on{" "}
            <a className="underline" href="/art-pass">
              /art-pass
            </a>
            .
          </p>
        </section>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Teaser, egg, then Lit</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-3">
            <div>
              <PetFrame src="/pets/sealed-id3.svg" label="Cat #3 Sealed" />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#3 · Unrevealed · possible-outcomes reel
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Cat-id3-dormant.svg"
                label="Cat #3 Dormant"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#3 · Dormant · spotted mystery egg
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Cat-id3-lit.svg"
                label="Cat #3 Lit"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#3 · Cat · Lit · full traits
              </p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Same handheld — Dormant vs Lit</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <PetFrame src="/pets/id-1-dormant.svg" label="Bear #1 Dormant" />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#1 · Dormant · spotted egg
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Bear-id1-lit.svg"
                label="Bear #1 Lit"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#1 · Bear · Lit
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Dino-id12-dormant.svg"
                label="Dino #12 Dormant"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#12 · Dormant · spotted egg
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Dino-id12-lit.svg"
                label="Dino #12 Lit"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#12 · Dino · Lit
              </p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Ignite wake — egg cracks</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <div>
              <PetFrame
                src="/pets/species-Cat-id3-wake.svg"
                label="Cat #3 wake"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#3 · wake SMIL · OpenSea Lit is the hatched still
              </p>
            </div>
            <div>
              <PetFrame
                src="/pets/species-Dino-id12-wake.svg"
                label="Dino #12 wake"
              />
              <p className="mt-2 font-mono text-xs text-muted-foreground">
                PET#12 · Dino hatches · same handheld
              </p>
            </div>
          </CardContent>
        </Card>

        <section className="space-y-4">
          <h2 className="text-xl font-semibold tracking-tight">
            Lit — all 12 species
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {SPECIES.map((pet) => (
              <Card key={pet.file}>
                <CardHeader className="pb-2">
                  <CardTitle className="flex items-baseline justify-between gap-2 text-base">
                    <span>{pet.name}</span>
                    <span className="font-mono text-xs font-normal text-muted-foreground">
                      PET#{pet.id}
                    </span>
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <PetFrame
                    src={`/pets/${pet.file}`}
                    label={`${pet.name} #${pet.id} Lit`}
                  />
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
