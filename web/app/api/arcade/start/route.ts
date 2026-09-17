import {
  arcadeIsClosed,
  ARCADE_COPY,
  ARCADE_GTD_CAP,
  ARCADE_MAX_DURATION_MS,
  ARCADE_TOKEN_TTL_MS,
  arcadeClosesAt,
} from "@/lib/arcade";
import { arcadeStoreKind } from "@/lib/arcade-store";
import { issueArcadeRunToken } from "@/lib/arcade-token";
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
  if (rateLimited(clientIp(request), 20, 60_000)) {
    return NextResponse.json(
      { error: "rate_limited", message: "Slow down." },
      { status: 429 },
    );
  }

  const { token, claims } = issueArcadeRunToken(ARCADE_TOKEN_TTL_MS);
  return NextResponse.json(
    {
      runToken: token,
      runId: claims.runId,
      durationMs: ARCADE_MAX_DURATION_MS,
      gtdCap: ARCADE_GTD_CAP,
      closesAt: arcadeClosesAt().toISOString(),
      store: arcadeStoreKind(),
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
