#!/usr/bin/env node
/**
 * Regenerate the unlock prices in index.html.
 *
 * A set's unlock cost is derived from what it actually costs to complete on the
 * secondary market, at 1 shard ≈ $1. Two corrections keep that playable:
 *
 *   cap  — a per-card price ceiling. The 30th Celebration RGB Mews list at
 *          $3.5k–$4.5k each; uncapped they price the whole set at 13,500 shards.
 *          Pokémon cards are capped at $150, Magic prints at $5 (an MTG set is
 *          hundreds of near-identical prints, so a per-print ceiling has to be
 *          far lower for the total to mean anything).
 *   clamp — [150, 2400], so no set is free and none is unreachable.
 *
 * Usage:  node scripts/set-values.js            # print the table
 *         node scripts/set-values.js --json     # print SET_VALUE_USD/UNLOCK_COST
 *
 * Then paste the two objects into index.html next to SET_VALUE_USD and bump the
 * pool cache key if the pools themselves changed (they do not for a price pass).
 */
const BASE = 'https://cdn.jsdelivr.net/gh/nemixis/tcgpricedrop@main/prices/';

// expansion code -> price feed files, and the per-card cap that applies to it
const SETS = {
  cel: { files: ['30th', '30th-c'], cap: 150 },
  ah:  { files: ['ah'], cap: 150 },
  blk: { files: ['blk'], cap: 150 },
  meg: { files: ['meg'], cap: 150 },
  pfl: { files: ['pfl'], cap: 150 },
  pbl: { files: ['pbl'], cap: 150 },
  mep: { files: ['mep'], cap: 150 },
  cri: { files: ['cri'], cap: 150 },
  ff:  { files: ['ff-main', 'ff-art', 'ff-commander', 'ff-bonus'], cap: 5 },
  eoe: { files: ['eoe-main', 'eoe-art', 'eoe-commander', 'eoe-bonus'], cap: 5 },
  spm: { files: ['spm-main', 'spm-art', 'spm-bonus'], cap: 5 },
  tla: { files: ['tla-main', 'tla-art'], cap: 5 },
  ecl: { files: ['ecl-main', 'ecl-art'], cap: 5 },
};

const MIN = 150, MAX = 2400;

function primaryPrice(entry) {
  const prices = entry.prices || [];
  for (const want of ['Normal', 'Holofoil']) {
    for (const p of prices) if (p.finish === want && p.market) return p.market;
  }
  for (const p of prices) if (p.market) return p.market;
  return 0;
}

async function setValue({ files, cap }) {
  let raw = 0, capped = 0, cards = 0, missing = 0;
  for (const f of files) {
    let arr;
    try {
      const res = await fetch(BASE + f + '.json');
      if (!res.ok) { missing++; continue; }
      const data = await res.json();
      arr = Array.isArray(data) ? data : (data.data || data.cards || []);
    } catch (e) { missing++; continue; }
    for (const entry of arr) {
      const v = primaryPrice(entry);
      raw += v; capped += Math.min(v, cap); cards++;
    }
  }
  const cost = Math.max(MIN, Math.min(MAX, Math.round(Math.round(capped / 5) * 5)));
  return { cards, raw: Math.round(raw), capped: Math.round(capped), cost, missing };
}

(async () => {
  const asJson = process.argv.includes('--json');
  const values = {}, costs = {}, rows = [];
  for (const [code, cfg] of Object.entries(SETS)) {
    const r = await setValue(cfg);
    values[code] = r.capped;
    costs[code] = r.cost;
    rows.push([code, r.cards, r.raw, r.capped, r.cost, r.missing ? `${r.missing} feed(s) missing` : '']);
  }
  if (asJson) {
    console.log('const SET_VALUE_USD = ' + JSON.stringify(values, null, 0).replace(/"/g, '') + ';');
    console.log('const UNLOCK_COST = ' + JSON.stringify(costs, null, 0).replace(/"/g, '') + ';');
    return;
  }
  console.log('set   cards      raw     capped     cost  note');
  for (const r of rows) {
    console.log(r[0].padEnd(5), String(r[1]).padStart(5), String(r[2]).padStart(8),
      String(r[3]).padStart(9), String(r[4]).padStart(8), ' ' + r[5]);
  }
  console.log(`\ncap: Pokémon $150/card, Magic $5/print · clamp ${MIN}–${MAX} · 1 shard ≈ $1`);
})();
