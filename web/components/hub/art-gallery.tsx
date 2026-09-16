import {
  ART_SAMPLES,
  ART_SHEETS,
  TEST_HOST_TOKENS,
  TEST_METADATA_URIS,
  TEST_TOKEN_COUNT,
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
      <Card>
        <CardHeader className="gap-2">
          <p className="font-mono text-[11px] text-primary">TEST HOST</p>
          <CardTitle className="text-base">
            Tokens 1–{TEST_TOKEN_COUNT} · animated GIF (not PNG)
          </CardTitle>
          <p className="text-sm text-muted-foreground">
            After this hub deploys, CollectionNFT.setMetadataURIs can point at
            these HTTPS JSON bases. Image fields already use absolute{" "}
            <code className="font-mono text-xs">.gif</code> URLs.
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          <dl className="grid gap-2 font-mono text-[11px] sm:grid-cols-1">
            <div className="rounded-xl border border-border/70 bg-background/40 px-3 py-2">
              <dt className="text-muted-foreground">hiddenURI</dt>
              <dd className="break-all text-foreground">
                {TEST_METADATA_URIS.hiddenURI}
              </dd>
            </div>
            <div className="rounded-xl border border-border/70 bg-background/40 px-3 py-2">
              <dt className="text-muted-foreground">dormantBaseURI</dt>
              <dd className="break-all text-foreground">
                {TEST_METADATA_URIS.dormantBaseURI}
              </dd>
            </div>
            <div className="rounded-xl border border-border/70 bg-background/40 px-3 py-2">
              <dt className="text-muted-foreground">litBaseURI</dt>
              <dd className="break-all text-foreground">
                {TEST_METADATA_URIS.litBaseURI}
              </dd>
            </div>
          </dl>
          <div className="-mx-1 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:thin]">
            {TEST_HOST_TOKENS.map((token) => (
              <figure
                key={token.id}
                className="w-[7.5rem] shrink-0 overflow-hidden rounded-xl border border-border/70 bg-black/40"
              >
                <div className="grid grid-cols-2">
                  <img
                    src={token.dormantSrc}
                    alt={`Token ${token.id} dormant egg GIF`}
                    className="aspect-square w-full object-cover"
                    width={128}
                    height={128}
                    loading="lazy"
                    decoding="async"
                  />
                  <img
                    src={token.awakeSrc}
                    alt={`Token ${token.id} awake pet GIF`}
                    className="aspect-square w-full object-cover"
                    width={128}
                    height={128}
                    loading="lazy"
                    decoding="async"
                  />
                </div>
                <figcaption className="px-2 py-1 font-mono text-[10px] text-muted-foreground">
                  #{token.id} egg · lit
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
