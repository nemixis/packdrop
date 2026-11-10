# Market v1 — server-owned wallet, inventory, listings

Status: **schema live** on project `mpriuxbhdfgdtsfhvpxt`. No client can write to any of it.

## Why

`public.profiles(id, profile jsonb)` is written by the client (policies: insert/update own row), so a
forged save can mint cards and shards. A listing board on top of that is cosmetic. The market needs
the server to know what a player owns, which means pulls have to be issued by the server.

## Tables (all RLS on, `SELECT` only for `authenticated`)

| table | purpose |
|---|---|
| `wallets(user_id pk, shards, updated_at)` | server-owned balance. Created by trigger for every new `auth.users` row |
| `inventory(user_id, card_key, lang, finish, qty, source)` | what the server says you own. `source ∈ claimed / legacy / purchase`; only `claimed` is tradeable |
| `pack_claims(id, user_id, expansion, seed, cards jsonb, drawn_at)` | one row per pack the server issued — the receipt |
| `listings(id, seller_id, card_key, lang, finish, qty, price, status, created_at, expires_at)` | the board. 7-day expiry, price 1..100000 |
| `trades_activity(...)` | append-only log of list/sell/cancel, for reputation and disputes |

Policies: wallets/inventory/claims/activity → own rows only. Listings → `status='active'` **or** your
own rows, because the board is public to signed-in players.

`revoke all ... from anon, authenticated` + `grant select` afterwards: even if a write policy is added
by mistake later, the role still cannot write.

## Verified (cheat test, 2026-11-07)

`has_table_privilege('authenticated', …)` on all five tables:

```
inventory      select=t insert=f update=f delete=f  rls=t
listings       select=t insert=f update=f delete=f  rls=t
pack_claims    select=t insert=f update=f delete=f  rls=t
trades_activity select=t insert=f update=f delete=f rls=t
wallets        select=t insert=f update=f delete=f  rls=t
profiles       select=t insert=t update=t delete=t   <- still client-writable, by design (save blob)
```

3 users / 3 wallets after backfill.

## RPCs (next)

All `SECURITY DEFINER`, `set search_path = public`, no direct table grants.

- `claim_pack(expansion)` → draws server-side, inserts `pack_claims`, adds `inventory` rows with
  `source='claimed'`.
- `list_card(card_key, lang, finish, qty, price)` → moves units from `inventory` into `listings`,
  enforces the gate and the daily cap.
- `buy_listing(listing_id)` → one transaction: debit buyer wallet, credit seller minus 5% fee, move
  inventory, flip listing to `sold`, log activity.
- `cancel_listing(listing_id)` → units back to inventory.
- `withdraw()` → optional, shelf back to inventory.

Gate: `count(pack_claims) >= 20` for the account. Listing cap: 20/day.

## RPCs — live for `cel`

All `SECURITY DEFINER`, `set search_path = public`, no direct table grants. Source of truth:
`supabase/market_rpcs.sql` in the repo.

| function | what it does |
|---|---|
| `claim_pack(expansion, lang)` | draws 5 cards against `pool_buckets`, writes `pack_claims` + `inventory(source='claimed')`, returns `{claim_id, cards[]}` |
| `list_card(card_key, qty, price, lang, finish)` | gate check, daily cap, inventory → `listings`, logs `listed` |
| `cancel_listing(id)` | units back to inventory, logs `cancelled` |
| `buy_listing(id)` | one transaction: debit buyer, credit seller −5%, transfer inventory as `purchase`, listing → `sold`, log |

`pool_buckets(expansion, bucket, cards jsonb)` holds the card ids per rarity bucket (9 rows for `cel`).
`_pick(exp, bucket)` is a volatile SQL helper — **must not be `stable`**, or `random()` is resolved
once per statement and every slot returns the same card.

### Measured draw rates (301 server-side packs, 30th Celebration)

| slot | result | published |
|---|---|---|
| 1-2 | common 100% | common |
| 3 | common 67.8% · IR 22.6% · classic 9.6% | 70 / 20 / 10 |
| 4 | rare 72.4% · double 20.9% · SIR 5.3% · futuristic 1.3% | remainder / 21.02 / 4.88 / 0.83 |
| 5 | Pikachu Rare 100% | guaranteed |

5 cards/pack, 171 of 191 ids seen in 301 packs (rgbRare is 1-in-4000 by design).

### End-to-end trade, verified

Seller opened 25 packs → gate open → listed `30th-001` at 100 → buyer bought:
buyer 1000 → **900**, seller 0 → **95** (100 − 5 fee), inventory shows `source='purchase'`,
activity logged `listed` + `sold` with `fee=5`. Test rows and the `zz_*` helpers were deleted afterwards.

## Traps found while building this

- **`gen_random_bytes` is not on `search_path=public`.** pgcrypto lives in `extensions`; with
  `set search_path = public` the call fails. Use `gen_random_uuid()::text` for seeds.
- **`on conflict do update` cannot touch the same row twice in one statement.** A pack can contain
  two copies of one card, so the inventory insert must aggregate first
  (`group by card_key, lang, finish`) and add `excluded.qty`.
- **The connector's migration endpoint rejects some valid SQL** (it failed on a multi-row upsert);
  `BETA_RUN_SQL_QUERY` runs the same statements fine, including several per call.
- **A failed function call came back as `TOOL_NOT_FOUND`**, not as a Postgres error. When a query
  "does not exist", test the same body in a `do` block and read the real exception.

## Client wiring — done for `cel`

`acquirePull()` in `index.html` replaces the synchronous `generatePack()` at pack tap:

- signed in **and** the expansion is in `SERVER_PULL_EXPANSIONS` → `sb.rpc('claim_pack')`, render the
  returned cards. Server cards skip the speculative language re-roll (`serverClaim`) because the RPC
  already fixed the language and the inventory recorded it.
- otherwise (signed out, offline, RPC error) → the local generator, and every slot is stamped
  `pullSource='legacy'`.
- `addToCollection()` increments `entry.claimedCount` for `claimed` pulls, so the trade UI can tell
  tradeable copies from legacy ones without a second source of truth.

Verified on the deployed build: signed-in pull → DB `pack_claims` +1, inventory 15 cards across 3
packs, profile save shows `claimedCount` on all 5 entries; signed-out pull → 5 cards rendered, 0
claimed, no claim row written; `claim_pack('ecl')` rejected with a clear message; `p_lang='fr'`
returned 5 French cards.

## Shard parity — server wallet authoritative

While signed in, `wallets.shards` is the only balance that counts and the client mirrors it:

| function | rule |
|---|---|
| `wallet_import(amount)` | one-time adoption of a device's existing balance, capped at 5000; second call is a no-op |
| `wallet_credit(amount, reason)` | earnings, capped per reason per day (`wallet_caps`), max 500 per call |
| `wallet_spend(amount, reason)` | the only way to spend; fails on insufficient balance |
| `recycle_copies(card_key, qty, lang, finish)` | melts claimed copies, pays the server-side `recycle_rates` |

Client: `walletSpend` gates unlocks and pack purchases, `earnShards` pays daily login / quests / level
rewards / arena / atelier through the server, and `walletSync` runs on sign-in.

Recycling is **per variant**. `claimedVariants['<finish>|<lang>']` is written at commit time (the same
key shape as the server's inventory rows), `takeExtraCopies` records which variants it drained in
`entry._lastDrain`, and each drained variant calls `recycle_copies` with its own lang/finish. If the
server has no row for that print — a legacy copy — **the copy is restored** rather than melted for
nothing, because removing a card the server never agreed to remove is exactly how two balances drift.

Verified: a French pack's card melts as `fr` (+1 shard), and the same card as `en` is refused with
`no such claimed copies`; client boots clean on the deployed build.

Verified with a throwaway account: import 500 → 500, second import ignored; spend 120 → 380; credit
50 → 430; spend 99999 refused; recycle a claimed common → +1 shard, repeating it returns
`no such claimed copies` (no infinite button).

## The Exchange (market screen)

New tab between Binder and Mint. `renderExchange()` reads `listings` (active only, 400 cap), joins
each row to `allCardsFlat` for art and name, and renders a gallery with language/finish/quantity
chips, the price, and a hover-revealed **Buy** that is disabled above the player's balance. Filtering
is by set chip, name search (multilingual index) and three sort orders. Own listings appear in a
"Your listings" list with **Cancel** instead of Buy. Signed out, the screen explains that the market
needs an account instead of showing an empty shelf.

Buy → confirm → `buy_listing` → mirror the returned balance → reload. Fee is `ceil(price*5%)`,
capped at the price, so a 9-shard sale still pays a 1-shard fee instead of 0.

Verified through the UI: a 9 ◆ listing bought for 591 → 591−9, shelf 10 → 9 rows, buyer inventory
+1 `purchase`, seller credited 8, `trades_activity` logged `sold` with the fee.

## Hardening: config tables need RLS too

Supabase's linter flagged `public.wallet_caps`: RLS disabled **and** the default grants left
`anon`/`authenticated` with `SELECT`, `INSERT` and `UPDATE` on it. That table holds the daily earning
caps, so a client could have rewritten its own limits (e.g. atelier → 1,000,000) and then drained
`wallet_credit` every day. Config is still data.

Fixed:

```sql
alter table public.wallet_caps enable row level security;
revoke all on public.wallet_caps from anon, authenticated;
revoke insert, update, delete on public.profiles from anon;
-- new tables in public are not exposed by default any more
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
```

Deliberate: **no policy** on `wallet_caps` / `pool_buckets` / `recycle_rates`. They are server-only
tables; `SECURITY DEFINER` functions read them as the owner, which bypasses RLS, so the caps still
apply while the client sees nothing.

Verified after the change: anon `GET wallet_caps` → 401 `42501`, anon `PATCH` → refused, signed-in
`GET` → 403, while `wallet_credit(50,'quest')` still works through the definer path (0 → 50, then
550 under the 600/day cap).

Rule of thumb: a table is only "safe" when it has RLS **and** the roles have no privilege beyond what
the policies allow. Enabling RLS without revoking leaves `402`-shaped holes where a future policy
mistake becomes a write.

## Playtest fixes: recycle + French art

**"Recycling works sometimes."** The signed-in melt drained the most-stacked *version* of a card, which
could be a legacy one. `recycle_copies` refused it (no server row), the copy was restored, and the UI
said nothing — indistinguishable from a dead button. `takeExtraCopies(entry, n, onlyKeys)` now takes
an eligibility set built from `claimedVariants`, so it can only remove versions the server issued; the
bulk path counts only eligible extras, and returns `skipped` so the overlay can say
"those duplicates predate the market" instead of failing silently. `hydrateClaims()` also runs on
login now, not just on boot.

**"French booster, English cards in the collection."** `resolvePackLanguages` returned early for server
pulls to protect their language, but that also skipped *art* resolution, so the binder fell back to the
English scan. Resolvers take an explicit language now, and a server pull resolves art for its own
`lang` without touching it.

Verified: a signed-out FR pack stores `langBreakdown {fr:1}` and `langImages.fr` pointing at the TCGdex
French asset; signed-in pulls store `claimedCount` and `claimedVariants {'normal|en': n}` per card.

## One-off: bring the whole cohort onto the server

Two passes over every `profiles.profile->'collection'`, expanded per version (`variantCounts` →
`finish|lang`) and written as `claimed`:

1. **Set** inventory to the save's quantity minus anything currently escrowed in an active listing.
2. **Gap fill** per card: where the save's `count` still exceeded the summed inventory (older saves
   drift ahead of their version buckets), the difference went into that card's largest version.

Result: anthony 164 prints / 165 cards · bastdup 302 / 717 · mboujbir 66 / 70 · risotto 216 / 256.
Every copy is `source='claimed'`, so all of it can be recycled, listed and bought. The surplus over a
save (bastdup +53) is packs opened after that profile was last written.

`hydrateClaims()` now also **adopts cards the binder has no entry for** — otherwise a card the server
owns but the save never saw would be invisible and unsellable while still counting toward the wallet.

**Do not re-run this after launch.** It trusts the client save; run again once anyone can write a save
and you have a mint. The correct long-term path is `pack_claims` only, which is already what new pulls
use.

## Still to do

**Trading**
1. **Magic sets** — `ecl` (Lorwyn Eclipsed), `ff` (Final Fantasy), `eoe` (Edge of Eternities) and
   `spm` (Marvel's Spider-Man) are ported: `pool_buckets` + `pack_plans` for both play and collector,
   `claim_pack` walks the plan. `spm` is the only set that draws from a second product: its Marvel
   Source Material cards come from the Marvel Universe pool and are imported as a bucket of `spm`.
   `ff` is the largest port (29 buckets, 1192 ids: main tiers, the Through the Ages bonus sheet, the
   Commander pool's obtainable subset, tokens and art cards); `eoe` adds the Stellar Sights sheet,
   galaxy foils and Special Guests. Still unported: `tla` — it refuses with "not open on the server
   yet" and its Exchange cards are not tradeable.
2. **Seller feedback** — a sale moves shards silently. `wallet_events` has the rows; nothing surfaces
   them. Needs a "sold" notice and a short ledger on the Exchange.
3. **Price suggestion from the feed** — the list sheet prefills `card.price`; the shipped TCGplayer
   feeds are the better anchor, and they already exist in the client.
4. **Shelf depth** — the screen loads 400 listings and filters by set/search/sort only. No rarity or
   language filter, no paging, and expired listings are only marked when someone tries to buy one
   (needs a sweep).
5. **Gate calibration** — 20 packs for a new account is a few days of daily opens. Fine for launch,
   slow for the current three testers (they pass via `migrated_at`).

**Client**
6. **Legacy messaging** — signed-in players cannot recycle pre-market copies, and nothing explains
   why. One line in the recycle sheet, or an offer to convert the rest of the cohort like the three
   testers got.

**Parked by decision**
7. **Shareable profiles** — designed (`packdrop-economy` §6), gated behind the claims layer, which now
   exists.
