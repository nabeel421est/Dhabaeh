-- One wallet per payment method: what customers paid through it, computed from orders,
-- so a newly added method gets its wallet automatically. (migration payment_method_wallets)
create or replace function public.admin_method_wallets()
returns table (code text, name text, kind text, gateway text, icon text, active boolean, archived boolean,
  orders_count int, paid_count int, paid_total numeric, pending_total numeric, review_total numeric,
  today_total numeric, month_total numeric, last_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  d0 timestamptz := date_trunc('day', now() at time zone 'Asia/Bahrain') at time zone 'Asia/Bahrain';
  m0 timestamptz := date_trunc('month', now() at time zone 'Asia/Bahrain') at time zone 'Asia/Bahrain';
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  return query
  with o as (
    select coalesce(x.payment_method_code, x.payment_method::text) as mcode, x.total, x.payment_status::text as ps,
      coalesce(x.paid_at, x.updated_at, x.created_at) as at
    from public.orders x
    where x.status <> 'cancelled' and x.deleted_at is null
  )
  select m.code, m.name, m.kind::text, m.gateway, m.icon, m.active, m.archived,
    count(o.mcode)::int,
    count(o.mcode) filter (where o.ps = 'paid')::int,
    coalesce(sum(o.total) filter (where o.ps = 'paid'), 0),
    coalesce(sum(o.total) filter (where o.ps = 'pending'), 0),
    coalesce(sum(o.total) filter (where o.ps = 'awaiting_review'), 0),
    coalesce(sum(o.total) filter (where o.ps = 'paid' and o.at >= d0), 0),
    coalesce(sum(o.total) filter (where o.ps = 'paid' and o.at >= m0), 0),
    max(o.at)
  from public.payment_methods m
  left join o on o.mcode = m.code
  group by m.code, m.name, m.kind, m.gateway, m.icon, m.active, m.archived, m.sort
  order by m.archived, m.sort;
end $$;
grant execute on function public.admin_method_wallets() to authenticated;

create or replace function public.admin_method_wallet_orders(p_code text, p_limit int default 200)
returns table (id uuid, code bigint, customer_name text, merchant_name text, total numeric, payment_status text,
  status text, created_at timestamptz, paid_at timestamptz, payment_auth text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  return query
  select x.id, x.code::bigint, x.customer_name, mm.name, x.total, x.payment_status::text, x.status::text,
    x.created_at, x.paid_at, x.payment_auth
  from public.orders x
  left join public.merchants mm on mm.id = x.merchant_id
  where coalesce(x.payment_method_code, x.payment_method::text) = p_code and x.deleted_at is null
  order by x.created_at desc
  limit least(p_limit, 500);
end $$;
grant execute on function public.admin_method_wallet_orders(text, int) to authenticated;
