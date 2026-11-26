# Live schema inventory (project mpriuxbhdfgdtsfhvpxt)

Written from the live database, because the migrations in this folder do not
cover it: `public_profile`, `public_binder_cosmetics`, `unlock_expansion`,
`recycle_copies` and the whole market layer exist only in Supabase. If the
project is lost, this file is the map back. Keep it current when you ship SQL.

## Tables (18) — RLS on for every one

| table | policies | access |
|---|---|---|
| profiles | 3 | read/update own; insert own |
| wallets | 1 | select own only — writes via RPC |
| wallet_events | 1 | select own only |
| inventory | 1 | select own only |
| listings | 1 | `status='active' OR seller_id=auth.uid()` |
| cosmetic_items | 1 | catalogue read |
| cosmetic_owned | 1 | select own |
| notifications | 1 | select own |
| pack_claims | 1 | select own |
| trades_activity | 1 | select own |
| unlocks | 1 | select own |
| wishlist | 1 | select own |
| free_pack_bank, pack_plans, pool_buckets, recycle_rates, set_prices, wallet_caps | 0 | **deny-all by design** — read only through security-definer RPCs |

Every write path is a function, not a table grant. That is the right shape: keep
`INSERT`/`UPDATE` grants off these tables.

## Functions (35), `[def]` = SECURITY DEFINER

```
_bank_lock(p_uid uuid) [def]
_level_for_xp(p_xp bigint)
_pack_cap(p_level integer)
_pick(p_exp text, p_bucket text)
buy_listing(p_listing_id uuid) [def]
buy_pack_open(p_booster text) [def]
cancel_listing(p_listing_id uuid) [def]
claim_pack(p_expansion text, p_lang text, p_booster text) [def]
cosmetic_buy(p_item text) [def]
cosmetic_catalogue() [def]
ensure_wallet() [def]
expire_listings() [def]
free_pack_bank() [def]
leaderboard(p_limit integer) [def]
list_card(p_card_key text, p_qty integer, p_price bigint, p_lang text, p_finish text) [def]
listings_fill_expansion()
my_activity(p_limit integer) [def]
my_inventory() [def]
my_inventory_sets() [def]
notification_state() [def]
notify_wishlist(p_card_key text, p_lang text, p_price bigint, p_seller uuid) [def]
public_binder_cosmetics(p_user_id uuid) [def]
public_profile(p_user_id uuid) [def]
pullable_finishes(p_expansion text) [def]
recycle_copies(p_card_key text, p_qty integer, p_lang text, p_finish text) [def]
seller_names(p_ids uuid[]) [def]
trade_gate_ok(p_uid uuid) [def]
trade_gate_status() [def]
trade_ping() [def]
unlock_expansion(p_expansion text) [def]
wallet_balance() [def]
wallet_credit(p_amount bigint, p_reason text) [def]
wallet_import(p_amount bigint) [def]
wallet_spend(p_amount bigint, p_reason text) [def]
```

## Grants after hardening-2026-11.sql

- `wallet_import` — **service_role only** (was minting 5000 shards from a client value).
- Every other function — `authenticated` only. `anon` revoked everywhere it had
  access; note the revoke has to be `from public`, not `from anon`, because the
  default PUBLIC grant is what anon/authenticated inherit.
- `public_profile` / `public_binder_cosmetics` still need `anon` if shared
  profiles are meant to open without an account — verify before launch.

## Known open items

- `wallet_credit` still takes its reason from the client: quest 400, arena 300,
  atelier 200, daily_login 100, badge 100 = 1100/day mintable with no gameplay.
  The fix is one server-verified RPC per earn reason.
- No table DDL here — this is an inventory, not a dump. Take a real `pg_dump
  --schema-only` before opening the doors.
