const http = require('http');

const PORT = 8080;
let total200 = 100;
let total500 = 0;
let latencyBuckets = { '0.1': 80, '0.25': 95, '0.5': 98, '1.0': 100, '+Inf': 100 };

// Trạng thái giả lập sự cố (Chaos State)
let chaosMode = 'normal'; // 'normal' | 'high_error' | 'high_latency'

setInterval(() => {
    let isError = false;
    let latency = 0.05;

    if (chaosMode === 'high_error') {
        // Khi kích hoạt Chaos: 60% giao dịch bị lỗi 500!
        isError = Math.random() < 0.60;
    } else if (chaosMode === 'high_latency') {
        // Khi kích hoạt Chaos độ trễ: thời gian phản hồi lên tới 1.2s!
        latency = 0.8 + Math.random() * 0.4;
    } else {
        // Bình thường: Chỉ 1% lỗi ngẫu nhiên
        isError = Math.random() < 0.01;
        latency = 0.03 + Math.random() * 0.05;
    }

    if (isError) {
        total500++;
    } else {
        total200++;
    }

    for (const le of Object.keys(latencyBuckets)) {
        if (le === '+Inf' || latency <= parseFloat(le)) {
            latencyBuckets[le]++;
        }
    }
}, 1000);

const server = http.createServer((req, res) => {
    if (req.url === '/metrics') {
        const total = total200 + total500;
        const body = [
            '# HELP http_requests_total Total HTTP requests.',
            '# TYPE http_requests_total counter',
            `http_requests_total{app="payment-vault",method="POST",status="200"} ${total200}`,
            `http_requests_total{app="payment-vault",method="POST",status="500"} ${total500}`,
            '',
            '# HELP http_request_duration_seconds HTTP request latency.',
            '# TYPE http_request_duration_seconds histogram',
            ...Object.keys(latencyBuckets).map(le => `http_request_duration_seconds_bucket{app="payment-vault",le="${le}"} ${latencyBuckets[le]}`),
            `http_request_duration_seconds_count{app="payment-vault"} ${total}`,
            `http_request_duration_seconds_sum{app="payment-vault"} ${(total200 * 0.05 + total500 * 0.5).toFixed(3)}`,
            ''
        ].join('\n');
        res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
        res.end(body);
    } else if (req.url === '/chaos/error') {
        chaosMode = 'high_error';
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'CHAOS_ACTIVATED', mode: 'high_error', error_rate: '60%' }));
    } else if (req.url === '/chaos/latency') {
        chaosMode = 'high_latency';
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'CHAOS_ACTIVATED', mode: 'high_latency', latency: '>800ms' }));
    } else if (req.url === '/chaos/normal') {
        chaosMode = 'normal';
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'CHAOS_DEACTIVATED', mode: 'normal' }));
    } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ service: 'Payment Vault API', mode: chaosMode }));
    }
});

server.listen(PORT, () => {
    console.log(`Payment Vault service running on port ${PORT}`);
});
