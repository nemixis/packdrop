-- Economy monitoring.
--
-- Three views over wallet_events. All of them are locked to postgres/service_role:
-- a view runs with its owner's privileges, so a grant to authenticated would leak
-- every player's rows past RLS. Verify with the ACL query at the bottom after any
-- change to them.
--
-- Read them from the SQL editor.

-- Daily mint vs sink for the whole economy.
--   minted  — shards created (earns: quest, atelier, recycle, daily_login)
--   burned  — shards destroyed (spends: packs, atelier buys, cosmetics, unlocks)
--   net     — the number that matters: sustained negative net means players are
--             draining savings, which is fine while reserves are deep and fatal
--             once they are not.
create or replace view public.economy_daily as
select (e.at at time zone 'utc')::date as day,
       sum(case when e.delta > 0 then e.delta else 0 end) as minted,
       sum(case when e.delta < 0 then -e.delta else 0 end) as burned,
       sum(e.delta) as net,
       count(*) as events,
       count(distinct e.user_id) as players
from public.wallet_events e
group by 1;

-- Which faucets and sinks actually move. A reason whose share of mint is large
-- while its cap is client-asserted is the one to verify next.
create or replace view public.economy_reason_daily as
select (e.at at time zone 'utc')::date as day,
       e.reason,
       sum(case when e.delta > 0 then e.delta else 0 end) as minted,
       sum(case when e.delta < 0 then -e.delta else 0 end) as burned,
       count(*) as events
from public.wallet_events e
group by 1, 2;

-- One row per player-day that minted 500+. With the caps as they stand, an honest
-- account cannot exceed 600/day, so anything at the top of this list is either a
-- whale of legitimate play or the exploit being exercised.
create or replace view public.economy_outliers as
select e.user_id,
       (e.at at time zone 'utc')::date as day,
       sum(e.delta) as minted,
       count(*) as events
from public.wallet_events e
where e.delta > 0
group by 1, 2
having sum(e.delta) >= 500;

revoke all on public.economy_daily        from public, anon, authenticated;
revoke all on public.economy_reason_daily from public, anon, authenticated;
revoke all on public.economy_outliers     from public, anon, authenticated;

-- Sanity queries
--   select * from economy_daily order by day desc limit 14;
--   select reason, sum(minted) as minted, sum(burned) as burned
--     from economy_reason_daily group by 1 order by minted desc;
--   select * from economy_outliers order by day desc, minted desc limit 20;
--
-- Verify the views did not leak:
--   select c.relname, coalesce(array_to_string(c.relacl,' | '),'NO GRANTS')
--   from pg_class c join pg_namespace n on n.oid=c.relnamespace
--   where n.nspname='public' and c.relname like 'economy%';
-- Expected: postgres and service_role only.
