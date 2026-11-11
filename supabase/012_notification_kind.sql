-- 012/013 (applied 2026-11-11): notifications.kind = message | offer | order.
-- Admin chooses message or offer; system inserts to user/merchant default to order (trigger notif_kind).
alter table public.notifications add column if not exists kind text not null default 'message'
  check (kind in ('message','offer','order'));
