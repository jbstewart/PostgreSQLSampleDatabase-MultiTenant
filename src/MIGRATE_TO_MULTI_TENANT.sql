-- Migration script to assign existing data to tenants
-- Run this AFTER CREATE_MULTI_TENANT.sql and AFTER loading your existing data

-- Temporarily disable RLS for data migration
ALTER TABLE webshop.labels DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.articles DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.stock DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.customer DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.address DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order DISABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order_positions DISABLE ROW LEVEL SECURITY;

-- Strategy: Distribute existing data across tenants randomly for demo purposes
-- In a real migration, you'd have business logic to determine tenant assignment

-- Update labels - assign randomly to tenants
UPDATE webshop.labels 
SET tenant_id = (
  SELECT id FROM webshop.tenants 
  ORDER BY random() 
  LIMIT 1
)
WHERE tenant_id IS NULL;

-- Update products - assign randomly to tenants
UPDATE webshop.products 
SET tenant_id = (
  SELECT id FROM webshop.tenants 
  ORDER BY random() 
  LIMIT 1
)
WHERE tenant_id IS NULL;

-- Update customers - distribute evenly across tenants
WITH numbered_customers AS (
  SELECT id, 
         ROW_NUMBER() OVER (ORDER BY id) as rn,
         (SELECT COUNT(*) FROM webshop.tenants) as tenant_count
  FROM webshop.customer 
  WHERE tenant_id IS NULL
),
tenant_assignment AS (
  SELECT nc.id as customer_id,
         t.id as tenant_id
  FROM numbered_customers nc
  CROSS JOIN LATERAL (
    SELECT id 
    FROM webshop.tenants 
    ORDER BY id 
    OFFSET ((nc.rn - 1) % nc.tenant_count) 
    LIMIT 1
  ) t
)
UPDATE webshop.customer 
SET tenant_id = ta.tenant_id
FROM tenant_assignment ta
WHERE webshop.customer.id = ta.customer_id;

-- Update orders - assign to same tenant as customer
UPDATE webshop.order 
SET tenant_id = c.tenant_id
FROM webshop.customer c
WHERE webshop.order.customerId = c.id
AND webshop.order.tenant_id IS NULL;

-- Re-enable RLS
ALTER TABLE webshop.labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.address ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order_positions ENABLE ROW LEVEL SECURITY;

-- Add NOT NULL constraints after migration
ALTER TABLE webshop.labels ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE webshop.products ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE webshop.customer ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE webshop.order ALTER COLUMN tenant_id SET NOT NULL;

-- Verify migration results
SELECT 
  t.name as tenant_name,
  COUNT(DISTINCT c.id) as customers,
  COUNT(DISTINCT o.id) as orders,
  COUNT(DISTINCT p.id) as products,
  COUNT(DISTINCT l.id) as labels
FROM webshop.tenants t
LEFT JOIN webshop.customer c ON t.id = c.tenant_id
LEFT JOIN webshop.order o ON t.id = o.tenant_id
LEFT JOIN webshop.products p ON t.id = p.tenant_id
LEFT JOIN webshop.labels l ON t.id = l.tenant_id
GROUP BY t.id, t.name
ORDER BY t.name;