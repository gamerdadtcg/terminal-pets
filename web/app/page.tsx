import { IgniteHome } from "@/components/ignite-home";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

export default function Home() {
  return (
    <>
      <SiteHeader />
      <IgniteHome />
      <SiteFooter />
    </>
  );
}
