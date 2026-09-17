"use client";

import { ELIGIBLE_SHARE } from "@/lib/site";
import Link from "next/link";
import { useEffect } from "react";

/** Client-only jump so crawlers still read /eligible OG tags (no HTTP redirect). */
export function EligibleRedirect() {
  useEffect(() => {
    window.location.replace(ELIGIBLE_SHARE.hash);
  }, []);

  return (
    <main className="mx-auto flex min-h-[60vh] max-w-lg flex-col justify-center px-4 py-16 text-center">
      <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
        PHASE ELIGIBILITY
      </p>
      <h1 className="mt-3 text-2xl font-medium">Check your wallet</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        Opening the GTD / FCFS eligibility checker…
      </p>
      <Link
        href={ELIGIBLE_SHARE.hash}
        className="mt-4 text-sm text-primary underline-offset-2 hover:underline"
      >
        Continue to checker
      </Link>
    </main>
  );
}
