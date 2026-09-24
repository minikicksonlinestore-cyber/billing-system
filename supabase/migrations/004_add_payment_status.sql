-- ============================================================
-- Stage 6 — Add partially_paid and due to invoice_status enum
-- Run this in your Supabase SQL Editor
-- ============================================================

ALTER TYPE invoice_status ADD VALUE IF NOT EXISTS 'partially_paid';
ALTER TYPE invoice_status ADD VALUE IF NOT EXISTS 'due';
