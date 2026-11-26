-- P0 hardening: close the client-mintable wallet paths.
--
-- Context: every public function was granted to `anon`, and two of them let the
-- CALLER decide how many shards it got:
--   * wallet_import(p_amount) minted up to 5000 shards, once per account, from a
--     number the client supplies. Sign up -> import 5000 -> buy the atelier.
--     It existed for the one-shot migration of pre-server saves, which is done.
--   * wallet_credit(p_amount, p_reason) still takes its reason from the client,
--     so 'recycle' (5000/day) can be claimed without recycling anything.
--     That one is NOT fixed here — it needs a server-verified earn path.
--
-- Run order matters: revoke first, verify with the ACL query at the bottom.

revoke execute on function public.wallet_import(bigint) from anon, authenticated;
revoke execute on function public.wallet_credit(bigint, text) from anon;
revoke execute on function public.wallet_spend(bigint, text) from anon;
revoke execute on function public.wallet_balance() from anon;
revoke execute on function public.free_pack_bank() from anon;
revoke execute on function public.recycle_copies(text, integer, text, text) from anon;
revoke execute on function public.unlock_expansion(text) from anon;

-- Expected after: wallet_import has service_role only; the rest keep
-- authenticated (the game needs them) and lose anon.
-- create policy statements for market_rpcs tables still live only in the live DB.
