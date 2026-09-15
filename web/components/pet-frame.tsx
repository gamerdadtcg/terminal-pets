import { cn } from "@/lib/utils";

export function PetFrame({
  src,
  label,
  className,
}: {
  src: string;
  label: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "hub-scan overflow-hidden rounded-xl bg-[#07080b]",
        className,
      )}
    >
      {/* object (not img) so Chrome/Safari play SMIL blink / idle / Zzz */}
      <object
        type="image/svg+xml"
        data={src}
        className="aspect-square w-full"
        aria-label={label}
      >
        <p className="p-4 text-sm text-muted-foreground">
          Open{" "}
          <a className="underline" href={src}>
            {src}
          </a>{" "}
          if the pet does not appear.
        </p>
      </object>
    </div>
  );
}
