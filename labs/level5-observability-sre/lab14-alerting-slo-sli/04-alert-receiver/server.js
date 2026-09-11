const http = require('http');

const PORT = 5001;

function parseAlerts(req, res, severityLabel) {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
        try {
            const data = JSON.parse(body);
            const status = data.status ? data.status.toUpperCase() : 'UNKNOWN';
            const alerts = data.alerts || [];

            console.log('\n' + '='.repeat(70));
            if (status === 'RESOLVED') {
                console.log(`🟢 [ALERT RESOLVED] Severity: ${severityLabel}`);
            } else {
                console.log(`🚨 [${severityLabel} ALERT RECEIVED] Status: ${status}`);
            }
            console.log(`📦 Nhận được ${alerts.length} cảnh báo trong đợt gom nhóm (Grouped):`);

            alerts.forEach((alert, index) => {
                const name = alert.labels.alertname || 'Unknown';
                const summary = alert.annotations.summary || 'No summary';
                const desc = alert.annotations.description || 'No description';
                const runbook = alert.annotations.runbook_url || 'No runbook';
                console.log(`   👉 [${index + 1}] Alert: ${name} (${alert.status})`);
                console.log(`      Tóm tắt: ${summary}`);
                console.log(`      Chi tiết: ${desc}`);
                console.log(`      Runbook: ${runbook}`);
            });
            console.log('='.repeat(70) + '\n');

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'received', count: alerts.length }));
        } catch (err) {
            console.error('❌ Lỗi phân tích JSON webhook:', err.message);
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        }
    });
}

const server = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/webhook/critical') {
        parseAlerts(req, res, 'CRITICAL P1');
    } else if (req.method === 'POST' && req.url === '/webhook/warning') {
        parseAlerts(req, res, 'WARNING P2');
    } else if (req.method === 'POST' && req.url === '/webhook/general') {
        parseAlerts(req, res, 'GENERAL');
    } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ service: 'SRE Alert Receiver Operational' }));
    }
});

server.listen(PORT, () => {
    console.log(`🚀 SRE Mock Alert Receiver listening on port ${PORT}...`);
});
