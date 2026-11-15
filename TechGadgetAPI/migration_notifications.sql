-- =====================================================================
-- TECH GADGET STORE - MIGRATION SCRIPT FOR NOTIFICATIONS
-- Safe and non-destructive script for PostgreSQL / Supabase
-- Chạy 1 lần trong Supabase SQL Editor.
--
-- Thông báo trong app cho Admin (đơn mới, đơn đã thanh toán, khách hủy/nhận hàng)
-- và cho Khách (đơn được xác nhận, đang giao, đã giao, bị hủy, thanh toán thành công).
-- =====================================================================

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade, -- người nhận
  type        text not null,          -- new_order | order_paid | order_status | order_cancelled | order_received
  title       text not null,
  message     text not null,
  order_id    uuid references public.orders (id) on delete cascade,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user_created on public.notifications (user_id, created_at desc);
create index if not exists idx_notifications_user_unread on public.notifications (user_id) where is_read = false;

alter table public.notifications enable row level security;
