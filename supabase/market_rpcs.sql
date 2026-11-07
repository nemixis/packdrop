-- pick one card id from a bucket (volatile: random() must re-evaluate per call)
create or replace function public._pick(p_exp text, p_bucket text) returns text
language sql volatile as $f$
  select b.cards -> (floor(random() * jsonb_array_length(b.cards))::int) #>> '{}'
  from public.pool_buckets b
  where b.expansion = p_exp and b.bucket = p_bucket;
$f$;

create or replace function public.claim_pack(p_expansion text, p_lang text default 'en')
returns jsonb
language plpgsql
security definer
set search_path = public
as $f$
declare
  v_uid uuid := auth.uid();
  v_cards jsonb := '[]'::jsonb;
  v_r double precision;
  v_id text;
  v_bucket text;
  v_claim uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_expansion <> 'cel' then raise exception 'expansion % not tradeable yet', p_expansion; end if;
  if p_lang is null or p_lang not in ('en','fr','de','es','it','pt','ja') then p_lang := 'en'; end if;

  -- slots 1-2: commons
  for i in 1..2 loop
    v_id := public._pick('cel','common');
    v_cards := v_cards || jsonb_build_array(jsonb_build_object('card_key',v_id,'bucket','common','finish','normal','lang',p_lang));
  end loop;

  -- slot 3: common 70% / illustration rare 20% / classic collection 10%
  v_r := random();
  v_bucket := case when v_r < 0.70 then 'common'
                   when v_r < 0.90 then 'illustrationRare'
                   else 'classicCollection' end;
  v_id := public._pick('cel', v_bucket);
  v_cards := v_cards || jsonb_build_array(jsonb_build_object('card_key',v_id,'bucket',v_bucket,'finish','normal','lang',p_lang));

  -- slot 4: published rates
  v_r := random();
  v_bucket := case when v_r < 0.2102 then 'doubleRare'
                   when v_r < 0.2590 then 'specialIllustrationRare'
                   when v_r < 0.2673 then 'futuristicRare'
                   when v_r < 0.26755 then 'rgbRare'
                   else 'rare' end;
  v_id := public._pick('cel', v_bucket);
  v_cards := v_cards || jsonb_build_array(jsonb_build_object('card_key',v_id,'bucket',v_bucket,'finish','normal','lang',p_lang));

  -- slot 5: guaranteed Pikachu Rare
  v_id := public._pick('cel','pikachuRare');
  v_cards := v_cards || jsonb_build_array(jsonb_build_object('card_key',v_id,'bucket','pikachuRare','finish','normal','lang',p_lang));

  insert into public.pack_claims (user_id, expansion, seed, cards)
  values (v_uid, p_expansion, encode(gen_random_bytes(16),'hex'), v_cards)
  returning id into v_claim;

  insert into public.inventory (user_id, card_key, lang, finish, qty, source)
  select v_uid, c->>'card_key', c->>'lang', coalesce(c->>'finish','normal'), 1, 'claimed'
  from jsonb_array_elements(v_cards) c
  on conflict (user_id, card_key, lang, finish) do update set qty = inventory.qty + 1;

  return jsonb_build_object('claim_id', v_claim, 'cards', v_cards);
end
$f$;

-- activity gate: 20 server-issued packs before you can trade
create or replace function public.trade_gate_ok(p_uid uuid) returns boolean
language sql stable security definer set search_path = public as $f$
  select (select count(*) from public.pack_claims where user_id = p_uid) >= 20;
$f$;

create or replace function public.list_card(p_card_key text, p_qty integer, p_price bigint,
                                            p_lang text default 'en', p_finish text default 'normal')
returns uuid
language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  v_have integer;
  v_today integer;
  v_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.trade_gate_ok(v_uid) then raise exception 'trading locked: open 20 packs first'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 10 then raise exception 'qty must be 1..10'; end if;
  if p_price is null or p_price < 1 or p_price > 100000 then raise exception 'price out of range'; end if;

  select count(*) into v_today from public.listings
   where seller_id = v_uid and created_at > now() - interval '1 day';
  if v_today >= 20 then raise exception 'daily listing cap reached'; end if;

  select qty into v_have from public.inventory
   where user_id = v_uid and card_key = p_card_key and lang = p_lang and finish = p_finish and source = 'claimed';
  if coalesce(v_have,0) < p_qty then raise exception 'not enough tradeable copies'; end if;

  update public.inventory set qty = qty - p_qty
   where user_id = v_uid and card_key = p_card_key and lang = p_lang and finish = p_finish;

  insert into public.listings (seller_id, card_key, lang, finish, qty, price)
  values (v_uid, p_card_key, p_lang, p_finish, p_qty, p_price)
  returning id into v_id;

  insert into public.trades_activity (kind, listing_id, seller_id, card_key, lang, finish, qty, price)
  values ('listed', v_id, v_uid, p_card_key, p_lang, p_finish, p_qty, p_price);

  return v_id;
end
$f$;

create or replace function public.cancel_listing(p_listing_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  l public.listings;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select * into l from public.listings where id = p_listing_id for update;
  if not found then raise exception 'listing not found'; end if;
  if l.seller_id <> v_uid then raise exception 'not your listing'; end if;
  if l.status <> 'active' then raise exception 'listing is %', l.status; end if;

  update public.listings set status = 'cancelled' where id = p_listing_id;
  insert into public.inventory (user_id, card_key, lang, finish, qty, source)
  values (v_uid, l.card_key, l.lang, l.finish, l.qty, 'claimed')
  on conflict (user_id, card_key, lang, finish) do update set qty = inventory.qty + l.qty;

  insert into public.trades_activity (kind, listing_id, seller_id, card_key, lang, finish, qty, price)
  values ('cancelled', l.id, v_uid, l.card_key, l.lang, l.finish, l.qty, l.price);

  return jsonb_build_object('ok', true);
end
$f$;

-- buy: debit, credit, transfer, all in one transaction. 5% fee, sunk.
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
    update public.listings set status = 'expired' where id = l.id;
    raise exception 'listing expired';
  end if;
  if l.seller_id = v_uid then raise exception 'cannot buy your own listing'; end if;

  v_fee := floor(l.price * 0.05);

  select shards into v_bal from public.wallets where user_id = v_uid for update;
  if coalesce(v_bal,0) < l.price then raise exception 'not enough shards'; end if;

  update public.wallets set shards = shards - l.price, updated_at = now() where user_id = v_uid;
  update public.wallets set shards = shards + (l.price - v_fee), updated_at = now() where user_id = l.seller_id;
  if not found then
    insert into public.wallets (user_id, shards) values (l.seller_id, l.price - v_fee);
  end if;

  update public.listings set status = 'sold' where id = l.id;

  insert into public.inventory (user_id, card_key, lang, finish, qty, source)
  values (v_uid, l.card_key, l.lang, l.finish, l.qty, 'purchase')
  on conflict (user_id, card_key, lang, finish) do update set qty = inventory.qty + l.qty;

  insert into public.trades_activity (kind, listing_id, buyer_id, seller_id, card_key, lang, finish, qty, price, fee)
  values ('sold', l.id, v_uid, l.seller_id, l.card_key, l.lang, l.finish, l.qty, l.price, v_fee);

  return jsonb_build_object('ok', true, 'paid', l.price, 'fee', v_fee, 'card_key', l.card_key);
end
$f$;

grant execute on function public.claim_pack(text, text) to authenticated;
grant execute on function public.list_card(text, integer, bigint, text, text) to authenticated;
grant execute on function public.cancel_listing(uuid) to authenticated;
grant execute on function public.buy_listing(uuid) to authenticated;
