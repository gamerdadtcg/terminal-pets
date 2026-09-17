import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

export type ArcadeRunClaims = {
  v: 1;
  runId: string;
  iat: number;
  exp: number;
};

function secret(): string {
  const configured = process.env.ARCADE_HMAC_SECRET?.trim();
  if (configured) return configured;
  if (process.env.VERCEL_ENV === "production") {
    return `term-arcade:${process.env.NEXT_PUBLIC_COLLECTION_NFT ?? "term"}`;
  }
  return "dev-arcade-hmac";
}

function b64url(value: Buffer | string): string {
  const buf = typeof value === "string" ? Buffer.from(value) : value;
  return buf.toString("base64url");
}

function sign(payload: string): string {
  return createHmac("sha256", secret()).update(payload).digest("base64url");
}

export function issueArcadeRunToken(ttlMs: number): {
  token: string;
  claims: ArcadeRunClaims;
} {
  const now = Date.now();
  const claims: ArcadeRunClaims = {
    v: 1,
    runId: randomUUID(),
    iat: now,
    exp: now + ttlMs,
  };
  const payload = b64url(JSON.stringify(claims));
  return { token: `${payload}.${sign(payload)}`, claims };
}

export function verifyArcadeRunToken(
  token: string,
  now = Date.now(),
): ArcadeRunClaims | null {
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [payload, sig] = parts;
  if (!payload || !sig) return null;
  const expected = sign(payload);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try {
    const claims = JSON.parse(
      Buffer.from(payload, "base64url").toString("utf8"),
    ) as ArcadeRunClaims;
    if (claims.v !== 1 || typeof claims.runId !== "string") return null;
    if (!Number.isFinite(claims.iat) || !Number.isFinite(claims.exp)) {
      return null;
    }
    if (now > claims.exp) return null;
    if (now + 2_000 < claims.iat) return null;
    return claims;
  } catch {
    return null;
  }
}
