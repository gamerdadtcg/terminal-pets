import {
  arcadeIsClosed,
  ARCADE_COPY,
  ARCADE_GTD_CAP,
  arcadeRankOf,
  isArcadeGtdRank,
  validateArcadeProof,
} from "@/lib/arcade";
import {
  consumeArcadeRun,
  listArcadeScores,
  upsertArcadeScore,
} from "@/lib/arcade-store";
import { verifyArcadeRunToken } from "@/lib/arcade-token";
import { parseWalletAddress } from "@/lib/eligibility";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const hits = new Map<string, number[]>();

function clientIp(request: Request): string {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip") ||
    "local"
  );
}

function rateLimited(ip: string, limit: number, windowMs: number): boolean {
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < windowMs);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > limit;
}

export async function POST(request: Request) {
  if (arcadeIsClosed()) {
    return NextResponse.json(
      { error: "closed", message: ARCADE_COPY.closed },
      { status: 410 },
    );
  }
  if (rateLimited(clientIp(request), 12, 60_000)) {
    return NextResponse.json(
      { error: "rate_limited", message: "Slow down." },
      { status: 429 },
    );
  }

  let body: {
    wallet?: unknown;
    score?: unknown;
    runToken?: unknown;
    ticksCaught?: unknown;
    glitchesHit?: unknown;
    durationMs?: unknown;
  };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return NextResponse.json(
      { error: "invalid_json", message: "Could not read score." },
      { status: 400 },
    );
  }

  const wallet =
    typeof body.wallet === "string" ? parseWalletAddress(body.wallet) : null;
  if (!wallet) {
    return NextResponse.json(
      { error: "invalid_address", message: "Paste a 0x wallet." },
      { status: 400 },
    );
  }

  const token = typeof body.runToken === "string" ? body.runToken : "";
  const claims = verifyArcadeRunToken(token);
  if (!claims) {
    return NextResponse.json(
      { error: "invalid_run", message: "Play a fresh round, then submit." },
      { status: 400 },
    );
  }

  const proof = {
    score: typeof body.score === "number" ? body.score : NaN,
    ticksCaught: typeof body.ticksCaught === "number" ? body.ticksCaught : NaN,
    glitchesHit: typeof body.glitchesHit === "number" ? body.glitchesHit : NaN,
    durationMs: typeof body.durationMs === "number" ? body.durationMs : NaN,
  };
  const proofError = validateArcadeProof(proof);
  if (proofError) {
    return NextResponse.json(
      { error: "invalid_score", message: proofError },
      { status: 400 },
    );
  }

  const consumed = await consumeArcadeRun(claims.runId);
  if (!consumed) {
    return NextResponse.json(
      { error: "replay", message: "That run was already submitted." },
      { status: 409 },
    );
  }

  const now = Date.now();
  const result = await upsertArcadeScore({
    wallet,
    score: proof.score,
    ticksCaught: proof.ticksCaught,
    glitchesHit: proof.glitchesHit,
    durationMs: Math.round(proof.durationMs),
    submittedAt: now,
    updatedAt: now,
  });

  const rows = await listArcadeScores();
  const rank = arcadeRankOf(rows, wallet) ?? result.rank;

  return NextResponse.json(
    {
      ok: true,
      message: result.improved
        ? ARCADE_COPY.accepted
        : "> BEST SCORE UNCHANGED",
      wallet: result.saved.wallet,
      score: result.saved.score,
      rank,
      gtd: isArcadeGtdRank(rank),
      gtdCap: ARCADE_GTD_CAP,
      improved: result.improved,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
