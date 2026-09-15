import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export function ComingSoon({
  children = "Deploying soon",
  className,
}: {
  children?: string;
  className?: string;
}) {
  return (
    <Badge
      variant="outline"
      className={cn("font-mono text-[10px] tracking-wide", className)}
    >
      {children}
    </Badge>
  );
}
