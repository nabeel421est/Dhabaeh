-- 023: merchant official working hours, document expiry dates with alerts, store city.

alter table public.merchants
  add column if not exists work_hours jsonb,
  add column if not exists address_city text;
alter table public.merchant_details
  add column if not exists cr_expiry date,
  add column if not exists health_expiry date,
  add column if not exists cpr_expiry date;

-- Documents that expire within 10 days or have expired, for one store or all.
create or replace function private.doc_rows(p_merchant uuid)
returns table(merchant_id uuid, merchant_name text, doc text, label text, number text, expiry date, days_left int)
language sql stable security definer set search_path = '' as $$
  select m.id, m.name, x.doc, x.label, x.num, x.exp, (x.exp - current_date)::int
  from public.merchants m
  join public.merchant_details d on d.merchant_id = m.id
  cross join lateral (values
    ('cr', 'السجل التجاري', d.cr_number, d.cr_expiry),
    ('health', 'الترخيص الصحي', d.health_license, d.health_expiry),
    ('cpr', 'الرقم الشخصي للتاجر', d.owner_cpr, d.cpr_expiry)
  ) as x(doc, label, num, exp)
  where x.exp is not null and x.exp <= current_date + 10
    and (p_merchant is null or m.id = p_merchant)
  order by x.exp;
$$;

create or replace function public.admin_expiring_docs()
returns table(merchant_id uuid, merchant_name text, doc text, label text, number text, expiry date, days_left int)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return query select * from private.doc_rows(null);
end $$;

create or replace function public.merchant_doc_alerts(p_merchant uuid)
returns table(merchant_id uuid, merchant_name text, doc text, label text, number text, expiry date, days_left int)
language plpgsql security definer set search_path = '' as $$
begin
  if not (public.is_admin() or public.is_merchant_member(p_merchant)) then raise exception 'غير مسموح'; end if;
  return query select * from private.doc_rows(p_merchant);
end $$;

-- Admin asks the store to renew a document.
create or replace function public.admin_request_doc_renewal(p_merchant uuid, p_doc text)
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  select * into r from private.doc_rows(p_merchant) where doc = p_doc;
  if r.doc is null then raise exception 'الوثيقة ليست قريبة من الانتهاء'; end if;
  insert into public.notifications (audience, merchant_id, title, body, created_by)
  values ('merchant', p_merchant, 'مطلوب تجديد ' || r.label,
    case when r.days_left < 0 then 'انتهت صلاحية ' || r.label || ' بتاريخ ' || to_char(r.expiry, 'DD/MM/YYYY')
      else 'تنتهي صلاحية ' || r.label || ' بتاريخ ' || to_char(r.expiry, 'DD/MM/YYYY') end
    || '. أرسل الوثيقة المجددة للإدارة.', auth.uid());
end $$;

-- Daily: alert the admins once when a document enters its last 10 days, and once when it expires.
create table if not exists private.doc_alerts (
  merchant_id uuid not null,
  doc text not null,
  expiry date not null,
  stage text not null,
  sent_at timestamptz not null default now(),
  primary key (merchant_id, doc, expiry, stage)
);

create or replace function private.doc_expiry_tick() returns void
language plpgsql security definer set search_path = '' as $$
declare r record; st text;
begin
  for r in select * from private.doc_rows(null) loop
    st := case when r.days_left < 0 then 'expired' else 'soon' end;
    insert into private.doc_alerts (merchant_id, doc, expiry, stage)
    values (r.merchant_id, r.doc, r.expiry, st) on conflict do nothing;
    if found then
      perform private.push_send(jsonb_build_object('admins', true,
        'title', case when st = 'expired' then 'انتهت وثيقة: ' else 'وثيقة قربت تنتهي: ' end || r.label,
        'body', r.merchant_name || ' · ' || to_char(r.expiry, 'DD/MM/YYYY') || ' · اطلب التجديد من التاجر',
        'tag', 'doc-' || r.merchant_id || '-' || r.doc));
    end if;
  end loop;
end $$;

select cron.schedule('doc-expiry-daily', '0 5 * * *', 'select private.doc_expiry_tick()');
