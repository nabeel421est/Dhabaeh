-- 026: online payment through the Tap gateway (Apple Pay, cards, Benefit).
-- A method with gateway = 'tap' sends the customer to Tap's hosted page after the order is placed.
-- The edge function «tap» creates the charge and marks the order paid once Tap reports CAPTURED.
alter table public.payment_methods add column if not exists gateway text
  check (gateway is null or gateway in ('tap'));
alter table public.orders add column if not exists gateway_charge text,
  add column if not exists paid_at timestamptz;

insert into public.payment_methods (code, name, name_en, kind, description, icon, active, gateway, builtin, sort)
values ('applepay', 'Apple Pay / البطاقة', 'Apple Pay / Card', 'benefitpay',
  'ادفع بـ Apple Pay أو بطاقتك عبر صفحة دفع آمنة', 'apple', false, 'tap', false,
  coalesce((select max(sort) + 1 from public.payment_methods), 1))
on conflict (code) do nothing;

-- admin_save_payment_method also takes «gateway».
do $$ declare d text; begin
  d := pg_get_functiondef('public.admin_save_payment_method(jsonb)'::regprocedure);
  if position('gateway =' in d) = 0 then
    d := replace(d, '    sort = coalesce((p->>''sort'')::int, sort),',
      '    gateway = case when p ? ''gateway'' then nullif(p->>''gateway'', '''') else gateway end,
    sort = coalesce((p->>''sort'')::int, sort),');
    execute d;
  end if;
end $$;
