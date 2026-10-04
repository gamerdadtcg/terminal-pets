import { HopperStatus } from "@/components/hopper-status";
import { HopperExplainer } from "@/components/hub/hopper-explainer";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui/button";
import { SITE } from "@/lib/site";
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Hopper & Pulse",
  description: `The Hopper is the ETH pot. After a ${SITE.hopperLock} lock, Pulse can run and awake pets can claim. Sleeping eggs do not earn.`,
};

export default function HopperPage() {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 lg:grid-cols-[1fr_300px]">
          <HopperExplainer />
          <aside className="space-y-4 lg:pt-10">
            <HopperStatus />
            <Button className="w-full" asChild>
              <Link href="/">Ignite an egg</Link>
            </Button>
            <Button className="w-full" variant="outline" asChild>
              <Link href="/how#dial">What Dial assigns</Link>
            </Button>
          </aside>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
