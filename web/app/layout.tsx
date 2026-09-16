import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
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
  title: {
    default: "Terminal Pets",
    template: "%s · Terminal Pets",
  },
  description:
    "Handheld pets that sleep until you Ignite them. Generative Pocket Critter PFPs. Free mint Friday, September 18, 2026 PT on this hub. Sealed until reveal — collectors cannot see traits. Hub GIFs are examples / not mint supply. 1,000 $TERM + 0.002 ETH. Hopper lock 7 days. Dial 1–4 by shell class.",
  openGraph: {
    title: "Terminal Pets",
    description:
      "Free mint Friday, September 18, 2026 PT. Mint on this hub. Sealed until reveal. Ignite 0.002 ETH. Hopper 7 days. Dial 1–4.",
    type: "website",
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
