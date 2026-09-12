const http = require('http');

const PORT = 8080;
const MAX_DB_CONNECTIONS = 100;
let activeConnections = 15; // Mức sử dụng an toàn cơ sở

let requests200 = 1000;
let requests500 = 0;
let latencySum = 45.0;
let latencyCount = 1000;

const server = http.createServer((req, res) => {
  if (req.url === '/metrics') {
    const body = [
      '# HELP http_requests_total Total number of HTTP requests.',
      '# TYPE http_requests_total counter',
      `http_requests_total{app="payment-vault",method="POST",status="200"} ${requests200}`,
      `http_requests_total{app="payment-vault",method="POST",status="500"} ${requests500}`,
      '',
      '# HELP db_connection_pool_active Active database connections in use.',
      '# TYPE db_connection_pool_active gauge',
      `db_connection_pool_active{app="payment-vault"} ${activeConnections}`,
      '',
      '# HELP process_resident_memory_bytes Resident memory size in bytes.',
      '# TYPE process_resident_memory_bytes gauge',
      `process_resident_memory_bytes{app="payment-vault"} ${process.memoryUsage().rss}`,
      ''
    ].join('\n');
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    return res.end(body);
  }

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'HEALTHY', version: 'v1.2.2-stable' }));
  }

  if (req.url === '/api/v1/charge' && req.method === 'POST') {
    // ✅ CODE CHUẨN: Mượn kết nối và luôn giải phóng trong chu kỳ
    requests200++;
    latencySum += 0.045; // Độ trễ siêu nhanh 45ms
    latencyCount++;

    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      status: 'SUCCESS',
      transaction_id: 'tx-stable-' + Math.random().toString(36).substring(2, 9),
      version: 'v1.2.2-stable'
    }));
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ service: 'Payment Vault v1.2.2-stable' }));
});

server.listen(PORT, () => {
  console.log(`[STABLE RESTORED] Payment Vault v1.2.2 running on port ${PORT}`);
});
