-- Fixes to admin_control: transfer resets dispatch queue to empty; a wrong password returns null
-- (instead of raising) so the failed attempt is kept and the lockout counts it.

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
    driver_phone = null, dispatch_at = null, dispatch_queue = '{}'::uuid[], dispatch_notified = null, updated_at = now()
  where id = p_order and status in ('new','accepted') and deleted_at is null returning * into o;
  if o.id is null then raise exception 'يمكن التحويل قبل بدء الذبح فقط'; end if;
  insert into public.order_events (order_id, status, by_user) values (o.id, 'new', auth.uid());
  insert into public.notifications (audience, merchant_id, title, body, kind) values
    ('merchant', old_m, 'تم تحويل طلب', 'حوّلت الإدارة الطلب #' || o.code || ' إلى متجر آخر' || coalesce(': ' || nullif(p_reason,''), ''), 'order'),
    ('merchant', p_merchant, 'طلب جديد محوّل إليك', 'حوّلت الإدارة إليك الطلب #' || o.code, 'order');
  perform private.log('control', 'order', o.id::text, 'تحويل الطلب #' || o.code || ' من ' ||
    coalesce((select name from public.merchants where id = old_m), '') || ' إلى ' || mname ||
    coalesce(' (' || nullif(p_reason,'') || ')', ''));
  return o;
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
      and k.hash = extensions.crypt(coalesce(p_password,''), k.hash)) into ok;
  insert into private.oc_attempts (user_id, ok) values (auth.uid(), ok);
  if not ok then
    perform private.log('control', 'session', auth.uid()::text, 'محاولة دخول خاطئة لقسم التحكم في الطلبات');
    return null;
  end if;
  insert into private.oc_sessions (user_id, expires_at) values (auth.uid(), now() + interval '30 minutes') returning token into t;
  perform private.log('control', 'session', auth.uid()::text, 'فتح قسم التحكم في الطلبات');
  return t;
end $$;

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
  order by a.at desc, a.id desc limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;
