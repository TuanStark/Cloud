const { Kafka } = require('kafkajs');
const { batchInsertOrders } = require('./db');

const brokers = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const topic = process.env.KAFKA_TOPIC || 'orders.events';
const groupId = process.env.KAFKA_GROUP_ID || 'order-processing-group';

const kafka = new Kafka({
  clientId: 'ecommerce-order-worker',
  brokers,
  retry: {
    initialRetryTime: 300,
    retries: 8,
  },
});

const consumer = kafka.consumer({
  groupId,
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

let isRunning = true;
let totalProcessedOrders = 0;
let poisonPillCount = 0;

async function runWorker() {
  try {
    await consumer.connect();
    console.log(`[Worker] Connected to Kafka brokers [${brokers.join(', ')}]`);

    await consumer.subscribe({ topic, fromBeginning: false });
    console.log(`[Worker] Subscribed to topic "${topic}" with GroupId "${groupId}"`);

    // DÙNG EACHBATCH ĐỂ ĐẠT THROUGHPUT HÀNG NGHÌN ĐƠN/GIÂY
    await consumer.run({
      eachBatchAutoResolve: true,
      eachBatch: async ({ batch, resolveOffset, heartbeat, isRunning, isStale }) => {
        const validOrders = [];

        for (const message of batch.messages) {
          if (!isRunning() || isStale()) break;

          try {
            const raw = message.value.toString();
            const orderData = JSON.parse(raw);

            // KIỂM TRA SCHEMA (CHỐNG POISON PILL)
            if (!orderData.order_id || !orderData.product_id || !orderData.quantity) {
              throw new Error('Malformed Order Schema');
            }

            validOrders.push(orderData);
          } catch (parseErr) {
            poisonPillCount++;
            console.error(`[Worker] ⚠️ POISON PILL DETECTED! Skipped corrupt message at offset ${message.offset}:`, parseErr.message);
            // Tiếp tục xử lý các message khác, không để poison pill làm sập worker (CrashLoopBackoff)
          }

          resolveOffset(message.offset);
          await heartbeat();
        }

        // BATCH INSERT VÀO POSTGRESQL PRIMARY
        if (validOrders.length > 0) {
          const startTime = Date.now();
          await batchInsertOrders(validOrders);
          const duration = Date.now() - startTime;

          totalProcessedOrders += validOrders.length;
          console.log(
            `[Worker] ✅ Processed batch of ${validOrders.length} orders in ${duration}ms (Total Confirmed: ${totalProcessedOrders}, Poison Pills: ${poisonPillCount})`
          );
        }
      },
    });
  } catch (err) {
    console.error('[Worker Fatal Error]', err);
    if (isRunning) {
      setTimeout(runWorker, 5000);
    }
  }
}

// GRACEFUL SHUTDOWN
const shutdown = async () => {
  console.log('[Worker] Shutting down gracefully...');
  isRunning = false;
  try {
    await consumer.disconnect();
    console.log('[Worker] Kafka consumer disconnected.');
    process.exit(0);
  } catch (err) {
    console.error('[Worker] Error during shutdown:', err);
    process.exit(1);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

runWorker();
