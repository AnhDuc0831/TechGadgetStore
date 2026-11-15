-- =====================================================================
-- TECH GADGET STORE - MIGRATION SCRIPT FOR PRODUCT REVIEWS
-- Safe and non-destructive script for PostgreSQL / Supabase
-- Chạy 1 lần trong Supabase SQL Editor (sau migration_vouchers.sql).
--
-- Nguyên tắc: Shop KHÔNG được ẩn/xóa đánh giá. Nội dung vi phạm bị chặn
-- tự động ngay khi gửi; Shop chỉ được phản hồi công khai.
-- =====================================================================

-- Bảng reviews đã có sẵn từ init (id, product_id, user_id, rating 1-5, comment, unique(product_id, user_id)).
-- Tạo lại nếu chưa có (môi trường mới).
create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (product_id, user_id)
);

alter table public.reviews
  add column if not exists order_id uuid references public.orders (id) on delete set null, -- đơn hàng chứng minh đã mua
  add column if not exists variant_sku text,                                               -- phân loại đã mua
  add column if not exists images text[] not null default '{}',                            -- tối đa 5 ảnh Cloudinary
  add column if not exists edited_at timestamptz,                                          -- lần khách tự sửa gần nhất
  add column if not exists admin_reply text,                                               -- phản hồi công khai của Shop
  add column if not exists replied_at timestamptz;

create index if not exists idx_reviews_product on public.reviews (product_id);
create index if not exists idx_reviews_user on public.reviews (user_id);
create index if not exists idx_reviews_product_rating on public.reviews (product_id, rating);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chk_reviews_images_max') then
    alter table public.reviews add constraint chk_reviews_images_max check (coalesce(array_length(images, 1), 0) <= 5);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'chk_reviews_comment_len') then
    alter table public.reviews add constraint chk_reviews_comment_len check (comment is null or char_length(comment) <= 1000);
  end if;
end $$;

-- Chặn truy cập trực tiếp bằng anon key, chỉ backend (.NET) được thao tác
alter table public.reviews enable row level security;
