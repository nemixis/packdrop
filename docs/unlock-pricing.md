# Unlock pricing

Cost to unlock a set, in shards. Derived from the set's market value, not chosen by hand.

## Rule

```
cost = clamp( round5( Σ min(price(card), cap) ), 150, 2400 )
```

- **1 shard ≈ $1** of set value. A set worth $534 costs 535 shards.
- **cap** — per-card ceiling, so one outlier print cannot price a whole set.
  Pokémon: **$150/card**. Magic: **$5/print** (an MTG "set" here is hundreds of
  near-identical prints; summing them raw gives five figures for any recent set).
- **clamp 150–2400** — nothing is free, nothing is unreachable.

Prices come from the TCGplayer feeds the app already ships
(`https://cdn.jsdelivr.net/gh/nemixis/tcgpricedrop@main/prices/*.json`), the same data
behind every card's price on screen. No new source, no extra request at runtime: the
table is computed at build time and baked into `index.html`.

## Current values

| set | raw | capped | cost | note |
|---|---:|---:|---:|---|
| cel | 13,509 | 1,723 | 1,725 | cap $150/card |
| blk | 3,863 | 2,846 | 2,400 | clamped |
| ah | 3,674 | 2,206 | 2,205 | |
| meg | 1,276 | 1,198 | 1,200 | |
| pbl | 534 | 534 | 535 | tcgindex lists this set at $538 |
| pfl | 939 | 480 | 480 | |
| mep | 451 | 451 | 450 | |
| cri | 425 | 425 | 425 | |
| ff | 86,979 | 2,955 | 2,400 | cap $5/print, clamped |
| eoe | 11,255 | 1,666 | 1,665 | |
| spm | 27,004 | 973 | 975 | |
| tla | 11,470 | 963 | 965 | |
| ecl | 2,033 | 615 | 615 | |

Why the caps matter, concretely: the three 30th Celebration RGB Mews list at $4,462 /
$4,244 / $3,529. Uncounted, the set prices at 13,509 shards — impossible to reach and
meaningless as a progression goal. Capped at $150/card it is 1,723, which is what a
191-card set of that quality is worth to a player.

## Regenerating

```bash
node scripts/set-values.js          # table
node scripts/set-values.js --json   # paste-ready objects
```

Paste `SET_VALUE_USD` / `UNLOCK_COST` next to their definitions in `index.html`
(above `Object.keys(UNLOCK_COST).forEach(...)`, which writes both into `EXPANSIONS`).
Adding a new priced set means adding its feed files and cap to `SETS` in the script.

## What players see

Each row of the Unlock screen prints the basis next to the price (`MARKET $534`), so the
number is explainable in the UI rather than a magic constant. The lead line states the
rule in one sentence, in both languages.

## Not covered

- `mar` (Marvel Universe) shares Spider-Man's price pool and is not independently
  openable, so it keeps its legacy cost.
- Graded/serialized products are excluded by the cap, not by a product-type filter —
  a serialized card simply cannot exceed the cap's contribution.
