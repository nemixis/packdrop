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

## The blocker: the server cannot draw a pack yet

The card pools and the slot/rarity weights live in `index.html` (a few hundred KB of JS). A server-side
draw needs them in Postgres:

1. `scripts/export-pools.js` → `pool_cards(expansion, card_key, bucket)` for every shipped pool.
2. Port the slot structure + bucket weights to `claim_pack` (one expansion first, then the rest).
3. Client: pack open calls the RPC, renders the returned cards; offline/signed-out pulls stay local and
   land as `source='legacy'` (untradeable).

Until step 3 exists, nothing is tradeable and no market UI ships — a board that lists unverifiable
cards teaches testers the numbers are fake.
