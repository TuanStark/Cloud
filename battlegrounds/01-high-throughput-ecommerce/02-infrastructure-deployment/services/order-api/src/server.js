const fastify = require('fastify')({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
  },
  disableRequestLogging: process.env.NODE_ENV === 'production',
});

const redis = require('./redis');
const { publishOrderEvent, isKafkaReady } = require('./kafka');
const db = require('./db');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = '0.0.0.0';

// ============================================================================
// KHỞI TẠO TỒN KHO REDIS BAN ĐẦU (FLASH SALE WARM-UP)
// ============================================================================
async function warmUpInventory() {
  try {
    const defaultProduct = 'prod_macbook_m3';
    const cachedStock = await redis.get(`stock:${defaultProduct}`);
    
    if (cachedStock === null) {
      // Query PostgreSQL Replica để lấy số lượng chuẩn
      const res = await db.query('SELECT stock_quantity, price FROM products WHERE product_id = $1', [defaultProduct]);
      let stock = 10000;
      let price = 2000.00;
      if (res.rows.length > 0) {
        stock = res.rows[0].stock_quantity;
        price = parseFloat(res.rows[0].price);
      }
      await redis.set(`stock:${defaultProduct}`, stock);
      await redis.set(`price:${defaultProduct}`, price);
      console.log(`[WarmUp] Seeded Redis cache for ${defaultProduct}: ${stock} units, $${price}`);
    } else {
      console.log(`[WarmUp] Redis already warmed up for ${defaultProduct}: ${cachedStock} units`);
    }
  } catch (err) {
    console.warn('[WarmUp] Could not warmup from DB yet, using default stock 10000:', err.message);
    await redis.set('stock:prod_macbook_m3', 10000);
    await redis.set('price:prod_macbook_m3', 2000.00);
  }
}

// ============================================================================
// 1. HEALTHCHECK ENDPOINT
// ============================================================================
fastify.get('/healthz', async (request, reply) => {
  let redisStatus = 'healthy';
  let kafkaStatus = isKafkaReady() ? 'healthy' : 'degraded';
  
  try {
    await redis.ping();
  } catch (err) {
    redisStatus = 'down';
  }

  const isHealthy = redisStatus === 'healthy';
  return reply.status(isHealthy ? 200 : 503).send({
    status: isHealthy ? 'UP' : 'DOWN',
    redis: redisStatus,
    kafka: kafkaStatus,
    timestamp: new Date().toISOString(),
  });
});

// ============================================================================
// 2. READ-THROUGH CACHE: LẤY THÔNG TIN SẢN PHẨM
// ============================================================================
fastify.get('/api/v1/products/:id', async (request, reply) => {
  const { id } = request.params;
  
  // 1. Đọc từ Redis Cache trước
  const cachedStock = await redis.get(`stock:${id}`);
  const cachedPrice = await redis.get(`price:${id}`);
  
  if (cachedStock !== null && cachedPrice !== null) {
    return reply.send({
      product_id: id,
      stock_quantity: parseInt(cachedStock, 10),
      price: parseFloat(cachedPrice),
      source: 'cache_redis',
    });
  }

  // 2. Cache miss -> Đọc từ PostgreSQL Replica
  try {
    const res = await db.query('SELECT * FROM products WHERE product_id = $1', [id]);
    if (res.rows.length === 0) {
      return reply.status(404).send({ error: 'Product not found' });
    }
    const product = res.rows[0];
    await redis.set(`stock:${id}`, product.stock_quantity);
    await redis.set(`price:${id}`, product.price);
    
    return reply.send({
      ...product,
      source: 'database_replica',
    });
  } catch (err) {
    request.log.error(err);
    return reply.status(500).send({ error: 'Failed to fetch product' });
  }
});

// ============================================================================
// 3. HIGH-THROUGHPUT FLASH SALE ORDER INGESTION (10,000 RPS TARGET)
// ============================================================================
fastify.post('/api/v1/orders', async (request, reply) => {
  const { product_id, quantity = 1, user_id } = request.body || {};

  if (!product_id || !user_id) {
    return reply.status(400).send({ error: 'Missing product_id or user_id' });
  }

  const reqQty = parseInt(quantity, 10);
  if (isNaN(reqQty) || reqQty <= 0) {
    return reply.status(400).send({ error: 'Quantity must be positive integer' });
  }

  // BƯỚC 1: ATOMIC INVENTORY DECREMENT QUA LUA SCRIPT TRÊN REDIS
  let remainingStock = await redis.decrementStock(`stock:${product_id}`, reqQty);

  // Nếu Cache chưa có, thử warm-up từ DB rồi chạy lại
  if (remainingStock === -1) {
    await warmUpInventory();
    remainingStock = await redis.decrementStock(`stock:${product_id}`, reqQty);
  }

  // BƯỚC 2: KIỂM TRA HẾT HÀNG (CHỐNG BÁN ÂM KHO)
  if (remainingStock === -2) {
    return reply.status(409).send({
      error: 'OUT_OF_STOCK',
      message: 'Sản phẩm đã hết hàng hoặc không đủ số lượng trong đợt Flash Sale!',
      product_id,
    });
  }

  // BƯỚC 3: PHÁT SINH ORDER ID & ĐẨY ASYNC EVENT VÀO KAFKA
  const orderId = `ord_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  const cachedPrice = await redis.get(`price:${product_id}`) || 2000.00;
  const totalAmount = parseFloat(cachedPrice) * reqQty;

  const orderPayload = {
    order_id: orderId,
    user_id,
    product_id,
    quantity: reqQty,
    amount: totalAmount,
    status: 'QUEUED',
    created_at: new Date().toISOString(),
  };

  // Đẩy vào Kafka buffer
  try {
    await publishOrderEvent(orderPayload);
  } catch (err) {
    // Nếu Kafka lỗi, hoàn lại kho trên Redis (Compensating Transaction)
    await redis.incrby(`stock:${product_id}`, reqQty);
    request.log.error('Failed to publish order event to Kafka:', err);
    return reply.status(503).send({ error: 'Message broker unavailable, order rolled back' });
  }

  // BƯỚC 4: TRẢ VỀ 202 ACCEPTED SIÊU TỐC (< 15MS)
  return reply.status(202).send({
    success: true,
    order_id: orderId,
    status: 'QUEUED',
    remaining_stock: remainingStock,
    message: 'Đơn hàng đã được tiếp nhận và đưa vào hàng đợi xử lý!',
  });
});

// KHỞI ĐỘNG SERVER
const start = async () => {
  try {
    await fastify.listen({ port: PORT, host: HOST });
    console.log(`[Order API Engine] Running on http://${HOST}:${PORT}`);
    await warmUpInventory();
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
