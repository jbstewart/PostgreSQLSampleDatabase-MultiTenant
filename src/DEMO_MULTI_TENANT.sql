-- Demo script showing multi-tenant functionality
-- Run this after setting up the multi-tenant database

-- Show all tenants
SELECT * FROM webshop.tenants ORDER BY name;

-- Demo 1: Switch to Acme Fashion Store
SELECT webshop.set_current_tenant(1); -- Acme Fashion Store

-- Show data visible to Acme Fashion Store
SELECT 'Current tenant:' as info, webshop.get_current_tenant() as tenant_id;

SELECT 'Customers for current tenant:' as info;
SELECT id, firstName, lastName, email, tenant_id 
FROM webshop.customer 
ORDER BY lastName, firstName 
LIMIT 10;

SELECT 'Orders for current tenant:' as info;
SELECT o.id, c.firstName, c.lastName, o.total, o.orderTimestamp
FROM webshop.order o
JOIN webshop.customer c ON o.customerId = c.id
ORDER BY o.orderTimestamp DESC
LIMIT 10;

SELECT 'Products for current tenant:' as info;
SELECT p.id, p.name, p.category, l.name as label_name
FROM webshop.products p
LEFT JOIN webshop.labels l ON p.labelId = l.id
ORDER BY p.name
LIMIT 10;

-- Demo 2: Switch to Style Central
SELECT webshop.set_current_tenant(2); -- Style Central

SELECT 'Current tenant:' as info, webshop.get_current_tenant() as tenant_id;

SELECT 'Customers for Style Central:' as info;
SELECT id, firstName, lastName, email, tenant_id 
FROM webshop.customer 
ORDER BY lastName, firstName 
LIMIT 10;

SELECT 'Orders for Style Central:' as info;
SELECT o.id, c.firstName, c.lastName, o.total, o.orderTimestamp
FROM webshop.order o
JOIN webshop.customer c ON o.customerId = c.id
ORDER BY o.orderTimestamp DESC
LIMIT 10;

-- Demo 3: Switch to Urban Trends
SELECT webshop.set_current_tenant(3); -- Urban Trends

SELECT 'Current tenant:' as info, webshop.get_current_tenant() as tenant_id;

SELECT 'Revenue by tenant (switch back to show all data):' as info;
-- This query requires superuser or RLS bypass to see all data
SET row_security = off;
SELECT 
  t.name as tenant_name,
  COUNT(DISTINCT c.id) as total_customers,
  COUNT(DISTINCT o.id) as total_orders,
  COALESCE(SUM(o.total::numeric), 0) as total_revenue
FROM webshop.tenants t
LEFT JOIN webshop.customer c ON t.id = c.tenant_id
LEFT JOIN webshop.order o ON t.id = o.tenant_id
GROUP BY t.id, t.name
ORDER BY total_revenue DESC;
SET row_security = on;

-- Demo 4: Show tenant isolation works
SELECT 'Testing tenant isolation - set to tenant 1:' as info;
SELECT webshop.set_current_tenant(1);

SELECT 'Customer count (should only show tenant 1 customers):' as info;
SELECT COUNT(*) as customer_count FROM webshop.customer;

SELECT 'Order count (should only show tenant 1 orders):' as info;
SELECT COUNT(*) as order_count FROM webshop.order;

-- Reset tenant context
SELECT webshop.set_current_tenant(1); -- Default back to tenant 1