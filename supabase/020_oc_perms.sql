-- Order control (2026-11-12): per-admin permission for each action, and full control for the super admin,
-- including closed (delivered / cancelled) orders. Re-opening a delivered order reverses its money first.

alter table public.admin_access add column if not exists oc_perms jsonb not null
  default '{"edit":true,"status":true,"hold":true,"transfer":true,"driver":true,"delete":true}'::jsonb;

create or replace function private.oc_can(p_action text)
returns void language plpgsql stable security definer set search_path to '' as $$
begin
  if public.is_super_admin() then return; end if;
  if not coalesce((select (a.oc_perms->>p_action)::boolean from public.admin_access a where a.user_id = auth.uid()), true) then
    raise exception 'لا تملك صلاحية هذا الإجراء في التحكم بالطلبات'; end if;
end $$;

-- Undo the money a delivered order put in the store wallet, the platform ledger and the driver ledger.
create or replace function private.reverse_delivery(p_order uuid)
returns void language plpgsql security definer set search_path to '' as $$
declare o public.orders; w numeric; k text; v numeric;
begin
  select * into o from public.orders where id = p_order;
  select coalesce(sum(amount), 0) into w from public.wallet_ledger where order_id = o.id;
  if w <> 0 then
    insert into public.wallet_ledger (merchant_id, order_id, kind, amount, note, created_by)
    values (o.merchant_id, o.id, 'adjustment', -w, 'عكس قيود الطلب #' || o.code || ' (أعاد المدير العام فتحه)', auth.uid());
  end if;
  foreach k in array array['merchant_commission','customer_commission','delivery_fee'] loop
    select coalesce(sum(amount), 0) into v from public.platform_ledger where order_id = o.id and kind = k;
    if v <> 0 then
      insert into public.platform_ledger (kind, amount, merchant_id, order_id) values (k, -v, o.merchant_id, o.id);
    end if;
  end loop;
  -- driver: offset each credit and free its once-per-order slot so a later delivery credits again
  insert into public.driver_ledger (driver_id, kind, amount, note)
  select driver_id, kind, -amount, 'عكس: ' || coalesce(note, '') from public.driver_ledger
  where order_id = o.id and kind in ('fee_earned','cash_collected');
  update public.driver_ledger set order_id = null, note = coalesce(note, '') || ' (أُعيد فتح الطلب)'
  where order_id = o.id and kind in ('fee_earned','cash_collected');
  update public.orders set delivered_at = null,
    payment_status = case when payment_method = 'cash' then 'pending'::public.payment_status else payment_status end
  where id = o.id;
end $$;

create or replace function public.oc_update_order(p_token uuid, p_order uuid, p_fields jsonb)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('edit');
  update public.orders set
    slaughter_date = case when p_fields ? 'slaughter_date' then nullif(p_fields->>'slaughter_date','')::date else slaughter_date end,
    slaughter_time = case when p_fields ? 'slaughter_time' then p_fields->>'slaughter_time' else slaughter_time end,
    delivery_date  = case when p_fields ? 'delivery_date' then nullif(p_fields->>'delivery_date','')::date else delivery_date end,
    delivery_slot  = case when p_fields ? 'delivery_slot' then p_fields->>'delivery_slot' else delivery_slot end,
    address        = case when p_fields ? 'address' then p_fields->>'address' else address end,
    notes          = case when p_fields ? 'notes' then p_fields->>'notes' else notes end,
    customer_name  = case when p_fields ? 'customer_name' then p_fields->>'customer_name' else customer_name end,
    customer_phone = case when p_fields ? 'customer_phone' then p_fields->>'customer_phone' else customer_phone end,
    updated_at = now()
  where id = p_order returning * into o;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  return o;
end $$;

create or replace function public.oc_set_status(p_token uuid, p_order uuid, p_status public.order_status)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('status');
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if o.status = p_status then return o; end if;
  if o.status in ('delivered','cancelled') then
    if not public.is_super_admin() then raise exception 'الطلب مغلق. إعادة فتحه للمدير العام فقط'; end if;
    if o.deleted_at is not null then raise exception 'استرجع الطلب المحذوف أولاً'; end if;
    if o.status = 'delivered' then perform private.reverse_delivery(o.id); end if;
    perform private.log('control', 'order', o.id::text, 'إعادة فتح الطلب #' || o.code || ' (' || private.status_ar(o.status::text) || ')');
    -- reopen at the step before the target, then move through the normal path (which credits a new delivery)
    update public.orders set status = case when p_status = 'delivered' then
        (case when fulfillment = 'pickup' then 'ready' else 'out_for_delivery' end)::public.order_status
      else p_status end, updated_at = now()
    where id = o.id returning * into o;
    insert into public.order_events (order_id, status, by_user) values (o.id, o.status, auth.uid());
    if p_status <> 'delivered' then return o; end if;
  end if;
  return public.set_order_status(p_order, p_status);
end $$;

create or replace function public.oc_hold(p_token uuid, p_order uuid, p_hold boolean, p_reason text default null)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('hold');
  update public.orders set held = p_hold, held_reason = case when p_hold then p_reason end,
    held_at = case when p_hold then now() end, updated_at = now()
  where id = p_order and status not in ('delivered','cancelled') returning * into o;
  if o.id is null then raise exception 'الطلب مغلق ولا يمكن إيقافه'; end if;
  insert into public.notifications (audience, merchant_id, title, body, kind)
  values ('merchant', o.merchant_id, case when p_hold then 'تم إيقاف طلب' else 'تم استئناف طلب' end,
    'الطلب #' || o.code || case when p_hold then ' موقوف من الإدارة' || coalesce(': ' || nullif(p_reason,''), '') else ' عاد للعمل' end, 'order');
  if o.driver_id is not null then
    insert into public.notifications (audience, user_id, title, body, kind)
    values ('user', o.driver_id, case when p_hold then 'تم إيقاف طلب' else 'تم استئناف طلب' end,
      'الطلب #' || o.code || case when p_hold then ' موقوف من الإدارة' else ' عاد للعمل' end, 'order');
  end if;
  return o;
end $$;

create or replace function public.oc_delete(p_token uuid, p_order uuid, p_reason text, p_restore boolean default false)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  perform private.oc_can('delete');
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if p_restore then
    update public.orders set deleted_at = null, deleted_reason = null, deleted_by = null, updated_at = now()
    where id = p_order returning * into o;
    return o;
  end if;
  if o.status = 'delivered' then
    if not public.is_super_admin() then
      raise exception 'لا يمكن حذف طلب تم تسليمه إلا من المدير العام'; end if;
    perform private.reverse_delivery(o.id);
  end if;
  update public.orders set deleted_at = now(), deleted_reason = p_reason, deleted_by = auth.uid(),
    status = 'cancelled', held = false, updated_at = now()
  where id = p_order returning * into o;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'cancelled', auth.uid());
  return o;
end $$;

create or replace function public.oc_transfer_merchant(p_token uuid, p_order uuid, p_merchant uuid, p_reason text default null)
returns public.orders language plpgsql security definer set search_path to '' as $$
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
  if old.status = 'delivered' then perform private.reverse_delivery(old.id); end if;
  update public.orders set merchant_id = p_merchant, status = 'new', held = false, driver_id = null, driver_name = null,
    driver_phone = null, dispatch_at = null, dispatch_queue = '{}'::uuid[], dispatch_notified = null, updated_at = now()
  where id = p_order returning * into o;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'new', auth.uid());
  insert into public.notifications (audience, merchant_id, title, body, kind) values
    ('merchant', old.merchant_id, 'تم تحويل طلب', 'حوّلت الإدارة الطلب #' || o.code || ' إلى متجر آخر' || coalesce(': ' || nullif(p_reason,''), ''), 'order'),
    ('merchant', p_merchant, 'طلب جديد محوّل إليك', 'حوّلت الإدارة إليك الطلب #' || o.code, 'order');
  perform private.log('control', 'order', o.id::text, 'تحويل الطلب #' || o.code || ' من ' ||
    coalesce((select name from public.merchants where id = old.merchant_id), '') || ' إلى ' || mname ||
    coalesce(' (' || nullif(p_reason,'') || ')', ''));
  return o;
end $$;

create or replace function public.oc_assign_driver(p_token uuid, p_order uuid, p_driver uuid)
returns public.orders language plpgsql security definer set search_path to '' as $$
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
  -- a delivered order's delivery fee and collected cash move to the new driver
  if o.status = 'delivered' and p_driver is not null then
    update public.driver_ledger set driver_id = p_driver where order_id = o.id;
  end if;
  return o;
end $$;

create or replace function public.admin_set_oc_perms(p_user uuid, p_perms jsonb)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not public.is_super_admin() then raise exception 'هذا الإجراء للمدير العام فقط'; end if;
  if not exists (select 1 from public.user_roles where user_id = p_user and role = 'admin') then
    raise exception 'المستخدم ليس من الإدارة'; end if;
  insert into public.admin_access (user_id, oc_perms, updated_at, updated_by)
  values (p_user, p_perms, now(), auth.uid())
  on conflict (user_id) do update set oc_perms = excluded.oc_perms, updated_at = now(), updated_by = auth.uid();
  perform private.log('control', 'user', p_user::text, 'تعديل صلاحيات التحكم بالطلبات للمستخدم ' ||
    coalesce((select full_name from public.profiles where id = p_user), ''), p_perms);
end $$;

create or replace function public.admin_access_list()
returns json language plpgsql stable security definer set search_path to '' as $$
declare all_on jsonb := '{"edit":true,"status":true,"hold":true,"transfer":true,"driver":true,"delete":true}';
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return json_build_object(
    'me', (select json_build_object('super', coalesce(a.is_super,false), 'activity', coalesce(a.is_super or a.can_activity,false),
            'perms', case when coalesce(a.is_super,false) then all_on else coalesce(a.oc_perms, all_on) end,
            'has_key', exists (select 1 from private.oc_keys k where k.user_id = auth.uid() and k.active))
           from (select auth.uid() u) x left join public.admin_access a on a.user_id = x.u),
    'master_set', exists (select 1 from private.oc_keys where user_id is null and active),
    'any_key', exists (select 1 from private.oc_keys where active),
    'admins', case when public.is_super_admin() then (select coalesce(json_agg(json_build_object(
        'id', r.user_id, 'name', p.full_name, 'phone', p.phone,
        'super', coalesce(a.is_super,false), 'activity', coalesce(a.can_activity,false),
        'perms', coalesce(a.oc_perms, all_on),
        'has_key', exists (select 1 from private.oc_keys k where k.user_id = r.user_id and k.active)) order by p.full_name), '[]')
      from public.user_roles r join public.profiles p on p.id = r.user_id
      left join public.admin_access a on a.user_id = r.user_id where r.role = 'admin' and p.deleted_at is null) else '[]'::json end);
end $$;
