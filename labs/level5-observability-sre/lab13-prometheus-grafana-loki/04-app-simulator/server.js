const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const LOG_DIR = '/var/log/app';
const LOG_FILE = path.join(LOG_DIR, 'payment-vault.log');

// Đảm bảo thư mục log tồn tại
if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Bộ đếm Metrics trong bộ nhớ
let totalRequests200 = 120;
let totalRequests500 = 4;
let latencyBuckets = {
    '0.05': 50,
    '0.1': 95,
    '0.25': 115,
    '0.5': 122,
    '1.0': 124,
    '+Inf': 124
};

function writeLog(level, status, method, message) {
    const logEntry = {
        timestamp: new Date().toISOString(),
        service: 'payment-vault',
        app: 'payment-vault',
        level: level,
        status: status,
        method: method,
        trace_id: 'tx-' + Math.random().toString(36).substring(2, 10),
        message: message
    };
    const logLine = JSON.stringify(logEntry) + '\n';
    process.stdout.write(logLine);
    fs.appendFileSync(LOG_FILE, logLine);
}

// Giả lập lưu lượng giao dịch ngẫu nhiên chạy ngầm mỗi 1.5 giây
setInterval(() => {
    const isError = Math.random() < 0.08; // 8% tỷ lệ lỗi giả lập
    const latency = isError ? 0.45 + Math.random() * 0.5 : 0.02 + Math.random() * 0.15;

    if (isError) {
        totalRequests500++;
        writeLog('ERROR', 500, 'POST', 'Database connection timeout during payment authorization');
    } else {
        totalRequests200++;
        writeLog('INFO', 200, 'POST', 'Payment processed successfully for customer vault');
    }

    // Cập nhật histogram bucket
    for (const le of Object.keys(latencyBuckets)) {
        if (le === '+Inf' || latency <= parseFloat(le)) {
            latencyBuckets[le]++;
        }
    }
}, 1500);

const server = http.createServer((req, res) => {
    if (req.url === '/metrics') {
        // Xuất định dạng OpenMetrics chuẩn cho Prometheus cào
        const total = totalRequests200 + totalRequests500;
        const body = [
            '# HELP http_requests_total Total number of HTTP requests processed.',
            '# TYPE http_requests_total counter',
            `http_requests_total{app="payment-vault",method="POST",status="200"} ${totalRequests200}`,
            `http_requests_total{app="payment-vault",method="POST",status="500"} ${totalRequests500}`,
            '',
            '# HELP http_request_duration_seconds HTTP request latency distribution.',
            '# TYPE http_request_duration_seconds histogram',
            ...Object.keys(latencyBuckets).map(le => `http_request_duration_seconds_bucket{app="payment-vault",le="${le}"} ${latencyBuckets[le]}`),
            `http_request_duration_seconds_count{app="payment-vault"} ${total}`,
            `http_request_duration_seconds_sum{app="payment-vault"} ${(totalRequests200 * 0.08 + totalRequests500 * 0.6).toFixed(3)}`,
            ''
        ].join('\n');

        res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
        res.end(body);
    } else if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'HEALTHY' }));
    } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ message: 'Payment Vault API Operational' }));
    }
});

server.listen(PORT, () => {
    writeLog('INFO', 200, 'START', `Payment Vault service listening on port ${PORT}`);
});
