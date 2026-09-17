# Terminal Pets Arcade — Cursor build brief

## Goal
Ship a short CRT-terminal mini-game on the hub where players chase a high score, submit a wallet, and the **top 150** wallets get **GTD** (and therefore **FCFS** via existing carryover) for Friday’s mint.

## Theme / vibe
- Monospace CRT green (and amber accents like the OpenSea banner): prompt `>`, blinking cursor, scanlines, soft phosphor glow.
- Framing: **“Ignite the Dial”** or **“Hatch Score”** — you’re waking a sealed pet / spinning the stock Dial, not a generic flappy clone.
- Copy voice: short terminal lines (`> SCORE LOCKED`, `> WALLET ACCEPTED`, `> TOP 150 GTD`).
- Art: reuse sealed egg / hatch / demo pets already on the hub — no new collection traits, no awake 1/1 leaks before reveal.

## Player loop (keep it tiny)
1. Play (~30–60s rounds): dodge glitches / catch Dial ticks / keep the pet lit — pick **one** mechanic and polish it.
2. End screen: final score + rank preview.
3. Connect or paste `0x` wallet → submit score (one best score per wallet).
4. Live leaderboard: top 150 highlighted as **GTD LOCKED**; ranks 151+ shown as “warm” but not eligible.

## Eligibility rules (product)
- Arcade winners write into the same path as X-thread GTD: `web/lib/manual-gtd-wallets.ts` (or a generated JSON it imports).
- Hard cap **150** wallets by **best score**, then earliest submit time as tie-break.
- GTD already unlocks FCFS on the hub checker — do not add a separate FCFS arcade list.
- Partner NFT GTD (School of NFTs ETH, StonkBrokers, etc.) stays independent; arcade is an extra GTD path.
- Contest closes early enough that winners are on `main` before **Fri Sep 18 7:00 AM PT** hub redeploy (GTD mint 8:00 AM PT).

## Tech (repo: `gamerdadtcg/terminal-pets`)
- Route: `/arcade` (and link from hub / mint / eligible).
- Client: Canvas or lightweight Phaser/Pixi; mobile-friendly touch.
- Server: Next.js route handler — accept `{ wallet, score, runId }`, verify lightly (signed run token or server-issued nonce), store best score per wallet (Vercel KV / Supabase / simple JSON+PR if you must ship fast).
- Anti-abuse light: rate limit, one wallet, discard absurd scores, optional short proof-of-play.
- After close: script `scripts/export-arcade-gtd.ts` → overwrite/merge top 150 into manual GTD → PR to main.
- Fri 7am redeploy routine already armed; your job is having that export merged before then.

## Out of scope
- No on-chain mint allowlist / Merkle for v1 (hub preview only, same as partners).
- No reveal, no `mintOpen`, no teamMint from this feature.
- No public DNA/rarity maps.

## Success
- Playable CRT arcade live on `terminalpets.xyz/arcade`.
- Top 150 wallets appear as GTD (and FCFS via GTD) on `/eligible` after the Fri 7am redeploy.
- Feels like Terminal Pets, not a bolted-on random game.

## Suggested first PR
Scaffold `/arcade` shell (CRT UI + placeholder game + wallet form + fake leaderboard), wire score API stub, document export → `manual-gtd-wallets` path.

## Implementation (this repo)

- Playable canvas at `/arcade`: **Ignite the Dial** — jump example SNAG, dodge glitch panels (penalties), catch Dial ticks, keep SNAG lit (45s).
- Score API: `POST /api/arcade/start`, `POST /api/arcade/score`, `GET /api/arcade/board`. HMAC run tokens, rate limits, one best score per wallet.
- Storage: Upstash Redis REST when `KV_REST_API_*` or `UPSTASH_REDIS_REST_*` are set; otherwise `web/data/arcade-scores.json` locally; in-memory on Vercel without Redis.
- Live top 150 count as GTD on `/eligible` (and FCFS via GTD). After close, export into `web/lib/arcade-gtd-wallets.ts` and merge to `main` before Fri 7:00 AM PT.

```bash
cd web
# local file:
node scripts/export-arcade-gtd.mjs
# or production board:
ARCADE_BOARD_URL=https://terminalpets.xyz/api/arcade/board \
  ARCADE_EXPORT_SECRET=… node scripts/export-arcade-gtd.mjs
```
