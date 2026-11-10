-- ذبائح البحرين: core schema
create type public.app_role as enum ('customer','merchant_owner','merchant_staff','driver','admin');
create type public.order_status as enum ('new','accepted','slaughtering','ready','out_for_delivery','delivered','cancelled');
create type public.payment_method as enum ('benefitpay','bank_transfer','cash');
create type public.payment_status as enum ('pending','awaiting_review','paid','refunded');
create type public.plan_type as enum ('trial','monthly','yearly');
create type public.value_type as enum ('percent','fixed');

-- ---------- people ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text unique,
  area text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_roles (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  merchant_id uuid,
  created_at timestamptz not null default now(),
  unique (user_id, role, merchant_id)
);

create table public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null default 'المنزل',
  house text, road text, block text, area text not null, note text,
  created_at timestamptz not null default now()
);

-- ---------- platform settings ----------
create table public.platform_settings (
  id int primary key default 1 check (id = 1),
  merchant_comm_enabled boolean not null default true,
  merchant_comm_type public.value_type not null default 'percent',
  merchant_comm_value numeric(12,3) not null default 5,
  customer_comm_enabled boolean not null default true,
  customer_comm_type public.value_type not null default 'fixed',
  customer_comm_value numeric(12,3) not null default 0.500,
  trial_days int not null default 14,
  monthly_price numeric(12,3) not null default 25,
  yearly_price numeric(12,3) not null default 250,
  platform_iban text,
  updated_at timestamptz not null default now()
);
insert into public.platform_settings (id) values (1);

create table public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  fee numeric(12,3) not null default 2,
  active boolean not null default true
);

-- ---------- merchants ----------
-- public part: what customers see
create table public.merchants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  logo_url text,
  store_phone text not null,
  area text not null,
  description text,
  is_open boolean not null default true,
  suspended boolean not null default false,
  frozen boolean not null default false,
  plan public.plan_type not null default 'trial',
  plan_ends date not null default (current_date + 14),
  perms jsonb not null default '{"products":true,"pricing":true,"offers":true,"orders":true,"wallet":true,"staff":true}',
  created_at timestamptz not null default now()
);
alter table public.user_roles add constraint user_roles_merchant_fk foreign key (merchant_id) references public.merchants(id) on delete cascade;

-- private part: admin + owner only
create table public.merchant_details (
  merchant_id uuid primary key references public.merchants(id) on delete cascade,
  owner_id uuid references public.profiles(id),
  owner_name text not null,
  owner_phone text not null,
  owner_cpr text not null,
  cr_number text not null,
  vat_number text,
  health_license text not null,
  shop_no text not null, building text not null, road text not null, block text not null, address_area text not null, address_note text,
  iban text not null, account_name text not null, bank_name text not null,
  doc_id_path text, doc_cr_path text, doc_tax_path text, doc_health_path text,
  updated_at timestamptz not null default now()
);

create table public.merchant_staff (
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'موظف',
  perms jsonb not null default '{"orders":true}',
  created_at timestamptz not null default now(),
  primary key (merchant_id, user_id)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  plan public.plan_type not null,
  starts date not null default current_date,
  ends date not null,
  amount numeric(12,3) not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- catalogue ----------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  name text not null,
  category text not null default 'ذبائح',
  description text,
  price numeric(12,3) not null check (price >= 0),
  image_url text,
  available boolean not null default true,
  created_at timestamptz not null default now()
);
create index on public.products (merchant_id);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  title text not null,
  discount_type public.value_type not null default 'fixed',
  discount_value numeric(12,3) not null default 0,
  ends_on date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- orders ----------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  code bigint generated always as identity (start with 1001) unique,
  customer_id uuid not null references public.profiles(id),
  merchant_id uuid not null references public.merchants(id),
  driver_id uuid references public.profiles(id),
  slaughter_date date not null,
  slaughter_time text not null,
  delivery_date date not null,
  delivery_slot text not null,
  zone_id uuid references public.delivery_zones(id),
  address text not null,
  notes text,
  subtotal numeric(12,3) not null,
  discount numeric(12,3) not null default 0,
  customer_commission numeric(12,3) not null default 0,
  merchant_commission numeric(12,3) not null default 0,
  delivery_fee numeric(12,3) not null default 0,
  total numeric(12,3) not null,
  merchant_net numeric(12,3) not null,
  payment_method public.payment_method not null,
  payment_status public.payment_status not null default 'pending',
  receipt_path text,
  status public.order_status not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.orders (merchant_id, created_at desc);
create index on public.orders (customer_id, created_at desc);
create index on public.orders (driver_id);
create index on public.orders (status);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  qty int not null check (qty > 0),
  unit_price numeric(12,3) not null,
  options jsonb not null default '{}'
);
create index on public.order_items (order_id);

create table public.order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null,
  by_user uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index on public.order_events (order_id);

-- ---------- money ----------
create table public.wallet_ledger (
  id bigint generated always as identity primary key,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  order_id uuid references public.orders(id),
  kind text not null check (kind in ('order_credit','payout','adjustment')),
  amount numeric(12,3) not null,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index on public.wallet_ledger (merchant_id, created_at desc);

create table public.platform_ledger (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('merchant_commission','customer_commission','subscription','delivery_fee')),
  amount numeric(12,3) not null,
  merchant_id uuid references public.merchants(id) on delete set null,
  order_id uuid references public.orders(id),
  created_at timestamptz not null default now()
);
create index on public.platform_ledger (kind, created_at desc);

-- ---------- notifications ----------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  audience text not null check (audience in ('all','customers','merchants','drivers','user','merchant')),
  user_id uuid references public.profiles(id) on delete cascade,
  merchant_id uuid references public.merchants(id) on delete cascade,
  title text not null,
  body text not null default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index on public.notifications (created_at desc);
