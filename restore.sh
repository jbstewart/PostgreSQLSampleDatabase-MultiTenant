#!/usr/bin/env bash

# PostgreSQL webshop database setup script
# Usage: ./restore.sh [database_name] [username] [host] [port] [--multi-tenant]

# Check for help flag
for arg in "$@"; do
    if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
        echo "PostgreSQL webshop database setup script"
        echo ""
        echo "Usage: $0 [database_name] [username] [host] [port] [--multi-tenant]"
        echo ""
        echo "Arguments:"
        echo "  database_name   Database name (default: mywebshop)"
        echo "  username        PostgreSQL username (default: jbstewart)"
        echo "  host           PostgreSQL host (default: localhost)"
        echo "  port           PostgreSQL port (default: 5432)"
        echo ""
        echo "Options:"
        echo "  --multi-tenant  Enable multi-tenant setup"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Single-tenant with defaults"
        echo "  $0 myshop postgres localhost 5432    # Custom connection"
        echo "  $0 myshop postgres --multi-tenant    # Multi-tenant setup"
        exit 0
    fi
done

DB_NAME=${1:-mywebshop}
USERNAME=${2:-jbstewart}
HOST=${3:-localhost}
PORT=${4:-5432}
MULTI_TENANT=false

# Check for --multi-tenant flag in any position
for arg in "$@"; do
    if [ "$arg" = "--multi-tenant" ]; then
        MULTI_TENANT=true
        break
    fi
done

echo "Setting up database: $DB_NAME"
echo "Using connection: $USERNAME@$HOST:$PORT"
if [ "$MULTI_TENANT" = true ]; then
    echo "Multi-tenant mode: enabled"
else
    echo "Multi-tenant mode: disabled"
fi
echo ""

echo "Step 1: Creating database..."
createdb -h $HOST -p $PORT -U $USERNAME $DB_NAME
if [ $? -eq 0 ]; then
    echo "✓ Database created successfully"
else
    echo "⚠ Database may already exist, continuing..."
fi

echo "Step 2: Restoring base data..."
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/create.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/products.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/articles.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/labels.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/customer.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/address.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/order.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/order_positions.sql
psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/stock.sql

# Check if tenants.sql exists and restore it if found
if [ -f "data/tenants.sql" ]; then
    echo "Found existing tenants data, restoring..."
    psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f data/tenants.sql
fi

if [ $? -eq 0 ]; then
    echo "✓ Base data restored successfully"
else
    echo "✗ Failed to restore base data"
    exit 1
fi

# Multi-tenant setup if requested
if [ "$MULTI_TENANT" = true ]; then
    echo ""
    echo "Step 3: Setting up multi-tenant architecture..."
    psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f src/CREATE_MULTI_TENANT.sql
    
    if [ $? -eq 0 ]; then
        echo "✓ Multi-tenant schema created successfully"
    else
        echo "✗ Failed to create multi-tenant schema"
        exit 1
    fi
    
    echo "Step 4: Migrating existing data to multi-tenant structure..."
    psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -f src/MIGRATE_TO_MULTI_TENANT.sql
    
    if [ $? -eq 0 ]; then
        echo "✓ Data migration completed successfully"
    else
        echo "✗ Failed to migrate data"
        exit 1
    fi
    
    echo ""
    echo "🎉 Multi-tenant database setup complete!"
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
else
    echo ""
    echo "🎉 Single-tenant database setup complete!"
    echo ""
    echo "To enable multi-tenant support later, run:"
    echo "   ./restore.sh $DB_NAME $USERNAME $HOST $PORT --multi-tenant"
fi