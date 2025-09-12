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

-- Update products - distribute evenly across the 3 tenants using modulo
WITH numbered_products AS (
  SELECT id, 
         ROW_NUMBER() OVER (ORDER BY id) as rn
  FROM webshop.products 
  WHERE tenant_id IS NULL
),
tenant_assignment AS (
  SELECT np.id as product_id,
         CASE 
           WHEN (np.rn - 1) % 3 = 0 THEN 1
           WHEN (np.rn - 1) % 3 = 1 THEN 2
           ELSE 3
         END as tenant_id
  FROM numbered_products np
)
UPDATE webshop.products 
SET tenant_id = ta.tenant_id
FROM tenant_assignment ta
WHERE webshop.products.id = ta.product_id;

-- Update articles - assign to same tenant as their product
UPDATE webshop.articles 
SET tenant_id = p.tenant_id
FROM webshop.products p
WHERE webshop.articles.productid = p.id
AND webshop.articles.tenant_id IS NULL;

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

-- Update orders - this is complex because we need to ensure order tenant matches article tenants
-- First, let's identify orders that have articles from multiple tenants (these need to be handled)
WITH order_tenant_conflicts AS (
  SELECT 
    o.id as order_id,
    o.customerId,
    COUNT(DISTINCT a.tenant_id) as tenant_count,
    MIN(a.tenant_id) as primary_tenant_id
  FROM webshop.order o
  JOIN webshop.order_positions op ON o.id = op.orderId
  JOIN webshop.articles a ON op.articleId = a.id
  WHERE o.tenant_id IS NULL
  GROUP BY o.id, o.customerId
),
-- For orders with conflicting tenants, we'll reassign the customer to match the primary article tenant
customer_reassignments AS (
  SELECT DISTINCT
    otc.customerId,
    otc.primary_tenant_id
  FROM order_tenant_conflicts otc
  WHERE otc.tenant_count > 1
)
-- First, update customers for orders that have tenant conflicts
UPDATE webshop.customer 
SET tenant_id = cr.primary_tenant_id
FROM customer_reassignments cr
WHERE webshop.customer.id = cr.customerId;

-- Now update orders - assign to same tenant as customer (which now aligns with articles)
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
ALTER TABLE webshop.articles ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE webshop.customer ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE webshop.order ALTER COLUMN tenant_id SET NOT NULL;

-- Verify migration results
SELECT 
  t.name as tenant_name,
  COUNT(DISTINCT c.id) as customers,
  COUNT(DISTINCT o.id) as orders,
  COUNT(DISTINCT p.id) as products,
  COUNT(DISTINCT a.id) as articles,
  COUNT(DISTINCT l.id) as labels
FROM webshop.tenants t
LEFT JOIN webshop.customer c ON t.id = c.tenant_id
LEFT JOIN webshop.order o ON t.id = o.tenant_id
LEFT JOIN webshop.products p ON t.id = p.tenant_id
LEFT JOIN webshop.articles a ON t.id = a.tenant_id
LEFT JOIN webshop.labels l ON t.id = l.tenant_id
GROUP BY t.id, t.name
ORDER BY t.name;

-- Additional verification: Check for tenant consistency in order_positions
SELECT 
  'Order-Article Tenant Consistency Check' as check_name,
  COUNT(*) as total_order_positions,
  COUNT(CASE WHEN o.tenant_id = a.tenant_id THEN 1 END) as consistent_positions,
  COUNT(CASE WHEN o.tenant_id != a.tenant_id THEN 1 END) as inconsistent_positions
FROM webshop.order_positions op
JOIN webshop.order o ON op.orderId = o.id
JOIN webshop.articles a ON op.articleId = a.id;