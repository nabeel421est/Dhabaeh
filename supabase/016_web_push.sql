-- Web Push: device subscriptions, keys kept server-side, and triggers that send
-- pushes through the `push` edge function (via pg_net).

create extension if not exists pg_net;
create extension if not exists pg_cron;
create schema if not exists private;

create table if not exists public.push_subscriptions (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
do $$ begin
  create policy push_own_read on public.push_subscriptions for select using (user_id = (select auth.uid()));
exception when duplicate_object then null; end $$;

-- This device now belongs to the signed-in user.
create or replace function public.push_register(p_endpoint text, p_p256dh text, p_auth text, p_ua text default null)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول'; end if;
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, p_ua)
  on conflict (endpoint) do update set user_id = auth.uid(), p256dh = excluded.p256dh,
    auth = excluded.auth, user_agent = excluded.user_agent, updated_at = now();
end $$;

-- On sign-out the device stops receiving this user's pushes.
create or replace function public.push_unregister(p_endpoint text)
returns void language sql security definer set search_path to '' as $$
  update public.push_subscriptions set user_id = null, updated_at = now()
  where endpoint = p_endpoint and user_id = auth.uid();
$$;

-- VAPID keys: generated once by the edge function, never sent to clients except the public one.
create table if not exists private.push_keys (
  id int primary key default 1 check (id = 1),
  public_key text not null,
  private_key text not null,
  created_at timestamptz not null default now()
);

create or replace function public.push_public_key()
returns text language sql stable security definer set search_path to '' as $$
  select public_key from private.push_keys where id = 1
$$;

do $$ begin
  if not exists (select 1 from vault.secrets where name = 'push_hook') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'push_hook');
  end if;
end $$;

-- For the edge function only (service role).
create or replace function public.push_server_config()
returns json language plpgsql stable security definer set search_path to '' as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'not allowed'; end if;
  return json_build_object(
    'public', (select public_key from private.push_keys where id = 1),
    'private', (select private_key from private.push_keys where id = 1),
    'hook', (select decrypted_secret from vault.decrypted_secrets where name = 'push_hook'));
end $$;

create or replace function public.push_store_keys(p_public text, p_private text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'not allowed'; end if;
  insert into private.push_keys (id, public_key, private_key) values (1, p_public, p_private)
  on conflict (id) do nothing;
end $$;

-- Queue one push (who + what) to the edge function.
create or replace function private.push_send(p jsonb)
returns void language plpgsql security definer set search_path to '' as $$
begin
  perform net.http_post(
    url := 'https://onrjdddcutnmbmicfjcu.supabase.co/functions/v1/push',
    body := p,
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-hook', (select decrypted_secret from vault.decrypted_secrets where name = 'push_hook')),
    timeout_milliseconds := 8000);
exception when others then null; -- a push must never break the action that triggered it
end $$;

-- Every notification row is also pushed to its audience's phones.
create or replace function private.notifications_push()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  perform private.push_send(jsonb_build_object(
    'audience', new.audience, 'user_id', new.user_id, 'merchant_id', new.merchant_id,
    'title', new.title, 'body', coalesce(new.body, ''), 'tag', 'n-' || new.id));
  return new;
end $$;
do $$ begin
  create trigger notifications_push after insert on public.notifications
    for each row execute function private.notifications_push();
exception when duplicate_object then null; end $$;

alter table public.orders add column if not exists dispatch_notified text;

-- Push the current delivery turn (driver, or all online drivers) when it changes.
create or replace function private.dispatch_tick_one(p_order uuid)
returns void language plpgsql security definer set search_path to '' as $$
declare o public.orders; cur uuid; k text;
begin
  select * into o from public.orders where id = p_order;
  if o.id is null or o.driver_id is not null or o.fulfillment <> 'delivery'
     or o.status not in ('accepted','slaughtering','ready') or o.dispatch_at is null then return; end if;
  cur := public.dispatch_current(o.dispatch_queue, o.dispatch_at);
  k := coalesce(cur::text, 'all');
  if k is not distinct from o.dispatch_notified then return; end if;
  update public.orders set dispatch_notified = k where id = o.id;
  perform private.push_send(jsonb_build_object(
    'users', case when cur is null then null else jsonb_build_array(cur) end,
    'drivers_online', cur is null,
    'title', 'طلب توصيل جديد #' || o.code,
    'body', case when cur is null then 'متاح لكل المناديب، الأسرع يقبله'
                 else 'معروض عليك أولاً لأنك الأقرب. اقبله خلال 3 دقائق' end,
    'tag', 'offer-' || o.id, 'loud', true));
end $$;

create or replace function private.dispatch_tick()
returns void language plpgsql security definer set search_path to '' as $$
declare r record;
begin
  for r in select id from public.orders
    where driver_id is null and fulfillment = 'delivery' and dispatch_at is not null
      and status in ('accepted','slaughtering','ready') loop
    perform private.dispatch_tick_one(r.id);
  end loop;
end $$;

-- New order: admins and the store's team. Status change: tell the customer.
create or replace function private.orders_push()
returns trigger language plpgsql security definer set search_path to '' as $$
declare msg text; mname text;
begin
  if tg_op = 'INSERT' then
    select name into mname from public.merchants where id = new.merchant_id;
    perform private.push_send(jsonb_build_object(
      'admins', true, 'merchant_staff', new.merchant_id,
      'title', 'طلب جديد #' || new.code,
      'body', coalesce(mname, '') || ' · ' || coalesce(new.customer_name, '') || ' · ' ||
              case when new.fulfillment = 'pickup' then 'استلام من المحل' else 'توصيل' end,
      'tag', 'new-' || new.id, 'loud', true));
    return new;
  end if;
  if new.status is distinct from old.status then
    msg := case new.status
      when 'accepted' then 'تم قبول طلبك'
      when 'slaughtering' then 'بدأ تجهيز ذبيحتك'
      when 'ready' then case when new.fulfillment = 'pickup' then 'طلبك جاهز للاستلام من المحل' else 'طلبك جاهز وبانتظار المندوب' end
      when 'out_for_delivery' then 'طلبك في الطريق إليك'
      when 'delivered' then 'تم تسليم طلبك، بالعافية'
      when 'cancelled' then 'تم إلغاء طلبك'
      else null end;
    if msg is not null then
      insert into public.notifications (audience, user_id, title, body, kind)
      values ('user', new.customer_id, msg, 'الطلب #' || new.code, 'order');
    end if;
  end if;
  if new.status is distinct from old.status or new.driver_id is distinct from old.driver_id
     or new.dispatch_at is distinct from old.dispatch_at then
    perform private.dispatch_tick_one(new.id);
  end if;
  return new;
end $$;
do $$ begin
  create trigger orders_push after insert or update on public.orders
    for each row execute function private.orders_push();
exception when duplicate_object then null; end $$;

-- Turns move with time: check every 20 seconds.
do $$ begin
  perform cron.schedule('dispatch-tick', '20 seconds', 'select private.dispatch_tick()');
exception when others then null; end $$;
