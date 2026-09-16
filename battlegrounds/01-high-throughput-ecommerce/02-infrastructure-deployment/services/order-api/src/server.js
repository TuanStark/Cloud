const fastify = require('fastify')({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
  },
  disableRequestLogging: process.env.NODE_ENV === 'production',
});

const redis = require('./redis');
const { publishOrderEvent, isKafkaReady } = require('./kafka');
const db = require('./db');
const singleflight = require('./singleflight');
const { CircuitBreaker } = require('./circuitBreaker');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = '0.0.0.0';

// ============================================================================
// KHỞI TẠO LÁ CHẮN CIRCUIT BREAKER CHO PHỤ THUỘC BÊN NGOÀI
// ============================================================================
const redisBreaker = new CircuitBreaker('redis-cache', {
  failureThreshold: 5,
  cooldownPeriodMs: 8000,
  halfOpenSuccessThreshold: 2,
});

const kafkaBreaker = new CircuitBreaker('kafka-broker', {
  failureThreshold: 5,
  cooldownPeriodMs: 8000,
  halfOpenSuccessThreshold: 2,
});

// ============================================================================
// KHỞI TẠO TỒN KHO REDIS BAN ĐẦU (FLASH SALE WARM-UP)
// ============================================================================
async function warmUpInventory() {
  try {
    const defaultProduct = 'prod_macbook_m3';
    const cachedStock = await redis.get(`stock:${defaultProduct}`);
    
    if (cachedStock === null) {
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
    await redis.set('stock:prod_macbook_m3', 10000).catch(() => {});
    await redis.set('price:prod_macbook_m3', 2000.00).catch(() => {});
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
    circuitBreakers: {
      redis: redisBreaker.state,
      kafka: kafkaBreaker.state,
    },
    timestamp: new Date().toISOString(),
  });
});

// ============================================================================
// 2. SRE RESILIENCE METRICS ENDPOINT (SINGLEFLIGHT & CIRCUIT BREAKER MONITORING)
// ============================================================================
fastify.get('/metrics/resilience', async (request, reply) => {
  return reply.send({
    singleflight: singleflight.getMetrics(),
    circuitBreakers: {
      redis: redisBreaker.getMetrics(),
      kafka: kafkaBreaker.getMetrics(),
    },
    timestamp: new Date().toISOString(),
  });
});

// ============================================================================
// 3. READ-THROUGH CACHE VỚI SINGLEFLIGHT PATTERN CHỐNG CACHE STAMPEDE
// ============================================================================
fastify.get('/api/v1/products/:id', async (request, reply) => {
  const { id } = request.params;
  
  // 1. Đọc từ Redis Cache (được bảo vệ qua Circuit Breaker)
  let cachedStock = null;
  let cachedPrice = null;
  try {
    [cachedStock, cachedPrice] = await redisBreaker.execute(async () => {
      return await Promise.all([
        redis.get(`stock:${id}`),
        redis.get(`price:${id}`),
      ]);
    });
  } catch (err) {
    request.log.warn({ err: err.message }, '[Product] Redis cache degraded, fallback to singleflight DB');
  }
  
  if (cachedStock !== null && cachedPrice !== null) {
    return reply.send({
      product_id: id,
      stock_quantity: parseInt(cachedStock, 10),
      price: parseFloat(cachedPrice),
      source: 'cache_redis',
    });
  }

  // 2. Cache miss -> Sử dụng Singleflight gom toàn bộ requests đồng thời thành DUY NHẤT 1 query vào DB
  try {
    const product = await singleflight.do(`fetch_product_${id}`, async () => {
      const res = await db.query('SELECT * FROM products WHERE product_id = $1', [id]);
      if (res.rows.length === 0) {
        return null;
      }
      const p = res.rows[0];
      // Nếu Redis phục hồi, tự động nạp lại cache trong background
      redisBreaker.execute(async () => {
        await redis.set(`stock:${id}`, p.stock_quantity);
        await redis.set(`price:${id}`, p.price);
      }).catch(() => {});
      return p;
    });

    if (!product) {
      return reply.status(404).send({ error: 'Product not found' });
    }

    return reply.send({
      ...product,
      source: 'database_replica_singleflight',
      resilience: 'singleflight_coalesced',
    });
  } catch (err) {
    request.log.error(err);
    return reply.status(500).send({ error: 'Failed to fetch product from database' });
  }
});

// ============================================================================
// 4. HIGH-THROUGHPUT FLASH SALE ORDER INGESTION (BẢO VỆ QUA CIRCUIT BREAKER)
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

  // BƯỚC 1: ATOMIC INVENTORY DECREMENT QUA LUA SCRIPT TRÊN REDIS (QUA REDIS BREAKER)
  let remainingStock;
  try {
    remainingStock = await redisBreaker.execute(async () => {
      let stock = await redis.decrementStock(`stock:${product_id}`, reqQty);
      if (stock === -1) {
        await warmUpInventory();
        stock = await redis.decrementStock(`stock:${product_id}`, reqQty);
      }
      return stock;
    });
  } catch (err) {
    // Fast-Fail ngay lập tức nếu Redis Breaker đang OPEN (< 1ms)
    request.log.warn({ err: err.message }, '[Order API] Redis circuit breaker open or failed');
    return reply.status(503).send({
      error: 'CIRCUIT_BREAKER_TRIGGERED',
      circuit: 'redis-cache',
      state: redisBreaker.state,
      message: 'Dịch vụ tồn kho đang gặp sự cố. Hệ thống đã kích hoạt bảo vệ ngắt mạch (Fast-Fail)!',
    });
  }

  // BƯỚC 2: KIỂM TRA HẾT HÀNG (CHỐNG BÁN ÂM KHO)
  if (remainingStock === -2) {
    return reply.status(409).send({
      error: 'OUT_OF_STOCK',
      message: 'Sản phẩm đã hết hàng hoặc không đủ số lượng trong đợt Flash Sale!',
      product_id,
    });
  }

  // BƯỚC 3: PHÁT SINH ORDER ID & ĐẨY ASYNC EVENT VÀO KAFKA (QUA KAFKA BREAKER)
  const orderId = `ord_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  const cachedPrice = await redis.get(`price:${product_id}`).catch(() => '2000.00') || 2000.00;
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

  // Đẩy vào Kafka buffer qua Kafka Circuit Breaker
  try {
    await kafkaBreaker.execute(async () => {
      await publishOrderEvent(orderPayload);
    });
  } catch (err) {
    // Nếu Kafka lỗi/mở mạch, hoàn lại kho trên Redis (Compensating Transaction)
    redis.incrby(`stock:${product_id}`, reqQty).catch(() => {});
    request.log.error({ err: err.message }, 'Failed to publish order event to Kafka:');
    return reply.status(503).send({
      error: 'MESSAGE_BROKER_UNAVAILABLE',
      circuit: 'kafka-broker',
      state: kafkaBreaker.state,
      message: 'Hệ thống hàng đợi tạm thời gián đoạn, đơn hàng đã được hoàn kho an toàn!',
    });
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
