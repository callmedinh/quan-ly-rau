-- =====================================================================
-- QUẢN LÝ RAU — initial schema (Supabase / PostgreSQL)
-- ---------------------------------------------------------------------
-- How to run:  Supabase Dashboard → SQL Editor → paste & Run
--              or   supabase db push   (Supabase CLI, local repo)
--
-- NOTE ON SECURITY / RLS:
--   This app is designed as a *personal, single-vendor* tool. The tables
--   below are created WITHOUT row level security so the app works out of
--   the box with the public `anon` key.
--   For a multi-user deployment add an `owner_id uuid` column to every
--   table, enable RLS and add per-user policies (helper policies are
--   included at the bottom, commented out). See README → Security.
-- =====================================================================

-- =====================================================================
-- 1. Suppliers  (nhà cung cấp)
-- =====================================================================
CREATE TABLE IF NOT EXISTS suppliers (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(100) NOT NULL,
    phone      VARCHAR(20),
    address    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_name  ON suppliers (name);
CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers (phone);

-- =====================================================================
-- 2. Products  (mặt hàng / loại rau)
-- =====================================================================
CREATE TABLE IF NOT EXISTS products (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(100) NOT NULL,
    unit       VARCHAR(20) NOT NULL DEFAULT 'kg',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_name ON products (name);

-- =====================================================================
-- 3. Purchase Orders  (phiếu nhập — nhập buổi sáng, chốt giá buổi tối)
--    is_price_settled = FALSE : vừa nhập, chưa thống nhất giá
--    is_price_settled = TRUE  : đã chốt giá (final_cost) với nhà cung cấp
-- =====================================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id        UUID REFERENCES suppliers(id),
    product_id         UUID REFERENCES products(id),
    quantity           DECIMAL(10,2) NOT NULL,
    import_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    is_price_settled   BOOLEAN NOT NULL DEFAULT FALSE,
    final_cost         DECIMAL(12,2),          -- giá nhập đã chốt (theo đơn vị)
    total_sales_amount DECIMAL(12,2),          -- tổng tiền bán được của lô hàng
    notes              TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_po_supplier   ON purchase_orders (supplier_id);
CREATE INDEX IF NOT EXISTS idx_po_product    ON purchase_orders (product_id);
CREATE INDEX IF NOT EXISTS idx_po_date       ON purchase_orders (import_date);
CREATE INDEX IF NOT EXISTS idx_po_settled    ON purchase_orders (is_price_settled);

-- =====================================================================
-- 4. Payments  (sổ trả nợ cho nhà cung cấp)
--    outstanding debt of a supplier =
--        SUM(quantity * final_cost) of SETTLED purchase_orders
--      - SUM(amount)                of payments
-- =====================================================================
CREATE TABLE IF NOT EXISTS payments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id  UUID REFERENCES suppliers(id),
    amount       DECIMAL(12,2) NOT NULL,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes        TEXT
);

CREATE INDEX IF NOT EXISTS idx_payments_supplier ON payments (supplier_id);

-- =====================================================================
-- 5. Daily profit view
-- =====================================================================
CREATE OR REPLACE VIEW daily_profit_report AS
SELECT
    import_date,
    COUNT(id)                                        AS total_orders,
    SUM(total_sales_amount)                          AS total_revenue,
    SUM(quantity * final_cost)                       AS total_cost,
    SUM(total_sales_amount - (quantity * final_cost)) AS net_profit
FROM purchase_orders
WHERE is_price_settled = TRUE
GROUP BY import_date
ORDER BY import_date DESC;

-- =====================================================================
-- 6. Supplier balances — aggregates computed INSIDE Postgres.
--    Used by the "Sổ Nợ" screen. Doing this in SQL is safe even when a
--    supplier has thousands of orders/payments (client-side SUM would be
--    truncated by the API row limit).
-- =====================================================================
CREATE OR REPLACE FUNCTION public.supplier_balances()
RETURNS TABLE (
    supplier_id        uuid,
    total_due          numeric,   -- Σ(quantity × final_cost) đã chốt giá
    paid_amount        numeric,   -- Σ(payments.amount)
    order_count        bigint,    -- số phiếu đã chốt
    last_payment_date  timestamptz
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        s.id AS supplier_id,
        COALESCE(po.due, 0)          AS total_due,
        COALESCE(pay.paid, 0)        AS paid_amount,
        COALESCE(po.cnt, 0)          AS order_count,
        pay.last_payment_date        AS last_payment_date
    FROM suppliers s
    LEFT JOIN (
        SELECT supplier_id,
               SUM(quantity * final_cost) AS due,
               COUNT(*)                   AS cnt
        FROM purchase_orders
        WHERE is_price_settled = TRUE
        GROUP BY supplier_id
    ) po ON po.supplier_id = s.id
    LEFT JOIN (
        SELECT supplier_id,
               SUM(amount)          AS paid,
               MAX(payment_date)    AS last_payment_date
        FROM payments
        GROUP BY supplier_id
    ) pay ON pay.supplier_id = s.id
$$;

GRANT EXECUTE ON FUNCTION public.supplier_balances() TO anon, authenticated;

-- =====================================================================
-- Optional seeds (uncomment to try the app with sample data)
-- =====================================================================
-- INSERT INTO suppliers (name, phone) VALUES
--   ('Chú Tư rau xanh', '0912 345 678'),
--   ('Cô Ba Đà Lạt',    '0987 654 321');
--
-- INSERT INTO products (name, unit) VALUES
--   ('Cải ngọt', 'kg'),
--   ('Rau muống', 'bó'),
--   ('Cà chua', 'kg'),
--   ('Xà lách', 'kg');

-- =====================================================================
-- RLS helper policies for a multi-user deployment (optional).
-- Enable only after adding `owner_id uuid NOT NULL DEFAULT auth.uid()`
-- to every table and a matching `WHERE owner_id = auth.uid()` policy.
-- =====================================================================
-- ALTER TABLE suppliers       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE products        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE payments        ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY "owner_suppliers"       ON suppliers       FOR ALL USING (owner_id = auth.uid());
-- CREATE POLICY "owner_products"        ON products        FOR ALL USING (owner_id = auth.uid());
-- CREATE POLICY "owner_purchase_orders" ON purchase_orders FOR ALL USING (owner_id = auth.uid());
-- CREATE POLICY "owner_payments"        ON payments        FOR ALL USING (owner_id = auth.uid());
