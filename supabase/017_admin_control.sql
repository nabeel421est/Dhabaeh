-- Admin control: super admins, password-locked order control, activity log.

create schema if not exists private;

-- ───────────── Admin access flags ─────────────
create table if not exists public.admin_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_super boolean not null default false,
  can_activity boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.admin_access enable row level security;

create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path to '' as $$
  select public.is_admin() and exists (select 1 from public.admin_access where user_id = auth.uid() and is_super);
$$;

create or replace function public.can_view_activity()
returns boolean language sql stable security definer set search_path to '' as $$
  select public.is_admin() and exists (select 1 from public.admin_access
    where user_id = auth.uid() and (is_super or can_activity));
$$;

do $$ begin
  create policy admin_access_read on public.admin_access for select
    using (user_id = (select auth.uid()) or public.is_super_admin());
exception when duplicate_object then null; end $$;

-- Every current admin starts as a super admin; the super admin can then narrow it down.
insert into public.admin_access (user_id, is_super, can_activity)
select user_id, true, true from public.user_roles where role = 'admin'
on conflict (user_id) do nothing;

-- ───────────── Order control passwords and sessions ─────────────
create table if not exists private.oc_keys (
  id bigserial primary key,
  user_id uuid,                -- null = the master password
  hash text not null,
  active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now()
);
create table if not exists private.oc_sessions (
  token uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  expires_at timestamptz not null
);
create table if not exists private.oc_attempts (
  id bigserial primary key,
  user_id uuid not null,
  ok boolean not null,
  at timestamptz not null default now()
);

-- ───────────── Orders: hold and soft delete ─────────────
alter table public.orders add column if not exists held boolean not null default false;
alter table public.orders add column if not exists held_reason text;
alter table public.orders add column if not exists held_at timestamptz;
alter table public.orders add column if not exists deleted_at timestamptz;
alter table public.orders add column if not exists deleted_reason text;
alter table public.orders add column if not exists deleted_by uuid;

-- Deleted orders disappear for everyone except the admin.
alter policy orders_read on public.orders using (
  public.is_admin() or (deleted_at is null and (
    (customer_id = (select auth.uid())) or (driver_id = (select auth.uid()))
    or public.staff_can(merchant_id, 'orders')
    or ((driver_id is null) and (fulfillment = 'delivery')
        and (status = any (array['accepted'::public.order_status, 'slaughtering'::public.order_status, 'ready'::public.order_status]))
        and not held
        and public.offer_visible(dispatch_queue, dispatch_at)))));

-- ───────────── Activity log ─────────────
create table if not exists public.activity_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor_id uuid,
  actor_name text,
  actor_role text,           -- admin | merchant_owner | merchant_staff | driver | customer | system
  action text not null,      -- create | update | remove | status | login | logout | control ...
  entity text not null,      -- order | product | offer | merchant | staff | user | payout | wallet | notification | driver | settings | zone | session
  entity_id text,
  summary text not null,
  details jsonb
);
create index if not exists activity_log_at on public.activity_log (at desc);
create index if not exists activity_log_actor on public.activity_log (actor_id, at desc);
create index if not exists activity_log_entity on public.activity_log (entity, entity_id);
alter table public.activity_log enable row level security;  -- read through activity_search only

create or replace function private.role_of(u uuid)
returns text language sql stable security definer set search_path to '' as $$
  select coalesce((select r.role::text from public.user_roles r where r.user_id = u
    order by case r.role when 'admin' then 1 when 'merchant_owner' then 2 when 'merchant_staff' then 3
      when 'driver' then 4 else 5 end limit 1), case when u is null then 'system' else 'customer' end);
$$;

create or replace function private.log(p_action text, p_entity text, p_id text, p_summary text, p_details jsonb default null)
returns void language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid();
begin
  insert into public.activity_log (actor_id, actor_name, actor_role, action, entity, entity_id, summary, details)
  values (me, coalesce((select full_name from public.profiles where id = me), case when me is null then 'النظام' end),
          private.role_of(me), p_action, p_entity, p_id, p_summary, p_details);
exception when others then null;  -- logging must never block the action itself
end $$;

create or replace function private.status_ar(s text)
returns text language sql immutable as $$
  select case s when 'new' then 'جديد' when 'accepted' then 'مقبول' when 'slaughtering' then 'قيد الذبح'
    when 'ready' then 'جاهز' when 'out_for_delivery' then 'في الطريق' when 'delivered' then 'تم التسليم'
    when 'cancelled' then 'ملغي' else s end;
$$;

-- Sign-in / sign-out from the apps.
create or replace function public.log_client_event(p_action text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null or p_action not in ('login','logout') then return; end if;
  perform private.log(p_action, 'session', auth.uid()::text,
    case p_action when 'login' then 'تسجيل دخول' else 'تسجيل خروج' end);
end $$;

-- Generic change tracker.
create or replace function private.track()
returns trigger language plpgsql security definer set search_path to '' as $$
declare n jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
        o jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
        r jsonb := coalesce(n, o); act text; ent text; s text; nm text;
begin
  act := case tg_op when 'INSERT' then 'create' when 'UPDATE' then 'update' else 'remove' end;
  case tg_table_name
  when 'orders' then
    ent := 'order'; nm := '#' || (r->>'code');
    if tg_op = 'INSERT' then s := 'طلب جديد ' || nm || ' بقيمة ' || (r->>'total') || ' د.ب';
    elsif (n->>'deleted_at') is not null and (o->>'deleted_at') is null then act := 'remove'; s := 'حذف الطلب ' || nm;
    elsif (n->>'deleted_at') is null and (o->>'deleted_at') is not null then s := 'استرجاع الطلب المحذوف ' || nm;
    elsif (n->>'status') is distinct from (o->>'status') then act := 'status';
      s := 'الطلب ' || nm || ': ' || private.status_ar(o->>'status') || ' ← ' || private.status_ar(n->>'status');
    elsif (n->>'held') is distinct from (o->>'held') then act := 'control';
      s := case when (n->>'held')::boolean then 'إيقاف الطلب ' else 'استئناف الطلب ' end || nm;
    elsif (n->>'driver_id') is distinct from (o->>'driver_id') then
      s := case when n->>'driver_id' is null then 'إلغاء إسناد المندوب للطلب ' || nm
        else 'إسناد الطلب ' || nm || ' للمندوب ' || coalesce(n->>'driver_name','') end;
    elsif (n->>'merchant_id') is distinct from (o->>'merchant_id') then
      s := 'تحويل الطلب ' || nm || ' إلى ' || coalesce((select name from public.merchants where id = (n->>'merchant_id')::uuid), 'تاجر آخر');
    elsif (n->>'payment_status') is distinct from (o->>'payment_status') then
      s := 'تحديث حالة الدفع للطلب ' || nm;
    elsif (n - array['updated_at','dispatch_at','dispatch_queue','dispatch_notified'])
          is distinct from (o - array['updated_at','dispatch_at','dispatch_queue','dispatch_notified']) then
      s := 'تعديل بيانات الطلب ' || nm;
    else return null; end if;
  when 'products' then ent := 'product'; nm := r->>'name';
    s := case act when 'create' then 'إضافة منتج: ' when 'update' then 'تعديل منتج: ' else 'حذف منتج: ' end || nm;
  when 'offers' then ent := 'offer'; nm := r->>'title';
    s := case act when 'create' then 'إضافة عرض: ' when 'update' then 'تعديل عرض: ' else 'حذف عرض: ' end || coalesce(nm,'');
  when 'merchants' then ent := 'merchant'; nm := r->>'name';
    if tg_op = 'UPDATE' and (n - array['plan_ends']) = (o - array['plan_ends']) then return null; end if;
    s := case act when 'create' then 'إضافة متجر: ' when 'update' then 'تعديل متجر: ' else 'حذف متجر: ' end || nm;
    if tg_op = 'UPDATE' and (n->>'suspended') is distinct from (o->>'suspended') then
      s := case when (n->>'suspended')::boolean then 'إيقاف متجر: ' else 'تفعيل متجر: ' end || nm; end if;
    if tg_op = 'UPDATE' and (n->>'frozen') is distinct from (o->>'frozen') then
      s := case when (n->>'frozen')::boolean then 'تجميد متجر: ' else 'فك تجميد متجر: ' end || nm; end if;
  when 'merchant_staff' then ent := 'staff';
    nm := coalesce((select full_name from public.profiles where id = (r->>'user_id')::uuid), '');
    s := case act when 'create' then 'إضافة موظف: ' when 'update' then 'تعديل صلاحيات موظف: ' else 'حذف موظف: ' end || nm;
  when 'user_roles' then ent := 'user';
    nm := coalesce((select full_name from public.profiles where id = (r->>'user_id')::uuid), '');
    s := case act when 'remove' then 'سحب دور ' else 'منح دور ' end || (r->>'role') || ' للمستخدم ' || nm;
  when 'profiles' then ent := 'user'; nm := coalesce(r->>'full_name','');
    if tg_op = 'INSERT' then s := 'حساب جديد: ' || nm || ' (' || coalesce(r->>'phone','') || ')';
    elsif (n->>'is_active') is distinct from (o->>'is_active') then
      s := case when (n->>'is_active')::boolean then 'تفعيل حساب: ' else 'إيقاف حساب: ' end || nm;
    elsif (n->>'deleted_at') is distinct from (o->>'deleted_at') then s := 'حذف حساب: ' || nm;
    elsif (n - array['language']) is distinct from (o - array['language']) then s := 'تعديل بيانات حساب: ' || nm;
    else return null; end if;
  when 'payout_requests' then ent := 'payout';
    nm := coalesce((select name from public.merchants where id = (r->>'merchant_id')::uuid), '');
    s := case when tg_op = 'INSERT' then 'طلب سحب ' || (r->>'amount') || ' د.ب من ' || nm
      else 'طلب سحب ' || nm || ': ' || (r->>'status') end;
  when 'wallet_ledger' then ent := 'wallet';
    if r->>'kind' in ('order_credit') then return null; end if;
    nm := coalesce((select name from public.merchants where id = (r->>'merchant_id')::uuid), '');
    s := 'حركة محفظة ' || nm || ': ' || (r->>'amount') || ' د.ب ' || coalesce(r->>'note','');
  when 'notifications' then ent := 'notification';
    if r->>'audience' = 'user' then return null; end if;
    s := 'إرسال إشعار (' || (r->>'audience') || '): ' || (r->>'title');
  when 'driver_locations' then ent := 'driver';
    if tg_op = 'UPDATE' and (n->>'online') is not distinct from (o->>'online') then return null; end if;
    nm := coalesce((select full_name from public.profiles where id = (r->>'driver_id')::uuid), '');
    s := case when (r->>'online')::boolean then 'المندوب متاح: ' else 'المندوب غير متاح: ' end || nm;
  when 'platform_settings' then ent := 'settings'; s := 'تعديل إعدادات المنصة';
  when 'delivery_zones' then ent := 'zone';
    s := case act when 'create' then 'إضافة منطقة توصيل: ' when 'update' then 'تعديل منطقة توصيل: ' else 'حذف منطقة توصيل: ' end || coalesce(r->>'name','');
  else return null;
  end case;
  perform private.log(act, ent, coalesce(r->>'id', r->>'user_id', r->>'driver_id'), s,
    case when tg_op = 'UPDATE' then jsonb_build_object('before', o, 'after', n) else jsonb_build_object('row', r) end);
  return null;
exception when others then return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['orders','products','offers','merchants','merchant_staff','user_roles','profiles',
    'payout_requests','wallet_ledger','notifications','driver_locations','platform_settings','delivery_zones'] loop
    begin
      execute format('create trigger zz_activity after insert or update or delete on public.%I for each row execute function private.track()', t);
    exception when duplicate_object then null; when undefined_table then null; end;
  end loop;
end $$;

-- Search the log (admins with permission only).
create or replace function public.activity_search(
  p_q text default null, p_role text default null, p_entity text default null, p_action text default null,
  p_from date default null, p_to date default null, p_actor uuid default null,
  p_limit int default 50, p_offset int default 0)
returns setof public.activity_log language plpgsql stable security definer set search_path to '' as $$
begin
  if not public.can_view_activity() then raise exception 'لا تملك صلاحية عرض سجل الأنشطة'; end if;
  return query select * from public.activity_log a
  where (p_q is null or p_q = '' or a.summary ilike '%' || p_q || '%' or a.actor_name ilike '%' || p_q || '%'
         or a.entity_id = p_q)
    and (p_role is null or a.actor_role = p_role)
    and (p_entity is null or a.entity = p_entity)
    and (p_action is null or a.action = p_action)
    and (p_from is null or a.at >= p_from::timestamptz)
    and (p_to is null or a.at < (p_to + 1)::timestamptz)
    and (p_actor is null or a.actor_id = p_actor)
  order by a.at desc limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;

create or replace function public.activity_stats()
returns json language plpgsql stable security definer set search_path to '' as $$
begin
  if not public.can_view_activity() then raise exception 'لا تملك صلاحية عرض سجل الأنشطة'; end if;
  return json_build_object(
    'today', (select count(*) from public.activity_log where at >= date_trunc('day', now())),
    'week', (select count(*) from public.activity_log where at >= now() - interval '7 days'),
    'actors_today', (select count(distinct actor_id) from public.activity_log where at >= date_trunc('day', now())),
    'by_role', (select coalesce(json_object_agg(actor_role, c), '{}') from
       (select actor_role, count(*) c from public.activity_log where at >= now() - interval '7 days' group by 1) x));
end $$;

-- ───────────── Access management (super admin) ─────────────
create or replace function public.admin_access_list()
returns json language plpgsql stable security definer set search_path to '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return json_build_object(
    'me', (select json_build_object('super', coalesce(a.is_super,false), 'activity', coalesce(a.is_super or a.can_activity,false),
            'has_key', exists (select 1 from private.oc_keys k where k.user_id = auth.uid() and k.active))
           from (select auth.uid() u) x left join public.admin_access a on a.user_id = x.u),
    'master_set', exists (select 1 from private.oc_keys where user_id is null and active),
    'admins', case when public.is_super_admin() then (select coalesce(json_agg(json_build_object(
        'id', r.user_id, 'name', p.full_name, 'phone', p.phone,
        'super', coalesce(a.is_super,false), 'activity', coalesce(a.can_activity,false),
        'has_key', exists (select 1 from private.oc_keys k where k.user_id = r.user_id and k.active)) order by p.full_name), '[]')
      from public.user_roles r join public.profiles p on p.id = r.user_id
      left join public.admin_access a on a.user_id = r.user_id where r.role = 'admin' and p.deleted_at is null) else '[]'::json end);
end $$;

create or replace function public.admin_set_access(p_user uuid, p_super boolean, p_activity boolean)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not public.is_super_admin() then raise exception 'هذا الإجراء للمدير العام فقط'; end if;
  if not exists (select 1 from public.user_roles where user_id = p_user and role = 'admin') then
    raise exception 'المستخدم ليس من الإدارة'; end if;
  if not p_super and (select count(*) from public.admin_access where is_super and user_id <> p_user) = 0 then
    raise exception 'لا بد من بقاء مدير عام واحد على الأقل'; end if;
  insert into public.admin_access (user_id, is_super, can_activity, updated_at, updated_by)
  values (p_user, p_super, p_activity, now(), auth.uid())
  on conflict (user_id) do update set is_super = excluded.is_super, can_activity = excluded.can_activity,
    updated_at = now(), updated_by = auth.uid();
  perform private.log('control', 'user', p_user::text, 'تعديل صلاحيات الإدارة للمستخدم ' ||
    coalesce((select full_name from public.profiles where id = p_user), ''),
    jsonb_build_object('super', p_super, 'activity', p_activity));
end $$;

-- p_user null = master password. p_password null = remove.
create or replace function public.oc_set_password(p_user uuid, p_password text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not public.is_super_admin() then raise exception 'هذا الإجراء للمدير العام فقط'; end if;
  if p_password is not null and length(p_password) < 6 then raise exception 'كلمة المرور 6 أحرف على الأقل'; end if;
  if p_user is not null and not exists (select 1 from public.user_roles where user_id = p_user and role = 'admin') then
    raise exception 'المستخدم ليس من الإدارة'; end if;
  update private.oc_keys set active = false where user_id is not distinct from p_user and active;
  if p_password is not null then
    insert into private.oc_keys (user_id, hash, created_by)
    values (p_user, extensions.crypt(p_password, extensions.gen_salt('bf', 8)), auth.uid());
  end if;
  -- end any open sessions that relied on the old password
  update private.oc_sessions set expires_at = now() where p_user is null or user_id = p_user;
  perform private.log('control', 'settings', coalesce(p_user::text, 'master'),
    case when p_user is null then 'تغيير كلمة المرور الرئيسية لقسم التحكم في الطلبات'
         when p_password is null then 'سحب كلمة مرور التحكم في الطلبات من ' || coalesce((select full_name from public.profiles where id = p_user), '')
         else 'منح كلمة مرور التحكم في الطلبات للمستخدم ' || coalesce((select full_name from public.profiles where id = p_user), '') end);
end $$;

create or replace function public.oc_unlock(p_password text)
returns uuid language plpgsql security definer set search_path to '' as $$
declare ok boolean; t uuid;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if (select count(*) from private.oc_attempts a where a.user_id = auth.uid() and not a.ok and a.at > now() - interval '15 minutes') >= 5 then
    raise exception 'محاولات كثيرة خاطئة. حاول بعد 15 دقيقة'; end if;
  if not exists (select 1 from private.oc_keys where active) then
    raise exception 'لم يحدد المدير العام كلمة مرور لهذا القسم بعد'; end if;
  select exists (select 1 from private.oc_keys k where k.active
      and (k.user_id is null or k.user_id = auth.uid())
      and k.hash = extensions.crypt(p_password, k.hash)) into ok;
  insert into private.oc_attempts (user_id, ok) values (auth.uid(), ok);
  if not ok then
    perform private.log('control', 'session', auth.uid()::text, 'محاولة دخول خاطئة لقسم التحكم في الطلبات');
    raise exception 'كلمة المرور غير صحيحة';
  end if;
  insert into private.oc_sessions (user_id, expires_at) values (auth.uid(), now() + interval '30 minutes') returning token into t;
  perform private.log('control', 'session', auth.uid()::text, 'فتح قسم التحكم في الطلبات');
  return t;
end $$;

create or replace function private.oc_check(p_token uuid)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not public.is_admin() or not exists (select 1 from private.oc_sessions
      where token = p_token and user_id = auth.uid() and expires_at > now()) then
    raise exception 'انتهت جلسة التحكم في الطلبات. أدخل كلمة المرور مرة أخرى';
  end if;
end $$;

-- Edit schedule, address, contact and notes.
create or replace function public.oc_update_order(p_token uuid, p_order uuid, p_fields jsonb)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
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
begin
  perform private.oc_check(p_token);
  return public.set_order_status(p_order, p_status);
end $$;

create or replace function public.oc_hold(p_token uuid, p_order uuid, p_hold boolean, p_reason text default null)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
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

-- Soft delete (hidden from customer, store and driver; kept for the record).
create or replace function public.oc_delete(p_token uuid, p_order uuid, p_reason text, p_restore boolean default false)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders;
begin
  perform private.oc_check(p_token);
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if p_restore then
    update public.orders set deleted_at = null, deleted_reason = null, deleted_by = null, updated_at = now()
    where id = p_order returning * into o;
    return o;
  end if;
  if o.status = 'delivered' then
    raise exception 'لا يمكن حذف طلب تم تسليمه لأن مبالغه دخلت المحافظ'; end if;
  update public.orders set deleted_at = now(), deleted_reason = p_reason, deleted_by = auth.uid(),
    status = 'cancelled', held = false, updated_at = now()
  where id = p_order returning * into o;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'cancelled', auth.uid());
  return o;
end $$;

-- Move an order to another store (before slaughtering starts). It goes back to "new" for the new store to accept.
create or replace function public.oc_transfer_merchant(p_token uuid, p_order uuid, p_merchant uuid, p_reason text default null)
returns public.orders language plpgsql security definer set search_path to '' as $$
declare o public.orders; old_m uuid; mname text;
begin
  perform private.oc_check(p_token);
  select merchant_id into old_m from public.orders where id = p_order;
  if old_m is null then raise exception 'الطلب غير موجود'; end if;
  if old_m = p_merchant then raise exception 'الطلب لدى هذا التاجر أصلاً'; end if;
  select name into mname from public.merchants where id = p_merchant and not suspended;
  if mname is null then raise exception 'التاجر غير موجود أو موقوف'; end if;
  update public.orders set merchant_id = p_merchant, status = 'new', driver_id = null, driver_name = null,
    driver_phone = null, dispatch_at = null, dispatch_queue = null, dispatch_notified = null, updated_at = now()
  where id = p_order and status in ('new','accepted') and deleted_at is null returning * into o;
  if o.id is null then raise exception 'يمكن التحويل قبل بدء الذبح فقط'; end if;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'new', auth.uid());
  insert into public.notifications (audience, merchant_id, title, body, kind) values
    ('merchant', old_m, 'تم تحويل طلب', 'حوّلت الإدارة الطلب #' || o.code || ' إلى متجر آخر' || coalesce(': ' || nullif(p_reason,''), ''), 'order'),
    ('merchant', p_merchant, 'طلب جديد محوّل إليك', 'حوّلت الإدارة إليك الطلب #' || o.code, 'order');
  return o;
end $$;

create or replace function public.oc_assign_driver(p_token uuid, p_order uuid, p_driver uuid)
returns public.orders language plpgsql security definer set search_path to '' as $$
begin
  perform private.oc_check(p_token);
  return public.admin_assign_driver(p_order, p_driver);
end $$;

-- ───────────── A held order cannot move ─────────────
create or replace function public.set_order_status(p_order uuid, p_status order_status)
 returns orders language plpgsql security definer set search_path to '' as $function$
declare
  me uuid := auth.uid(); o public.orders; ok boolean := false; fees numeric;
begin
  select * into o from public.orders where id = p_order for update;
  if o.id is null then raise exception 'الطلب غير موجود'; end if;
  if o.status in ('delivered','cancelled') then raise exception 'الطلب مغلق'; end if;
  if o.held and not public.is_admin() then raise exception 'الطلب موقوف من الإدارة'; end if;

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
end $function$;

create or replace function public.driver_claim(p_order uuid)
 returns orders language plpgsql security definer set search_path to '' as $function$
declare o public.orders; pr public.profiles;
begin
  if not public.has_role('driver') then raise exception 'هذا الحساب ليس مندوباً'; end if;
  select * into pr from public.profiles where id = auth.uid();
  update public.orders set driver_id = auth.uid(), driver_name = pr.full_name, driver_phone = pr.phone, updated_at = now()
  where id = p_order and driver_id is null and fulfillment = 'delivery' and not held and deleted_at is null
    and status in ('accepted','slaughtering','ready')
    and public.offer_visible(dispatch_queue, dispatch_at)
  returning * into o;
  if o.id is null then raise exception 'الطلب لم يعد متاحاً لك'; end if;
  return o;
end $function$;
