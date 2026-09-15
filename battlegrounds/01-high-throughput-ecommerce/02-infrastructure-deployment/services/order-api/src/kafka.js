const { Kafka, CompressionTypes } = require('kafkajs');

const brokers = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const topic = process.env.KAFKA_TOPIC || 'orders.events';

const kafka = new Kafka({
  clientId: 'ecommerce-order-api',
  brokers,
  retry: {
    initialRetryTime: 300,
    retries: 5,
  },
});

const producer = kafka.producer({
  allowAutoTopicCreation: true,
  transactionTimeout: 30000,
});

let isConnected = false;

async function connectProducer() {
  if (!isConnected) {
    try {
      await producer.connect();
      isConnected = true;
      console.log(`[Kafka Producer] Connected successfully to [${brokers.join(', ')}]`);
    } catch (err) {
      console.error('[Kafka Producer] Failed to connect:', err.message);
      setTimeout(connectProducer, 3000);
    }
  }
}

// Bắn event đặt hàng bất đồng bộ vào Kafka topic
async function publishOrderEvent(orderPayload) {
  if (!isConnected) {
    await connectProducer();
  }

  return producer.send({
    topic,
    compression: CompressionTypes.GZIP,
    messages: [
      {
        key: orderPayload.order_id,
        value: JSON.stringify(orderPayload),
        headers: {
          'source': 'order-api',
          'timestamp': Date.now().toString(),
        },
      },
    ],
  });
}

connectProducer();

module.exports = {
  kafka,
  producer,
  publishOrderEvent,
  isKafkaReady: () => isConnected,
};
