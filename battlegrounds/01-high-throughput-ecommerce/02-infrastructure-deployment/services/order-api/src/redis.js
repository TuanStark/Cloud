const Redis = require('ioredis');

const redisHost = process.env.REDIS_HOST || 'redis';
const redisPort = parseInt(process.env.REDIS_PORT || '6379', 10);
const redisPassword = process.env.REDIS_PASSWORD || undefined;

const redis = new Redis({
  host: redisHost,
  port: redisPort,
  password: redisPassword,
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  retryStrategy(times) {
    const delay = Math.min(times * 100, 2000);
    return delay;
  },
});

// LUA SCRIPT: ATOMIC INVENTORY DECREMENT (CHỐNG OVERSELLING 100%)
// Trả về:
// >= 0: Thành công (số lượng tồn kho còn lại)
// -1: Sản phẩm chưa được cache trong Redis
// -2: Hết hàng (Không đủ số lượng yêu cầu)
const DECR_STOCK_LUA = `
local stock_key = KEYS[1]
local qty = tonumber(ARGV[1])
local current = tonumber(redis.call('get', stock_key))

if not current then
    return -1
end

if current >= qty then
    local remaining = redis.call('decrby', stock_key, qty)
    return remaining
else
    return -2
end
`;

redis.defineCommand('decrementStock', {
  numberOfKeys: 1,
  lua: DECR_STOCK_LUA,
});

redis.on('connect', () => {
  console.log(`[Redis] Connected successfully to ${redisHost}:${redisPort}`);
});

redis.on('error', (err) => {
  console.error('[Redis] Connection Error:', err.message);
});

module.exports = redis;
