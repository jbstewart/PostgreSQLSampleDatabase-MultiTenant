# PostgreSQL Sample Database

This is a sample webshop, including 

* 1000 customers
* 2000 orders
* 1000 products with 17730 different articles

## Setup

### Quick Setup

You can set up the database using the unified `restore.sh` script:

```bash
# Single-tenant setup (default)
$ ./restore.sh [database_name] [username] [host] [port]

# Multi-tenant setup
$ ./restore.sh [database_name] [username] [host] [port] --multi-tenant
```

### Examples

```bash
# Single-tenant with defaults (mywebshop, jbstewart, localhost:5432)
$ ./restore.sh

# Multi-tenant with defaults
$ ./restore.sh --multi-tenant

# Custom configuration
$ ./restore.sh myshop postgres localhost 5432 --multi-tenant

# Show help
$ ./restore.sh --help
```

### Multi-tenant Features

When using `--multi-tenant`, the setup includes:
- Row-level security (RLS) for tenant data isolation
- Helper functions for tenant context management
- Three sample tenants: Acme Fashion Store, Style Central, Urban Trends

Set tenant context in your application:
```sql
SELECT webshop.set_current_tenant(1); -- Acme Fashion Store
SELECT webshop.set_current_tenant(2); -- Style Central  
SELECT webshop.set_current_tenant(3); -- Urban Trends
```

### Manual Setup

Alternatively, you can create the database manually with the scripts in `src` or restore individual dumps from `data`

## Schema

Created with schemaspy:

![](schema/diagrams/summary/relationships.real.large.png)