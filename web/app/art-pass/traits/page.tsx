import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SITE } from "@/lib/site";
import { sheetSrc, TRAIT_GROUPS, TRAIT_SHEETS } from "@/lib/trait-catalog";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: `Trait catalog · ${SITE.name}`,
  description:
    "Every Terminal Pets Lit trait option on a frozen base pet, plus species-specific faces. Review sheets for shell, color, eyes, mouths, accessories, and the Dormant egg.",
};

export default function TraitCatalogPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            Trait catalog
          </Badge>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Every rolled option, one trait at a time.
          </h1>
          <p className="text-muted-foreground">
            Neutral base is a Round / Sky Cat: Mint body, white belly, Dot
            eyes, smile, no brows, no accessory, Solid wallpaper, Stub
            antenna, Blue buttons, Alpha. Only the labeled trait changes.
            Dino, Bird, Frog, Robot, and Ghost get their own face sheets
            because those heads do not share the Cat drawing path. Belly is
            n/a for Dino and Ghost. Bird&apos;s mouth roll is beak color, not
            an expression. Seed is
            still <span className="font-mono">{SITE.artDomain}</span> — these
            stills are catalog renders, not random tokenIds.
          </p>
          <p className="font-mono text-xs text-muted-foreground">
            <Link className="underline" href="/art-pass">
              ← Art pass
            </Link>
            {" · "}
            <a className="underline" href="/art-pass/traits/traits-index.png">
              /art-pass/traits/traits-index.png
            </a>
          </p>
        </section>

        <nav className="flex flex-wrap gap-2">
          {TRAIT_GROUPS.map((group) => (
            <a
              key={group.id}
              href={`#${group.id}`}
              className="rounded-md bg-muted px-2.5 py-1 font-mono text-[11px] text-muted-foreground hover:text-foreground"
            >
              {group.label}
            </a>
          ))}
        </nav>

        {TRAIT_GROUPS.map((group) => {
          const sheets = TRAIT_SHEETS.filter((s) => s.group === group.id);
          return (
            <section key={group.id} id={group.id} className="space-y-4">
              <h2 className="text-lg font-semibold tracking-tight">
                {group.label}
              </h2>
              <div className="grid gap-6">
                {sheets.map((sheet) => (
                  <Card key={sheet.id} id={sheet.id}>
                    <CardHeader>
                      <CardTitle className="text-base">{sheet.title}</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-3">
                      <div className="overflow-hidden rounded-xl bg-[#07080b]">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={sheetSrc(sheet.id)}
                          alt={`${sheet.title}: ${sheet.options} options`}
                          className="w-full"
                        />
                      </div>
                      <p className="text-sm text-muted-foreground">
                        {sheet.blurb}
                      </p>
                      <p className="font-mono text-xs text-muted-foreground">
                        {sheet.options} options ·{" "}
                        <a className="underline" href={sheetSrc(sheet.id)}>
                          {sheetSrc(sheet.id)}
                        </a>
                      </p>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </section>
          );
        })}
      </main>
      <SiteFooter />
    </>
  );
}
