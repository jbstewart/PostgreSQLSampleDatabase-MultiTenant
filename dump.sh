#!/usr/bin/env bash

# PostgreSQL webshop database dump script
# Usage: ./dump.sh [database_name] [username] [host] [port]

DB_NAME=${1:-mywebshop}
USERNAME=${2:-jbstewart}
HOST=${3:-localhost}
PORT=${4:-5432}

# Check for help flag
for arg in "$@"; do
    if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
        echo "PostgreSQL webshop database dump script"
        echo ""
        echo "Usage: $0 [database_name] [username] [host] [port]"
        echo ""
        echo "Arguments:"
        echo "  database_name   Database name (default: mywebshop)"
        echo "  username        PostgreSQL username (default: jbstewart)"
        echo "  host           PostgreSQL host (default: localhost)"
        echo "  port           PostgreSQL port (default: 5432)"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        exit 0
    fi
done

echo "Dumping data from database $DB_NAME to folder data/"
echo "Using connection: $USERNAME@$HOST:$PORT"

# Check if tenants table exists to determine if this is multi-tenant
MULTI_TENANT_CHECK=$(psql -h $HOST -p $PORT -U $USERNAME -d $DB_NAME -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'webshop' AND table_name = 'tenants');" 2>/dev/null | tr -d ' ')

if [ "$MULTI_TENANT_CHECK" = "t" ]; then
    echo "Multi-tenant database detected - including tenants table in dump"
    
    pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --schema=webshop --schema=public \
        --exclude-table=webshop.products \
        --exclude-table=webshop.articles \
        --exclude-table=webshop.labels \
        --exclude-table=webshop.customer \
        --exclude-table=webshop.address \
        --exclude-table=webshop.order \
        --exclude-table=webshop.order_positions \
        --exclude-table=webshop.stock \
        --exclude-table=webshop.tenants > data/create.sql
    
    # Dump tenants table separately for multi-tenant setup
    pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.tenants > data/tenants.sql
else
    echo "Single-tenant database detected"
    
    pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --schema=webshop --schema=public \
        --exclude-table=webshop.products \
        --exclude-table=webshop.articles \
        --exclude-table=webshop.labels \
        --exclude-table=webshop.customer \
        --exclude-table=webshop.address \
        --exclude-table=webshop.order \
        --exclude-table=webshop.order_positions \
        --exclude-table=webshop.stock > data/create.sql
fi

# Dump all data tables
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.products > data/products.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.articles > data/articles.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.labels > data/labels.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.customer > data/customer.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.address > data/address.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.order > data/order.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.order_positions > data/order_positions.sql
pg_dump -h $HOST -p $PORT -U $USERNAME $DB_NAME --table=webshop.stock > data/stock.sql

echo "✓ Database dump completed successfully"
if [ "$MULTI_TENANT_CHECK" = "t" ]; then
    echo "Note: Multi-tenant data (tenants.sql) has been included in the dump"
fi
