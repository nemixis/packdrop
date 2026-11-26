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
