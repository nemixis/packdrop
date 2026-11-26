-- P0 hardening: close the client-mintable wallet paths.
--
-- Context: every public function carried the DEFAULT PUBLIC execute grant, which
-- `revoke ... from anon, authenticated` does NOT remove (the leading `=X` in a
-- proacl is PUBLIC itself). First attempt at this looked correct in the ACL and
-- changed nothing: a fresh account still minted 5000 shards. Revoke from PUBLIC.
--
--   * wallet_import(p_amount) minted up to 5000 shards, once per account, from a
--     number the client supplies. Sign up -> import -> buy the atelier. It existed
--     for the one-shot migration of pre-server saves, which is done: service_role
--     only now.
--   * wallet_credit(p_amount, p_reason) still takes its reason FROM THE CLIENT, so
--     'recycle' (5000/day) can be claimed without recycling anything. NOT fixed
--     here — it needs a server-verified earn path, one RPC per reason.

revoke execute on function public.wallet_import(bigint) from public, anon, authenticated;

revoke execute on function public.wallet_credit(bigint, text) from public, anon;
grant  execute on function public.wallet_credit(bigint, text) to authenticated;

revoke execute on function public.wallet_spend(bigint, text) from public, anon;
grant  execute on function public.wallet_spend(bigint, text) to authenticated;

revoke execute on function public.wallet_balance() from public, anon;
grant  execute on function public.wallet_balance() to authenticated;

revoke execute on function public.free_pack_bank() from public, anon;
grant  execute on function public.free_pack_bank() to authenticated;

revoke execute on function public.recycle_copies(text, integer, text, text) from public, anon;
grant  execute on function public.recycle_copies(text, integer, text, text) to authenticated;

revoke execute on function public.unlock_expansion(text) from public, anon;
grant  execute on function public.unlock_expansion(text) to authenticated;

-- Verify: wallet_import must show service_role only, the rest `authenticated`.
--   select proname, coalesce(array_to_string(proacl,' | '),'default')
--   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--   where n.nspname='public' and proname like 'wallet%';
--
-- ---------------------------------------------------------------------------
-- The reason table IS the mint surface.
--
-- wallet_credit will credit any reason that exists in wallet_caps, and the client
-- picks the reason. So a generous cap is a licence to mint: 'recycle' allowed
-- 5000/day and the UI never even calls it (recycle_copies credits internally),
-- which made it a pure faucet. Deleting the row closes it — verified: a fresh
-- account calling wallet_credit(500,'recycle') now gets 'unknown reason recycle'.
--
-- Every row left is a capability. Keep each cap at or below the real earn rate,
-- and never add a reason nothing actually earns: a test row 'level' (cap 300) was
-- added and immediately mintable for zero gameplay, then removed.
delete from public.wallet_caps where reason = 'recycle';

update public.wallet_caps
   set daily_cap = case reason
        when 'arena'   then 300
        when 'quest'   then 400
        when 'atelier' then 200
        else daily_cap end
 where reason in ('arena','quest','atelier');

-- Resulting surface: quest=400, arena=300, atelier=200, daily_login=100, badge=100
-- i.e. 1100/day mintable from the client, down from 8600.
--
-- Still open, deliberately: these five are still client-asserted. Server-side
-- verification is the real fix (one RPC per earn: arena checks a match record,
-- quest checks quest state). The caps bound the blast radius until then.
--
-- Still open: market_rpcs tables have no create policy in the repo.

-- ---------------------------------------------------------------------------
-- Playtest telemetry (write-only event log)
--
-- Same trap as the functions above, one level down: creating the table and its
-- INSERT policy is not enough — a new table has NO table-level grant, so the
-- first insert returned `401 permission denied for table telemetry_events`.
-- RLS decides which ROWS you may touch; GRANT decides whether you may touch the
-- table at all. Both are needed.
create table if not exists public.telemetry_events (
  id bigserial primary key,
  user_id uuid,
  anon_id text,
  kind text not null check (length(kind) <= 24),
  name text not null check (length(name) <= 64),
  meta jsonb,
  created_at timestamptz not null default now()
);
create index if not exists telemetry_events_created_idx on public.telemetry_events (created_at desc);
alter table public.telemetry_events enable row level security;
drop policy if exists telemetry_insert on public.telemetry_events;
create policy telemetry_insert on public.telemetry_events
  for insert to anon, authenticated with check (true);
grant insert on public.telemetry_events to anon, authenticated;
-- No select/update/delete grant: the log is write-only from the client.
-- Read it from the SQL editor or the dashboard.

-- ---------------------------------------------------------------------------
-- Playtest feedback (write-only, same shape as telemetry_events)
--
-- Telemetry answers "where a tester went"; this answers "why they gave up".
create table if not exists public.feedback (
  id bigserial primary key,
  user_id uuid,
  anon_id text,
  screen text check (length(screen) <= 40),
  message text not null check (length(message) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table public.feedback enable row level security;
drop policy if exists feedback_insert on public.feedback;
create policy feedback_insert on public.feedback for insert to anon, authenticated with check (true);
grant insert on public.feedback to anon, authenticated;
-- No select grant: read it from the SQL editor.

-- Continuity note that cannot be fixed from SQL: this repo has a MAP of the
-- schema, not a backup. Take a real dump / enable point-in-time recovery in the
-- dashboard before opening signups — a dropped project is unrecoverable from git.

-- ---------------------------------------------------------------------------
-- First server-verified earn: daily login.
--
-- The pattern for the rest. The client no longer asks to be paid — it asks to
-- claim, and the server decides whether it may:
--   claim 1 -> {"claimed": true, "amount": 100, "balance": 100}
--   claim 2 -> {"claimed": false, "reason": "already", "balance": 100}
-- and the old route is closed at the same time: wallet_credit(100,'daily_login')
-- now returns 'unknown reason daily_login', because the cap row is deleted.
--
-- Deleting the wallet_caps row is what makes this a real fix rather than a
-- parallel path: a verified RPC alongside a live mintable reason buys nothing.
create table if not exists public.daily_claims (
  user_id uuid primary key,
  claimed_on date not null,
  updated_at timestamptz not null default now()
);
alter table public.daily_claims enable row level security;  -- no policy: definer-only

create or replace function public.claim_daily_login()
returns jsonb language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_reward bigint := 100;
  v_bal bigint;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  update public.daily_claims set claimed_on = v_today, updated_at = now()
   where user_id = v_uid and claimed_on <> v_today;
  if not found then
    insert into public.daily_claims (user_id, claimed_on) values (v_uid, v_today)
    on conflict (user_id) do nothing;
    if not found then
      return jsonb_build_object('claimed', false, 'reason', 'already', 'balance', public.wallet_balance());
    end if;
  end if;
  if not exists (select 1 from public.wallets where user_id = v_uid) then
    insert into public.wallets (user_id, shards) values (v_uid, 0);
  end if;
  update public.wallets set shards = shards + v_reward, updated_at = now()
   where user_id = v_uid returning shards into v_bal;
  insert into public.wallet_events (user_id, delta, reason, balance_after)
  values (v_uid, v_reward, 'daily_login', v_bal);
  return jsonb_build_object('claimed', true, 'amount', v_reward, 'balance', v_bal);
end $f$;

revoke execute on function public.claim_daily_login() from public, anon;
grant  execute on function public.claim_daily_login() to authenticated;
delete from public.wallet_caps where reason = 'daily_login';

-- Still client-asserted (next to convert): quest 400, arena 300, atelier 200,
-- badge 100. Each needs the same shape — a record the server can check.

-- ---------------------------------------------------------------------------
-- Two reasons nobody honestly earns: delete them.
--
-- 'arena' (300/day): the arena has no tab in the UI (0 hits for data-tab="arena"),
--   so no player can reach it — but wallet_credit(300,'arena') was callable by any
--   account. "Not shipped yet" does not make an RPC harmless; it makes every credit
--   of it a pure faucet. Verified: now 'unknown reason arena'.
-- 'badge' (100/day): badges pay through 'quest' (the award loop calls
--   earnShards(b.shards,'quest')), so this row was never used by the game at all.
--   Verified: now 'unknown reason badge'.
--
-- RULE: a reason with no reachable UI, or whose payout happens under another
-- reason, is free money. Delete the row. When arena ships, do NOT re-add it —
-- build the verifying RPC first, the way claim_daily_login was done.
delete from public.wallet_caps where reason in ('arena','badge');

-- Mintable from the client after this pass: quest 400 + atelier 200 = 600/day,
-- down from 8600 at the start. Both are genuinely used and both are still
-- client-asserted: quests are client flags, crafting is a client RNG roll.
-- Without server-authoritative gameplay or a soft-currency split (declined), this
-- 600/day is the floor. It matters the day trading opens, not before.
