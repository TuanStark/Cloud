const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PG_REPLICA_HOST || 'postgres-replica',
  port: parseInt(process.env.PG_REPLICA_PORT || '5432', 10),
  database: process.env.POSTGRES_DB || 'ecommerce',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'PrimaryPassword2026!',
  max: 20,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 3000,
});

pool.on('error', (err) => {
  console.error('[PostgreSQL Replica Pool Error]', err.message);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
