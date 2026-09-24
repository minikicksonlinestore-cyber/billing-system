-- ============================================================
-- Stage 7 — Atomic Invoice Confirmation Stored Procedure
-- Handles validation, stock deduction, movements, and payment in one transaction
-- ============================================================

CREATE OR REPLACE FUNCTION confirm_invoice_transaction(
  p_invoice_number TEXT,
  p_customer_id UUID,
  p_status invoice_status,
  p_issue_date DATE,
  p_due_date DATE,
  p_subtotal NUMERIC,
  p_tax_amount NUMERIC,
  p_discount_amount NUMERIC,
  p_total_amount NUMERIC,
  p_amount_paid NUMERIC,
  p_amount_due NUMERIC,
  p_notes TEXT,
  p_created_by UUID,
  p_items JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_id UUID;
  v_invoice_id UUID;
  v_item JSONB;
  v_product_id UUID;
  v_qty NUMERIC;
  v_current_stock NUMERIC;
  v_new_stock NUMERIC;
  v_product_name TEXT;
BEGIN
  -- 1. Prevent duplicate invoice creation
  SELECT id INTO v_existing_id FROM invoices WHERE invoice_number = p_invoice_number;
  IF v_existing_id IS NOT NULL THEN
    RAISE EXCEPTION 'Duplicate invoice: Invoice number % already exists.', p_invoice_number;
  END IF;

  -- 2. Validate Customer
  IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
    RAISE EXCEPTION 'Customer not found.';
  END IF;

  -- 3. Validate Stock & Products (Lock rows for update)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    IF (v_item->>'product_id') IS NOT NULL AND (v_item->>'product_id') != '' THEN
      v_product_id := (v_item->>'product_id')::UUID;
      v_qty := (v_item->>'quantity')::NUMERIC;

      SELECT stock_quantity, name INTO v_current_stock, v_product_name
      FROM products
      WHERE id = v_product_id
      FOR UPDATE;

      IF v_product_name IS NULL THEN
        RAISE EXCEPTION 'Product not found.';
      END IF;

      -- Enforce stock validation for confirmed invoices
      IF p_status != 'draft' AND v_current_stock < v_qty THEN
        RAISE EXCEPTION 'Insufficient stock for product "%". Requested: %, Available: %', v_product_name, v_qty, v_current_stock;
      END IF;
    END IF;
  END LOOP;

  -- 4. Create Invoice Header
  INSERT INTO invoices (
    invoice_number,
    customer_id,
    status,
    issue_date,
    due_date,
    subtotal,
    tax_amount,
    discount_amount,
    total_amount,
    amount_paid,
    notes,
    created_by
  ) VALUES (
    p_invoice_number,
    p_customer_id,
    p_status,
    p_issue_date,
    p_due_date,
    p_subtotal,
    p_tax_amount,
    p_discount_amount,
    p_total_amount,
    p_amount_paid,
    p_notes,
    p_created_by
  ) RETURNING id INTO v_invoice_id;

  -- 5. Loop Items: Insert Line Items + Deduct Stock + Record Movements
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Insert line item
    INSERT INTO invoice_items (
      invoice_id,
      product_id,
      description,
      quantity,
      unit_price,
      tax_rate,
      tax_amount,
      discount_percentage,
      discount_amount,
      total_amount
    ) VALUES (
      v_invoice_id,
      CASE WHEN (v_item->>'product_id') IS NOT NULL AND (v_item->>'product_id') != '' THEN (v_item->>'product_id')::UUID ELSE NULL END,
      v_item->>'description',
      (v_item->>'quantity')::NUMERIC,
      (v_item->>'unit_price')::NUMERIC,
      (v_item->>'tax_rate')::NUMERIC,
      (v_item->>'tax_amount')::NUMERIC,
      (v_item->>'discount_percentage')::NUMERIC,
      (v_item->>'discount_amount')::NUMERIC,
      (v_item->>'total_amount')::NUMERIC
    );

    -- Stock deduction and movement logging (ONLY if invoice is not draft and product_id exists)
    IF p_status != 'draft' AND (v_item->>'product_id') IS NOT NULL AND (v_item->>'product_id') != '' THEN
      v_product_id := (v_item->>'product_id')::UUID;
      v_qty := (v_item->>'quantity')::NUMERIC;

      SELECT stock_quantity INTO v_current_stock FROM products WHERE id = v_product_id;
      v_new_stock := v_current_stock - v_qty;

      -- Deduct stock
      UPDATE products SET stock_quantity = v_new_stock WHERE id = v_product_id;

      -- Create stock movement record
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
        v_product_id,
        'sale',
        -v_qty,
        v_current_stock,
        v_new_stock,
        v_invoice_id,
        'invoice',
        'Sale via Invoice #' || p_invoice_number,
        p_created_by
      );
    END IF;
  END LOOP;

  -- 6. Save Payment Information (if amount_paid > 0)
  IF p_amount_paid > 0 THEN
    INSERT INTO payments (
      invoice_id,
      payment_date,
      amount,
      payment_method,
      status,
      notes,
      created_by
    ) VALUES (
      v_invoice_id,
      p_issue_date,
      p_amount_paid,
      'cash',
      'completed',
      'Initial payment for Invoice #' || p_invoice_number,
      p_created_by
    );
  END IF;

  -- 7. Return Result
  RETURN jsonb_build_object(
    'invoice_id', v_invoice_id,
    'invoice_number', p_invoice_number,
    'status', p_status
  );
END;
$$;
