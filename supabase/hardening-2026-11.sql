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
-- Still open, deliberately: market_rpcs tables have no create policy in the repo.
