const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PG_PRIMARY_HOST || 'postgres-primary',
  port: parseInt(process.env.PG_PRIMARY_PORT || '5432', 10),
  database: process.env.POSTGRES_DB || 'ecommerce',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'PrimaryPassword2026!',
  max: 30, // Pool size dành riêng cho Worker ghi tải nặng
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[PostgreSQL Primary Pool Error]', err.message);
});

// THỰC HIỆN BATCH INSERT ĐƠN HÀNG (GIẢM THIỂU SỐ LẦN ROUND-TRIP ĐẾN DB)
async function batchInsertOrders(orders) {
  if (!orders || orders.length === 0) return;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Gom dữ liệu thành multi-row INSERT
    const values = [];
    const placeholders = [];
    let paramIndex = 1;

    for (const ord of orders) {
      placeholders.push(
        `($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, $${paramIndex + 5}, $${paramIndex + 6})`
      );
      values.push(
        ord.order_id,
        ord.user_id,
        ord.product_id,
        ord.quantity,
        ord.amount,
        'CONFIRMED', // Đã qua bước kiểm tra tồn kho tại Redis, ghi nhận thành công
        ord.created_at || new Date()
      );
      paramIndex += 7;
    }

    const queryText = `
      INSERT INTO orders (order_id, user_id, product_id, quantity, amount, status, created_at)
      VALUES ${placeholders.join(', ')}
      ON CONFLICT (order_id) DO NOTHING;
    `;

    await client.query(queryText, values);

    // Cập nhật giảm tồn kho trong DB cho từng sản phẩm trong đợt batch
    const productQuantities = {};
    for (const ord of orders) {
      productQuantities[ord.product_id] = (productQuantities[ord.product_id] || 0) + ord.quantity;
    }

    for (const [prodId, totalQty] of Object.entries(productQuantities)) {
      await client.query(
        'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE product_id = $2',
        [totalQty, prodId]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  batchInsertOrders,
};
