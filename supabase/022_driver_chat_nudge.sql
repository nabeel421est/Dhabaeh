-- 022: admin <-> driver live text chat, and "nudge" (a loud alert on the driver's phone).

create table if not exists public.driver_chat (
  id bigint generated always as identity primary key,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  from_admin boolean not null,
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists driver_chat_driver_idx on public.driver_chat (driver_id, created_at);
alter table public.driver_chat enable row level security;
create policy chat_read on public.driver_chat for select to authenticated
  using (public.is_admin() or driver_id = (select auth.uid()));

create table if not exists public.driver_nudges (
  id bigint generated always as identity primary key,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid references public.profiles(id),
  note text,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
create index if not exists driver_nudges_driver_idx on public.driver_nudges (driver_id, created_at);
alter table public.driver_nudges enable row level security;
create policy nudge_read on public.driver_nudges for select to authenticated
  using (public.is_admin() or driver_id = (select auth.uid()));

alter publication supabase_realtime add table public.driver_chat, public.driver_nudges;

create or replace function public.chat_send(p_driver uuid, p_body text)
returns public.driver_chat
language plpgsql security definer set search_path = '' as $$
declare m public.driver_chat; adm boolean := public.is_admin(); nm text;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'اكتب الرسالة'; end if;
  if not adm then
    if not public.has_role('driver'::public.app_role) then raise exception 'غير مسموح'; end if;
    p_driver := auth.uid();
  elsif not exists (select 1 from public.user_roles where user_id = p_driver and role = 'driver') then
    raise exception 'المندوب غير موجود';
  end if;
  insert into public.driver_chat (driver_id, sender_id, from_admin, body)
  values (p_driver, auth.uid(), adm, left(trim(p_body), 2000)) returning * into m;
  if adm then
    perform private.push_send(jsonb_build_object('audience', 'user', 'user_id', p_driver,
      'title', 'رسالة من الإدارة', 'body', left(m.body, 140), 'tag', 'chat-' || p_driver));
  else
    select full_name into nm from public.profiles where id = p_driver;
    perform private.push_send(jsonb_build_object('admins', true,
      'title', 'رسالة من المندوب ' || coalesce(nm, ''), 'body', left(m.body, 140), 'tag', 'chat-' || p_driver));
  end if;
  return m;
end $$;

create or replace function public.chat_mark_read(p_driver uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.is_admin() then
    update public.driver_chat set read_at = now()
    where driver_id = p_driver and not from_admin and read_at is null;
  else
    update public.driver_chat set read_at = now()
    where driver_id = auth.uid() and from_admin and read_at is null;
  end if;
end $$;

create or replace function public.admin_chat_overview()
returns table(driver_id uuid, unread bigint, last_at timestamptz, last_body text)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  return query
  select c.driver_id,
    count(*) filter (where not c.from_admin and c.read_at is null),
    max(c.created_at),
    (select x.body from public.driver_chat x where x.driver_id = c.driver_id order by x.created_at desc limit 1)
  from public.driver_chat c group by c.driver_id;
end $$;

create or replace function public.admin_nudge_driver(p_driver uuid, p_note text default null)
returns public.driver_nudges
language plpgsql security definer set search_path = '' as $$
declare n public.driver_nudges;
begin
  if not public.is_admin() then raise exception 'للإدارة فقط'; end if;
  if not exists (select 1 from public.user_roles where user_id = p_driver and role = 'driver') then
    raise exception 'المندوب غير موجود'; end if;
  if exists (select 1 from public.driver_nudges where driver_id = p_driver and created_at > now() - interval '20 seconds') then
    raise exception 'نُكز المندوب قبل لحظات، انتظر قليلاً'; end if;
  insert into public.driver_nudges (driver_id, created_by, note)
  values (p_driver, auth.uid(), nullif(trim(p_note), '')) returning * into n;
  perform private.push_send(jsonb_build_object('audience', 'user', 'user_id', p_driver,
    'title', 'نكز من الإدارة', 'body', coalesce(n.note, 'الإدارة تطلب انتباهك الآن'),
    'tag', 'nudge-' || n.id, 'loud', true));
  return n;
end $$;

create or replace function public.driver_nudge_seen(p_id bigint) returns void
language sql security definer set search_path = '' as $$
  update public.driver_nudges set seen_at = now()
  where id = p_id and driver_id = auth.uid() and seen_at is null;
$$;
