import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { SITE, SITE_URL } from "@/lib/site";
import { Providers } from "./providers";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Terminal Pets",
    template: "%s · Terminal Pets",
  },
  description:
    "Handheld pets that sleep until you Ignite them. Generative Pocket Critter PFPs. Public mint sold out. Collection stays sealed until reveal — collectors cannot see traits. Hub GIFs are examples / not mint supply. Ignite and $TERM trading stay off until then. 1,000 $TERM + 0.002 ETH. Hopper lock 7 days. Dial 1–4 by shell class.",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "16x16 32x32 48x48" },
      { url: "/favicon-32x32.png", type: "image/png", sizes: "32x32" },
      { url: "/icon.png", type: "image/png", sizes: "512x512" },
    ],
    apple: [{ url: "/apple-icon.png", sizes: "180x180", type: "image/png" }],
  },
  openGraph: {
    title: "Terminal Pets",
    description:
      "Public mint sold out. Collection stays sealed until reveal. Ignite and $TERM trading stay off until then. Ignite 0.002 ETH. Hopper 7 days. Dial 1–4.",
    url: "/",
    siteName: SITE.name,
    type: "website",
    images: [
      {
        url: "/og.png",
        width: 1200,
        height: 630,
        alt: "Terminal Pets",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    images: ["/og.png"],
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} dark h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
