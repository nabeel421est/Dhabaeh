-- Merchant renew / upgrade requests with a bank-transfer receipt, reviewed by admin.
create type public.plan_request_status as enum ('pending','approved','rejected');

create table public.subscription_requests (
  id uuid primary key default gen_random_uuid(),
  code bigint generated always as identity,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  kind text not null check (kind in ('renew','upgrade')),
  from_plan public.plan_type not null,
  plan public.plan_type not null,
  amount numeric(12,3) not null default 0,
  receipt_path text,
  transfer_ref text,
  note text,
  status public.plan_request_status not null default 'pending',
  admin_note text,
  new_ends date,
  requested_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.subscription_requests (merchant_id, created_at desc);
alter table public.subscription_requests enable row level security;
create policy subreq_read on public.subscription_requests for select to authenticated
  using (public.is_admin() or public.is_merchant_owner(merchant_id));

-- owner submits a request; amount comes from platform settings, never from the client
create or replace function public.merchant_request_plan(p_merchant uuid, p_plan public.plan_type, p_receipt text, p_ref text, p_note text)
returns public.subscription_requests
language plpgsql security definer set search_path = '' as $$
declare s public.platform_settings; m public.merchants; r public.subscription_requests; v_amt numeric;
begin
  if not public.is_merchant_owner(p_merchant) then raise exception 'طلب الاشتراك لمالك المتجر فقط'; end if;
  select * into m from public.merchants where id = p_merchant;
  if exists (select 1 from public.subscription_requests where merchant_id = p_merchant and status = 'pending') then
    raise exception 'لديك طلب اشتراك قيد المراجعة'; end if;
  select * into s from public.platform_settings where id = 1;
  v_amt := case p_plan when 'trial' then 0 when 'monthly' then s.monthly_price else s.yearly_price end;
  if v_amt > 0 and coalesce(p_receipt, '') = '' then raise exception 'ارفع إيصال التحويل'; end if;
  if p_receipt is not null and p_receipt <> '' and split_part(p_receipt, '/', 1) <> auth.uid()::text then
    raise exception 'مسار الإيصال غير صالح'; end if;
  insert into public.subscription_requests (merchant_id, kind, from_plan, plan, amount, receipt_path, transfer_ref, note, requested_by)
  values (p_merchant, case when p_plan = m.plan then 'renew' else 'upgrade' end, m.plan, p_plan, v_amt,
          nullif(p_receipt, ''), nullif(p_ref, ''), nullif(p_note, ''), auth.uid())
  returning * into r;
  return r;
end $$;

-- admin approves (applies the plan, extending from the later of today or the current end) or rejects
create or replace function public.admin_review_plan_request(p_request uuid, p_approve boolean, p_note text)
returns public.subscription_requests
language plpgsql security definer set search_path = '' as $$
declare r public.subscription_requests; m public.merchants; v_start date; v_ends date;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into r from public.subscription_requests where id = p_request for update;
  if r.id is null or r.status <> 'pending' then raise exception 'الطلب غير قابل للمعالجة'; end if;
  if not p_approve and coalesce(trim(p_note), '') = '' then raise exception 'اكتب سبب الرفض'; end if;
  if p_approve then
    select * into m from public.merchants where id = r.merchant_id;
    v_start := case when r.kind = 'renew' then greatest(current_date, m.plan_ends) else current_date end;
    v_ends := case r.plan when 'trial' then v_start + (select trial_days from public.platform_settings where id = 1)
      when 'monthly' then (v_start + interval '1 month')::date else (v_start + interval '1 year')::date end;
    update public.merchants set plan = r.plan, plan_ends = v_ends where id = r.merchant_id;
    insert into public.subscriptions (merchant_id, plan, starts, ends, amount) values (r.merchant_id, r.plan, v_start, v_ends, r.amount);
    if r.amount > 0 then insert into public.platform_ledger (kind, amount, merchant_id) values ('subscription', r.amount, r.merchant_id); end if;
  end if;
  update public.subscription_requests set status = case when p_approve then 'approved'::public.plan_request_status else 'rejected' end,
    admin_note = nullif(trim(p_note), ''), new_ends = v_ends, reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_request returning * into r;
  insert into public.notifications (audience, merchant_id, title, body, created_by)
  values ('merchant', r.merchant_id,
    case when p_approve then 'تم تفعيل اشتراكك' else 'تم رفض طلب الاشتراك #' || r.code end,
    case when p_approve then 'اشتراكك ساري حتى ' || to_char(v_ends, 'YYYY-MM-DD') else coalesce(r.admin_note, '') end,
    auth.uid());
  return r;
end $$;

grant execute on function public.merchant_request_plan(uuid, public.plan_type, text, text, text) to authenticated;
grant execute on function public.admin_review_plan_request(uuid, boolean, text) to authenticated;
alter publication supabase_realtime add table public.subscription_requests;
