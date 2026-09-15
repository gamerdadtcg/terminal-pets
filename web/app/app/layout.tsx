import { Providers } from "../providers";
import type { ReactNode } from "react";

export default function TerminalLayout({ children }: { children: ReactNode }) {
  return <Providers>{children}</Providers>;
}
