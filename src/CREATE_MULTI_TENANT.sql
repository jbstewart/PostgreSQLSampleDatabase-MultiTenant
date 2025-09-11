-- Multi-tenant setup for webshop database
-- This script adds tenant support to the existing webshop schema

-- Step 1: Create tenants table
CREATE TABLE webshop.tenants (
  id SERIAL PRIMARY KEY,
  key UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  domain TEXT,
  created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated TIMESTAMP WITH TIME ZONE,
  active BOOLEAN DEFAULT TRUE,
  UNIQUE(key)
);

COMMENT ON TABLE webshop.tenants IS 'Tenant organizations using the webshop platform';

-- Step 2: Add tenant_id to all main tables
ALTER TABLE webshop.labels ADD COLUMN tenant_id INTEGER REFERENCES webshop.tenants(id);
ALTER TABLE webshop.products ADD COLUMN tenant_id INTEGER REFERENCES webshop.tenants(id);
ALTER TABLE webshop.customer ADD COLUMN tenant_id INTEGER REFERENCES webshop.tenants(id);
ALTER TABLE webshop.order ADD COLUMN tenant_id INTEGER REFERENCES webshop.tenants(id);

-- Note: colors, sizes, articles, stock, address, order_positions inherit tenant through relationships

-- Step 3: Create indexes for performance
CREATE INDEX idx_labels_tenant_id ON webshop.labels(tenant_id);
CREATE INDEX idx_products_tenant_id ON webshop.products(tenant_id);
CREATE INDEX idx_customer_tenant_id ON webshop.customer(tenant_id);
CREATE INDEX idx_order_tenant_id ON webshop.order(tenant_id);

-- Step 4: Enable Row Level Security (RLS)
ALTER TABLE webshop.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.address ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order ENABLE ROW LEVEL SECURITY;
ALTER TABLE webshop.order_positions ENABLE ROW LEVEL SECURITY;

-- Step 5: Create RLS policies
-- Tenants can only see their own data
CREATE POLICY tenant_isolation_labels ON webshop.labels
  USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_products ON webshop.products
  USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_articles ON webshop.articles
  USING (productId IN (SELECT id FROM webshop.products WHERE tenant_id = current_setting('app.current_tenant_id')::INTEGER));

CREATE POLICY tenant_isolation_stock ON webshop.stock
  USING (articleId IN (
    SELECT a.id FROM webshop.articles a 
    JOIN webshop.products p ON a.productId = p.id 
    WHERE p.tenant_id = current_setting('app.current_tenant_id')::INTEGER
  ));

CREATE POLICY tenant_isolation_customer ON webshop.customer
  USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_address ON webshop.address
  USING (customerId IN (SELECT id FROM webshop.customer WHERE tenant_id = current_setting('app.current_tenant_id')::INTEGER));

CREATE POLICY tenant_isolation_order ON webshop.order
  USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_order_positions ON webshop.order_positions
  USING (orderId IN (SELECT id FROM webshop.order WHERE tenant_id = current_setting('app.current_tenant_id')::INTEGER));

-- Step 6: Helper functions
CREATE OR REPLACE FUNCTION webshop.set_current_tenant(tenant_id INTEGER)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_tenant_id', tenant_id::TEXT, false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION webshop.get_current_tenant()
RETURNS INTEGER AS $$
BEGIN
  RETURN current_setting('app.current_tenant_id', true)::INTEGER;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Insert sample tenants
INSERT INTO webshop.tenants (name, slug, domain) VALUES
('Acme Fashion Store', 'acme-fashion', 'acme.example.com'),
('Style Central', 'style-central', 'style.example.com'),
('Urban Trends', 'urban-trends', 'urban.example.com');