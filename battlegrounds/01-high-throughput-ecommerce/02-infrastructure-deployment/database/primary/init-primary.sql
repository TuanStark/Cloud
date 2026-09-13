-- ============================================================================
-- POSTGRESQL PRIMARY INITIALIZATION SCRIPT
-- Battleground 01: High-Throughput E-Commerce & Fintech Core
-- ============================================================================

-- 1. Create Replication User for Standby Replica
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'ReplicaPassword2026!';
        RAISE NOTICE 'Role "replicator" created successfully.';
    END IF;
END $$;

-- 2. Configure pg_hba.conf to allow streaming replication from replica host
DO $$
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS _hba_lines (line text);
    COPY _hba_lines FROM '/var/lib/postgresql/data/pg_hba.conf';
    IF NOT EXISTS (SELECT 1 FROM _hba_lines WHERE line LIKE '%host replication replicator%') THEN
        INSERT INTO _hba_lines VALUES ('host replication replicator 0.0.0.0/0 md5');
        COPY _hba_lines TO '/var/lib/postgresql/data/pg_hba.conf';
        PERFORM pg_reload_conf();
        RAISE NOTICE 'Added replication rule to pg_hba.conf and reloaded config.';
    END IF;
    DROP TABLE _hba_lines;
END $$;

-- 3. Create Physical Replication Slot for Replica
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replica_1_slot') THEN
        PERFORM pg_create_physical_replication_slot('replica_1_slot');
        RAISE NOTICE 'Physical replication slot "replica_1_slot" created.';
    END IF;
END $$;

-- 4. E-Commerce Core Schema & Seed Data (Flash Sale Target)
CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(12, 2) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    product_id VARCHAR(64) NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'QUEUED', -- QUEUED, PROCESSING, CONFIRMED, CANCELLED
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);

-- Seed Target Product for Flash Sale 10,000 RPS Stress Test
INSERT INTO products (product_id, name, description, price, stock_quantity)
VALUES (
    'prod_macbook_m3',
    'Apple MacBook Pro 16" M3 Max (36GB RAM / 1TB SSD)',
    'Flash Sale Flagship Item for High-Throughput Battleground Drill',
    2000.00,
    10000
)
ON CONFLICT (product_id) DO UPDATE 
SET stock_quantity = EXCLUDED.stock_quantity;
