import { MintPanel } from "@/components/mint-panel";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { SITE, mintScheduleCopy } from "@/lib/site";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Mint",
  description: `${mintScheduleCopy.sentence} Mint 1 Terminal Pet on this hub when CollectionNFT.mintOpen is true. Pets mint as a sealed mystery until reveal — traits unknown. Ignite ${SITE.igniteFeeEth}. Hopper lock ${SITE.hopperLock}. Dial 1–4 by shell class.`,
};

export default function MintPage() {
  return (
    <>
      <SiteHeader />
      <MintPanel />
      <SiteFooter />
    </>
  );
}
