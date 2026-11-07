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

## Still to do

1. Client wiring: pack open calls `claim_pack`; offline/signed-out pulls stay local and land as
   `source='legacy'` (untradeable).
2. `ecl` pool rows (13 buckets, ~360 ids) — same shape, deferred until Magic is in scope.
3. Market screen: browse/filter/buy, list-from-card-sheet, wallet readout.

