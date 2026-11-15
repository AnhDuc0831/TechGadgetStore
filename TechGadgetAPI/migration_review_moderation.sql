-- =====================================================================
-- TECH GADGET STORE - MIGRATION: ẨN NỘI DUNG ĐÁNH GIÁ KHIẾM NHÃ
-- Safe and non-destructive script for PostgreSQL / Supabase
-- Chạy 1 lần trong Supabase SQL Editor (sau migration_reviews.sql).
--
-- Admin có thể ẩn PHẦN NỘI DUNG (bình luận + ảnh) của đánh giá vi phạm.
-- Số sao vẫn được giữ và vẫn tính vào điểm trung bình để đảm bảo minh bạch.
-- Không xóa dữ liệu: nội dung gốc vẫn còn trong DB, admin có thể bỏ ẩn.
-- =====================================================================

alter table public.reviews
  add column if not exists content_hidden boolean not null default false, -- nội dung đang bị ẩn
  add column if not exists hidden_reason  text,                           -- lý do ẩn (hiện cho khách viết & admin)
  add column if not exists hidden_at      timestamptz;                    -- thời điểm ẩn

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chk_reviews_hidden_reason_len') then
    alter table public.reviews add constraint chk_reviews_hidden_reason_len
      check (hidden_reason is null or char_length(hidden_reason) <= 200);
  end if;
end $$;
