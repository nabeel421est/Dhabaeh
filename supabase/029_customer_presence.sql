-- Live customer presence and browsing trail for «مراقبة وتتبع العملاء» (admin).
-- The customer app calls track_customer() on every screen change and every 30 s;
-- a customer is online while the last ping is younger than 75 s.
create table if not exists public.customer_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seen timestamptz not null default now(),
  online boolean not null default true,
  screen text,
  store_id uuid,
  store_name text,
  product_name text,
  session_started timestamptz not null default now(),
  device text
);
alter table public.customer_presence enable row level security;
create policy customer_presence_admin_read on public.customer_presence for select using (public.is_admin());
alter publication supabase_realtime add table public.customer_presence;

create table if not exists public.customer_trail (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  at timestamptz not null default now(),
  screen text,
  store_id uuid,
  store_name text,
  product_name text
);
create index if not exists customer_trail_user_at on public.customer_trail (user_id, at desc);
alter table public.customer_trail enable row level security;
create policy customer_trail_admin_read on public.customer_trail for select using (public.is_admin());

-- Ping from the customer app. p_screen null = heartbeat only; p_screen 'offline' = closing.
create or replace function public.track_customer(p_screen text default null, p_store uuid default null,
  p_product text default null, p_device text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  prev public.customer_presence;
  sname text;
begin
  if me is null then return; end if;
  select * into prev from public.customer_presence where user_id = me;
  if p_screen = 'offline' then
    update public.customer_presence set online = false, last_seen = now() where user_id = me;
    return;
  end if;
  if p_store is not null then select name into sname from public.merchants where id = p_store; end if;
  insert into public.customer_presence as c (user_id, last_seen, online, screen, store_id, store_name, product_name, session_started, device)
  values (me, now(), true, p_screen, p_store, sname, p_product, now(), left(p_device, 120))
  on conflict (user_id) do update set
    last_seen = now(),
    online = true,
    session_started = case when c.online and c.last_seen > now() - interval '75 seconds' then c.session_started else now() end,
    screen = coalesce(excluded.screen, c.screen),
    store_id = case when excluded.screen is null then c.store_id else excluded.store_id end,
    store_name = case when excluded.screen is null then c.store_name else excluded.store_name end,
    product_name = case when excluded.screen is null then c.product_name else excluded.product_name end,
    device = coalesce(excluded.device, c.device);
  -- Log the move, skipping heartbeats and repeats of the same place.
  if p_screen is not null and (prev.user_id is null or prev.screen is distinct from p_screen
      or prev.store_id is distinct from p_store or prev.product_name is distinct from p_product
      or prev.last_seen < now() - interval '75 seconds') then
    insert into public.customer_trail (user_id, screen, store_id, store_name, product_name)
    values (me, p_screen, p_store, sname, p_product);
  end if;
end $$;
grant execute on function public.track_customer(text, uuid, text, text) to authenticated;

-- Every customer with their live status, for the admin board.
create or replace function public.admin_customer_presence()
returns table (user_id uuid, full_name text, phone text, area text, online boolean, last_seen timestamptz,
  screen text, store_name text, product_name text, session_started timestamptz, device text,
  visits_today int, orders_count int)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  return query
  select p.id, p.full_name, p.phone, p.area,
    coalesce(c.online and c.last_seen > now() - interval '75 seconds', false),
    c.last_seen, c.screen, c.store_name, c.product_name, c.session_started, c.device,
    (select count(*)::int from public.customer_trail t where t.user_id = p.id and t.at >= date_trunc('day', now() at time zone 'Asia/Bahrain') at time zone 'Asia/Bahrain'),
    (select count(*)::int from public.orders o where o.customer_id = p.id)
  from public.profiles p
  join public.user_roles r on r.user_id = p.id and r.role = 'customer'
  left join public.customer_presence c on c.user_id = p.id
  order by 5 desc, c.last_seen desc nulls last, p.full_name;
end $$;
grant execute on function public.admin_customer_presence() to authenticated;

create or replace function public.admin_customer_trail(p_user uuid, p_limit int default 80)
returns setof public.customer_trail language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  return query select * from public.customer_trail where user_id = p_user order by at desc limit least(p_limit, 300);
end $$;
grant execute on function public.admin_customer_trail(uuid, int) to authenticated;

