import { ART_SAMPLES, ART_SHEETS } from "@/lib/art-samples";
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
      />
      <figcaption className="px-3 py-2 font-mono text-[10px] tracking-wide text-muted-foreground">
        {caption}
      </figcaption>
    </figure>
  );
}

export function ArtGallery() {
  return (
    <div className="space-y-8">
      <div className="grid gap-4 md:grid-cols-3">
        {ART_SAMPLES.map((sample) => (
          <Card key={sample.id} className="overflow-hidden">
            <CardHeader className="pb-3">
              <p className="font-mono text-[11px] text-primary">
                SAMPLE #{sample.id}
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
                alt={`${sample.pet} dormant egg GIF`}
                caption="Dormant · egg rock"
              />
              <PetFrame
                src={sample.awakeSrc}
                alt={`${sample.pet} awake pet GIF`}
                caption="Lit · awake FX"
              />
            </CardContent>
          </Card>
        ))}
      </div>
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
