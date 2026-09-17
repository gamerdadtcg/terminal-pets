import { mintAllocation, mintSchedule, mintScheduleCopy, sealedCopy } from "@/lib/site";
import { cn } from "@/lib/utils";

export function MintScheduleCard({
  compact = false,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-[1.6rem] border border-primary/25 bg-card/70 p-5 shadow-[0_0_80px_rgba(240,180,41,0.08)]",
        className,
      )}
    >
      <p className="font-mono text-[11px] tracking-[0.28em] text-primary">
        FREE MINT · FRI SEP 18 2026
      </p>
      <p className="mt-3 text-lg font-medium">{mintSchedule.date}</p>
      <p className="mt-1 text-sm text-muted-foreground">
        {mintSchedule.timezoneIana} ({mintSchedule.timezoneLabel}) · 1 per
        public phase
      </p>
      <div className="mt-4 rounded-xl border border-border/70 bg-background/50 px-3 py-2">
        <p className="font-mono text-[11px] text-primary">
          {mintSchedule.teamAllocation.shortDate} ·{" "}
          {mintSchedule.teamAllocation.time}
        </p>
        <p className="text-sm font-medium">
          {mintSchedule.teamAllocation.name}
          <span className="ml-1 font-normal text-muted-foreground">
            (owner-only · not public)
          </span>
        </p>
      </div>
      <ol className="mt-2 grid gap-2 sm:grid-cols-3">
        {mintSchedule.phases.map((phase) => (
          <li
            key={phase.name}
            className="rounded-xl border border-border/70 bg-background/50 px-3 py-2"
          >
            <p className="font-mono text-[11px] text-primary">{phase.time}</p>
            <p className="text-sm font-medium">
              {phase.name}
              {"note" in phase && phase.note ? (
                <span className="ml-1 font-normal text-muted-foreground">
                  ({phase.note})
                </span>
              ) : null}
            </p>
          </li>
        ))}
      </ol>
      <p className="mt-4 text-sm text-muted-foreground">
        {compact ? mintSchedule.rule : mintScheduleCopy.sentence}{" "}
        {mintAllocation.sentence} Mint 1 on this hub when on-chain{" "}
        <span className="font-mono">mintOpen</span> is true Friday.{" "}
        {sealedCopy.tokenUri}
      </p>
      <p className="mt-2 break-all font-mono text-[11px] text-muted-foreground">
        Sealed tokenURI: {sealedCopy.hiddenUri}
        <span className="mt-1 block text-muted-foreground/80">
          Alias until DNS cutover: {sealedCopy.hiddenUriAlias}
        </span>
      </p>
    </div>
  );
}
