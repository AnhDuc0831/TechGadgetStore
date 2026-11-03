-- =====================================================================
-- TECH GADGET STORE - MIGRATION SCRIPT FOR ADMIN PRODUCT CREATION
-- Adds fields for multiple images, discount price, and specifications
-- =====================================================================

ALTER TABLE public.products 
  ADD COLUMN IF NOT EXISTS images text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS discount_price numeric(14,2) NULL,
  ADD COLUMN IF NOT EXISTS specifications jsonb NOT NULL DEFAULT '{}'::jsonb;
