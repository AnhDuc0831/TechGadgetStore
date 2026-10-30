-- =====================================================================
-- TECH GADGET STORE - MIGRATION SCRIPT FOR PAYOS CHECKOUT & ORDERS
-- Safe and non-destructive script for PostgreSQL / Supabase
-- =====================================================================

-- 1. Extend PaymentMethod enum (only 'payos', no duplicate 'pay_os')
alter type public.payment_method add value if not exists 'payos';

-- 2. Extend PaymentStatus enum (add 'cancelled', 'expired')
alter type public.payment_status add value if not exists 'cancelled';
alter type public.payment_status add value if not exists 'expired';

-- 3. Add new columns to orders table
alter table public.orders
  add column if not exists shipping_name text,
  add column if not exists shipping_phone text,
  add column if not exists payos_order_code bigint,
  add column if not exists payment_link_id text,
  add column if not exists checkout_url text,
  add column if not exists paid_at timestamptz,
  add column if not exists internal_note text;

-- 4. Create unique index for payos_order_code
create unique index if not exists idx_orders_payos_order_code
  on public.orders (payos_order_code)
  where payos_order_code is not null;
