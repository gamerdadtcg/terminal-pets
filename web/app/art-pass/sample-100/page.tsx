import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `100 Lit pets · ${SITE.name}`,
  description:
    "Token ids 1–100 as Lit stills. Mixed species, eyes, and bird beak colors for art review.",
};

const IDS = Array.from({ length: 100 }, (_, i) => i + 1);

export default function Sample100Page() {
  return (
    <>
      <SiteHeader />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            Sample 100
          </Badge>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            First 100 Lit pets, one grid.
          </h1>
          <p className="text-muted-foreground">
            Token ids 1–100 from seed{" "}
            <span className="font-mono">{SITE.artDomain}</span>. Real rolls —
            mixed species, body colors, eye types, and Bird beak colors.
            Use this to judge how combos land together.
          </p>
          <p className="font-mono text-xs text-muted-foreground">
            <Link className="underline" href="/art-pass">
              ← Art pass
            </Link>
            {" · "}
            <Link className="underline" href="/art-pass/traits">
              Trait catalog
            </Link>
            {" · "}
            <a className="underline" href="/art-pass/sample-100.png">
              /art-pass/sample-100.png
            </a>
          </p>
        </section>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">10 × 10 sheet</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="overflow-hidden rounded-xl bg-[#07080b]">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/art-pass/sample-100.png"
                alt="10 by 10 grid of Lit pets, token ids 1 through 100"
                className="w-full"
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Click a pet</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-5 gap-2 sm:grid-cols-10">
              {IDS.map((id) => (
                <a
                  key={id}
                  href={`/art-pass/sample-100/${id}.svg`}
                  className="overflow-hidden rounded-lg bg-[#07080b]"
                  title={`PET#${id}`}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={`/art-pass/sample-100/${id}.png`}
                    alt={`Lit PET#${id}`}
                    className="aspect-square w-full object-contain"
                  />
                </a>
              ))}
            </div>
          </CardContent>
        </Card>
      </main>
      <SiteFooter />
    </>
  );
}
