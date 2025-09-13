-- RLS (Row Level Security) Test Script
-- This script tests that tenant isolation is working correctly

\echo '==========================================';
\echo 'Testing Row Level Security (RLS)';
\echo '==========================================';
\echo '';

-- First, show all available tenants
\echo '--- Available Tenants ---';
SELECT id, name, slug FROM webshop.tenants ORDER BY id;
\echo '';

-- Test 1: No tenant context set - should show no data due to RLS
\echo '--- Test 1: No tenant context (should show 0 records) ---';
SELECT 'Products' as table_name, COUNT(*) as count FROM webshop.products
UNION ALL
SELECT 'Articles' as table_name, COUNT(*) as count FROM webshop.articles  
UNION ALL
SELECT 'Customers' as table_name, COUNT(*) as count FROM webshop.customer
UNION ALL
SELECT 'Orders' as table_name, COUNT(*) as count FROM webshop.order
UNION ALL
SELECT 'Labels' as table_name, COUNT(*) as count FROM webshop.labels;
\echo '';

-- Test 2: Set tenant to 1 (Acme Fashion Store)
\echo '--- Test 2: Setting tenant to 1 (Acme Fashion Store) ---';
SELECT webshop.set_current_tenant(1);
\echo 'Current tenant:';
SELECT webshop.get_current_tenant() as current_tenant_id;
\echo '';

\echo 'Data counts for tenant 1:';
SELECT 'Products' as table_name, COUNT(*) as count FROM webshop.products
UNION ALL
SELECT 'Articles' as table_name, COUNT(*) as count FROM webshop.articles  
UNION ALL
SELECT 'Customers' as table_name, COUNT(*) as count FROM webshop.customer
UNION ALL
SELECT 'Orders' as table_name, COUNT(*) as count FROM webshop.order
UNION ALL
SELECT 'Labels' as table_name, COUNT(*) as count FROM webshop.labels;
\echo '';

\echo 'Sample data for tenant 1:';
SELECT 'Product' as type, id, name FROM webshop.products LIMIT 3
UNION ALL
SELECT 'Customer' as type, id, firstname || ' ' || lastname FROM webshop.customer LIMIT 3;
\echo '';

-- Test 3: Set tenant to 2 (Style Central)
\echo '--- Test 3: Setting tenant to 2 (Style Central) ---';
SELECT webshop.set_current_tenant(2);
\echo 'Current tenant:';
SELECT webshop.get_current_tenant() as current_tenant_id;
\echo '';

\echo 'Data counts for tenant 2:';
SELECT 'Products' as table_name, COUNT(*) as count FROM webshop.products
UNION ALL
SELECT 'Articles' as table_name, COUNT(*) as count FROM webshop.articles  
UNION ALL
SELECT 'Customers' as table_name, COUNT(*) as count FROM webshop.customer
UNION ALL
SELECT 'Orders' as table_name, COUNT(*) as count FROM webshop.order
UNION ALL
SELECT 'Labels' as table_name, COUNT(*) as count FROM webshop.labels;
\echo '';

\echo 'Sample data for tenant 2:';
SELECT 'Product' as type, id, name FROM webshop.products LIMIT 3
UNION ALL
SELECT 'Customer' as type, id, firstname || ' ' || lastname FROM webshop.customer LIMIT 3;
\echo '';

-- Test 4: Set tenant to 3 (Urban Trends)
\echo '--- Test 4: Setting tenant to 3 (Urban Trends) ---';
SELECT webshop.set_current_tenant(3);
\echo 'Current tenant:';
SELECT webshop.get_current_tenant() as current_tenant_id;
\echo '';

\echo 'Data counts for tenant 3:';
SELECT 'Products' as table_name, COUNT(*) as count FROM webshop.products
UNION ALL
SELECT 'Articles' as table_name, COUNT(*) as count FROM webshop.articles  
UNION ALL
SELECT 'Customers' as table_name, COUNT(*) as count FROM webshop.customer
UNION ALL
SELECT 'Orders' as table_name, COUNT(*) as count FROM webshop.order
UNION ALL
SELECT 'Labels' as table_name, COUNT(*) as count FROM webshop.labels;
\echo '';

\echo 'Sample data for tenant 3:';
SELECT 'Product' as type, id, name FROM webshop.products LIMIT 3
UNION ALL
SELECT 'Customer' as type, id, firstname || ' ' || lastname FROM webshop.customer LIMIT 3;
\echo '';

-- Test 5: Verify tenant isolation in order_positions
\echo '--- Test 5: Order-Article Tenant Consistency Test ---';
SELECT webshop.set_current_tenant(1);
\echo 'Testing tenant 1 order consistency:';
SELECT 
  COUNT(*) as total_order_positions,
  COUNT(CASE WHEN o.tenant_id = 1 THEN 1 END) as tenant_1_orders,
  COUNT(CASE WHEN a.tenant_id = 1 THEN 1 END) as tenant_1_articles,
  COUNT(CASE WHEN o.tenant_id = a.tenant_id THEN 1 END) as consistent_matches
FROM webshop.order_positions op
JOIN webshop.order o ON op.orderid = o.id  
JOIN webshop.articles a ON op.articleid = a.id
LIMIT 100;
\echo '';

-- Test 6: Cross-tenant verification (should be impossible to access other tenant data)
\echo '--- Test 6: Cross-tenant Access Test ---';
SELECT webshop.set_current_tenant(1);
\echo 'Set to tenant 1, trying to access all products (should only show tenant 1):';
SELECT tenant_id, COUNT(*) as count 
FROM webshop.products 
GROUP BY tenant_id 
ORDER BY tenant_id;
\echo '';

SELECT webshop.set_current_tenant(2);
\echo 'Set to tenant 2, trying to access all products (should only show tenant 2):';
SELECT tenant_id, COUNT(*) as count 
FROM webshop.products 
GROUP BY tenant_id 
ORDER BY tenant_id;
\echo '';

-- Test 7: Reset tenant context
\echo '--- Test 7: Reset tenant context ---';
-- Clear the tenant context by setting an invalid tenant
SELECT set_config('app.current_tenant_id', '', false);
\echo 'Tenant context cleared. Data should be filtered out again:';
SELECT 'Products' as table_name, COUNT(*) as count FROM webshop.products
UNION ALL
SELECT 'Customers' as table_name, COUNT(*) as count FROM webshop.customer;
\echo '';

\echo '==========================================';
\echo 'RLS Test Complete';
\echo '==========================================';
\echo '';
\echo 'Expected Results:';
\echo '- Test 1: All counts should be 0 (no tenant set)';
\echo '- Tests 2-4: Each tenant should show different data';
\echo '- Test 5: Orders and articles should have matching tenant_ids';
\echo '- Test 6: Each tenant context should only show its own data'; 
\echo '- Test 7: Clearing context should result in 0 counts again';
\echo '';