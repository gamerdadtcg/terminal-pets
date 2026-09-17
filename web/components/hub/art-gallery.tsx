import {
  ART_SAMPLES,
  ART_SHEETS,
  DEMO_LABEL,
  EXAMPLE_COUNT,
  EXAMPLE_PETS,
  HATCH_OTHERS,
  HATCH_PRIMARY,
  SEALED_METADATA_URI,
  SEALED_METADATA_URI_ALIAS,
} from "@/lib/art-samples";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function PetFrame({
  src,
  alt,
  caption,
}: {
  src: string;
  alt: string;
  caption: string;
}) {
  return (
    <figure className="overflow-hidden rounded-2xl border border-border/70 bg-black/40">
      {/* GIFs must use img so the loop stays animated. */}
      <img
        src={src}
        alt={alt}
        className="aspect-square w-full object-cover"
        width={512}
        height={512}
        decoding="async"
      />
      <figcaption className="px-3 py-2 font-mono text-[10px] tracking-wide text-muted-foreground">
        {caption}
      </figcaption>
    </figure>
  );
}

function HatchReveal() {
  return (
    <Card className="overflow-hidden border-primary/25">
      <CardHeader className="gap-2">
        <p className="font-mono text-[11px] text-primary">
          HATCH / IGNITE · {DEMO_LABEL.toUpperCase()}
        </p>
        <CardTitle className="text-xl sm:text-2xl">
          Crack. Split. Flash. Awake.
        </CardTitle>
        <p className="text-sm text-muted-foreground">
          Example hatch loops only — not mint supply, not live tokenIds. Ignite
          breaks the dormant egg open: crack, split, flash, matching pet wakes.
          These are composed GIFs (native loops), not the frame PNGs in{" "}
          <code className="font-mono text-xs">art/anim/hatch/</code>.
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        <figure className="overflow-hidden rounded-2xl border border-primary/20 bg-black/40">
          {/* GIFs must use img so the loop stays animated. */}
          <img
            src={HATCH_PRIMARY.src}
            alt={HATCH_PRIMARY.alt}
            className="mx-auto aspect-square w-full max-w-2xl object-cover"
            width={512}
            height={512}
            decoding="async"
          />
          <figcaption className="px-3 py-2.5 font-mono text-xs tracking-wide text-muted-foreground">
            {HATCH_PRIMARY.caption}
          </figcaption>
        </figure>
        <div className="-mx-1 flex snap-x snap-mandatory gap-3 overflow-x-auto pb-2 [scrollbar-width:thin]">
          {HATCH_OTHERS.map((hatch) => (
            <figure
              key={hatch.src}
              className="w-[min(18rem,78vw)] shrink-0 snap-start overflow-hidden rounded-2xl border border-border/70 bg-black/40"
            >
              <img
                src={hatch.src}
                alt={hatch.alt}
                className="aspect-square w-full object-cover"
                width={512}
                height={512}
                decoding="async"
              />
              <figcaption className="px-3 py-2 font-mono text-[10px] tracking-wide text-muted-foreground">
                {hatch.caption}
              </figcaption>
            </figure>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

export function ArtGallery() {
  return (
    <div className="space-y-8">
      <HatchReveal />
      <div className="grid gap-4 md:grid-cols-3">
        {ART_SAMPLES.map((sample) => (
          <Card key={sample.n} className="overflow-hidden">
            <CardHeader className="pb-3">
              <p className="font-mono text-[11px] text-primary">
                EXAMPLE {String(sample.n).padStart(2, "0")} · {DEMO_LABEL.toUpperCase()}
              </p>
              <CardTitle className="text-base">
                {sample.pet}{" "}
                <span className="font-mono text-xs text-muted-foreground">
                  {sample.petId} · {sample.egg}
                </span>
              </CardTitle>
              <p className="text-xs text-muted-foreground">{sample.handheld}</p>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-2">
              <PetFrame
                src={sample.dormantSrc}
                alt={`Example ${sample.pet} dormant egg GIF (${DEMO_LABEL})`}
                caption="Dormant · egg rock"
              />
              <PetFrame
                src={sample.awakeSrc}
                alt={`Example ${sample.pet} awake pet GIF (${DEMO_LABEL})`}
                caption="Lit · awake FX"
              />
            </CardContent>
          </Card>
        ))}
      </div>
      <Card>
        <CardHeader className="gap-2">
          <p className="font-mono text-[11px] text-primary">
            DEMO CAROUSEL · {DEMO_LABEL.toUpperCase()}
          </p>
          <CardTitle className="text-base">
            {EXAMPLE_COUNT} example pets · not the mint supply
          </CardTitle>
          <p className="text-sm text-muted-foreground">
            These GIFs are labeled demos. They are not CollectionNFT tokenIds
            and not the 4444 live metadata. Until{" "}
            <code className="font-mono text-xs">CollectionNFT.reveal()</code>,
            every minted tokenURI is the same sealed{" "}
            <code className="font-mono text-xs">hidden.json</code>. Collectors
            cannot see traits. Do not point production{" "}
            <code className="font-mono text-xs">dormantBaseURI</code> /{" "}
            <code className="font-mono text-xs">litBaseURI</code> at this hub.
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          <dl className="grid gap-2 font-mono text-[11px] sm:grid-cols-1">
            <div className="rounded-xl border border-border/70 bg-background/40 px-3 py-2">
              <dt className="text-muted-foreground">hiddenURI (sealed, all tokens)</dt>
              <dd className="break-all text-foreground">{SEALED_METADATA_URI}</dd>
              <dd className="mt-1 break-all text-muted-foreground">
                Alias until DNS cutover: {SEALED_METADATA_URI_ALIAS}
              </dd>
            </div>
            <div className="rounded-xl border border-dashed border-border/70 bg-background/20 px-3 py-2">
              <dt className="text-muted-foreground">dormant / lit JSON</dt>
              <dd className="text-foreground">
                Not on this hub. Pin privately; publish after reveal.
              </dd>
            </div>
          </dl>
          <div className="-mx-1 flex snap-x snap-mandatory gap-4 overflow-x-auto pb-2 [scrollbar-width:thin]">
            {EXAMPLE_PETS.map((pet) => (
              <figure
                key={pet.n}
                className="w-[17rem] shrink-0 snap-start overflow-hidden rounded-2xl border border-border/70 bg-black/40"
              >
                <div className="grid grid-cols-2">
                  <img
                    src={pet.dormantSrc}
                    alt={`Example ${pet.pad} dormant egg GIF (${DEMO_LABEL})`}
                    className="aspect-square w-full object-cover"
                    width={256}
                    height={256}
                    loading="lazy"
                    decoding="async"
                  />
                  <img
                    src={pet.awakeSrc}
                    alt={`Example ${pet.pad} awake pet GIF (${DEMO_LABEL})`}
                    className="aspect-square w-full object-cover"
                    width={256}
                    height={256}
                    loading="lazy"
                    decoding="async"
                  />
                </div>
                <figcaption className="px-3 py-2 font-mono text-xs tracking-wide text-muted-foreground">
                  {pet.caption}
                </figcaption>
              </figure>
            ))}
          </div>
        </CardContent>
      </Card>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {ART_SHEETS.map((sheet) => (
          <figure
            key={sheet.src}
            className="overflow-hidden rounded-2xl border border-border/70 bg-card/40"
          >
            <img
              src={sheet.src}
              alt={sheet.alt}
              className="aspect-square w-full object-cover"
            />
            <figcaption className="px-3 py-2 font-mono text-[10px] text-muted-foreground">
              {sheet.label}
            </figcaption>
          </figure>
        ))}
      </div>
    </div>
  );
}
