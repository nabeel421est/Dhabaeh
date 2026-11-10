-- Sign-up details: personal number (CPR) and contact email on the profile,
-- full address with city, flat and map pin on the customer address.
alter table public.profiles add column if not exists cpr text;
alter table public.profiles add column if not exists email text;
alter table public.customer_addresses add column if not exists city text;
alter table public.customer_addresses add column if not exists flat text;
alter table public.customer_addresses add column if not exists lat double precision;
alter table public.customer_addresses add column if not exists lng double precision;

-- Only an admin may change whether an account is active.
create or replace function public.profiles_guard_active() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.is_active is distinct from old.is_active
     and coalesce(auth.role(), '') <> 'service_role'
     and not public.is_admin() then
    raise exception 'لا يمكنك تغيير حالة الحساب';
  end if;
  return new;
end $$;
create or replace trigger profiles_guard_active before update on public.profiles
  for each row execute function public.profiles_guard_active();

-- Area names for the sign-up form, before the visitor has an account.
create or replace function public.public_zone_names() returns setof text
language sql stable security definer set search_path = public as $$
  select name from delivery_zones where active order by name
$$;
grant execute on function public.public_zone_names() to anon, authenticated;
