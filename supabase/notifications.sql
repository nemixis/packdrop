-- ---------- notifications ----------
-- One row per thing that happened to a player: a wishlist card hitting the
-- market, a sale, a purchase. The row stores structured fields rather than a
-- sentence so the client can render it in the player's own language.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null,               -- wish_listed | sold | bought
  card_key text,
  lang text,
  finish text,
  listing_id uuid,
  price bigint,
  fee bigint,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notif_user_idx on public.notifications(user_id, is_read, created_at desc);

alter table public.notifications enable row level security;
drop policy if exists notif_own on public.notifications;
create policy notif_own on public.notifications for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
grant select, insert, update, delete on public.notifications to authenticated;

-- Everyone who wishlisted this exact print, except the seller, gets told it
-- just appeared. Deduped per (user, card, language) so a card re-listed five
-- times does not produce five rows.
create or replace function public.notify_wishlist(p_card_key text, p_lang text, p_price bigint, p_seller uuid)
returns void language plpgsql security definer set search_path = 'public' as $f$
begin
  insert into public.notifications (user_id, kind, card_key, lang, price)
  select w.user_id, 'wish_listed', p_card_key, p_lang, p_price
  from public.wishlist w
  where w.card_key = p_card_key
    and w.lang = p_lang
    and w.user_id <> p_seller
    and not exists (
      select 1 from public.notifications n
      where n.user_id = w.user_id and n.kind = 'wish_listed'
        and n.card_key = p_card_key and n.lang = p_lang
    );
end
$f$;

-- Bell badge state. Deliberately tiny: the client polls this rather than
-- pulling the whole feed every few seconds.
create or replace function public.notification_state()
returns jsonb language plpgsql stable security definer set search_path = 'public' as $f$
declare v_uid uuid := auth.uid(); r jsonb;
begin
  if v_uid is null then return null; end if;
  select jsonb_build_object(
    'unread', count(*) filter (where not is_read),
    'latest', max(created_at)
  ) into r from public.notifications where user_id = v_uid;
  return r;
end
$f$;
grant execute on function public.notification_state() to anon, authenticated;

-- list: a wish that just appeared on the board.
create or replace function public.list_card(p_card_key text, p_qty integer, p_price bigint, p_lang text, p_finish text)
returns uuid language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_have integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.trade_gate_ok(v_uid) then raise exception 'trading locked: open 20 packs first'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 10 then raise exception 'qty must be 1..10'; end if;
  if p_price is null or p_price < 1 or p_price > 100000 then raise exception 'price out of range'; end if;

  perform public.expire_listings();

  -- Only claimed packs are tradeable, and the units leave the binder here.
  select qty into v_have from public.inventory
   where user_id = v_uid and card_key = p_card_key and lang = p_lang
     and finish = p_finish and source = 'claimed';
  if coalesce(v_have,0) < p_qty then raise exception 'not enough tradeable copies'; end if;

  update public.inventory set qty = qty - p_qty
   where user_id = v_uid and card_key = p_card_key and lang = p_lang and finish = p_finish;

  insert into public.listings (seller_id, card_key, lang, finish, qty, price)
  values (v_uid, p_card_key, p_lang, p_finish, p_qty, p_price)
  returning id into v_id;

  insert into public.trades_activity (kind, listing_id, seller_id, card_key, lang, finish, qty, price)
  values ('listed', v_id, v_uid, p_card_key, p_lang, p_finish, p_qty, p_price);

  perform public.notify_wishlist(p_card_key, p_lang, p_price, v_uid);

  return v_id;
end
$f$;
grant execute on function public.list_card(text, integer, bigint, text, text) to authenticated;

-- buy: tell both sides. The seller learns the sale, the buyer learns the purchase.
create or replace function public.buy_listing(p_listing_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  l public.listings;
  v_bal bigint;
  v_fee bigint;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select * into l from public.listings where id = p_listing_id for update;
  if not found then raise exception 'listing not found'; end if;
  if l.status <> 'active' then raise exception 'listing is %', l.status; end if;
  if l.expires_at < now() then
    perform public.expire_listings();
    raise exception 'listing expired';
  end if;
  if l.seller_id = v_uid then raise exception 'cannot buy your own listing'; end if;

  v_fee := floor(l.price * 0.05);

  select shards into v_bal from public.wallets where user_id = v_uid for update;
  if coalesce(v_bal,0) < l.price then raise exception 'not enough shards'; end if;

  update public.wallets set shards = shards - l.price, updated_at = now() where user_id = v_uid;
  update public.wallets set shards = shards + (l.price - v_fee), updated_at = now() where user_id = l.seller_id;

  update public.listings set status = 'sold' where id = l.id;

  insert into public.inventory (user_id, card_key, lang, finish, qty, source)
  values (v_uid, l.card_key, l.lang, l.finish, l.qty, 'purchase')
  on conflict (user_id, card_key, lang, finish) do update set qty = inventory.qty + l.qty;

  insert into public.trades_activity (kind, listing_id, buyer_id, seller_id, card_key, lang, finish, qty, price, fee)
  values ('sold', l.id, v_uid, l.seller_id, l.card_key, l.lang, l.finish, l.qty, l.price, v_fee);

  insert into public.notifications (user_id, kind, card_key, lang, finish, listing_id, price, fee)
  values (l.seller_id, 'sold', l.card_key, l.lang, l.finish, l.id, l.price, v_fee);
  insert into public.notifications (user_id, kind, card_key, lang, finish, listing_id, price, fee)
  values (v_uid, 'bought', l.card_key, l.lang, l.finish, l.id, l.price, 0);

  return jsonb_build_object('ok', true, 'paid', l.price, 'fee', v_fee, 'card_key', l.card_key);
end
$f$;
grant execute on function public.buy_listing(uuid) to authenticated;
