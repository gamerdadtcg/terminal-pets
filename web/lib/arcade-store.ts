import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { getCache } from "@vercel/functions";
import {
  arcadeRankOf,
  compareArcadeRows,
  isArcadeGtdRank,
  rankArcadeRows,
  type ArcadeScoreRow,
} from "@/lib/arcade";
import { isExportedArcadeGtdWallet } from "@/lib/arcade-gtd-wallets";

const HASH_KEY = "arcade:scores";
const FILE_NAME = "arcade-scores.json";
const CACHE_SCORES_KEY = "scores";
const CACHE_RUN_PREFIX = "run:";
const CACHE_SCORES_TTL_SECONDS = 60 * 60 * 24 * 14;
const RUN_TTL_SECONDS = 180;

type StoreKind = "redis" | "cache" | "file" | "memory";
type ArcadeCache = ReturnType<typeof getCache>;
type CachePayload = { rows: ArcadeScoreRow[] };

type MemoryState = {
  rows: Map<string, ArcadeScoreRow>;
  usedRuns: Map<string, number>;
};

const memory: MemoryState = {
  rows: new Map(),
  usedRuns: new Map(),
};

function redisConfig(): { url: string; token: string } | null {
  const url = (
    process.env.KV_REST_API_URL ||
    process.env.UPSTASH_REDIS_REST_URL ||
    ""
  ).trim();
  const token = (
    process.env.KV_REST_API_TOKEN ||
    process.env.UPSTASH_REDIS_REST_TOKEN ||
    ""
  ).trim();
  if (!url || !token) return null;
  return { url: url.replace(/\/$/, ""), token };
}

function scoresFilePath(): string {
  return path.join(process.cwd(), "data", FILE_NAME);
}

function canWriteFile(): boolean {
  return process.env.VERCEL !== "1";
}

function onVercel(): boolean {
  return process.env.VERCEL === "1";
}

function arcadeCache(): ArcadeCache | null {
  if (!onVercel() || redisConfig()) return null;
  try {
    return getCache({ namespace: "arcade" });
  } catch {
    return null;
  }
}

export function arcadeStoreKind(): StoreKind {
  if (redisConfig()) return "redis";
  if (onVercel()) return "cache";
  if (canWriteFile()) return "file";
  return "memory";
}

async function redisCommand(
  config: { url: string; token: string },
  args: Array<string | number>,
): Promise<unknown> {
  const response = await fetch(`${config.url}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
    cache: "no-store",
  });
  if (!response.ok) {
    throw new Error(`Redis ${response.status}`);
  }
  const body = (await response.json()) as { result?: unknown; error?: string };
  if (body.error) throw new Error(body.error);
  return body.result;
}

function parseRow(value: string): ArcadeScoreRow | null {
  try {
    return coerceRow(JSON.parse(value));
  } catch {
    return null;
  }
}

function coerceRow(value: unknown): ArcadeScoreRow | null {
  if (!value || typeof value !== "object") return null;
  const row = value as ArcadeScoreRow;
  if (
    typeof row.wallet !== "string" ||
    !Number.isInteger(row.score) ||
    !Number.isInteger(row.submittedAt)
  ) {
    return null;
  }
  return row;
}

async function readFileRows(): Promise<Map<string, ArcadeScoreRow>> {
  try {
    const raw = await readFile(scoresFilePath(), "utf8");
    const parsed = JSON.parse(raw) as { rows?: ArcadeScoreRow[] };
    const map = new Map<string, ArcadeScoreRow>();
    for (const row of parsed.rows ?? []) {
      const parsedRow = coerceRow(row);
      if (parsedRow) map.set(parsedRow.wallet.toLowerCase(), parsedRow);
    }
    return map;
  } catch {
    return new Map();
  }
}

async function writeFileRows(rows: Map<string, ArcadeScoreRow>): Promise<void> {
  const file = scoresFilePath();
  await mkdir(path.dirname(file), { recursive: true });
  const payload = {
    updatedAt: Date.now(),
    rows: rankArcadeRows([...rows.values()]),
  };
  await writeFile(file, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

async function readCacheRows(
  cache: ArcadeCache,
): Promise<Map<string, ArcadeScoreRow>> {
  const raw = await cache.get(CACHE_SCORES_KEY);
  const map = new Map<string, ArcadeScoreRow>();
  const rows = Array.isArray(raw)
    ? raw
    : raw && typeof raw === "object" && Array.isArray((raw as CachePayload).rows)
      ? (raw as CachePayload).rows
      : [];
  for (const value of rows) {
    const row = coerceRow(value);
    if (row) map.set(row.wallet.toLowerCase(), row);
  }
  return map;
}

async function writeCacheRows(
  cache: ArcadeCache,
  rows: Map<string, ArcadeScoreRow>,
): Promise<void> {
  const payload: CachePayload = {
    rows: rankArcadeRows([...rows.values()]),
  };
  await cache.set(CACHE_SCORES_KEY, payload, {
    ttl: CACHE_SCORES_TTL_SECONDS,
    tags: ["arcade-scores"],
    name: "arcade-scores",
  });
}

async function allRows(): Promise<ArcadeScoreRow[]> {
  const redis = redisConfig();
  if (redis) {
    const result = await redisCommand(redis, ["HGETALL", HASH_KEY]);
    const rows: ArcadeScoreRow[] = [];
    if (Array.isArray(result)) {
      for (let i = 1; i < result.length; i += 2) {
        const value = result[i];
        if (typeof value === "string") {
          const row = parseRow(value);
          if (row) rows.push(row);
        }
      }
    } else if (result && typeof result === "object") {
      for (const value of Object.values(result as Record<string, string>)) {
        const row = parseRow(value);
        if (row) rows.push(row);
      }
    }
    return rankArcadeRows(rows);
  }

  const cache = arcadeCache();
  if (cache) {
    const map = await readCacheRows(cache);
    return rankArcadeRows([...map.values()]);
  }

  if (canWriteFile()) {
    const map = await readFileRows();
    return rankArcadeRows([...map.values()]);
  }

  pruneUsedRuns();
  return rankArcadeRows([...memory.rows.values()]);
}

export async function listArcadeScores(): Promise<ArcadeScoreRow[]> {
  return allRows();
}

export async function getArcadeScore(
  wallet: string,
): Promise<ArcadeScoreRow | null> {
  const key = wallet.toLowerCase();
  const redis = redisConfig();
  if (redis) {
    const result = await redisCommand(redis, ["HGET", HASH_KEY, key]);
    return typeof result === "string" ? parseRow(result) : null;
  }
  const cache = arcadeCache();
  if (cache) {
    const map = await readCacheRows(cache);
    return map.get(key) ?? null;
  }
  if (canWriteFile()) {
    const map = await readFileRows();
    return map.get(key) ?? null;
  }
  return memory.rows.get(key) ?? null;
}

export async function consumeArcadeRun(runId: string): Promise<boolean> {
  const redis = redisConfig();
  if (redis) {
    const result = await redisCommand(redis, [
      "SET",
      `arcade:run:${runId}`,
      "1",
      "EX",
      RUN_TTL_SECONDS,
      "NX",
    ]);
    return result === "OK";
  }
  const cache = arcadeCache();
  if (cache) {
    const usedKey = `${CACHE_RUN_PREFIX}${runId}`;
    const existing = await cache.get(usedKey);
    if (existing) return false;
    await cache.set(usedKey, 1, {
      ttl: RUN_TTL_SECONDS,
      tags: ["arcade-runs"],
      name: "arcade-run",
    });
    return true;
  }
  pruneUsedRuns();
  if (memory.usedRuns.has(runId)) return false;
  memory.usedRuns.set(runId, Date.now() + RUN_TTL_SECONDS * 1000);
  return true;
}

function pruneUsedRuns(now = Date.now()) {
  for (const [id, exp] of memory.usedRuns) {
    if (exp <= now) memory.usedRuns.delete(id);
  }
}

export async function upsertArcadeScore(
  incoming: ArcadeScoreRow,
): Promise<{
  saved: ArcadeScoreRow;
  improved: boolean;
  rank: number;
  gtd: boolean;
}> {
  const key = incoming.wallet.toLowerCase();
  const redis = redisConfig();

  if (redis) {
    const existingRaw = await redisCommand(redis, ["HGET", HASH_KEY, key]);
    const existing =
      typeof existingRaw === "string" ? parseRow(existingRaw) : null;
    const next = pickBest(existing, incoming);
    const improved = !existing || compareArcadeRows(next, existing) < 0;
    if (improved || !existing) {
      await redisCommand(redis, ["HSET", HASH_KEY, key, JSON.stringify(next)]);
    }
    const ranked = await allRows();
    const rank = arcadeRankOf(ranked, next.wallet) ?? ranked.length;
    return { saved: next, improved, rank, gtd: isArcadeGtdRank(rank) };
  }

  const cache = arcadeCache();
  if (cache) {
    const map = await readCacheRows(cache);
    const existing = map.get(key) ?? null;
    const next = pickBest(existing, incoming);
    const improved = !existing || compareArcadeRows(next, existing) < 0;
    map.set(key, next);
    await writeCacheRows(cache, map);
    const rank = arcadeRankOf([...map.values()], next.wallet) ?? map.size;
    return { saved: next, improved, rank, gtd: isArcadeGtdRank(rank) };
  }

  if (canWriteFile()) {
    const map = await readFileRows();
    const existing = map.get(key) ?? null;
    const next = pickBest(existing, incoming);
    const improved = !existing || compareArcadeRows(next, existing) < 0;
    map.set(key, next);
    await writeFileRows(map);
    const rank = arcadeRankOf([...map.values()], next.wallet) ?? map.size;
    return { saved: next, improved, rank, gtd: isArcadeGtdRank(rank) };
  }

  const existing = memory.rows.get(key) ?? null;
  const next = pickBest(existing, incoming);
  const improved = !existing || compareArcadeRows(next, existing) < 0;
  memory.rows.set(key, next);
  const rank =
    arcadeRankOf([...memory.rows.values()], next.wallet) ?? memory.rows.size;
  return { saved: next, improved, rank, gtd: isArcadeGtdRank(rank) };
}

function pickBest(
  existing: ArcadeScoreRow | null,
  incoming: ArcadeScoreRow,
): ArcadeScoreRow {
  if (!existing) return incoming;
  return compareArcadeRows(incoming, existing) < 0
    ? { ...incoming, submittedAt: incoming.submittedAt }
    : existing;
}

export async function isLiveArcadeGtdWallet(address: string): Promise<boolean> {
  if (isExportedArcadeGtdWallet(address)) return true;
  const rows = await allRows();
  return isArcadeGtdRank(arcadeRankOf(rows, address));
}
