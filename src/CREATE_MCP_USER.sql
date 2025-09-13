-- Create dedicated user for MCP server with RLS enforcement
-- This user will be subject to Row Level Security policies

-- Drop user if exists (for re-running the script)
DROP USER IF EXISTS mcp_user;

-- Create the MCP server user
CREATE USER mcp_user WITH PASSWORD 'mcp_secure_password';

-- Grant connection to the database (database name will be current database)
-- Note: If your database is named differently, update this line
-- GRANT CONNECT ON DATABASE your_database_name TO mcp_user;

-- Grant usage on the webshop schema
GRANT USAGE ON SCHEMA webshop TO mcp_user;

-- Grant SELECT, INSERT, UPDATE, DELETE on all tables in webshop schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA webshop TO mcp_user;

-- Grant usage on all sequences (for INSERT operations)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA webshop TO mcp_user;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION webshop.set_current_tenant(INTEGER) TO mcp_user;
GRANT EXECUTE ON FUNCTION webshop.get_current_tenant() TO mcp_user;

-- Ensure future tables and sequences also get permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA webshop 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mcp_user;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA webshop 
    GRANT USAGE, SELECT ON SEQUENCES TO mcp_user;

-- Important: This user is NOT a superuser and NOT the owner of tables
-- Therefore, RLS policies WILL be enforced for this user

-- Display confirmation
SELECT 'MCP user created successfully' as status;
SELECT 
    'Username: mcp_user' as connection_info
    UNION ALL
    SELECT 'Password: mcp_secure_password'
    UNION ALL
    SELECT 'Note: Change the password in production!'
    UNION ALL
    SELECT 'RLS will be enforced for this user';