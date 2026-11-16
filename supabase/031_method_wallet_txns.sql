-- Wallet transactions with a date range (filter in the wallet dialog)
create or replace function public.admin_method_wallet_txns(p_code text, p_from timestamptz default null,
  p_to timestamptz default null, p_limit int default 500)
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
    and (p_from is null or x.created_at >= p_from) and (p_to is null or x.created_at < p_to)
  order by x.created_at desc
  limit least(p_limit, 1000);
end $$;
grant execute on function public.admin_method_wallet_txns(text, timestamptz, timestamptz, int) to authenticated;
