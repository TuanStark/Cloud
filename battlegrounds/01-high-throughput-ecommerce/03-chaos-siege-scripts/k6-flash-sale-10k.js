import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// CÁC CHỈ SỐ ĐO LƯỜNG ĐỘ GÃY ĐỔ (BREAKING METRICS)
const orderSuccessCount = new Counter('orders_success_202');
const orderOutOfStockCount = new Counter('orders_out_of_stock_409');
const orderFailedRate = new Rate('orders_failed_rate');
const orderResponseTime = new Trend('order_response_time_ms');

export const options = {
  scenarios: {
    flash_sale_siege: {
      executor: 'ramping-arrival-rate',
      startRate: 100,
      timeUnit: '1s',
      preAllocatedVUs: 500,
      maxVUs: 3000,
      stages: [
        { target: 1000, duration: '20s' },   // Giai đoạn 1: Warm-up lên 1,000 RPS
        { target: 5000, duration: '30s' },   // Giai đoạn 2: Tăng tốc 5,000 RPS
        { target: 10000, duration: '60s' },  // Giai đoạn 3: BÃO FLASH SALE ĐỈNH ĐIỂM 10,000 RPS
        { target: 10000, duration: '30s' },  // Giai đoạn 4: Duy trì tải cực hạn
        { target: 0, duration: '20s' },      // Giai đoạn 5: Hạ nhiệt (Cooldown)
      ],
    },
  },
  thresholds: {
    // SLO kỳ vọng của hệ thống
    'http_req_duration': ['p(95)<200', 'p(99)<500'],
    'orders_failed_rate': ['rate<0.05'], // Tỷ lệ lỗi 5xx không vượt quá 5%
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://order-api-service:80';
const TARGET_PRODUCT = 'prod_macbook_m3';

export default function () {
  const userId = `usr_${__VU}_${__ITER}_${Math.floor(Math.random() * 100000)}`;

  const payload = JSON.stringify({
    product_id: TARGET_PRODUCT,
    quantity: 1,
    user_id: userId,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Simulated-Client': 'k6-red-team-siege',
    },
    timeout: '10s',
  };

  const startTime = Date.now();
  const res = http.post(`${BASE_URL}/api/v1/orders`, payload, params);
  const latency = Date.now() - startTime;
  orderResponseTime.add(latency);

  if (res.status === 202) {
    orderSuccessCount.add(1);
    orderFailedRate.add(0);
    check(res, {
      'order accepted (202)': (r) => r.status === 202,
    });
  } else if (res.status === 409) {
    // Hết hàng hợp lệ (Kho = 0), không tính là lỗi hệ thống sập
    orderOutOfStockCount.add(1);
    orderFailedRate.add(0);
  } else {
    // Lỗi 500, 502, 503, 504 (Hệ thống bị gãy đổ dưới áp lực tải)
    orderFailedRate.add(1);
  }
}
