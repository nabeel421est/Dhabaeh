-- 021: التحكم الإداري في الحركات المالية
-- Settlements (cash receipts + driver fee payouts), payout requests, subscriptions
-- and platform ledger rows can be edited, transferred, frozen and soft-deleted
-- from inside the password-locked admin control. Money effects are kept in step
-- by "sync" functions that post the difference to the linked ledger rows, so all
-- existing balance sums stay plain sums.

alter table public.driver_settlements
  add column if not exists frozen boolean not null default false,
  add column if not exists frozen_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists ctl_note text;
alter table public.payout_requests
  add column if not exists frozen boolean not null default false,
  add column if not exists frozen_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists ctl_note text;
alter table public.subscriptions
  add column if not exists frozen boolean not null default false,
  add column if not exists frozen_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists ctl_note text;
alter table public.platform_ledger
  add column if not exists note text,
  add column if not exists ref_id uuid,
  add column if not exists frozen boolean not null default false,
  add column if not exists frozen_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists orig_amount numeric,
  add column if not exists orig_merchant uuid;
alter table public.wallet_ledger
  add column if not exists ref_id uuid,
  add column if not exists pl_ref bigint;

create index if not exists wallet_ledger_ref_idx on public.wallet_ledger (ref_id);
create index if not exists wallet_ledger_pl_ref_idx on public.wallet_ledger (pl_ref);
create index if not exists platform_ledger_ref_idx on public.platform_ledger (ref_id);
create index if not exists driver_ledger_settlement_idx on public.driver_ledger (settlement_id);

-- Backfill links for existing rows.
update public.wallet_ledger w set ref_id = p.id
from public.payout_requests p
where w.kind = 'payout' and w.ref_id is null and w.merchant_id = p.merchant_id
  and (w.note = 'طلب سحب #' || p.code or w.note like 'طلب سحب #' || p.code || ' ·%');

update public.platform_ledger l set ref_id = s.id
from public.subscriptions s
where l.kind = 'subscription' and l.ref_id is null and l.merchant_id = s.merchant_id
  and l.amount = s.amount and abs(extract(epoch from l.created_at - s.created_at)) < 2
  and not exists (select 1 from public.platform_ledger x where x.ref_id = s.id);

-- Keep future rows linked.
create or replace function private.link_wallet_payout() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'payout' and new.ref_id is null and new.note like 'طلب سحب #%' then
    select p.id into new.ref_id from public.payout_requests p
    where p.merchant_id = new.merchant_id
      and (new.note = 'طلب سحب #' || p.code or new.note like 'طلب سحب #' || p.code || ' ·%')
    limit 1;
  end if;
  return new;
end $$;
create or replace trigger link_payout before insert on public.wallet_ledger
  for each row execute function private.link_wallet_payout();

create or replace function private.link_platform_sub() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'subscription' and new.ref_id is null then
    select s.id into new.ref_id from public.subscriptions s
    where s.merchant_id = new.merchant_id and s.amount = new.amount
      and s.created_at >= now() - interval '5 seconds'
      and not exists (select 1 from public.platform_ledger x where x.ref_id = s.id)
    order by s.created_at desc limit 1;
  end if;
  return new;
end $$;
create or replace trigger link_sub before insert on public.platform_ledger
  for each row execute function private.link_platform_sub();

-- Frozen or deleted records cannot move through the normal flows.
create or replace function private.guard_ctl_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('dh.ctl', true), '') <> '1'
     and (old.frozen or old.deleted_at is not null)
     and new.status is distinct from old.status then
    raise exception 'هذه الحركة مجمّدة أو محذوفة من التحكم الإداري';
  end if;
  return new;
end $$;
create or replace trigger guard_ctl before update on public.payout_requests
  for each row execute function private.guard_ctl_status();
create or replace trigger guard_ctl before update on public.driver_settlements
  for each row execute function private.guard_ctl_status();

-- Pending amounts ignore deleted records.
create or replace function public.merchant_available(p_merchant uuid) returns numeric
language sql security definer set search_path = '' as $$
  select coalesce((select sum(amount) from public.wallet_ledger where merchant_id = p_merchant), 0)
       - coalesce((select sum(amount) from public.payout_requests where merchant_id = p_merchant
                   and status in ('requested', 'under_review', 'approved') and deleted_at is null), 0)
$$;

create or replace function public.driver_balance(p_driver uuid)
returns table(cash_held numeric, fees_due numeric, pending_payout numeric)
language sql security definer set search_path = '' as $$
  select
    coalesce(sum(amount) filter (where kind in ('cash_collected','cash_handover')), 0),
    coalesce(sum(amount) filter (where kind in ('fee_earned','fee_paid')), 0),
    (select coalesce(sum(amount), 0) from public.driver_settlements
      where driver_id = p_driver and kind = 'fee_payout' and status = 'pending' and deleted_at is null)
  from public.driver_ledger
  where driver_id = p_driver and (public.is_admin() or p_driver = auth.uid());
$$;

create or replace function public.admin_driver_balances()
returns table(driver_id uuid, full_name text, phone text, cash_held numeric, fees_due numeric,
              pending_payout numeric, cash_orders bigint, delivered bigint)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return query
  select p.id, p.full_name, p.phone,
    coalesce((select sum(l.amount) from public.driver_ledger l where l.driver_id = p.id and l.kind in ('cash_collected','cash_handover')), 0),
    coalesce((select sum(l.amount) from public.driver_ledger l where l.driver_id = p.id and l.kind in ('fee_earned','fee_paid')), 0),
    coalesce((select sum(s.amount) from public.driver_settlements s where s.driver_id = p.id and s.kind = 'fee_payout' and s.status = 'pending' and s.deleted_at is null), 0),
    (select count(*) from public.driver_ledger l where l.driver_id = p.id and l.kind = 'cash_collected'),
    (select count(*) from public.driver_ledger l where l.driver_id = p.id and l.kind = 'fee_earned')
  from public.profiles p
  where exists (select 1 from public.user_roles r where r.user_id = p.id and r.role = 'driver')
  order by p.full_name;
end $$;

create or replace function public.admin_pay_driver_fees(p_driver uuid, p_amount numeric, p_note text)
returns public.driver_settlements
language plpgsql security definer set search_path = '' as $$
declare s public.driver_settlements; v_due numeric; v_pending numeric;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select coalesce(sum(amount), 0) into v_due from public.driver_ledger
    where driver_id = p_driver and kind in ('fee_earned','fee_paid');
  select coalesce(sum(amount), 0) into v_pending from public.driver_settlements
    where driver_id = p_driver and kind = 'fee_payout' and status = 'pending' and deleted_at is null;
  if coalesce(p_amount, 0) <= 0 then raise exception 'المبلغ غير صحيح'; end if;
  if p_amount > v_due - v_pending then raise exception 'المبلغ أكبر من الرسوم المستحقة للمندوب'; end if;
  insert into public.driver_settlements (driver_id, kind, amount, status, note, created_by)
  values (p_driver, 'fee_payout', p_amount, 'pending', nullif(trim(p_note), ''), auth.uid())
  returning * into s;
  return s;
end $$;

-- ---------- sync: make linked ledger rows match the record ----------

create or replace function private.ctl_sync_settlement(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare s public.driver_settlements; k text;
begin
  select * into s from public.driver_settlements where id = p_id;
  k := case s.kind when 'cash_receipt' then 'cash_handover' else 'fee_paid' end;
  insert into public.driver_ledger (driver_id, kind, amount, settlement_id, note)
  select coalesce(h.driver_id, w.driver_id), k, coalesce(w.a, 0) - coalesce(h.a, 0), s.id,
         'تعديل إداري للحركة #' || s.code
  from (select driver_id, sum(amount) a from public.driver_ledger where settlement_id = s.id group by driver_id) h
  full join (select s.driver_id driver_id, -s.amount a
             where s.status = 'confirmed' and not s.frozen and s.deleted_at is null) w
    on h.driver_id = w.driver_id
  where coalesce(w.a, 0) - coalesce(h.a, 0) <> 0;
end $$;

create or replace function private.ctl_sync_payout(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare p public.payout_requests;
begin
  select * into p from public.payout_requests where id = p_id;
  insert into public.wallet_ledger (merchant_id, kind, amount, note, created_by, ref_id)
  select coalesce(h.merchant_id, w.merchant_id), 'payout', coalesce(w.a, 0) - coalesce(h.a, 0),
         'تعديل إداري لطلب السحب #' || p.code, auth.uid(), p.id
  from (select merchant_id, sum(amount) a from public.wallet_ledger where ref_id = p.id group by merchant_id) h
  full join (select p.merchant_id merchant_id, -p.amount a
             where p.status = 'transferred' and not p.frozen and p.deleted_at is null) w
    on h.merchant_id = w.merchant_id
  where coalesce(w.a, 0) - coalesce(h.a, 0) <> 0;
end $$;

create or replace function private.ctl_sync_plan(p_merchant uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare s public.subscriptions;
begin
  if p_merchant is null then return; end if;
  select * into s from public.subscriptions
  where merchant_id = p_merchant and not frozen and deleted_at is null
  order by ends desc nulls last, created_at desc limit 1;
  if s.id is not null then
    update public.merchants set plan = s.plan, plan_ends = s.ends where id = p_merchant;
  end if;
end $$;

create or replace function private.ctl_sync_subscription(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare s public.subscriptions;
begin
  select * into s from public.subscriptions where id = p_id;
  update public.platform_ledger set amount = s.amount, merchant_id = s.merchant_id,
    frozen = s.frozen, deleted_at = s.deleted_at,
    note = 'اشتراك ' || s.plan || ' · معدّل إدارياً'
  where ref_id = s.id;
  if not found and s.amount > 0 then
    insert into public.platform_ledger (kind, amount, merchant_id, ref_id, frozen, deleted_at, note)
    values ('subscription', s.amount, s.merchant_id, s.id, s.frozen, s.deleted_at, 'اشتراك ' || s.plan);
  end if;
end $$;

-- A merchant commission row also changes what the merchant kept: mirror it.
create or replace function private.ctl_sync_platform(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare l public.platform_ledger; act boolean;
begin
  select * into l from public.platform_ledger where id = p_id;
  if l.kind <> 'merchant_commission' or l.orig_merchant is null then return; end if;
  act := not l.frozen and l.deleted_at is null;
  insert into public.wallet_ledger (merchant_id, kind, amount, note, created_by, pl_ref, order_id)
  select coalesce(h.m, w.m), 'adjustment', coalesce(w.a, 0) - coalesce(h.a, 0),
         'تعديل إداري لعمولة المنصة', auth.uid(), l.id, l.order_id
  from (select merchant_id m, sum(amount) a from public.wallet_ledger where pl_ref = l.id group by merchant_id) h
  full join (
    select m, sum(a) a from (
      select l.orig_merchant m, l.orig_amount a
      union all
      select l.merchant_id, -l.amount where act and l.merchant_id is not null
    ) z group by m
  ) w on h.m = w.m
  where coalesce(w.a, 0) - coalesce(h.a, 0) <> 0;
end $$;

-- ---------- the one control entry point ----------

create or replace function public.ctl_txn(p_token uuid, p_type text, p_id text, p_action text,
                                          p_data jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  perm text := case p_action when 'edit' then 'edit' when 'transfer' then 'transfer'
                             when 'freeze' then 'hold' when 'delete' then 'delete' end;
  d jsonb := coalesce(p_data, '{}'::jsonb);
  v_on boolean := coalesce((d->>'on')::boolean, true);
  v_reason text := nullif(trim(d->>'reason'), '');
  v_to uuid := nullif(d->>'to', '')::uuid;
  v_amt numeric := nullif(d->>'amount', '')::numeric;
  old_m uuid; r jsonb;
begin
  perform private.oc_check(p_token);
  if perm is null then raise exception 'إجراء غير معروف'; end if;
  perform private.oc_can(perm);
  if v_amt is not null and (v_amt < 0 or (v_amt = 0 and p_type in ('settlement', 'payout'))) then raise exception 'المبلغ يجب أن يكون أكبر من صفر'; end if;
  perform set_config('dh.ctl', '1', true);

  if p_type = 'settlement' then
    if p_action = 'transfer' then
      if v_to is null or not exists (select 1 from public.user_roles where user_id = v_to and role = 'driver')
        then raise exception 'اختر مندوباً'; end if;
    end if;
    update public.driver_settlements s set
      amount = case when p_action = 'edit' then coalesce(v_amt, s.amount) else s.amount end,
      note = case when p_action = 'edit' and d ? 'note' then nullif(trim(d->>'note'), '') else s.note end,
      driver_id = case when p_action = 'transfer' then v_to else s.driver_id end,
      frozen = case when p_action = 'freeze' then v_on else s.frozen end,
      frozen_reason = case when p_action = 'freeze' then case when v_on then v_reason end else s.frozen_reason end,
      deleted_at = case when p_action = 'delete' then case when v_on then now() end else s.deleted_at end,
      ctl_note = coalesce(v_reason, s.ctl_note)
    where id = p_id::uuid returning to_jsonb(s.*) into r;
    if r is null then raise exception 'الحركة غير موجودة'; end if;
    perform private.ctl_sync_settlement(p_id::uuid);

  elsif p_type = 'payout' then
    if p_action = 'transfer' and (v_to is null or not exists (select 1 from public.merchants where id = v_to))
      then raise exception 'اختر متجراً'; end if;
    update public.payout_requests p set
      amount = case when p_action = 'edit' then coalesce(v_amt, p.amount) else p.amount end,
      admin_note = case when p_action = 'edit' and d ? 'note' then nullif(trim(d->>'note'), '') else p.admin_note end,
      transfer_ref = case when p_action = 'edit' and d ? 'ref' then nullif(trim(d->>'ref'), '') else p.transfer_ref end,
      scheduled_date = case when p_action = 'edit' and d ? 'date' then nullif(d->>'date', '')::date else p.scheduled_date end,
      merchant_id = case when p_action = 'transfer' then v_to else p.merchant_id end,
      frozen = case when p_action = 'freeze' then v_on else p.frozen end,
      frozen_reason = case when p_action = 'freeze' then case when v_on then v_reason end else p.frozen_reason end,
      deleted_at = case when p_action = 'delete' then case when v_on then now() end else p.deleted_at end,
      ctl_note = coalesce(v_reason, p.ctl_note), updated_at = now()
    where id = p_id::uuid returning to_jsonb(p.*) into r;
    if r is null then raise exception 'الطلب غير موجود'; end if;
    perform private.ctl_sync_payout(p_id::uuid);

  elsif p_type = 'subscription' then
    if p_action = 'transfer' and (v_to is null or not exists (select 1 from public.merchants where id = v_to))
      then raise exception 'اختر متجراً'; end if;
    select merchant_id into old_m from public.subscriptions where id = p_id::uuid;
    update public.subscriptions s set
      amount = case when p_action = 'edit' and d ? 'amount' then coalesce(nullif(d->>'amount', '')::numeric, 0) else s.amount end,
      plan = case when p_action = 'edit' and d ? 'plan' then (d->>'plan')::public.plan_type else s.plan end,
      starts = case when p_action = 'edit' and d ? 'starts' then (d->>'starts')::date else s.starts end,
      ends = case when p_action = 'edit' and d ? 'ends' then (d->>'ends')::date else s.ends end,
      merchant_id = case when p_action = 'transfer' then v_to else s.merchant_id end,
      frozen = case when p_action = 'freeze' then v_on else s.frozen end,
      frozen_reason = case when p_action = 'freeze' then case when v_on then v_reason end else s.frozen_reason end,
      deleted_at = case when p_action = 'delete' then case when v_on then now() end else s.deleted_at end,
      ctl_note = case when p_action = 'edit' and d ? 'note' then nullif(trim(d->>'note'), '') else coalesce(v_reason, s.ctl_note) end
    where id = p_id::uuid returning to_jsonb(s.*) into r;
    if r is null then raise exception 'الاشتراك غير موجود'; end if;
    perform private.ctl_sync_subscription(p_id::uuid);
    perform private.ctl_sync_plan(old_m);
    perform private.ctl_sync_plan((r->>'merchant_id')::uuid);

  elsif p_type = 'platform' then
    if p_action = 'transfer' and (v_to is null or not exists (select 1 from public.merchants where id = v_to))
      then raise exception 'اختر متجراً'; end if;
    update public.platform_ledger l set
      orig_amount = coalesce(l.orig_amount, l.amount),
      orig_merchant = coalesce(l.orig_merchant, l.merchant_id),
      amount = case when p_action = 'edit' then coalesce(v_amt, l.amount) else l.amount end,
      note = case when p_action = 'edit' and d ? 'note' then nullif(trim(d->>'note'), '') else l.note end,
      merchant_id = case when p_action = 'transfer' then v_to else l.merchant_id end,
      frozen = case when p_action = 'freeze' then v_on else l.frozen end,
      frozen_reason = case when p_action = 'freeze' then case when v_on then v_reason end else l.frozen_reason end,
      deleted_at = case when p_action = 'delete' then case when v_on then now() end else l.deleted_at end
    where id = p_id::bigint returning to_jsonb(l.*) into r;
    if r is null then raise exception 'الحركة غير موجودة'; end if;
    perform private.ctl_sync_platform(p_id::bigint);
    -- a subscription row follows its subscription record
    if (r->>'ref_id') is not null and p_action in ('freeze', 'delete') then
      update public.subscriptions set frozen = (r->>'frozen')::boolean,
        deleted_at = (r->>'deleted_at')::timestamptz where id = (r->>'ref_id')::uuid;
      perform private.ctl_sync_plan((r->>'merchant_id')::uuid);
    end if;
  else
    raise exception 'نوع غير معروف';
  end if;

  insert into public.activity_log (actor_id, actor_name, actor_role, action, entity, entity_id, summary, details)
  values (auth.uid(), (select full_name from public.profiles where id = auth.uid()), 'admin', 'control',
    case p_type when 'payout' then 'payout' else 'wallet' end, p_id,
    'التحكم الإداري · ' || case p_type when 'settlement' then 'حركة مندوب #' || (r->>'code')
      when 'payout' then 'طلب سحب #' || (r->>'code') when 'subscription' then 'اشتراك'
      else 'حركة محفظة المنصة #' || p_id end || ': ' ||
      case p_action when 'edit' then 'تعديل' when 'transfer' then 'نقل'
        when 'freeze' then case when v_on then 'تجميد' else 'فك التجميد' end
        else case when v_on then 'حذف' else 'استرجاع' end end,
    d);
  return r;
end $$;

