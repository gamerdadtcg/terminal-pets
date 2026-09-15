import { SITE } from "@/lib/site";

export function HopperUnlockCountdown() {
  return (
    <p className="rounded-2xl border border-amber-500/20 bg-amber-500/10 px-4 py-3 font-mono text-[11px] leading-relaxed text-amber-100/90">
      After reveal, Hopper ETH keeps accruing but payouts stay locked for{" "}
      {SITE.hopperLock} from the reveal timestamp. First Ignite does not unlock
      early. Pulse snapshots and claims wait for unlock.
    </p>
  );
}
