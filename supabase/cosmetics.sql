-- ============================================================================
-- The Atelier — personalisation store
--
-- Cosmetics are bought with shards and applied to the public profile and to
-- binders. Ownership is server truth; the equipped choice lives in the
-- player's profile snapshot (profiles.profile), which is what the public
-- profile already reads. The client never states a price.
-- ============================================================================

create table if not exists public.cosmetic_items (
  id        text primary key,
  kind      text not null check (kind in ('profile','binder')),
  slot      text not null,                   -- frame | banner | name | cover | theme
  name_en   text not null,
  name_fr   text not null,
  blurb_en  text not null default '',
  blurb_fr  text not null default '',
  price     integer not null check (price > 0),
  payload   jsonb not null default '{}'::jsonb,
  sort      integer not null default 0,
  active    boolean not null default true
);

create table if not exists public.cosmetic_owned (
  user_id     uuid not null references auth.users(id) on delete cascade,
  item_id     text not null references public.cosmetic_items(id) on delete cascade,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

alter table public.cosmetic_items enable row level security;
alter table public.cosmetic_owned enable row level security;

drop policy if exists "cosmetics readable by all" on public.cosmetic_items;
create policy "cosmetics readable by all"
  on public.cosmetic_items for select using (true);

drop policy if exists "own cosmetics readable" on public.cosmetic_owned;
create policy "own cosmetics readable"
  on public.cosmetic_owned for select using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Catalogue. Prices sit against real shard income (dupes + level milestones),
-- so the cheapest cosmetic is a couple of dupes and the best is a project.
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items (id, kind, slot, name_en, name_fr, blurb_en, blurb_fr, price, payload, sort) values
  ('frame_gold',    'profile','frame', 'Gilded Frame',      'Cadre Doré',        'A thin gold ring that catches the light.',        'Un fin anneau doré qui accroche la lumière.',      400, '{"ring":"linear-gradient(140deg,#f7e7a8,#d4a63a 45%,#8a6420)"}', 10),
  ('frame_ember',   'profile','frame', 'Ember Frame',       'Cadre Braise',      'Warm ember light around your avatar.',            'Une lueur de braise autour de votre avatar.',      600, '{"ring":"linear-gradient(140deg,#ffd08a,#ff7a2e 50%,#8c2f00)"}', 20),
  ('frame_holo',    'profile','frame', 'Holo Frame',        'Cadre Holo',        'Full holographic ring — the showpiece.',          'Anneau holographique complet — la pièce maîtresse.',900,'{"ring":"conic-gradient(from 140deg,#8ef0ff,#b08bff,#ff9ad5,#ffe08a,#8ef0ff)","holo":true}', 30),
  ('banner_nebula', 'profile','banner','Nebula Banner',     'Bannière Nébuleuse','A violet starfield behind your name.',            'Un champ d’étoiles violet derrière votre nom.',    750, '{"bg":"radial-gradient(120% 130% at 20% 0%, #3a2a6b 0%, #1a1630 55%, #0b0b16 100%)"}', 40),
  ('banner_dusk',   'profile','banner','Ember Dusk Banner', 'Bannière Crépuscule','Low amber horizon, fading to black.',            'Un horizon ambré qui se fond dans le noir.',       550, '{"bg":"linear-gradient(180deg,#4a2313 0%,#241109 45%,#0b0b16 100%)"}', 50),
  ('name_gold',     'profile','name',  'Gold Name',         'Nom Doré',          'Your handle in struck gold.',                     'Votre pseudo en or frappé.',                       300, '{"color":"#f3cf7a"}', 60),
  ('name_crystal',  'profile','name',  'Crystal Name',      'Nom Cristal',       'Your handle in crystal.',                         'Votre pseudo en cristal.',                         300, '{"color":"#8ef0ff"}', 70),
  ('cover_onyx',    'binder', 'cover', 'Onyx Cover',        'Couverture Onyx',   'Matte black grain, blind-embossed.',              'Grain noir mat, gaufrage à l’aveugle.',            500, '{"cover":"linear-gradient(160deg,#242430,#101018 60%,#08080c)"}', 80),
  ('cover_holo',    'binder', 'cover', 'Holo Cover',        'Couverture Holo',   'Foil that shifts as it turns.',                   'Un foil qui change selon l’angle.',                950, '{"cover":"linear-gradient(150deg,#8ef0ff,#b08bff 35%,#ff9ad5 65%,#ffe08a)","holo":true}', 90),
  ('theme_night',   'binder', 'theme', 'Night Shelf',       'Étagère Nuit',      'A cool, deep shelf for your pages.',              'Une étagère profonde et froide pour vos pages.',   650, '{"bg":"linear-gradient(180deg,#141a2c,#0a0c14)"}', 100),
  ('theme_parchment','binder','theme', 'Parchment Shelf',   'Étagère Parchemin', 'Warm paper behind the pages.',                    'Un papier chaud derrière les pages.',              650, '{"bg":"linear-gradient(180deg,#2a2118,#14100c)"}', 110)
on conflict (id) do update set
  kind = excluded.kind, slot = excluded.slot,
  name_en = excluded.name_en, name_fr = excluded.name_fr,
  blurb_en = excluded.blurb_en, blurb_fr = excluded.blurb_fr,
  price = excluded.price, payload = excluded.payload, sort = excluded.sort, active = true;

-- ---------------------------------------------------------------------------
-- Buy. Price comes from the table, the wallet is debited in the same
-- statement, and a repeat purchase is a no-op rather than a second charge.
-- ---------------------------------------------------------------------------
create or replace function public.cosmetic_buy(p_item text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $f$
declare
  v_uid     uuid := auth.uid();
  v_price   integer;
  v_owned   boolean;
  v_bal     bigint;
  v_kind    text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select price, kind into v_price, v_kind
    from public.cosmetic_items
   where id = p_item and active
   limit 1;
  if v_price is null then raise exception 'unknown item: %', p_item; end if;

  select exists(select 1 from public.cosmetic_owned where user_id = v_uid and item_id = p_item)
    into v_owned;
  if v_owned then
    select shards into v_bal from public.wallets where user_id = v_uid;
    return jsonb_build_object('ok', true, 'already_owned', true, 'balance', coalesce(v_bal,0));
  end if;

  update public.wallets
     set shards = shards - v_price, updated_at = now()
   where user_id = v_uid and shards >= v_price
   returning shards into v_bal;

  if v_bal is null then
    raise exception 'insufficient shards';
  end if;

  insert into public.cosmetic_owned (user_id, item_id) values (v_uid, p_item);

  insert into public.wallet_events (user_id, delta, reason, balance_after)
  values (v_uid, -v_price, 'cosmetic:' || p_item, v_bal);

  return jsonb_build_object('ok', true, 'already_owned', false, 'balance', v_bal, 'kind', v_kind);
end
$f$;

grant execute on function public.cosmetic_buy(text) to authenticated;

-- Catalog + what this player owns, in one round trip for the store screen.
create or replace function public.cosmetic_catalogue()
returns jsonb
language sql
stable
security definer
set search_path = public
as $f$
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'kind', i.kind, 'slot', i.slot,
        'name_en', i.name_en, 'name_fr', i.name_fr,
        'blurb_en', i.blurb_en, 'blurb_fr', i.blurb_fr,
        'price', i.price, 'payload', i.payload
      ) order by i.sort)
      from public.cosmetic_items i where i.active
    ), '[]'::jsonb),
    'owned', coalesce((
      select jsonb_agg(o.item_id) from public.cosmetic_owned o
       where o.user_id = auth.uid()
    ), '[]'::jsonb),
    'balance', coalesce((select w.shards from public.wallets w where w.user_id = auth.uid()), 0)
  );
$f$;

grant execute on function public.cosmetic_catalogue() to authenticated;
