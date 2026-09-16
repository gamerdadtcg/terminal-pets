import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { TerminalApp } from "@/components/terminal-app";

export default function TerminalPage() {
  return (
    <>
      <SiteHeader />
      <TerminalApp />
      <SiteFooter />
    </>
  );
}
