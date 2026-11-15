-- =====================================================================
-- TECH GADGET STORE - MIGRATION SCRIPT FOR VOUCHERS (VÍ VOUCHER)
-- Safe and non-destructive script for PostgreSQL / Supabase
-- Chạy 1 lần trong Supabase SQL Editor.
-- =====================================================================

-- 1. Bảng voucher do Admin tạo
create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  discount_type text not null check (discount_type in ('percent', 'fixed')),
  discount_value numeric(14,2) not null check (discount_value > 0),
  max_discount numeric(14,2) check (max_discount is null or max_discount > 0),
  min_order_value numeric(14,2) not null default 0 check (min_order_value >= 0),
  total_quantity int not null check (total_quantity > 0),          -- tổng số suất được lưu
  claimed_count int not null default 0 check (claimed_count >= 0), -- số suất đã được lưu
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default true,
  is_public boolean not null default true,                         -- hiện trong Kho voucher
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_vouchers_time check (ends_at > starts_at),
  constraint chk_vouchers_percent check (discount_type <> 'percent' or discount_value <= 100),
  constraint chk_vouchers_claimed check (claimed_count <= total_quantity)
);

create unique index if not exists idx_vouchers_code on public.vouchers (code);
create index if not exists idx_vouchers_active_time on public.vouchers (is_active, starts_at, ends_at);

-- 2. Ví voucher của từng khách hàng
create table if not exists public.user_vouchers (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'available' check (status in ('available', 'used')),
  order_id uuid references public.orders(id) on delete set null,
  discount_amount numeric(14,2),
  claimed_at timestamptz not null default now(),
  used_at timestamptz,
  constraint uq_user_vouchers_voucher_user unique (voucher_id, user_id)
);

create index if not exists idx_user_vouchers_user on public.user_vouchers (user_id);
create index if not exists idx_user_vouchers_order on public.user_vouchers (order_id);

-- 3. Lưu "ảnh chụp" giảm giá trên đơn hàng
alter table public.orders
  add column if not exists subtotal numeric(14,2),
  add column if not exists discount_amount numeric(14,2) not null default 0,
  add column if not exists voucher_code text;

-- 4. Bật RLS: chặn truy cập trực tiếp bằng anon key, chỉ backend (.NET) được thao tác
alter table public.vouchers enable row level security;
alter table public.user_vouchers enable row level security;

-- 5. (Tuỳ chọn) Dữ liệu mẫu để demo
insert into public.vouchers (code, name, description, discount_type, discount_value, max_discount, min_order_value, total_quantity, starts_at, ends_at)
values
  ('TECH50K', 'Giảm 50K cho đơn từ 1 triệu', 'Áp dụng cho mọi sản phẩm', 'fixed', 50000, null, 1000000, 100, now(), now() + interval '30 days'),
  ('SALE10', 'Giảm 10% tối đa 200K', 'Áp dụng cho đơn từ 500K', 'percent', 10, 200000, 500000, 50, now(), now() + interval '30 days')
on conflict (code) do nothing;
