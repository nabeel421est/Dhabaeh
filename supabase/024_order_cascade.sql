-- 024: an order's money follows it everywhere.
-- Deleting, editing, moving or re-assigning an order voids every ledger row it
-- produced (store wallet, platform ledger, driver ledger) and, when the order
-- still counts, posts fresh rows from its current values. Voided rows and their
-- offsets net to zero, so every balance stays a plain sum, and lists hide them.

alter table public.wallet_ledger
  add column if not exists voided boolean not null default false,
  add column if not exists void_order uuid;
alter table public.driver_ledger
  add column if not exists voided boolean not null default false,
  add column if not exists void_order uuid;
alter table public.platform_ledger
  add column if not exists voided boolean not null default false;
alter table public.orders
  add column if not exists deleted_status public.order_status;

create index if not exists wallet_ledger_order_idx on public.wallet_ledger (order_id);
create index if not exists platform_ledger_order_idx on public.platform_ledger (order_id);

-- Void everything an order has posted.
create or replace function private.order_void(p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare r record; pids bigint[];
begin
  select coalesce(array_agg(id), '{}') into pids
  from public.platform_ledger where order_id = p_order and not voided;

  for r in select * from public.wallet_ledger
           where not voided and (order_id = p_order or pl_ref = any(pids)) loop
    update public.wallet_ledger set voided = true, void_order = p_order where id = r.id;
    insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by, voided, void_order)
    values (r.merchant_id, r.order_id, r.kind, -r.amount, 'إلغاء: ' || coalesce(r.note, ''), auth.uid(), true, p_order);
  end loop;

  update public.platform_ledger set voided = true, deleted_at = coalesce(deleted_at, now())
  where id = any(pids);

  for r in select * from public.driver_ledger where not voided and order_id = p_order loop
    update public.driver_ledger set voided = true, void_order = p_order, order_id = null where id = r.id;
    insert into public.driver_ledger (driver_id, kind, amount, note, voided, void_order)
    values (r.driver_id, r.kind, -r.amount, 'إلغاء: ' || coalesce(r.note, ''), true, p_order);
  end loop;
end $$;

-- Post a delivered order's money from its current values (same rules as delivery).
create or replace function private.order_post(p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.orders; fees numeric;
begin
  select * into o from public.orders where id = p_order;
  if o.id is null or o.status <> 'delivered' or o.deleted_at is not null then return; end if;
  if o.fulfillment = 'pickup' and o.payment_method = 'cash' then
    fees := o.merchant_commission + o.customer_commission;
    if fees <> 0 then
      insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
      values (o.merchant_id, o.id, 'adjustment', -fees,
        'رسوم المنصة لطلب #' || o.code || ' (استلام من المحل ودفع نقدي)', auth.uid());
    end if;
  else
    insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
    values (o.merchant_id, o.id, 'order_credit', o.merchant_net, 'طلب #' || o.code, auth.uid());
  end if;
  insert into public.platform_ledger (kind, amount, merchant_id, order_id) values
    ('merchant_commission', o.merchant_commission, o.merchant_id, o.id),
    ('customer_commission', o.customer_commission, o.merchant_id, o.id),
    ('delivery_fee', o.delivery_fee, o.merchant_id, o.id);
  if o.driver_id is not null then
    insert into public.driver_ledger (driver_id, kind, amount, order_id, note)
    values (o.driver_id, 'fee_earned', o.delivery_fee, o.id, 'رسوم توصيل طلب #' || o.code)
    on conflict do nothing;
    if o.payment_method = 'cash' then
      insert into public.driver_ledger (driver_id, kind, amount, order_id, note)
      values (o.driver_id, 'cash_collected', o.total, o.id, 'تحصيل نقدي طلب #' || o.code)
      on conflict do nothing;
    end if;
  end if;
end $$;

create or replace function private.order_rebuild(p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.order_void(p_order);
  perform private.order_post(p_order);
end $$;

-- Re-opening a delivered order now voids its rows instead of posting visible reversals.
create or replace function private.reverse_delivery(p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.order_void(p_order);
  update public.orders set delivered_at = null,
    payment_status = case when payment_method = 'cash' then 'pending'::public.payment_status else payment_status end
  where id = p_order;
end $$;

-- Edit: details and amounts. A delivered order's ledgers are rebuilt from the new amounts.
create or replace function public.oc_update_order(p_token uuid, p_order uuid, p_fields jsonb)
returns public.orders language plpgsql security definer set search_path = '' as $$
declare o public.orders; old public.orders; money boolean;
  n numeric;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('edit');
  select * into old from public.orders where id = p_order for update;
  if old.id is null then raise exception 'الطلب غير موجود'; end if;
  money := p_fields ?| array['subtotal','discount','delivery_fee','customer_commission','merchant_commission','payment_method'];
  if money and old.deleted_at is not null then raise exception 'استرجع الطلب المحذوف أولاً'; end if;
  foreach n in array array[
    nullif(p_fields->>'subtotal','')::numeric, nullif(p_fields->>'discount','')::numeric,
    nullif(p_fields->>'delivery_fee','')::numeric, nullif(p_fields->>'customer_commission','')::numeric,
    nullif(p_fields->>'merchant_commission','')::numeric] loop
    if n < 0 then raise exception 'المبالغ لا تكون سالبة'; end if;
  end loop;

  update public.orders set
    slaughter_date = case when p_fields ? 'slaughter_date' then nullif(p_fields->>'slaughter_date','')::date else slaughter_date end,
    slaughter_time = case when p_fields ? 'slaughter_time' then p_fields->>'slaughter_time' else slaughter_time end,
    delivery_date  = case when p_fields ? 'delivery_date' then nullif(p_fields->>'delivery_date','')::date else delivery_date end,
    delivery_slot  = case when p_fields ? 'delivery_slot' then p_fields->>'delivery_slot' else delivery_slot end,
    address        = case when p_fields ? 'address' then p_fields->>'address' else address end,
    notes          = case when p_fields ? 'notes' then p_fields->>'notes' else notes end,
    customer_name  = case when p_fields ? 'customer_name' then p_fields->>'customer_name' else customer_name end,
    customer_phone = case when p_fields ? 'customer_phone' then p_fields->>'customer_phone' else customer_phone end,
    subtotal = coalesce(nullif(p_fields->>'subtotal','')::numeric, subtotal),
    discount = coalesce(nullif(p_fields->>'discount','')::numeric, discount),
    delivery_fee = coalesce(nullif(p_fields->>'delivery_fee','')::numeric, delivery_fee),
    customer_commission = coalesce(nullif(p_fields->>'customer_commission','')::numeric, customer_commission),
    merchant_commission = coalesce(nullif(p_fields->>'merchant_commission','')::numeric, merchant_commission),
    payment_method = coalesce(nullif(p_fields->>'payment_method','')::public.payment_method, payment_method),
    updated_at = now()
  where id = p_order;
  update public.orders set
    total = subtotal - discount + customer_commission + delivery_fee,
    merchant_net = subtotal - discount - merchant_commission
  where id = p_order returning * into o;

  if money and o.status = 'delivered' and (
     o.total, o.merchant_net, o.delivery_fee, o.customer_commission, o.merchant_commission, o.payment_method)
     is distinct from
     (old.total, old.merchant_net, old.delivery_fee, old.customer_commission, old.merchant_commission, old.payment_method) then
    perform private.order_rebuild(o.id);
  end if;
  if money and o.total is distinct from old.total then
    perform private.log('control', 'order', o.id::text, 'تعديل مبالغ الطلب #' || o.code || ': ' ||
      old.total || ' ← ' || o.total || ' د.ب');
  end if;
  return o;
end $$;

-- Delete: void every movement; restore brings the order back with its old status and money.
create or replace function public.oc_delete(p_token uuid, p_order uuid, p_reason text, p_restore boolean default false)
returns public.orders language plpgsql security definer set search_path = '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('delete');
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if p_restore then
    if o.deleted_at is null then return o; end if;
    update public.orders set deleted_at = null, deleted_reason = null, deleted_by = null,
      status = coalesce(deleted_status, status), deleted_status = null, updated_at = now()
    where id = p_order returning * into o;
    insert into public.order_events (order_id, status, by_user) values (o.id, o.status, auth.uid());
    perform private.order_post(o.id);
    perform private.log('control', 'order', o.id::text, 'استرجاع الطلب #' || o.code);
    return o;
  end if;
  if o.deleted_at is not null then return o; end if;
  if o.status = 'delivered' and not public.is_super_admin() then
    raise exception 'لا يمكن حذف طلب تم تسليمه إلا من المدير العام'; end if;
  perform private.order_void(o.id);
  update public.orders set deleted_at = now(), deleted_reason = p_reason, deleted_by = auth.uid(),
    deleted_status = status, status = 'cancelled', held = false, updated_at = now()
  where id = p_order returning * into o;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'cancelled', auth.uid());
  return o;
end $$;

-- Transfer: a delivered order keeps its status and its money moves to the new store.
create or replace function public.oc_transfer_merchant(p_token uuid, p_order uuid, p_merchant uuid, p_reason text default null)
returns public.orders language plpgsql security definer set search_path = '' as $$
declare o public.orders; old public.orders; mname text; sup boolean := public.is_super_admin();
begin
  perform private.oc_check(p_token);
  perform private.oc_can('transfer');
  select * into old from public.orders where id = p_order for update;
  if old.id is null then raise exception 'الطلب غير موجود'; end if;
  if old.merchant_id = p_merchant then raise exception 'الطلب لدى هذا التاجر أصلاً'; end if;
  if old.deleted_at is not null then raise exception 'استرجع الطلب المحذوف أولاً'; end if;
  select name into mname from public.merchants where id = p_merchant and not suspended;
  if mname is null then raise exception 'التاجر غير موجود أو موقوف'; end if;
  if not sup and old.status not in ('new','accepted') then raise exception 'يمكن التحويل قبل بدء الذبح فقط'; end if;

  if old.status = 'delivered' then
    update public.orders set merchant_id = p_merchant, updated_at = now()
    where id = p_order returning * into o;
    perform private.order_rebuild(o.id);
  else
    update public.orders set merchant_id = p_merchant, status = 'new', held = false, driver_id = null, driver_name = null,
      driver_phone = null, dispatch_at = null, dispatch_queue = '{}'::uuid[], dispatch_notified = null, updated_at = now()
    where id = p_order returning * into o;
    insert into public.order_events (order_id, status, by_user) values (o.id, 'new', auth.uid());
  end if;

  insert into public.notifications (audience, merchant_id, title, body, kind) values
    ('merchant', old.merchant_id, 'تم تحويل طلب', 'حوّلت الإدارة الطلب #' || o.code || ' إلى متجر آخر' || coalesce(': ' || nullif(p_reason,''), ''), 'order'),
    ('merchant', p_merchant, case when old.status = 'delivered' then 'طلب مسلَّم محوّل إليك' else 'طلب جديد محوّل إليك' end,
      'حوّلت الإدارة إليك الطلب #' || o.code, 'order');
  perform private.log('control', 'order', o.id::text, 'تحويل الطلب #' || o.code || ' من ' ||
    coalesce((select name from public.merchants where id = old.merchant_id), '') || ' إلى ' || mname ||
    coalesce(' (' || nullif(p_reason,'') || ')', ''));
  return o;
end $$;

-- Changing the driver of a delivered order moves its fee and cash to the new driver.
create or replace function public.oc_assign_driver(p_token uuid, p_order uuid, p_driver uuid)
returns public.orders language plpgsql security definer set search_path = '' as $$
declare o public.orders; pr public.profiles;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('driver');
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if o.status not in ('delivered','cancelled') then
    return public.admin_assign_driver(p_order, p_driver);
  end if;
  if not public.is_super_admin() then raise exception 'الطلب مغلق. تغيير مندوبه للمدير العام فقط'; end if;
  if p_driver is not null and not exists (select 1 from public.user_roles where user_id = p_driver and role = 'driver') then
    raise exception 'المستخدم ليس مندوباً'; end if;
  select * into pr from public.profiles where id = p_driver;
  update public.orders set driver_id = p_driver, driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = o.id returning * into o;
  if o.status = 'delivered' then perform private.order_rebuild(o.id); end if;
  return o;
end $$;

-- Control of single driver ledger rows (from the driver statement).
create or replace function public.ctl_driver_entry(p_token uuid, p_id bigint, p_action text, p_data jsonb default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare r public.driver_ledger; amt numeric;
begin
  perform private.oc_check(p_token);
  select * into r from public.driver_ledger where id = p_id for update;
  if r.id is null or r.voided then raise exception 'الحركة غير موجودة'; end if;
  if p_action = 'edit' then
    perform private.oc_can('edit');
    amt := coalesce(nullif(p_data->>'amount','')::numeric, r.amount);
    update public.driver_ledger set amount = amt,
      note = coalesce(nullif(p_data->>'note',''), note) where id = r.id;
    perform private.log('control', 'driver_ledger', r.id::text,
      'تعديل حركة مندوب: ' || r.amount || ' ← ' || amt || ' د.ب');
  elsif p_action = 'delete' then
    perform private.oc_can('delete');
    update public.driver_ledger set voided = true, void_order = r.order_id, order_id = null where id = r.id;
    insert into public.driver_ledger (driver_id, kind, amount, note, voided, void_order)
    values (r.driver_id, r.kind, -r.amount, 'إلغاء: ' || coalesce(r.note, '') ||
      coalesce(' (' || nullif(p_data->>'reason','') || ')', ''), true, r.order_id);
    perform private.log('control', 'driver_ledger', r.id::text,
      'حذف حركة مندوب ' || r.amount || ' د.ب' || coalesce(': ' || nullif(p_data->>'reason',''), ''));
  else
    raise exception 'إجراء غير معروف';
  end if;
end $$;

grant execute on function public.ctl_driver_entry(uuid, bigint, text, jsonb) to authenticated;
