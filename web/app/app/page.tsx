import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { TerminalApp } from "@/components/terminal-app";
import { ConnectButton } from "@/components/connect-button";

export default function TerminalPage() {
  return (
    <>
      <SiteHeader trailing={<ConnectButton />} />
      <TerminalApp />
      <SiteFooter />
    </>
  );
}
