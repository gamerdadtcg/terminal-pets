import { HubLanding } from "@/components/hub/hub-landing";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

export default function Home() {
  return (
    <>
      <SiteHeader />
      <HubLanding />
      <SiteFooter />
    </>
  );
}
