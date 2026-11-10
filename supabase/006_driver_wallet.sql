-- Driver wallet: cash collected on cash-on-delivery orders (owed to the platform)
-- and delivery fees earned (owed to the driver), plus admin settlements of both.
create table public.driver_ledger (
  id bigint generated always as identity primary key,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('cash_collected','cash_handover','fee_earned','fee_paid')),
  amount numeric(12,3) not null,
  order_id uuid references public.orders(id) on delete set null,
  settlement_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index on public.driver_ledger (driver_id, created_at desc);
create unique index driver_ledger_once on public.driver_ledger (order_id, kind) where order_id is not null;

create table public.driver_settlements (
  id uuid primary key default gen_random_uuid(),
  code bigint generated always as identity,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('cash_receipt','fee_payout')),
  amount numeric(12,3) not null check (amount > 0),
  status text not null default 'confirmed' check (status in ('pending','confirmed')),
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);
create index on public.driver_settlements (driver_id, created_at desc);

alter table public.driver_ledger enable row level security;
alter table public.driver_settlements enable row level security;
create policy driver_ledger_read on public.driver_ledger for select to authenticated
  using (public.is_admin() or driver_id = auth.uid());
create policy driver_settlements_read on public.driver_settlements for select to authenticated
  using (public.is_admin() or driver_id = auth.uid());

-- when an order with a driver is delivered: fee goes to the driver, cash (if COD) is held by the driver
create or replace function public.driver_on_delivered() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' and new.driver_id is not null then
    insert into public.driver_ledger (driver_id, kind, amount, order_id, note)
    values (new.driver_id, 'fee_earned', new.delivery_fee, new.id, 'رسوم توصيل طلب #' || new.code)
    on conflict do nothing;
    if new.payment_method = 'cash' then
      insert into public.driver_ledger (driver_id, kind, amount, order_id, note)
      values (new.driver_id, 'cash_collected', new.total, new.id, 'تحصيل نقدي طلب #' || new.code)
      on conflict do nothing;
    end if;
  end if;
  return new;
end $$;
create trigger orders_driver_delivered after update of status on public.orders
  for each row execute function public.driver_on_delivered();

-- backfill orders already delivered
insert into public.driver_ledger (driver_id, kind, amount, order_id, note, created_at)
select driver_id, 'fee_earned', delivery_fee, id, 'رسوم توصيل طلب #' || code, updated_at
from public.orders where status = 'delivered' and driver_id is not null
on conflict do nothing;
insert into public.driver_ledger (driver_id, kind, amount, order_id, note, created_at)
select driver_id, 'cash_collected', total, id, 'تحصيل نقدي طلب #' || code, updated_at
from public.orders where status = 'delivered' and driver_id is not null and payment_method = 'cash'
on conflict do nothing;

-- balances per driver
create or replace function public.driver_balance(p_driver uuid)
returns table (cash_held numeric, fees_due numeric, pending_payout numeric)
language sql stable security definer set search_path = '' as $$
  select
    coalesce(sum(amount) filter (where kind in ('cash_collected','cash_handover')), 0),
    coalesce(sum(amount) filter (where kind in ('fee_earned','fee_paid')), 0),
    (select coalesce(sum(amount), 0) from public.driver_settlements
      where driver_id = p_driver and kind = 'fee_payout' and status = 'pending')
  from public.driver_ledger
  where driver_id = p_driver and (public.is_admin() or p_driver = auth.uid());
$$;

create or replace function public.admin_driver_balances()
returns table (driver_id uuid, full_name text, phone text, cash_held numeric, fees_due numeric,
  pending_payout numeric, cash_orders bigint, delivered bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return query
  select p.id, p.full_name, p.phone,
    coalesce((select sum(l.amount) from public.driver_ledger l where l.driver_id = p.id and l.kind in ('cash_collected','cash_handover')), 0),
    coalesce((select sum(l.amount) from public.driver_ledger l where l.driver_id = p.id and l.kind in ('fee_earned','fee_paid')), 0),
    coalesce((select sum(s.amount) from public.driver_settlements s where s.driver_id = p.id and s.kind = 'fee_payout' and s.status = 'pending'), 0),
    (select count(*) from public.driver_ledger l where l.driver_id = p.id and l.kind = 'cash_collected'),
    (select count(*) from public.driver_ledger l where l.driver_id = p.id and l.kind = 'fee_earned')
  from public.profiles p
  where exists (select 1 from public.user_roles r where r.user_id = p.id and r.role = 'driver')
  order by p.full_name;
end $$;

-- admin receives cash collected by a driver (effective immediately)
create or replace function public.admin_receive_cash(p_driver uuid, p_amount numeric, p_note text)
returns public.driver_settlements
language plpgsql security definer set search_path = '' as $$
declare s public.driver_settlements; v_held numeric;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select coalesce(sum(amount), 0) into v_held from public.driver_ledger
    where driver_id = p_driver and kind in ('cash_collected','cash_handover');
  if coalesce(p_amount, 0) <= 0 then raise exception 'المبلغ غير صحيح'; end if;
  if p_amount > v_held then raise exception 'المبلغ أكبر من النقد الذي بحوزة المندوب'; end if;
  insert into public.driver_settlements (driver_id, kind, amount, status, note, created_by, confirmed_at)
  values (p_driver, 'cash_receipt', p_amount, 'confirmed', nullif(trim(p_note), ''), auth.uid(), now())
  returning * into s;
  insert into public.driver_ledger (driver_id, kind, amount, settlement_id, note)
  values (p_driver, 'cash_handover', -p_amount, s.id, 'تسليم نقد للإدارة #' || s.code);
  insert into public.notifications (audience, title, body, created_by, user_id)
  values ('user', 'استلمت الإدارة ' || p_amount || ' د.ب', 'تم تسجيل تسليمك للمبالغ المحصلة نقداً', auth.uid(), p_driver);
  return s;
end $$;

-- admin hands delivery fees to a driver; the driver must confirm receipt in the app
create or replace function public.admin_pay_driver_fees(p_driver uuid, p_amount numeric, p_note text)
returns public.driver_settlements
language plpgsql security definer set search_path = '' as $$
declare s public.driver_settlements; v_due numeric; v_pending numeric;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select coalesce(sum(amount), 0) into v_due from public.driver_ledger
    where driver_id = p_driver and kind in ('fee_earned','fee_paid');
  select coalesce(sum(amount), 0) into v_pending from public.driver_settlements
    where driver_id = p_driver and kind = 'fee_payout' and status = 'pending';
  if coalesce(p_amount, 0) <= 0 then raise exception 'المبلغ غير صحيح'; end if;
  if p_amount > v_due - v_pending then raise exception 'المبلغ أكبر من الرسوم المستحقة للمندوب'; end if;
  insert into public.driver_settlements (driver_id, kind, amount, status, note, created_by)
  values (p_driver, 'fee_payout', p_amount, 'pending', nullif(trim(p_note), ''), auth.uid())
  returning * into s;
  return s;
end $$;

create or replace function public.driver_confirm_payout(p_settlement uuid)
returns public.driver_settlements
language plpgsql security definer set search_path = '' as $$
declare s public.driver_settlements;
begin
  update public.driver_settlements set status = 'confirmed', confirmed_at = now()
  where id = p_settlement and driver_id = auth.uid() and kind = 'fee_payout' and status = 'pending'
  returning * into s;
  if s.id is null then raise exception 'لا يوجد تسليم بانتظار تأكيدك'; end if;
  insert into public.driver_ledger (driver_id, kind, amount, settlement_id, note)
  values (s.driver_id, 'fee_paid', -s.amount, s.id, 'استلام رسوم التوصيل #' || s.code);
  return s;
end $$;

alter publication supabase_realtime add table public.driver_ledger, public.driver_settlements;
