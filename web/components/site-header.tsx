"use client";

import { ComingSoon } from "@/components/coming-soon";
import { Button } from "@/components/ui/button";
import { contractsConfigured } from "@/lib/contracts";
import { cn } from "@/lib/utils";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

const NAV = [
  { href: "/#how", label: "How" },
  { href: "/hopper", label: "Hopper" },
  { href: "/dial", label: "Dial" },
  { href: "/#economics", label: "Econ" },
  { href: "/#art", label: "Art" },
  { href: "/gallery", label: "Gallery" },
  { href: "/art-pass", label: "Art pass" },
  { href: "/art-pass/pixel", label: "Pixel" },
  { href: "/art-pass/traits", label: "Traits" },
  { href: "/art-pass/sample-100", label: "100" },
  { href: "/#status", label: "Status" },
  { href: "/#faq", label: "FAQ" },
] as const;

export function SiteHeader({ trailing }: { trailing?: ReactNode }) {
  const pathname = usePathname();
  const live = contractsConfigured();

  return (
    <header className="sticky top-0 z-30 border-b border-border/70 bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-3 sm:px-6">
        <div className="flex items-center justify-between gap-3">
          <Link href="/" className="min-w-0 shrink-0">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              TERM // 4663
            </p>
            <p className="truncate text-lg font-semibold tracking-tight">
              Terminal Pets
            </p>
          </Link>
          <div className="flex items-center gap-2">
            {live ? (
              <ComingSoon className="hidden sm:inline-flex">
                Contracts live
              </ComingSoon>
            ) : (
              <ComingSoon className="hidden sm:inline-flex" />
            )}
            <Button size="sm" asChild>
              <Link href="/app">Terminal</Link>
            </Button>
            {trailing}
          </div>
        </div>
        <nav
          aria-label="Site"
          className="-mx-1 flex gap-1 overflow-x-auto pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {NAV.map((item) => {
            const active = !item.href.includes("#") && pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "shrink-0 rounded-md px-2.5 py-1 font-mono text-[11px] tracking-wide text-muted-foreground transition-colors hover:bg-muted hover:text-foreground",
                  active && "bg-muted text-foreground",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </div>
    </header>
  );
}
