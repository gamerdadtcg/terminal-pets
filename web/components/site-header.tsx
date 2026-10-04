"use client";

import { ConnectButton } from "@/components/connect-button";
import { configuredChainId } from "@/lib/chain";
import { cn } from "@/lib/utils";
import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  { href: "/", label: "Ignite" },
  { href: "/how", label: "How it works" },
  { href: "/hopper", label: "Hopper & Pulse" },
] as const;

export function SiteHeader() {
  const pathname = usePathname();
  const chainId = configuredChainId();

  return (
    <header className="sticky top-0 z-30 border-b border-border/70 bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-3 sm:px-6">
        <div className="flex items-center justify-between gap-3">
          <Link href="/" className="min-w-0 shrink-0">
            <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
              TERM // {chainId}
            </p>
            <p className="truncate text-lg font-semibold tracking-tight">
              Terminal Pets
            </p>
          </Link>
          <ConnectButton />
        </div>
        <nav
          aria-label="Site"
          className="-mx-1 flex gap-1 overflow-x-auto pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {NAV.map((item) => {
            const active =
              item.href === "/"
                ? pathname === "/"
                : pathname === item.href || pathname.startsWith(`${item.href}/`);
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
