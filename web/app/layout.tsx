import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
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
    "Handheld pets that sleep until you Ignite them. Generative Pocket Critter PFPs. Free mint Friday, September 18, 2026 PT. 1,000 $TERM + 0.002 ETH. Live $TERM trades skim 3% (Hopper / burn / treasury). Mint. Ignite. Dormant→Lit. Hopper. Pulse. Dial. TBA. Robinhood Chain.",
  openGraph: {
    title: "Terminal Pets",
    description:
      "Free mint Friday, September 18, 2026 PT. On-chain Tamagotchi terminals. Mint. Ignite. Dial. Hopper. Pulse. TBA.",
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
        {children}
      </body>
    </html>
  );
}
