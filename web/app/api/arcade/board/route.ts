import {
  ARCADE_GTD_CAP,
  arcadeClosesAt,
  arcadeIsClosed,
  arcadeRankOf,
  isArcadeGtdRank,
  rankArcadeRows,
} from "@/lib/arcade";
import { arcadeStoreKind, listArcadeScores } from "@/lib/arcade-store";
import { parseWalletAddress } from "@/lib/eligibility";
import { shortAddress } from "@/lib/format";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const walletParam = url.searchParams.get("wallet") ?? "";
  const wallet = walletParam ? parseWalletAddress(walletParam) : null;
  const exportAll = url.searchParams.get("export") === "1";
  const exportSecret = (
    process.env.ARCADE_EXPORT_SECRET ||
    process.env.ARCADE_HMAC_SECRET ||
    ""
  ).trim();
  const provided = request.headers.get("x-arcade-export") ?? "";
  const allowExport =
    exportAll && exportSecret.length > 0 && provided === exportSecret;

  const rows = rankArcadeRows(await listArcadeScores());
  const limit = allowExport ? rows.length : Math.max(ARCADE_GTD_CAP + 25, 175);
  const sliced = rows.slice(0, limit);

  const board = sliced.map((row, index) => {
    const rank = index + 1;
    return {
      rank,
      wallet: row.wallet,
      short: shortAddress(row.wallet),
      score: row.score,
      ticksCaught: row.ticksCaught,
      submittedAt: row.submittedAt,
      gtd: isArcadeGtdRank(rank),
    };
  });

  const you = wallet
    ? (() => {
        const rank = arcadeRankOf(rows, wallet);
        const row = rows.find(
          (entry) => entry.wallet.toLowerCase() === wallet.toLowerCase(),
        );
        if (!row || rank === null) {
          return { wallet, rank: null, score: 0, gtd: false };
        }
        return {
          wallet: row.wallet,
          rank,
          score: row.score,
          gtd: isArcadeGtdRank(rank),
        };
      })()
    : null;

  return NextResponse.json(
    {
      gtdCap: ARCADE_GTD_CAP,
      closed: arcadeIsClosed(),
      closesAt: arcadeClosesAt().toISOString(),
      store: arcadeStoreKind(),
      count: rows.length,
      board,
      you,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
