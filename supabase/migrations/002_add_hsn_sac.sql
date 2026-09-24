-- Add HSN/SAC column to products table for Stage 3
ALTER TABLE products ADD COLUMN IF NOT EXISTS hsn_sac TEXT;
