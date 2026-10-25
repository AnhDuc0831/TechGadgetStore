-- =====================================================================
-- TECH GADGET STORE - LOCAL POSTGRESQL INITIALIZATION SCRIPT
-- (Compatible with standard local PostgreSQL 14/15/16/17/18 & Supabase)
-- =====================================================================

-- ---------- 0. EXTENSIONS & SCHEMAS ----------
create schema if not exists extensions;
create extension if not exists "uuid-ossp" schema extensions;

-- Mock Supabase auth schema for local development
create schema if not exists auth;

create table if not exists auth.users (
  id                  uuid primary key default extensions.uuid_generate_v4(),
  email               text unique,
  raw_user_meta_data  jsonb default '{}'::jsonb,
  phone               text,
  created_at          timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select null::uuid;
$$;

-- ---------- 1. ENUM TYPES ----------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('admin', 'customer');
  end if;
  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type public.order_status as enum ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
  end if;
  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type public.payment_status as enum ('unpaid', 'paid', 'failed', 'refunded');
  end if;
  if not exists (select 1 from pg_type where typname = 'payment_method') then
    create type public.payment_method as enum ('cod', 'bank_transfer', 'momo', 'vnpay', 'credit_card');
  end if;
end $$;

-- ---------- 2. GENERIC HELPERS ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- 3. PROFILES ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  avatar_url  text,
  phone       text,
  role        public.user_role not null default 'customer',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, full_name, avatar_url, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture'),
    nullif(new.phone, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.role is distinct from old.role
     and not (public.is_admin() or current_user in ('postgres', 'service_role', 'supabase_admin')) then
    raise exception 'You are not allowed to change the role';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_escalation on public.profiles;
create trigger profiles_prevent_role_escalation
  before update on public.profiles
  for each row execute function public.prevent_role_escalation();

-- ---------- 4. PRODUCT CATALOG ----------
create table if not exists public.categories (
  id           uuid primary key default extensions.uuid_generate_v4(),
  name         text not null,
  slug         text not null unique,
  description  text,
  image_url    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.brands (
  id          uuid primary key default extensions.uuid_generate_v4(),
  name        text not null unique,
  logo_url    text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.products (
  id            uuid primary key default extensions.uuid_generate_v4(),
  category_id   uuid not null references public.categories (id) on delete restrict,
  brand_id      uuid not null references public.brands (id)     on delete restrict,
  name          text not null,
  slug          text not null unique,
  description   text,
  thumbnail_url text,
  base_price    numeric(14,2) not null check (base_price >= 0),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists idx_products_category on public.products (category_id);
create index if not exists idx_products_brand    on public.products (brand_id);
create index if not exists idx_products_active   on public.products (is_active);

create table if not exists public.product_variants (
  id               uuid primary key default extensions.uuid_generate_v4(),
  product_id       uuid not null references public.products (id) on delete cascade,
  sku              text not null unique,
  attributes       jsonb not null default '{}'::jsonb,
  price_adjustment numeric(14,2) not null default 0,
  stock_quantity   integer not null default 0 check (stock_quantity >= 0),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists idx_variants_product    on public.product_variants (product_id);
create index if not exists idx_variants_attributes on public.product_variants using gin (attributes);

-- ---------- 5. SHOPPING CART & CHECKOUT ----------
create table if not exists public.shopping_cart (
  id          uuid primary key default extensions.uuid_generate_v4(),
  user_id     uuid unique references public.profiles (id) on delete cascade,
  session_id  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.cart_items (
  id                  uuid primary key default extensions.uuid_generate_v4(),
  cart_id             uuid not null references public.shopping_cart (id)    on delete cascade,
  product_variant_id  uuid not null references public.product_variants (id) on delete cascade,
  quantity            integer not null default 1 check (quantity > 0),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (cart_id, product_variant_id)
);
create index if not exists idx_cart_items_cart on public.cart_items (cart_id);

create table if not exists public.orders (
  id               uuid primary key default extensions.uuid_generate_v4(),
  user_id          uuid references public.profiles (id) on delete set null,
  status           public.order_status   not null default 'pending',
  shipping_fee     numeric(14,2) not null default 0 check (shipping_fee >= 0),
  total_amount     numeric(14,2) not null check (total_amount >= 0),
  shipping_address jsonb not null,
  payment_method   public.payment_method not null default 'cod',
  payment_status   public.payment_status not null default 'unpaid',
  note             text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists idx_orders_user   on public.orders (user_id);
create index if not exists idx_orders_status on public.orders (status);

create table if not exists public.order_items (
  id                  uuid primary key default extensions.uuid_generate_v4(),
  order_id            uuid not null references public.orders (id)           on delete cascade,
  product_variant_id  uuid not null references public.product_variants (id) on delete restrict,
  product_name        text not null,
  sku                 text not null,
  unit_price          numeric(14,2) not null check (unit_price >= 0),
  quantity            integer not null check (quantity > 0),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists idx_order_items_order on public.order_items (order_id);

-- ---------- 6. USER ENGAGEMENT ----------
create table if not exists public.reviews (
  id          uuid primary key default extensions.uuid_generate_v4(),
  product_id  uuid not null references public.products (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (product_id, user_id)
);
create index if not exists idx_reviews_product on public.reviews (product_id);

create table if not exists public.favorites (
  id          uuid primary key default extensions.uuid_generate_v4(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  product_id  uuid not null references public.products (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, product_id)
);
create index if not exists idx_favorites_user on public.favorites (user_id);

-- ---------- 7. UPDATED_AT TRIGGERS ----------
do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles','categories','brands','products','product_variants',
    'shopping_cart','cart_items','orders','order_items','reviews','favorites'
  ]
  loop
    execute format('drop trigger if exists trg_%1$s_updated_at on public.%1$s;', t);
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$s
         for each row execute function public.set_updated_at();', t);
  end loop;
end $$;

-- ---------- 8. SEED DATA ----------
insert into public.categories (name, slug, description, image_url) values
  ('Smartphones', 'smartphones', 'Latest smartphones and mobile devices', 'https://example.com/img/cat-phone.jpg'),
  ('Laptops',     'laptops',     'Laptops for work, study and gaming',    'https://example.com/img/cat-laptop.jpg'),
  ('Accessories', 'accessories', 'Chargers, cases, headphones and more',  'https://example.com/img/cat-acc.jpg')
on conflict (slug) do nothing;

insert into public.brands (name, logo_url) values
  ('Apple',   'https://example.com/img/brand-apple.png'),
  ('Samsung', 'https://example.com/img/brand-samsung.png'),
  ('Dell',    'https://example.com/img/brand-dell.png')
on conflict (name) do nothing;

-- Product 1: iPhone 15
insert into public.products (category_id, brand_id, name, slug, description, thumbnail_url, base_price)
select c.id, b.id, 'iPhone 15', 'iphone-15',
       'Apple iPhone 15 with A16 Bionic chip and 48MP camera.',
       'https://example.com/img/iphone15.jpg', 19990000
from public.categories c, public.brands b
where c.slug = 'smartphones' and b.name = 'Apple'
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, attributes, price_adjustment, stock_quantity)
select p.id, v.sku, v.attrs::jsonb, v.adj, v.stock
from public.products p,
     (values
        ('IP15-128-BLK', '{"Storage":"128GB","Color":"Black"}', 0,       50),
        ('IP15-256-BLK', '{"Storage":"256GB","Color":"Black"}', 3000000, 30),
        ('IP15-256-BLU', '{"Storage":"256GB","Color":"Blue"}',  3000000, 20)
     ) as v(sku, attrs, adj, stock)
where p.slug = 'iphone-15'
on conflict (sku) do nothing;

-- Product 2: Dell XPS 13
insert into public.products (category_id, brand_id, name, slug, description, thumbnail_url, base_price)
select c.id, b.id, 'Dell XPS 13', 'dell-xps-13',
       'Ultra-portable 13.4" laptop with Intel Core Ultra processor.',
       'https://example.com/img/xps13.jpg', 27990000
from public.categories c, public.brands b
where c.slug = 'laptops' and b.name = 'Dell'
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, attributes, price_adjustment, stock_quantity)
select p.id, v.sku, v.attrs::jsonb, v.adj, v.stock
from public.products p,
     (values
        ('XPS13-8-256',  '{"RAM":"8GB","Storage":"256GB"}',   0,        15),
        ('XPS13-16-512', '{"RAM":"16GB","Storage":"512GB"}',  6000000,  10),
        ('XPS13-32-1TB', '{"RAM":"32GB","Storage":"1TB"}',    14000000,  5)
     ) as v(sku, attrs, adj, stock)
where p.slug = 'dell-xps-13'
on conflict (sku) do nothing;

-- Product 3: Galaxy S24
insert into public.products (category_id, brand_id, name, slug, description, thumbnail_url, base_price)
select c.id, b.id, 'Samsung Galaxy S24', 'samsung-galaxy-s24',
       'Galaxy S24 with Galaxy AI and a 6.2" Dynamic AMOLED display.',
       'https://example.com/img/s24.jpg', 18990000
from public.categories c, public.brands b
where c.slug = 'smartphones' and b.name = 'Samsung'
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, attributes, price_adjustment, stock_quantity)
select p.id, v.sku, v.attrs::jsonb, v.adj, v.stock
from public.products p,
     (values
        ('S24-8-256', '{"RAM":"8GB","Storage":"256GB"}', 0,       40),
        ('S24-8-512', '{"RAM":"8GB","Storage":"512GB"}', 3500000, 25)
     ) as v(sku, attrs, adj, stock)
where p.slug = 'samsung-galaxy-s24'
on conflict (sku) do nothing;
