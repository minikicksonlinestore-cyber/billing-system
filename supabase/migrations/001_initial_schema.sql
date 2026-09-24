-- ============================================================
-- Stage 1 — Initial Database Schema
-- Billing, Inventory & Invoice Management System
-- Run this in your Supabase SQL Editor (or via supabase db push)
-- ============================================================

-- Enable the pgcrypto extension for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────

CREATE TYPE user_role AS ENUM ('admin', 'manager', 'staff');
CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'overdue', 'cancelled');
CREATE TYPE payment_method AS ENUM ('cash', 'card', 'bank_transfer', 'upi', 'cheque', 'other');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE stock_movement_type AS ENUM ('purchase', 'sale', 'adjustment', 'return', 'damage');
CREATE TYPE setting_category AS ENUM ('general', 'billing', 'tax', 'notifications', 'appearance');

-- ─────────────────────────────────────────────────────────────
-- HELPER FUNCTION: auto-update updated_at timestamp
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────
-- TABLE: user_profiles
-- Extends Supabase auth.users with business-specific fields
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT NOT NULL,
  full_name     TEXT,
  role          user_role NOT NULL DEFAULT 'staff',
  phone         TEXT,
  avatar_url    TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Automatically insert a user_profile row when a new auth user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    'staff'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- TABLE: categories
-- Product categories with optional parent for subcategories
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  description   TEXT,
  parent_id     UUID REFERENCES categories(id) ON DELETE SET NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT categories_name_unique UNIQUE (name)
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);

CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─────────────────────────────────────────────────────────────
-- TABLE: products
-- Product catalog with pricing, stock tracking, and tax info
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku               TEXT NOT NULL,
  name              TEXT NOT NULL,
  description       TEXT,
  category_id       UUID REFERENCES categories(id) ON DELETE SET NULL,
  unit_price        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  cost_price        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  tax_rate          NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  unit_of_measure   TEXT NOT NULL DEFAULT 'pcs',
  stock_quantity    NUMERIC(12, 3) NOT NULL DEFAULT 0,
  min_stock_level   NUMERIC(12, 3) NOT NULL DEFAULT 0,
  max_stock_level   NUMERIC(12, 3),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  image_url         TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT products_sku_unique UNIQUE (sku)
);

CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_is_active ON products(is_active);

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─────────────────────────────────────────────────────────────
-- TABLE: customers
-- Customer master with billing/shipping addresses and GST
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS customers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  email               TEXT,
  phone               TEXT,
  gstin               TEXT,                          -- GST Identification Number
  billing_address     TEXT,
  shipping_address    TEXT,
  city                TEXT,
  state               TEXT,
  pincode             TEXT,
  country             TEXT NOT NULL DEFAULT 'India',
  credit_limit        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  outstanding_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_is_active ON customers(is_active);

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─────────────────────────────────────────────────────────────
-- TABLE: invoices
-- Invoice header with status, dates, and financial totals
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number  TEXT NOT NULL,
  customer_id     UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  status          invoice_status NOT NULL DEFAULT 'draft',
  issue_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date        DATE NOT NULL,
  subtotal        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_amount      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount    NUMERIC(12, 2) NOT NULL DEFAULT 0,
  amount_paid     NUMERIC(12, 2) NOT NULL DEFAULT 0,
  amount_due      NUMERIC(12, 2) GENERATED ALWAYS AS (total_amount - amount_paid) STORED,
  notes           TEXT,
  terms           TEXT,
  created_by      UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT invoices_number_unique UNIQUE (invoice_number),
  CONSTRAINT invoices_due_date_check CHECK (due_date >= issue_date)
);

CREATE INDEX idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_issue_date ON invoices(issue_date);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_created_by ON invoices(created_by);

CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─────────────────────────────────────────────────────────────
-- TABLE: invoice_items
-- Line items for each invoice (product or custom description)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoice_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id          UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  product_id          UUID REFERENCES products(id) ON DELETE SET NULL,
  description         TEXT NOT NULL,
  quantity            NUMERIC(12, 3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price          NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  tax_rate            NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  tax_amount          NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
  discount_amount     NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_product_id ON invoice_items(product_id);

-- ─────────────────────────────────────────────────────────────
-- TABLE: payments
-- Payment records against invoices
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS payments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id       UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  payment_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  amount           NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  payment_method   payment_method NOT NULL DEFAULT 'cash',
  status           payment_status NOT NULL DEFAULT 'completed',
  reference_number TEXT,
  notes            TEXT,
  created_by       UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_invoice_id ON payments(invoice_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
CREATE INDEX idx_payments_status ON payments(status);

CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-update invoice.amount_paid when a payment is inserted/updated/deleted
CREATE OR REPLACE FUNCTION sync_invoice_amount_paid()
RETURNS TRIGGER AS $$
DECLARE
  v_invoice_id UUID;
  v_total_paid NUMERIC(12, 2);
BEGIN
  v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);

  SELECT COALESCE(SUM(amount), 0)
  INTO v_total_paid
  FROM payments
  WHERE invoice_id = v_invoice_id
    AND status = 'completed';

  UPDATE invoices
  SET
    amount_paid = v_total_paid,
    status = CASE
      WHEN v_total_paid >= total_amount THEN 'paid'::invoice_status
      WHEN v_total_paid > 0 THEN status   -- keep existing (partial payment doesn't change status automatically)
      ELSE status
    END
  WHERE id = v_invoice_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_invoice_amount_paid
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION sync_invoice_amount_paid();

-- ─────────────────────────────────────────────────────────────
-- TABLE: stock_movements
-- Immutable ledger of all inventory changes
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stock_movements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id      UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  movement_type   stock_movement_type NOT NULL,
  quantity        NUMERIC(12, 3) NOT NULL,           -- positive = in, negative = out
  quantity_before NUMERIC(12, 3) NOT NULL,
  quantity_after  NUMERIC(12, 3) NOT NULL,
  reference_id    UUID,                              -- points to invoice, purchase order, etc.
  reference_type  TEXT,                              -- 'invoice' | 'purchase' | 'adjustment'
  notes           TEXT,
  created_by      UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stock_movements_product_id ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_movement_type ON stock_movements(movement_type);
CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at);
CREATE INDEX idx_stock_movements_reference_id ON stock_movements(reference_id);

-- ─────────────────────────────────────────────────────────────
-- TABLE: settings
-- Key-value store for application configuration
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS settings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL,
  value       JSONB NOT NULL DEFAULT '{}',
  category    setting_category NOT NULL DEFAULT 'general',
  description TEXT,
  is_public   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT settings_key_unique UNIQUE (key)
);

CREATE INDEX idx_settings_category ON settings(category);
CREATE INDEX idx_settings_key ON settings(key);

CREATE TRIGGER trg_settings_updated_at
  BEFORE UPDATE ON settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─────────────────────────────────────────────────────────────
-- DEFAULT SETTINGS (seed data)
-- ─────────────────────────────────────────────────────────────

INSERT INTO settings (key, value, category, description, is_public) VALUES
  ('company_name',       '"Your Company Name"',        'general',  'Business name shown on invoices',          TRUE),
  ('company_email',      '"contact@yourcompany.com"',  'general',  'Primary contact email',                    TRUE),
  ('company_phone',      '""',                         'general',  'Primary contact phone number',             TRUE),
  ('company_address',    '""',                         'general',  'Registered business address',              TRUE),
  ('company_gstin',      '""',                         'general',  'GST Identification Number',                TRUE),
  ('currency',           '"INR"',                      'billing',  'Default currency code (ISO 4217)',         TRUE),
  ('currency_symbol',    '"₹"',                        'billing',  'Currency symbol for display',              TRUE),
  ('invoice_prefix',     '"INV"',                      'billing',  'Prefix for generated invoice numbers',     FALSE),
  ('invoice_due_days',   '30',                         'billing',  'Default payment due days after issue',     FALSE),
  ('default_tax_rate',   '18',                         'tax',      'Default GST/tax rate percentage',          FALSE),
  ('tax_name',           '"GST"',                      'tax',      'Tax label shown on invoices',              TRUE),
  ('enable_email_notif', 'true',                       'notifications', 'Send email notifications',            FALSE),
  ('theme',              '"system"',                   'appearance', 'UI theme: light | dark | system',        FALSE)
ON CONFLICT (key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS)
-- Enable RLS on all tables — users can only see their own data
-- or data within their organization (simplified for Stage 1)
-- ─────────────────────────────────────────────────────────────

ALTER TABLE user_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories       ENABLE ROW LEVEL SECURITY;
ALTER TABLE products         ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices         ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements  ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings         ENABLE ROW LEVEL SECURITY;

-- user_profiles: each user can see and edit only their own profile
CREATE POLICY "Users can view own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id);

-- Authenticated users can read/write all business data (Stage 1 simplified policy)
-- In later stages, restrict by role or organization

CREATE POLICY "Authenticated users can read categories"
  ON categories FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage categories"
  ON categories FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read products"
  ON products FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage products"
  ON products FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read customers"
  ON customers FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage customers"
  ON customers FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read invoices"
  ON invoices FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage invoices"
  ON invoices FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read invoice_items"
  ON invoice_items FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage invoice_items"
  ON invoice_items FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read payments"
  ON payments FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage payments"
  ON payments FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "Authenticated users can read stock_movements"
  ON stock_movements FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can insert stock_movements"
  ON stock_movements FOR INSERT TO authenticated WITH CHECK (TRUE);

-- Public settings are readable by anyone; private settings by authenticated users only
CREATE POLICY "Anyone can read public settings"
  ON settings FOR SELECT
  USING (is_public = TRUE);

CREATE POLICY "Authenticated users can read all settings"
  ON settings FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can manage settings"
  ON settings FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

-- ─────────────────────────────────────────────────────────────
-- COMMENTS (documentation for each table)
-- ─────────────────────────────────────────────────────────────

COMMENT ON TABLE user_profiles    IS 'Extended profile data for Supabase auth users';
COMMENT ON TABLE categories       IS 'Product categories (supports nested subcategories via parent_id)';
COMMENT ON TABLE products         IS 'Product/item catalog with pricing, tax, and stock information';
COMMENT ON TABLE customers        IS 'Customer master data including billing/shipping addresses';
COMMENT ON TABLE invoices         IS 'Invoice headers with status tracking and financial totals';
COMMENT ON TABLE invoice_items    IS 'Line items belonging to an invoice';
COMMENT ON TABLE payments         IS 'Payment records against invoices; triggers amount_paid sync';
COMMENT ON TABLE stock_movements  IS 'Immutable audit log of all inventory quantity changes';
COMMENT ON TABLE settings         IS 'Application configuration key-value store';
