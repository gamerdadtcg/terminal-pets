/** Ignite the Dial — hub arcade contest. Hub preview only (not an on-chain allowlist). */

export const ARCADE_GTD_CAP = 150;
export const ARCADE_ROUND_MS = 45_000;
export const ARCADE_TOKEN_TTL_MS = 90_000;
export const ARCADE_MIN_DURATION_MS = 2_500;
export const ARCADE_MAX_DURATION_MS = ARCADE_ROUND_MS + 4_000;
export const ARCADE_MIN_SPAWN_MS = 420;
export const ARCADE_MAX_TICK_POINTS = 120;
export const ARCADE_MAX_COMBO = 8;
export const ARCADE_ABSURD_SCORE = 100_000;

/** Contest closes 2h before the Fri 7:00 AM PT hub redeploy. */
export const ARCADE_CLOSE_ISO =
  process.env.NEXT_PUBLIC_ARCADE_CLOSE_AT?.trim() ||
  "2026-09-18T12:00:00.000Z";

export const ARCADE_PATH = "/arcade";

export const ARCADE_COPY = {
  title: "Ignite the Dial",
  badge: "ARCADE · TOP 150 GTD",
  prompt: "> IGNITE THE DIAL",
  play: "> CATCH TICKS · DODGE GLITCHES · KEEP THE PET LIT",
  locked: "> SCORE LOCKED",
  accepted: "> WALLET ACCEPTED",
  gtd: "> TOP 150 GTD",
  warm: "> WARM · NOT GTD",
  closed: "> CONTEST CLOSED",
  reason: "Arcade top 150",
} as const;

export type ArcadeTickSymbol =
  | "AAPL"
  | "MSFT"
  | "GOOGL"
  | "AMZN"
  | "META"
  | "NVDA"
  | "TSLA"
  | "OMEGA";

export const ARCADE_TICKS: ReadonlyArray<{
  symbol: ArcadeTickSymbol;
  points: number;
}> = [
  { symbol: "AAPL", points: 50 },
  { symbol: "MSFT", points: 50 },
  { symbol: "GOOGL", points: 55 },
  { symbol: "AMZN", points: 55 },
  { symbol: "META", points: 60 },
  { symbol: "NVDA", points: 80 },
  { symbol: "TSLA", points: 80 },
  { symbol: "OMEGA", points: 120 },
];

export function arcadeClosesAt(): Date {
  return new Date(ARCADE_CLOSE_ISO);
}

export function arcadeIsClosed(now = Date.now()): boolean {
  return now >= arcadeClosesAt().getTime();
}

export function maxPlausibleTicks(durationMs: number): number {
  const duration = Math.max(0, Math.min(durationMs, ARCADE_MAX_DURATION_MS));
  return Math.ceil(duration / ARCADE_MIN_SPAWN_MS) + 10;
}

export function maxPlausibleScore(ticksCaught: number): number {
  return ticksCaught * ARCADE_MAX_TICK_POINTS * ARCADE_MAX_COMBO;
}

export type ArcadeRunProof = {
  score: number;
  ticksCaught: number;
  glitchesHit: number;
  durationMs: number;
};

export function validateArcadeProof(
  proof: ArcadeRunProof,
): string | null {
  const { score, ticksCaught, glitchesHit, durationMs } = proof;
  if (!Number.isInteger(score) || score < 0 || score > ARCADE_ABSURD_SCORE) {
    return "Score rejected.";
  }
  if (!Number.isInteger(ticksCaught) || ticksCaught < 0) {
    return "Run proof rejected.";
  }
  if (!Number.isInteger(glitchesHit) || glitchesHit < 0 || glitchesHit > 80) {
    return "Run proof rejected.";
  }
  if (
    !Number.isFinite(durationMs) ||
    durationMs < ARCADE_MIN_DURATION_MS ||
    durationMs > ARCADE_MAX_DURATION_MS
  ) {
    return "Run duration rejected.";
  }
  if (ticksCaught > maxPlausibleTicks(durationMs)) {
    return "Run proof rejected.";
  }
  if (score > maxPlausibleScore(ticksCaught)) {
    return "Score rejected.";
  }
  if (ticksCaught === 0 && score > 0) {
    return "Score rejected.";
  }
  if (ticksCaught > 0 && score < ticksCaught * 10) {
    return "Score rejected.";
  }
  return null;
}

export type ArcadeScoreRow = {
  wallet: string;
  score: number;
  ticksCaught: number;
  glitchesHit: number;
  durationMs: number;
  /** First time this best score was submitted (tie-break). */
  submittedAt: number;
  updatedAt: number;
};

export function compareArcadeRows(a: ArcadeScoreRow, b: ArcadeScoreRow): number {
  if (b.score !== a.score) return b.score - a.score;
  if (a.submittedAt !== b.submittedAt) return a.submittedAt - b.submittedAt;
  return a.wallet.localeCompare(b.wallet);
}

export function rankArcadeRows(rows: ArcadeScoreRow[]): ArcadeScoreRow[] {
  return [...rows].sort(compareArcadeRows);
}

export function arcadeRankOf(
  rows: ArcadeScoreRow[],
  wallet: string,
): number | null {
  const ranked = rankArcadeRows(rows);
  const index = ranked.findIndex(
    (row) => row.wallet.toLowerCase() === wallet.toLowerCase(),
  );
  return index === -1 ? null : index + 1;
}

export function isArcadeGtdRank(rank: number | null): boolean {
  return rank !== null && rank >= 1 && rank <= ARCADE_GTD_CAP;
}
