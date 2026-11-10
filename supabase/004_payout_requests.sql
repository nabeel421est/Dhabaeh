-- Merchant withdrawal requests and their stages.
-- requested -> under_review -> approved (with a transfer date) -> transferred, or rejected at any point before transfer.
create type public.payout_status as enum ('requested', 'under_review', 'approved', 'transferred', 'rejected');

create table public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  code bigint generated always as identity,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  amount numeric(12,3) not null check (amount > 0),
  status public.payout_status not null default 'requested',
  note text,                         -- merchant's note
  admin_note text,                   -- shown to the merchant (reason, instructions)
  scheduled_date date,               -- planned transfer date, set on approval
  transfer_ref text,                 -- bank reference, set on transfer
  iban text, account_name text, bank_name text,  -- bank details at the time of the request
  requested_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.payout_requests (merchant_id, created_at desc);
create index on public.payout_requests (status);

create table public.payout_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.payout_requests(id) on delete cascade,
  status public.payout_status not null,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index on public.payout_events (request_id, created_at);

alter table public.payout_requests enable row level security;
alter table public.payout_events enable row level security;

create policy payout_requests_read on public.payout_requests for select to authenticated
  using (public.is_admin() or public.is_merchant_owner(merchant_id) or public.staff_can(merchant_id, 'wallet'));
create policy payout_events_read on public.payout_events for select to authenticated
  using (exists (select 1 from public.payout_requests r where r.id = request_id
    and (public.is_admin() or public.is_merchant_owner(r.merchant_id) or public.staff_can(r.merchant_id, 'wallet'))));

-- Money still claimable: balance minus requests that are open (not yet transferred or rejected).
create or replace function public.merchant_available(p_merchant uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select sum(amount) from public.wallet_ledger where merchant_id = p_merchant), 0)
       - coalesce((select sum(amount) from public.payout_requests where merchant_id = p_merchant
                   and status in ('requested', 'under_review', 'approved')), 0)
$$;

create or replace function public.merchant_request_payout(p_merchant uuid, p_amount numeric, p_note text default null)
returns public.payout_requests
language plpgsql security definer set search_path = '' as $$
declare m public.merchants; d public.merchant_details; r public.payout_requests; avail numeric;
begin
  if not public.is_merchant_owner(p_merchant) then
    raise exception 'طلب السحب لمالك المتجر فقط';
  end if;
  select * into m from public.merchants where id = p_merchant for update;
  if m.frozen then raise exception 'محفظة المتجر مجمّدة، تواصل مع الإدارة'; end if;
  avail := public.merchant_available(p_merchant);
  if p_amount is null or p_amount <= 0 then raise exception 'اكتب مبلغاً صحيحاً'; end if;
  if p_amount > avail then raise exception 'المبلغ أكبر من الرصيد المتاح للسحب (%)', avail; end if;
  select * into d from public.merchant_details where merchant_id = p_merchant;
  insert into public.payout_requests (merchant_id, amount, note, iban, account_name, bank_name, requested_by)
  values (p_merchant, p_amount, nullif(trim(p_note), ''), d.iban, d.account_name, d.bank_name, auth.uid())
  returning * into r;
  insert into public.payout_events (request_id, status, created_by) values (r.id, 'requested', auth.uid());
  return r;
end $$;

-- Admin moves a request forward. Transferring debits the wallet in the same step.
create or replace function public.admin_process_payout(p_request uuid, p_status public.payout_status,
  p_note text default null, p_date date default null, p_ref text default null)
returns public.payout_requests
language plpgsql security definer set search_path = '' as $$
declare r public.payout_requests; m public.merchants; bal numeric;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into r from public.payout_requests where id = p_request for update;
  if r.id is null then raise exception 'الطلب غير موجود'; end if;
  if r.status in ('transferred', 'rejected') then raise exception 'الطلب مُغلق'; end if;
  if p_status = 'requested' then raise exception 'حالة غير صحيحة'; end if;
  if p_status = 'approved' and coalesce(p_date, r.scheduled_date) is null then raise exception 'حدّد موعد التحويل'; end if;
  if p_status = 'rejected' and nullif(trim(p_note), '') is null then raise exception 'اكتب سبب الرفض'; end if;
  if p_status = 'transferred' then
    select * into m from public.merchants where id = r.merchant_id for update;
    if m.frozen then raise exception 'محفظة المتجر مجمّدة'; end if;
    select coalesce(sum(amount), 0) into bal from public.wallet_ledger where merchant_id = r.merchant_id;
    if r.amount > bal then raise exception 'رصيد التاجر أقل من المبلغ المطلوب'; end if;
    insert into public.wallet_ledger (merchant_id, kind, amount, note, created_by)
    values (r.merchant_id, 'payout', -r.amount,
            'طلب سحب #' || r.code || coalesce(' · حوالة ' || nullif(trim(p_ref), ''), ''), auth.uid());
  end if;
  update public.payout_requests set
    status = p_status,
    admin_note = coalesce(nullif(trim(p_note), ''), admin_note),
    scheduled_date = coalesce(p_date, scheduled_date),
    transfer_ref = coalesce(nullif(trim(p_ref), ''), transfer_ref),
    updated_at = now()
  where id = p_request returning * into r;
  insert into public.payout_events (request_id, status, note, created_by)
  values (r.id, p_status, nullif(trim(p_note), ''), auth.uid());
  insert into public.notifications (audience, merchant_id, title, body, created_by)
  values ('merchant', r.merchant_id, 'طلب السحب #' || r.code || ': ' || case p_status
      when 'under_review' then 'قيد المراجعة'
      when 'approved' then 'تمت الموافقة، التحويل يوم ' || to_char(r.scheduled_date, 'DD/MM/YYYY')
      when 'transferred' then 'تم التحويل'
      else 'مرفوض' end,
    coalesce(nullif(trim(p_note), ''), ''), auth.uid());
  return r;
end $$;

alter publication supabase_realtime add table public.payout_requests, public.payout_events;
