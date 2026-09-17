import { EligibleRedirect } from "@/components/hub/eligible-redirect";
import { ELIGIBLE_SHARE, SITE } from "@/lib/site";
import type { Metadata } from "next";

const ogTitle = `${ELIGIBLE_SHARE.title} · ${SITE.name}`;

export const metadata: Metadata = {
  title: ELIGIBLE_SHARE.title,
  description: ELIGIBLE_SHARE.description,
  alternates: {
    canonical: ELIGIBLE_SHARE.path,
  },
  openGraph: {
    title: ogTitle,
    description: ELIGIBLE_SHARE.description,
    url: ELIGIBLE_SHARE.path,
    siteName: SITE.name,
    type: "website",
    images: [
      {
        url: ELIGIBLE_SHARE.image,
        width: ELIGIBLE_SHARE.imageWidth,
        height: ELIGIBLE_SHARE.imageHeight,
        alt: ELIGIBLE_SHARE.imageAlt,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: ogTitle,
    description: ELIGIBLE_SHARE.description,
    images: [ELIGIBLE_SHARE.image],
  },
};

export default function EligiblePage() {
  return <EligibleRedirect />;
}
