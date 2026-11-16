-- 028: التحكم الإداري → «الدومين» and «النسخ الاحتياطية».
-- Domain: platform_settings.custom_domain mirrors the GitHub Pages custom domain set by the «site» edge function.
-- Backups: the «backup» edge function exports every public table to a gzip JSON file in the private
-- «backups» bucket and logs it in public.backup_log; a daily pg_cron job asks for an automatic one.
alter table public.platform_settings
  add column if not exists custom_domain text,
  add column if not exists backup_auto boolean not null default true,
  add column if not exists backup_keep int not null default 14;

create table if not exists public.backup_log (
  id uuid primary key default gen_random_uuid(),
  file text not null,
  kind text not null default 'manual' check (kind in ('manual','auto')),
  size_bytes bigint,
  tables int,
  total_rows bigint,
  summary jsonb,
  created_by uuid,
  created_at timestamptz not null default now()
);
alter table public.backup_log enable row level security;
create policy backup_log_read on public.backup_log for select using (public.is_admin());
alter publication supabase_realtime add table public.backup_log;

insert into storage.buckets (id, name, public) values ('backups', 'backups', false)
on conflict (id) do nothing;

do $$ begin
  if not exists (select 1 from vault.secrets where name = 'backup_hook') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'backup_hook');
  end if;
end $$;

-- Service role only: the tables to export and the hook secret for the daily run.
create or replace function public.backup_server_config()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'not allowed'; end if;
  return json_build_object(
    'hook', (select decrypted_secret from vault.decrypted_secrets where name = 'backup_hook'),
    'tables', (select json_agg(table_name order by table_name) from information_schema.tables
               where table_schema = 'public' and table_type = 'BASE TABLE'));
end $$;

create or replace function private.backup_tick() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select backup_auto from public.platform_settings where id = 1), false) then return; end if;
  perform net.http_post(
    url := 'https://onrjdddcutnmbmicfjcu.supabase.co/functions/v1/backup',
    body := '{"action":"auto"}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-hook', (select decrypted_secret from vault.decrypted_secrets where name = 'backup_hook')),
    timeout_milliseconds := 120000);
end $$;

-- Every day at 03:00 Bahrain time (00:00 UTC).
select cron.schedule('daily-backup', '0 0 * * *', 'select private.backup_tick()');
