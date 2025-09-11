#!/bin/bash

# Multi-tenant setup script for PostgreSQL webshop database
# Usage: ./setup_multi_tenant.sh [database_name] [username]

DB_NAME=${1:-mywebshop}
USERNAME=${2:-postgres}
HOST=${3:-localhost}
PORT=${4:-5432}

echo "Setting up multi-tenant architecture for database: $DB_NAME"
echo "Using connection: $USERNAME@$HOST:$PORT"

# Check if database exists
if ! psql -h $HOST -p $PORT -U $USERNAME -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "Database $DB_NAME does not exist. Please create it first or run restore.sh"
    exit 1
fi

echo "Step 1: Creating multi-tenant schema..."
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f src/CREATE_MULTI_TENANT.sql

if [ $? -eq 0 ]; then
    echo "✓ Multi-tenant schema created successfully"
else
    echo "✗ Failed to create multi-tenant schema"
    exit 1
fi

echo "Step 2: Migrating existing data to multi-tenant structure..."
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f src/MIGRATE_TO_MULTI_TENANT.sql

if [ $? -eq 0 ]; then
    echo "✓ Data migration completed successfully"
else
    echo "✗ Failed to migrate data"
    exit 1
fi

echo ""
echo "🎉 Multi-tenant setup complete!"
echo ""
echo "Next steps:"
echo "1. Test the setup:"
echo "   psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f src/DEMO_MULTI_TENANT.sql"
echo ""
echo "2. Set tenant context in your application:"
echo "   SELECT webshop.set_current_tenant(1); -- for Acme Fashion Store"
echo "   SELECT webshop.set_current_tenant(2); -- for Style Central"
echo "   SELECT webshop.set_current_tenant(3); -- for Urban Trends"
echo ""
echo "3. All queries will now automatically filter by tenant_id"
echo ""
echo "Available tenants:"
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -c "SELECT id, name, slug FROM webshop.tenants ORDER BY id;"