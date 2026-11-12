-- 025: payment methods managed by the admin («وسائل الدفع»).
-- Each method behaves like one of the three built-in kinds (the orders.payment_method
-- enum): cash on delivery, bank transfer with a receipt, or electronic payment.
-- The order keeps the kind for the business rules plus the method's code and name.

create table if not exists public.payment_methods (
  code text primary key,
  name text not null,
  name_en text,
  kind public.payment_method not null,
  description text,
  account text,          -- IBAN, Benefit number or wallet the customer pays to
  instructions text,     -- shown to the customer when the method is picked
  icon text not null default 'payments',
  active boolean not null default true,
  for_delivery boolean not null default true,
  for_pickup boolean not null default true,
  builtin boolean not null default false,
  archived boolean not null default false,
  sort int not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.payment_methods enable row level security;
create policy payment_methods_read on public.payment_methods for select using (true);
create policy payment_methods_admin on public.payment_methods for all
  using (public.is_admin()) with check (public.is_admin());

alter table public.orders
  add column if not exists payment_method_code text,
  add column if not exists payment_method_name text;

insert into public.payment_methods (code, name, name_en, kind, description, account, icon, active, builtin, sort)
select 'benefitpay', 'BenefitPay', 'BenefitPay', 'benefitpay', 'ادفع من تطبيق بنفت', null, 'phone', coalesce(s.allow_benefitpay, true), true, 1
from public.platform_settings s where s.id = 1
on conflict (code) do nothing;
insert into public.payment_methods (code, name, name_en, kind, description, account, icon, active, builtin, sort)
select 'bank_transfer', 'تحويل بنكي', 'Bank transfer', 'bank_transfer', 'حوّل وارفع الإيصال', s.platform_iban, 'bank', coalesce(s.allow_bank_transfer, true), true, 2
from public.platform_settings s where s.id = 1
on conflict (code) do nothing;
insert into public.payment_methods (code, name, name_en, kind, description, account, icon, active, builtin, sort)
select 'cash', 'نقداً عند الاستلام', 'Cash on delivery', 'cash', 'ادفع للمندوب عند الاستلام', null, 'cash', coalesce(s.allow_cod, true), true, 3
from public.platform_settings s where s.id = 1
on conflict (code) do nothing;

update public.orders set payment_method_code = payment_method::text,
  payment_method_name = (select name from public.payment_methods where code = payment_method::text)
where payment_method_code is null;

-- The old per-kind switches in settings follow the methods, so place_order keeps working.
create or replace function private.payment_methods_sync() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.platform_settings set
    allow_cod = exists (select 1 from public.payment_methods where kind = 'cash' and active and not archived),
    allow_bank_transfer = exists (select 1 from public.payment_methods where kind = 'bank_transfer' and active and not archived),
    allow_benefitpay = exists (select 1 from public.payment_methods where kind = 'benefitpay' and active and not archived)
  where id = 1;
  return null;
end $$;
create trigger payment_methods_sync after insert or update on public.payment_methods
  for each statement execute function private.payment_methods_sync();

-- Admin: add or update a method.
create or replace function public.admin_save_payment_method(p jsonb)
returns public.payment_methods language plpgsql security definer set search_path = '' as $$
declare r public.payment_methods; c text := nullif(trim(p->>'code'), '');
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if c is null then
    if nullif(trim(p->>'name'), '') is null then raise exception 'اكتب اسم وسيلة الدفع'; end if;
    c := 'pm_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
    insert into public.payment_methods (code, name, kind, sort)
    values (c, trim(p->>'name'), coalesce(nullif(p->>'kind','')::public.payment_method, 'bank_transfer'),
      coalesce((select max(sort) + 1 from public.payment_methods), 1));
  end if;
  select * into r from public.payment_methods where code = c for update;
  if r.code is null then raise exception 'وسيلة الدفع غير موجودة'; end if;
  update public.payment_methods set
    name = coalesce(nullif(trim(p->>'name'), ''), name),
    name_en = case when p ? 'name_en' then nullif(trim(p->>'name_en'), '') else name_en end,
    kind = case when builtin then kind else coalesce(nullif(p->>'kind','')::public.payment_method, kind) end,
    description = case when p ? 'description' then nullif(trim(p->>'description'), '') else description end,
    account = case when p ? 'account' then nullif(trim(p->>'account'), '') else account end,
    instructions = case when p ? 'instructions' then nullif(trim(p->>'instructions'), '') else instructions end,
    icon = coalesce(nullif(p->>'icon', ''), icon),
    active = coalesce((p->>'active')::boolean, active),
    for_delivery = coalesce((p->>'for_delivery')::boolean, for_delivery),
    for_pickup = coalesce((p->>'for_pickup')::boolean, for_pickup),
    archived = case when builtin then false else coalesce((p->>'archived')::boolean, archived) end,
    sort = coalesce((p->>'sort')::int, sort),
    updated_at = now()
  where code = c returning * into r;
  if r.code = 'bank_transfer' and p ? 'account' then
    update public.platform_settings set platform_iban = r.account where id = 1;
  end if;
  perform private.log('update', 'payment_method', r.code, 'وسيلة دفع: ' || r.name ||
    case when r.archived then ' (حذف)' when r.active then '' else ' (موقوفة)' end);
  return r;
end $$;

-- Customer: record which method the new order used (right after place_order).
create or replace function public.set_order_method(p_order uuid, p_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.orders; m public.payment_methods;
begin
  select * into o from public.orders where id = p_order;
  if o.id is null or (o.customer_id <> auth.uid() and not public.is_admin()) then raise exception 'غير مسموح'; end if;
  select * into m from public.payment_methods where code = p_code;
  if m.code is null or m.archived or not m.active then raise exception 'وسيلة الدفع غير متاحة'; end if;
  if m.kind <> o.payment_method then raise exception 'وسيلة الدفع لا تطابق الطلب'; end if;
  update public.orders set payment_method_code = m.code, payment_method_name = m.name where id = o.id;
end $$;

grant execute on function public.admin_save_payment_method(jsonb) to authenticated;
grant execute on function public.set_order_method(uuid, text) to authenticated;

-- New orders (and a changed kind) default to the built-in method of their kind until set_order_method runs.
create or replace function private.orders_method_default() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.payment_method_code is null or (tg_op = 'UPDATE'
      and new.payment_method is distinct from old.payment_method
      and (select kind from public.payment_methods where code = new.payment_method_code) is distinct from new.payment_method) then
    new.payment_method_code := new.payment_method::text;
    new.payment_method_name := (select name from public.payment_methods where code = new.payment_method::text);
  end if;
  return new;
end $$;
create trigger orders_method_default before insert or update of payment_method on public.orders
  for each row execute function private.orders_method_default();
