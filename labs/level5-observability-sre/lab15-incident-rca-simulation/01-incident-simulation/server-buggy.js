const http = require('http');

const PORT = 8080;

// Giả lập Database Connection Pool tối đa 100 kết nối
const MAX_DB_CONNECTIONS = 100;
let activeConnections = 15; // Mức sử dụng cơ sở

// Giả lập biến toàn cục gây rò rỉ bộ nhớ (Memory Leak)
const leakedMemoryCache = [];

// Bộ đếm Metrics chuẩn OpenMetrics
let requests200 = 500;
let requests500 = 2;
let latencySum = 25.0;
let latencyCount = 502;

const server = http.createServer((req, res) => {
    // 1. Endpoint trả về Metrics cho Prometheus
    if (req.url === '/metrics') {
        const memoryUsageMB = (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2);
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
            '',
            '# HELP http_request_duration_seconds_count Total requests for duration calculation.',
            '# TYPE http_request_duration_seconds_count counter',
            `http_request_duration_seconds_count{app="payment-vault"} ${latencyCount}`,
            `http_request_duration_seconds_sum{app="payment-vault"} ${latencySum.toFixed(3)}`,
            ''
        ].join('\n');

        res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
        return res.end(body);
    }

    // 2. Endpoint Health Check
    if (req.url === '/health') {
        if (activeConnections >= MAX_DB_CONNECTIONS) {
            res.writeHead(503, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ status: 'UNHEALTHY', error: 'DB_POOL_EXHAUSTED' }));
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'HEALTHY' }));
    }

    // 3. Endpoint Nghiệp vụ: Quẹt thẻ thanh toán (Chứa 2 lỗi nghiêm trọng)
    if (req.url === '/api/v1/charge' && req.method === 'POST') {
        // 💣 BẪY 1: Rò rỉ kết nối Database (Chiếm kết nối mà không trả lại)
        activeConnections += 2; // Mỗi request chiếm 2 connection mà quên gọi release()

        // 💣 BẪY 2: Rò rỉ bộ nhớ (Bơm dữ liệu rác vào RAM liên tục)
        for (let i = 0; i < 5000; i++) {
            leakedMemoryCache.push({ tx_id: Math.random(), leak_payload: "BLOB_DATA_UNFREED_LEAK" });
        }

        // Nếu Connection Pool bị tràn (> 100) ➔ Toàn bộ request bị sập mã 500!
        if (activeConnections >= MAX_DB_CONNECTIONS) {
            requests500++;
            latencySum += 3.5; // Nghẽn connection khiến thời gian chờ lên tới 3.5s!
            latencyCount++;

            console.error(JSON.stringify({
                timestamp: new Date().toISOString(),
                level: 'FATAL',
                status: 500,
                error: 'DB_CONNECTION_POOL_EXHAUSTED',
                active_connections: activeConnections,
                max_connections: MAX_DB_CONNECTIONS,
                heap_used_mb: (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2),
                message: 'FATAL: Connection pool exhausted: 100/100 active connections timeout after 3000ms. Transaction failed!'
            }));

            res.writeHead(500, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({
                error: 'InternalServerError',
                message: 'Database connection pool exhausted. Please retry later.'
            }));
        }

        // Giao dịch thành công (khi connection còn trống)
        requests200++;
        latencySum += 0.08;
        latencyCount++;

        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
            status: 'SUCCESS',
            transaction_id: 'tx-' + Math.random().toString(36).substring(2, 9),
            active_connections: activeConnections
        }));
    }

    // Mặc định
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ service: 'Payment Vault v1.3.0-buggy' }));
});

server.listen(PORT, () => {
    console.log(`[OUTAGE CRIME SCENE] Payment Vault v1.3.0 running on port ${PORT}`);
});
