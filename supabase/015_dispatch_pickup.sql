-- Driver locations, nearest-driver dispatch (3-minute turns), pickup orders,
-- driver timers, and platform fees on cash pickup orders.

alter table public.orders
  add column if not exists fulfillment text not null default 'delivery',
  add column if not exists dispatch_at timestamptz,
  add column if not exists dispatch_queue uuid[] not null default '{}',
  add column if not exists driver_assigned_at timestamptz,
  add column if not exists picked_up_at timestamptz,
  add column if not exists delivered_at timestamptz;
do $$ begin
  alter table public.orders add constraint orders_fulfillment_chk check (fulfillment in ('delivery','pickup'));
exception when duplicate_object then null; end $$;

alter table public.merchants
  add column if not exists lat double precision,
  add column if not exists lng double precision;

alter table public.platform_settings
  add column if not exists dispatch_seconds int not null default 180;

create table if not exists public.driver_locations (
  driver_id uuid primary key references auth.users(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  online boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.driver_locations enable row level security;
do $$ begin
  create policy driver_locations_read on public.driver_locations for select
    using (public.is_admin() or driver_id = (select auth.uid()));
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.driver_locations;
exception when duplicate_object then null; end $$;

-- Driver shares position / goes online or offline.
create or replace function public.driver_set_location(p_lat double precision, p_lng double precision, p_online boolean default true)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not public.has_role('driver') then raise exception 'هذا الحساب ليس مندوباً'; end if;
  insert into public.driver_locations (driver_id, lat, lng, online, updated_at)
  values (auth.uid(), p_lat, p_lng, p_online, now())
  on conflict (driver_id) do update set lat = excluded.lat, lng = excluded.lng,
    online = excluded.online, updated_at = now();
end $$;

-- Which driver holds the offer right now (null = open to all drivers).
create or replace function public.dispatch_current(p_queue uuid[], p_at timestamptz)
returns uuid language sql stable security definer set search_path to '' as $$
  select case when p_at is null or coalesce(cardinality(p_queue), 0) = 0 then null
    else p_queue[floor(extract(epoch from (now() - p_at)) /
      greatest((select dispatch_seconds from public.platform_settings where id = 1), 30))::int + 1] end
$$;

-- Can the signed-in driver see / take this open order now?
create or replace function public.offer_visible(p_queue uuid[], p_at timestamptz)
returns boolean language sql stable security definer set search_path to '' as $$
  select public.has_role('driver') and (
    public.dispatch_current(p_queue, p_at) is null
    or public.dispatch_current(p_queue, p_at) = auth.uid())
$$;

alter policy orders_read on public.orders using (
  public.is_admin()
  or customer_id = (select auth.uid())
  or driver_id = (select auth.uid())
  or public.staff_can(merchant_id, 'orders')
  or (driver_id is null and fulfillment = 'delivery'
      and status in ('accepted','slaughtering','ready')
      and public.offer_visible(dispatch_queue, dispatch_at)));

-- Timestamps, driver timer and the nearest-first queue.
create or replace function public.orders_dispatch()
returns trigger language plpgsql security definer set search_path to '' as $$
declare m public.merchants;
begin
  if tg_op = 'UPDATE' then
    if new.driver_id is distinct from old.driver_id then
      new.driver_assigned_at := case when new.driver_id is null then null else now() end;
      if new.driver_id is null then new.dispatch_at := null; end if;
    end if;
    if new.status = 'out_for_delivery' and old.status is distinct from 'out_for_delivery' then
      new.picked_up_at := now(); end if;
    if new.status = 'delivered' and old.status is distinct from 'delivered' then
      new.delivered_at := now(); end if;
  end if;
  if new.fulfillment = 'delivery' and new.driver_id is null and new.dispatch_at is null
     and new.status in ('accepted','slaughtering','ready') then
    select * into m from public.merchants where id = new.merchant_id;
    new.dispatch_at := now();
    new.dispatch_queue := coalesce((
      select array_agg(d.driver_id order by
        case when m.lat is null then 0
          else power(d.lat - m.lat, 2) + power((d.lng - m.lng) * cos(radians(m.lat)), 2) end,
        d.updated_at desc)
      from public.driver_locations d
      join public.profiles p on p.id = d.driver_id
      where d.online and d.updated_at > now() - interval '15 minutes'
        and p.is_active and p.deleted_at is null
        and exists (select 1 from public.user_roles r where r.user_id = d.driver_id and r.role = 'driver')
    ), '{}');
  end if;
  return new;
end $$;
do $$ begin
  create trigger orders_dispatch before insert or update on public.orders
    for each row execute function public.orders_dispatch();
exception when duplicate_object then null; end $$;

-- Claim only when the offer is yours (or open to all).
create or replace function public.driver_claim(p_order uuid)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders; pr public.profiles;
begin
  if not public.has_role('driver') then raise exception 'هذا الحساب ليس مندوباً'; end if;
  select * into pr from public.profiles where id = auth.uid();
  update public.orders set driver_id = auth.uid(), driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = p_order and driver_id is null and fulfillment = 'delivery'
    and status in ('accepted','slaughtering','ready')
    and public.offer_visible(dispatch_queue, dispatch_at)
  returning * into o;
  if o.id is null then raise exception 'الطلب لم يعد متاحاً لك'; end if;
  return o;
end $$;

-- Pass the offer to the next nearest driver right away.
create or replace function public.driver_pass(p_order uuid)
returns void language plpgsql security definer set search_path to '' as $$
declare o public.orders; pos int; secs int;
begin
  select * into o from public.orders where id = p_order for update;
  if o.id is null or o.driver_id is not null then return; end if;
  if public.dispatch_current(o.dispatch_queue, o.dispatch_at) is distinct from auth.uid() then return; end if;
  pos := array_position(o.dispatch_queue, auth.uid());
  select greatest(dispatch_seconds, 30) into secs from public.platform_settings where id = 1;
  update public.orders set dispatch_at = now() - make_interval(secs => pos * secs) where id = p_order;
end $$;

-- Admin assigns, transfers or unassigns; the new driver is notified.
create or replace function public.admin_assign_driver(p_order uuid, p_driver uuid)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders; pr public.profiles; old_driver uuid;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if p_driver is not null and not exists (select 1 from public.user_roles where user_id = p_driver and role = 'driver') then
    raise exception 'المستخدم ليس مندوباً'; end if;
  select driver_id into old_driver from public.orders where id = p_order;
  if (select fulfillment from public.orders where id = p_order) = 'pickup' then
    raise exception 'هذا الطلب استلام من المحل ولا يحتاج مندوباً'; end if;
  select * into pr from public.profiles where id = p_driver;
  update public.orders set driver_id = p_driver, driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = p_order and status not in ('delivered','cancelled') returning * into o;
  if o.id is null then raise exception 'الطلب مغلق'; end if;
  if p_driver is not null and p_driver is distinct from old_driver then
    insert into public.notifications (audience, user_id, title, body, kind)
    values ('user', p_driver, 'طلب جديد مسند إليك', 'أسندت لك الإدارة الطلب #' || o.code, 'order');
  end if;
  if old_driver is not null and old_driver is distinct from p_driver then
    insert into public.notifications (audience, user_id, title, body, kind)
    values ('user', old_driver, 'تم تحويل طلب', 'حوّلت الإدارة الطلب #' || o.code || ' إلى مندوب آخر', 'order');
  end if;
  return o;
end $$;

-- Status rules: pickup orders are handed over by the store; drivers only deliver.
create or replace function public.set_order_status(p_order uuid, p_status order_status)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare
  me uuid := auth.uid(); o public.orders; ok boolean := false; fees numeric;
begin
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if o.status in ('delivered','cancelled') then raise exception 'الطلب مغلق'; end if;

  if public.is_admin() then ok := true;
  elsif public.staff_can(o.merchant_id, 'orders') then
    ok := (o.status = 'new' and p_status in ('accepted','cancelled'))
       or (o.status = 'accepted' and p_status in ('slaughtering','cancelled'))
       or (o.status = 'slaughtering' and p_status = 'ready')
       or (o.fulfillment = 'pickup' and o.status = 'ready' and p_status = 'delivered');
  elsif o.driver_id = me and o.fulfillment = 'delivery' then
    ok := (o.status = 'ready' and p_status = 'out_for_delivery')
       or (o.status = 'out_for_delivery' and p_status = 'delivered');
  elsif o.customer_id = me then
    ok := o.status = 'new' and p_status = 'cancelled';
  end if;
  if not ok then raise exception 'لا تملك صلاحية تغيير حالة هذا الطلب'; end if;

  update public.orders set status = p_status, updated_at = now(),
    payment_status = case when p_status = 'delivered' and payment_method = 'cash' then 'paid'::public.payment_status else payment_status end
  where id = p_order returning * into o;
  insert into public.order_events (order_id, status, by_user) values (o.id, p_status, me);

  if p_status = 'delivered' then
    if o.fulfillment = 'pickup' and o.payment_method = 'cash' then
      -- The store took the full amount in cash; the platform's fees come out of its wallet
      -- (the balance may go negative and is settled from the next credits).
      fees := o.merchant_commission + o.customer_commission;
      if fees <> 0 then
        insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
        values (o.merchant_id, o.id, 'adjustment', -fees,
          'رسوم المنصة لطلب #' || o.code || ' (استلام من المحل ودفع نقدي)', me);
      end if;
    else
      insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
      values (o.merchant_id, o.id, 'order_credit', o.merchant_net, 'طلب #' || o.code, me);
    end if;
    insert into public.platform_ledger (kind, amount, merchant_id, order_id) values
      ('merchant_commission', o.merchant_commission, o.merchant_id, o.id),
      ('customer_commission', o.customer_commission, o.merchant_id, o.id),
      ('delivery_fee', o.delivery_fee, o.merchant_id, o.id);
  end if;
  return o;
end $$;

-- place_order gains p_fulfillment; the old signature is kept under another name.
do $$ begin
  alter function public.place_order(uuid, jsonb, date, text, date, text, uuid, text, payment_method, text) rename to place_order_v1;
exception when undefined_function then null; end $$;

create or replace function public.place_order(p_merchant uuid, p_items jsonb, p_slaughter_date date, p_slaughter_time text,
  p_delivery_date date, p_delivery_slot text, p_zone uuid, p_address text, p_payment payment_method,
  p_notes text default null, p_fulfillment text default 'delivery')
returns public.orders language plpgsql security definer set search_path to '' as $$
declare
  me uuid := auth.uid();
  m public.merchants;
  s public.platform_settings;
  z public.delivery_zones;
  it jsonb; p public.products; u public.product_units; o public.orders;
  v_sub numeric := 0; v_disc numeric := 0; v_off numeric; q int;
  v_price numeric; v_unit text; v_sku text;
  prof public.profiles;
  pickup boolean := coalesce(p_fulfillment, 'delivery') = 'pickup';
begin
  if me is null then raise exception 'يجب تسجيل الدخول'; end if;
  if coalesce(p_fulfillment, 'delivery') not in ('delivery','pickup') then raise exception 'طريقة الاستلام غير معروفة'; end if;
  select * into m from public.merchants where id = p_merchant;
  if m.id is null or m.suspended or m.frozen or not m.is_open then raise exception 'المتجر غير متاح حالياً'; end if;
  if p_delivery_date < p_slaughter_date then raise exception 'تاريخ الاستلام قبل تاريخ الذبح'; end if;
  if jsonb_array_length(coalesce(p_items, '[]')) = 0 then raise exception 'السلة فارغة'; end if;
  select * into s from public.platform_settings where id = 1;
  if p_payment = 'benefitpay' and not coalesce(s.allow_benefitpay, true)
     or p_payment = 'bank_transfer' and not coalesce(s.allow_bank_transfer, true)
     or p_payment = 'cash' and not coalesce(s.allow_cod, true) then
    raise exception 'طريقة الدفع غير متاحة حالياً'; end if;
  if not pickup then
    select * into z from public.delivery_zones where id = p_zone and active;
    if z.id is null then raise exception 'منطقة التوصيل غير متاحة'; end if;
  end if;
  select * into prof from public.profiles where id = me;

  insert into public.orders (customer_id, merchant_id, slaughter_date, slaughter_time, delivery_date, delivery_slot,
    zone_id, address, notes, subtotal, total, merchant_net, payment_method, customer_name, customer_phone,
    payment_status, fulfillment)
  values (me, p_merchant, p_slaughter_date, p_slaughter_time, p_delivery_date, p_delivery_slot,
    case when pickup then null else p_zone end,
    case when pickup then 'استلام من المحل' else p_address end,
    p_notes, 0, 0, 0, p_payment, prof.full_name, prof.phone,
    case when p_payment = 'bank_transfer' then 'awaiting_review'::public.payment_status else 'pending'::public.payment_status end,
    case when pickup then 'pickup' else 'delivery' end)
  returning * into o;

  for it in select * from jsonb_array_elements(p_items) loop
    q := greatest(coalesce((it ->> 'qty')::int, 1), 1);
    select * into p from public.products where id = (it ->> 'product_id')::uuid and merchant_id = p_merchant and available;
    if p.id is null then raise exception 'منتج غير متوفر'; end if;
    v_price := p.price; v_unit := p.base_unit; v_sku := p.sku;
    if nullif(it ->> 'unit_id', '') is not null then
      select * into u from public.product_units where id = (it ->> 'unit_id')::uuid and product_id = p.id;
      if u.id is null then raise exception 'وحدة المنتج غير متوفرة'; end if;
      v_price := u.price; v_unit := u.name; v_sku := u.sku;
    end if;
    select coalesce(max(public.calc_value(v_price, discount_type, discount_value, true)), 0) into v_off
      from public.offers where active and merchant_id = p_merchant and product_id = p.id and (ends_on is null or ends_on >= current_date);
    v_sub := v_sub + v_price * q;
    v_disc := v_disc + least(v_off, v_price) * q;
    insert into public.order_items (order_id, product_id, name, qty, unit_price, options, unit_name, sku)
    values (o.id, p.id, p.name || case when v_unit is not null and v_unit <> 'ذبيحة' then ' · ' || v_unit else '' end,
      q, v_price, coalesce(it -> 'options', '{}'), v_unit, v_sku);
  end loop;

  update public.orders set
    subtotal = v_sub,
    discount = v_disc,
    delivery_fee = case when pickup then 0 else z.fee end,
    customer_commission = public.calc_value(v_sub - v_disc, s.customer_comm_type, s.customer_comm_value, s.customer_comm_enabled),
    merchant_commission = public.calc_value(v_sub - v_disc, s.merchant_comm_type, s.merchant_comm_value, s.merchant_comm_enabled)
  where id = o.id;
  update public.orders set
    total = subtotal - discount + customer_commission + delivery_fee,
    merchant_net = subtotal - discount - merchant_commission
  where id = o.id returning * into o;

  insert into public.order_events (order_id, status, by_user) values (o.id, 'new', me);
  return o;
end $$;
