-- ============================================================
-- Stage 4: Stock Adjustment RPC
-- Run this in your Supabase SQL Editor
-- ============================================================

CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_user_id UUID,
  p_movement_type stock_movement_type,
  p_quantity NUMERIC,
  p_notes TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_stock NUMERIC;
  v_new_stock NUMERIC;
BEGIN
  -- Lock the product row for update to prevent race conditions
  SELECT stock_quantity INTO v_current_stock
  FROM products
  WHERE id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Calculate new stock
  v_new_stock := v_current_stock + p_quantity;

  -- Validation (prevent negative stock if you want to strictly enforce it)
  -- IF v_new_stock < 0 THEN
  --   RAISE EXCEPTION 'Stock cannot be negative';
  -- END IF;

  -- Update product stock
  UPDATE products
  SET stock_quantity = v_new_stock
  WHERE id = p_product_id;

  -- Record the movement
  INSERT INTO stock_movements (
    product_id,
    movement_type,
    quantity,
    quantity_before,
    quantity_after,
    reference_id,
    reference_type,
    notes,
    created_by
  ) VALUES (
    p_product_id,
    p_movement_type,
    p_quantity,
    v_current_stock,
    v_new_stock,
    p_reference_id,
    p_reference_type,
    p_notes,
    p_user_id
  );
END;
$$;
