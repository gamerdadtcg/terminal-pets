import { ArcadeCabinet } from "@/components/arcade/arcade-cabinet";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import { ARCADE_COPY, ARCADE_GTD_CAP, ARCADE_PATH } from "@/lib/arcade";
import { mintSchedule, SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Arcade",
  description: `Ignite the Dial — endless BOLT climb, dodge glitch pads, catch ticks. Top ${ARCADE_GTD_CAP} wallets locked GTD (and FCFS via GTD) for the ${mintSchedule.date} mint. Public mint is sold out.`,
  alternates: { canonical: ARCADE_PATH },
  openGraph: {
    title: `Arcade · ${SITE.name}`,
    description: `Play Ignite the Dial. Top ${ARCADE_GTD_CAP} wallets locked GTD for the Friday mint. Public mint is sold out.`,
    url: ARCADE_PATH,
    siteName: SITE.name,
    type: "website",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: SITE.name }],
  },
};

export default function ArcadePage() {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative mx-auto max-w-6xl space-y-8 px-4 py-10 sm:px-6 sm:py-14">
          <div className="max-w-2xl space-y-3">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              {ARCADE_COPY.badge}
            </p>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
              {ARCADE_COPY.title}
            </h1>
            <p className="text-muted-foreground">
              Bounce example BOLT (the robot pet, not the handheld token) up
              the Dial like Doodle Jump. No timer — steer, bounce, climb until
              you fall. Best score per wallet. The top {ARCADE_GTD_CAP} locked GTD (and FCFS via GTD) on the hub checker
              for the Friday mint. Public mint is sold out; the arcade stays
              playable.
            </p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href="/#eligible">Check eligibility</Link>
              </Button>
              <Button variant="ghost" asChild>
                <Link href="/mint">Mint status</Link>
              </Button>
            </div>
          </div>
          <ArcadeCabinet />
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
