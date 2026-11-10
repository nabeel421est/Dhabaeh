-- commission helper
create or replace function public.calc_value(base numeric, t public.value_type, v numeric, enabled boolean) returns numeric
language sql immutable set search_path = '' as $$
  select case when not enabled then 0 when t = 'percent' then round(base * v / 100, 3) else v end;
$$;

-- ---------- place order (prices computed on the server) ----------
create or replace function public.place_order(
  p_merchant uuid, p_items jsonb,
  p_slaughter_date date, p_slaughter_time text,
  p_delivery_date date, p_delivery_slot text,
  p_zone uuid, p_address text, p_payment public.payment_method, p_notes text default null)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  m public.merchants;
  s public.platform_settings;
  z public.delivery_zones;
  it jsonb; p public.products; o public.orders;
  v_sub numeric := 0; v_disc numeric := 0; v_off numeric; q int;
  prof public.profiles;
begin
  if me is null then raise exception 'يجب تسجيل الدخول'; end if;
  select * into m from public.merchants where id = p_merchant;
  if m.id is null or m.suspended or m.frozen or not m.is_open then raise exception 'المتجر غير متاح حالياً'; end if;
  if p_delivery_date < p_slaughter_date then raise exception 'تاريخ التوصيل قبل تاريخ الذبح'; end if;
  if jsonb_array_length(coalesce(p_items, '[]')) = 0 then raise exception 'السلة فارغة'; end if;
  select * into s from public.platform_settings where id = 1;
  select * into z from public.delivery_zones where id = p_zone and active;
  if z.id is null then raise exception 'منطقة التوصيل غير متاحة'; end if;
  select * into prof from public.profiles where id = me;

  insert into public.orders (customer_id, merchant_id, slaughter_date, slaughter_time, delivery_date, delivery_slot,
    zone_id, address, notes, subtotal, total, merchant_net, payment_method, customer_name, customer_phone,
    payment_status)
  values (me, p_merchant, p_slaughter_date, p_slaughter_time, p_delivery_date, p_delivery_slot,
    p_zone, p_address, p_notes, 0, 0, 0, p_payment, prof.full_name, prof.phone,
    case when p_payment = 'bank_transfer' then 'awaiting_review'::public.payment_status else 'pending'::public.payment_status end)
  returning * into o;

  for it in select * from jsonb_array_elements(p_items) loop
    q := greatest(coalesce((it ->> 'qty')::int, 1), 1);
    select * into p from public.products where id = (it ->> 'product_id')::uuid and merchant_id = p_merchant and available;
    if p.id is null then raise exception 'منتج غير متوفر'; end if;
    select coalesce(max(public.calc_value(p.price, discount_type, discount_value, true)), 0) into v_off
      from public.offers where active and merchant_id = p_merchant and product_id = p.id and (ends_on is null or ends_on >= current_date);
    v_sub := v_sub + p.price * q;
    v_disc := v_disc + least(v_off, p.price) * q;
    insert into public.order_items (order_id, product_id, name, qty, unit_price, options)
    values (o.id, p.id, p.name, q, p.price, coalesce(it -> 'options', '{}'));
  end loop;

  update public.orders set
    subtotal = v_sub,
    discount = v_disc,
    delivery_fee = z.fee,
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

-- ---------- status changes with role checks ----------
create or replace function public.set_order_status(p_order uuid, p_status public.order_status)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid(); o public.orders; ok boolean := false;
begin
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if o.status in ('delivered','cancelled') then raise exception 'الطلب مغلق'; end if;

  if public.is_admin() then ok := true;
  elsif public.staff_can(o.merchant_id, 'orders') then
    ok := (o.status = 'new' and p_status in ('accepted','cancelled'))
       or (o.status = 'accepted' and p_status in ('slaughtering','cancelled'))
       or (o.status = 'slaughtering' and p_status = 'ready');
  elsif o.driver_id = me then
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
    insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
    values (o.merchant_id, o.id, 'order_credit', o.merchant_net, 'طلب #' || o.code, me);
    insert into public.platform_ledger (kind, amount, merchant_id, order_id) values
      ('merchant_commission', o.merchant_commission, o.merchant_id, o.id),
      ('customer_commission', o.customer_commission, o.merchant_id, o.id),
      ('delivery_fee', o.delivery_fee, o.merchant_id, o.id);
  end if;
  return o;
end $$;

-- driver takes an available order
create or replace function public.driver_claim(p_order uuid) returns public.orders
language plpgsql security definer set search_path = '' as $$
declare o public.orders; pr public.profiles;
begin
  if not public.has_role('driver') then raise exception 'هذا الحساب ليس مندوباً'; end if;
  select * into pr from public.profiles where id = auth.uid();
  update public.orders set driver_id = auth.uid(), driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = p_order and driver_id is null and status in ('accepted','slaughtering','ready')
  returning * into o;
  if o.id is null then raise exception 'الطلب لم يعد متاحاً'; end if;
  return o;
end $$;

create or replace function public.admin_assign_driver(p_order uuid, p_driver uuid) returns public.orders
language plpgsql security definer set search_path = '' as $$
declare o public.orders; pr public.profiles;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if p_driver is not null and not exists (select 1 from public.user_roles where user_id = p_driver and role = 'driver') then
    raise exception 'المستخدم ليس مندوباً'; end if;
  select * into pr from public.profiles where id = p_driver;
  update public.orders set driver_id = p_driver, driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = p_order returning * into o;
  return o;
end $$;

create or replace function public.admin_set_payment(p_order uuid, p_status public.payment_status) returns public.orders
language plpgsql security definer set search_path = '' as $$
declare o public.orders;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  update public.orders set payment_status = p_status, updated_at = now() where id = p_order returning * into o;
  return o;
end $$;

-- payouts: blocked when frozen, never above balance
create or replace function public.admin_payout(p_merchant uuid, p_amount numeric, p_ref text) returns numeric
language plpgsql security definer set search_path = '' as $$
declare m public.merchants; bal numeric;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into m from public.merchants where id = p_merchant for update;
  if m.frozen then raise exception 'محفظة المتجر مجمّدة'; end if;
  select coalesce(sum(amount), 0) into bal from public.wallet_ledger where merchant_id = p_merchant;
  if p_amount <= 0 or p_amount > bal then raise exception 'المبلغ أكبر من الرصيد المتاح'; end if;
  insert into public.wallet_ledger (merchant_id, kind, amount, note, created_by)
  values (p_merchant, 'payout', -p_amount, 'تحويل من الإدارة' || coalesce(' · حوالة ' || nullif(p_ref, ''), ''), auth.uid());
  return bal - p_amount;
end $$;

-- plans: records a subscription and the platform income
create or replace function public.admin_set_plan(p_merchant uuid, p_plan public.plan_type) returns public.merchants
language plpgsql security definer set search_path = '' as $$
declare s public.platform_settings; v_ends date; v_amt numeric; m public.merchants;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into s from public.platform_settings where id = 1;
  v_ends := case p_plan when 'trial' then current_date + s.trial_days when 'monthly' then (current_date + interval '1 month')::date else (current_date + interval '1 year')::date end;
  v_amt := case p_plan when 'trial' then 0 when 'monthly' then s.monthly_price else s.yearly_price end;
  update public.merchants set plan = p_plan, plan_ends = v_ends where id = p_merchant returning * into m;
  insert into public.subscriptions (merchant_id, plan, ends, amount) values (p_merchant, p_plan, v_ends, v_amt);
  if v_amt > 0 then insert into public.platform_ledger (kind, amount, merchant_id) values ('subscription', v_amt, p_merchant); end if;
  return m;
end $$;

-- delete a store only when balance is zero and nothing is open
create or replace function public.admin_delete_merchant(p_merchant uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if exists (select 1 from public.orders where merchant_id = p_merchant and status not in ('delivered','cancelled')) then
    raise exception 'لدى المتجر طلبات قائمة'; end if;
  if (select coalesce(sum(amount),0) from public.wallet_ledger where merchant_id = p_merchant) <> 0 then
    raise exception 'رصيد المحفظة ليس صفراً'; end if;
  if exists (select 1 from public.orders where merchant_id = p_merchant) then
    raise exception 'للمتجر طلبات سابقة، استخدم الإيقاف بدل الحذف للحفاظ على السجلات'; end if;
  delete from public.merchants where id = p_merchant;
end $$;

-- merchant owner edits the store fields they control
create or replace function public.merchant_update_store(p_merchant uuid, p_is_open boolean, p_description text, p_logo text) returns public.merchants
language plpgsql security definer set search_path = '' as $$
declare m public.merchants;
begin
  if not (public.is_admin() or public.is_merchant_owner(p_merchant)) then raise exception 'لا تملك الصلاحية'; end if;
  update public.merchants set is_open = coalesce(p_is_open, is_open), description = coalesce(p_description, description),
    logo_url = coalesce(p_logo, logo_url) where id = p_merchant returning * into m;
  return m;
end $$;

-- admin dashboards
create or replace function public.admin_merchant_summary()
returns table (merchant_id uuid, name text, orders_count bigint, sales numeric, merchant_comm numeric, customer_comm numeric, delivery_fees numeric, net numeric, balance numeric)
language sql stable security definer set search_path = '' as $$
  select m.id, m.name,
    count(o.id) filter (where o.status = 'delivered'),
    coalesce(sum(o.subtotal - o.discount) filter (where o.status = 'delivered'), 0),
    coalesce(sum(o.merchant_commission) filter (where o.status = 'delivered'), 0),
    coalesce(sum(o.customer_commission) filter (where o.status = 'delivered'), 0),
    coalesce(sum(o.delivery_fee) filter (where o.status = 'delivered'), 0),
    coalesce(sum(o.merchant_net) filter (where o.status = 'delivered'), 0),
    (select coalesce(sum(w.amount), 0) from public.wallet_ledger w where w.merchant_id = m.id)
  from public.merchants m left join public.orders o on o.merchant_id = m.id
  where public.is_admin()
  group by m.id, m.name order by m.name;
$$;

revoke execute on all functions in schema public from anon;
grant execute on all functions in schema public to authenticated;
-- customer attaches a bank-transfer receipt to their own order
create or replace function public.attach_receipt(p_order uuid, p_path text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.orders set receipt_path = p_path, payment_status = 'awaiting_review', updated_at = now()
  where id = p_order and customer_id = auth.uid();
  if not found then raise exception 'الطلب غير موجود'; end if;
end $$;
revoke execute on function public.attach_receipt(uuid, text) from anon;
grant execute on function public.attach_receipt(uuid, text) to authenticated;

-- storage: public media (logos, product photos), private docs (merchant papers, receipts)
insert into storage.buckets (id, name, public) values ('media', 'media', true), ('docs', 'docs', false)
on conflict (id) do nothing;
create policy media_admin_write on storage.objects for insert to authenticated with check (bucket_id = 'media' and public.is_admin());
create policy docs_admin_all on storage.objects for all to authenticated using (bucket_id = 'docs' and public.is_admin()) with check (bucket_id = 'docs' and public.is_admin());
create policy docs_own_upload on storage.objects for insert to authenticated with check (bucket_id = 'docs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy docs_own_read on storage.objects for select to authenticated using (bucket_id = 'docs' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- live updates in the apps
alter publication supabase_realtime add table public.orders, public.order_events, public.merchants, public.products, public.offers, public.wallet_ledger, public.platform_ledger, public.notifications, public.subscriptions;

-- Bahrain delivery zones (admin can edit)
insert into public.delivery_zones (name, fee) values
 ('المنامة', 2), ('المحرق', 2), ('الرفاع', 2.5), ('مدينة عيسى', 2), ('مدينة حمد', 2.5), ('سترة', 2), ('البديع', 2.5), ('الحد', 2.5), ('عالي', 2), ('سلماباد', 2), ('الزلاق', 3), ('عوالي', 3)
on conflict (name) do nothing;
