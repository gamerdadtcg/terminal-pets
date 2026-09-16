import {
  ART_SAMPLES,
  ART_SHEETS,
  EXAMPLE_TOKENS,
  EXAMPLES_LABEL,
  HATCH_OTHERS,
  HATCH_PRIMARY,
} from "@/lib/art-samples";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function ExamplesBadge() {
  return (
    <Badge variant="outline" className="font-mono">
      {EXAMPLES_LABEL}
    </Badge>
  );
}

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
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-mono text-[11px] text-primary">HATCH / IGNITE REVEAL</p>
          <ExamplesBadge />
        </div>
        <CardTitle className="text-xl sm:text-2xl">
          Crack. Split. Flash. Awake.
        </CardTitle>
        <p className="text-sm text-muted-foreground">
          {EXAMPLES_LABEL} Ignite breaks the dormant egg open. Minted tokens
          stay sealed — traits unknown — until reveal. These hatch GIFs are
          demos, not collection IDs.
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
          <Card key={sample.id} className="overflow-hidden">
            <CardHeader className="pb-3">
              <div className="flex flex-wrap items-center gap-2">
                <p className="font-mono text-[11px] text-primary">
                  EXAMPLE {sample.id}
                </p>
                <ExamplesBadge />
              </div>
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
                alt={`Example ${sample.pet} dormant egg GIF`}
                caption="Dormant · egg rock"
              />
              <PetFrame
                src={sample.awakeSrc}
                alt={`Example ${sample.pet} awake pet GIF`}
                caption="Lit · awake FX"
              />
            </CardContent>
          </Card>
        ))}
      </div>
      <Card>
        <CardHeader className="gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-mono text-[11px] text-primary">EXAMPLES</p>
            <ExamplesBadge />
          </div>
          <CardTitle className="text-base">
            Demo GIFs. Not the 4444 mint supply.
          </CardTitle>
          <p className="text-sm text-muted-foreground">
            {EXAMPLES_LABEL} Pets mint sealed; traits unknown until reveal.
            Do not point CollectionNFT.setMetadataURIs at these files. Real
            collection lit/dormant JSON is not published on this hub until
            after reveal.
          </p>
        </CardHeader>
        <CardContent>
          <div className="-mx-1 flex snap-x snap-mandatory gap-4 overflow-x-auto pb-2 [scrollbar-width:thin]">
            {EXAMPLE_TOKENS.map((token) => (
              <figure
                key={token.id}
                className="w-[17rem] shrink-0 snap-start overflow-hidden rounded-2xl border border-border/70 bg-black/40"
              >
                <div className="grid grid-cols-2">
                  <img
                    src={token.dormantSrc}
                    alt={`Example ${token.id} dormant egg GIF`}
                    className="aspect-square w-full object-cover"
                    width={256}
                    height={256}
                    loading="lazy"
                    decoding="async"
                  />
                  <img
                    src={token.awakeSrc}
                    alt={`Example ${token.id} awake pet GIF`}
                    className="aspect-square w-full object-cover"
                    width={256}
                    height={256}
                    loading="lazy"
                    decoding="async"
                  />
                </div>
                <figcaption className="px-3 py-2 font-mono text-xs tracking-wide text-muted-foreground">
                  Example {token.id} · egg / awake
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
