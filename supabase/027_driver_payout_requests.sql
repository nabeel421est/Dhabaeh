-- 027: a driver asks the administration to pay out the delivery fees owed to them.
-- The admin pays (this creates the usual fee_payout settlement the driver confirms) or rejects with a reason.
create table if not exists public.driver_payout_requests (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id),
  amount numeric(12,3) not null check (amount > 0),
  note text,
  status text not null default 'requested' check (status in ('requested','paid','rejected','cancelled')),
  reject_reason text,
  settlement_id uuid references public.driver_settlements(id),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid
);
create index if not exists driver_payout_requests_driver on public.driver_payout_requests(driver_id, created_at desc);
alter table public.driver_payout_requests enable row level security;
create policy driver_payout_requests_read on public.driver_payout_requests for select
  using (driver_id = auth.uid() or public.is_admin());
alter publication supabase_realtime add table public.driver_payout_requests;

-- What the driver can still ask for: fees owed minus payouts already on the way.
create or replace function private.driver_fees_open(p_driver uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select sum(amount) from public.driver_ledger
      where driver_id = p_driver and kind in ('fee_earned','fee_paid')), 0)
    - coalesce((select sum(amount) from public.driver_settlements
      where driver_id = p_driver and kind = 'fee_payout' and status = 'pending' and deleted_at is null), 0);
$$;

create or replace function public.driver_request_payout(p_amount numeric, p_note text default null)
returns public.driver_payout_requests language plpgsql security definer set search_path = '' as $$
declare r public.driver_payout_requests; me uuid := auth.uid(); v_open numeric; v_name text;
begin
  if not exists (select 1 from public.user_roles where user_id = me and role = 'driver') then
    raise exception 'للمناديب فقط'; end if;
  if exists (select 1 from public.driver_payout_requests where driver_id = me and status = 'requested') then
    raise exception 'عندك طلب صرف قيد المراجعة'; end if;
  v_open := private.driver_fees_open(me);
  if coalesce(p_amount, 0) <= 0 then raise exception 'المبلغ غير صحيح'; end if;
  if p_amount > v_open then raise exception 'المبلغ أكبر من مستحقاتك (%)', round(v_open, 3); end if;
  insert into public.driver_payout_requests (driver_id, amount, note)
  values (me, round(p_amount, 3), nullif(trim(p_note), '')) returning * into r;
  select full_name into v_name from public.profiles where id = me;
  insert into public.notifications (audience, user_id, title, body, created_by)
  select 'user', ur.user_id, 'طلب صرف مستحقات مندوب',
    coalesce(v_name, 'مندوب') || ' يطلب صرف ' || to_char(r.amount, 'FM999990.000') || ' د.ب', me
  from public.user_roles ur where ur.role = 'admin';
  return r;
end $$;

create or replace function public.driver_cancel_payout_request(p_id uuid)
returns public.driver_payout_requests language plpgsql security definer set search_path = '' as $$
declare r public.driver_payout_requests;
begin
  update public.driver_payout_requests set status = 'cancelled', handled_at = now(), handled_by = auth.uid()
  where id = p_id and driver_id = auth.uid() and status = 'requested' returning * into r;
  if r.id is null then raise exception 'لا يمكن إلغاء هذا الطلب'; end if;
  return r;
end $$;

-- Admin: pay (all or part of) the request, or reject it with a reason.
create or replace function public.admin_handle_payout_request(p_id uuid, p_action text, p_amount numeric default null, p_note text default null)
returns public.driver_payout_requests language plpgsql security definer set search_path = '' as $$
declare r public.driver_payout_requests; s public.driver_settlements;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into r from public.driver_payout_requests where id = p_id for update;
  if r.id is null or r.status <> 'requested' then raise exception 'الطلب غير متاح'; end if;
  if p_action = 'pay' then
    s := public.admin_pay_driver_fees(r.driver_id, coalesce(p_amount, r.amount),
      coalesce(nullif(trim(p_note), ''), 'صرف حسب طلب المندوب'));
    update public.driver_payout_requests set status = 'paid', settlement_id = s.id, amount = s.amount,
      handled_at = now(), handled_by = auth.uid() where id = p_id returning * into r;
    insert into public.notifications (audience, user_id, title, body, created_by)
    values ('user', r.driver_id, 'تمت الموافقة على طلب الصرف',
      'صرفت لك الإدارة ' || to_char(r.amount, 'FM999990.000') || ' د.ب، أكد الاستلام من محفظتك', auth.uid());
  elsif p_action = 'reject' then
    if nullif(trim(p_note), '') is null then raise exception 'اكتب سبب الرفض'; end if;
    update public.driver_payout_requests set status = 'rejected', reject_reason = trim(p_note),
      handled_at = now(), handled_by = auth.uid() where id = p_id returning * into r;
    insert into public.notifications (audience, user_id, title, body, created_by)
    values ('user', r.driver_id, 'رُفض طلب الصرف', trim(p_note), auth.uid());
  else
    raise exception 'إجراء غير معروف';
  end if;
  return r;
end $$;

grant execute on function public.driver_request_payout(numeric, text) to authenticated;
grant execute on function public.driver_cancel_payout_request(uuid) to authenticated;
grant execute on function public.admin_handle_payout_request(uuid, text, numeric, text) to authenticated;
