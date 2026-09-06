const express = require('express');
const cors = require('cors');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// In-memory mock database
const orders = [
  { id: "ORD-1001", customer: "Nguyễn Văn A", item: "AWS Cloud Architecture Book", amount: 45.0, status: "COMPLETED" },
  { id: "ORD-1002", customer: "Trần Thị B", item: "Kubernetes Production Guide", amount: 65.0, status: "PROCESSING" },
  { id: "ORD-1003", customer: "Lê Công Tuấn", item: "DevSecOps Masterclass", amount: 99.0, status: "PENDING" }
];

// 1. Healthcheck endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime_seconds: Math.floor(process.uptime())
  });
});

// 2. Security context endpoint (Phục vụ quan sát bảo mật Container Runtime)
app.get('/api/security', (req, res) => {
  const uid = typeof process.getuid === 'function' ? process.getuid() : 0;
  const gid = typeof process.getgid === 'function' ? process.getgid() : 0;
  let username = 'unknown';
  try {
    username = os.userInfo().username;
  } catch (e) {
    username = uid === 0 ? 'root' : 'nonroot';
  }

  res.json({
    runtime_security: {
      uid: uid,
      gid: gid,
      username: username,
      is_root: uid === 0,
      severity: uid === 0 ? "CRITICAL" : "SECURE",
      message: uid === 0 
        ? "CẢNH BÁO NGUY HIỂM: Container đang chạy dưới quyền ROOT (UID 0). Kẻ tấn công có thể thực hiện Container Breakout!"
        : "AN TOÀN: Container đang chạy dưới quyền NON-ROOT user có đặc quyền tối thiểu."
    },
    system_metrics: {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      node_version: process.version,
      memory_rss_mb: (process.memoryUsage().rss / (1024 * 1024)).toFixed(2)
    }
  });
});

// 3. Business logic: Orders API
app.get('/api/orders', (req, res) => {
  res.json({
    total: orders.length,
    data: orders
  });
});

app.post('/api/orders', (req, res) => {
  const { customer, item, amount } = req.body;
  if (!customer || !item) {
    return res.status(400).json({ error: "Vui lòng nhập tên khách hàng và sản phẩm!" });
  }

  const newOrder = {
    id: `ORD-${1000 + orders.length + 1}`,
    customer,
    item,
    amount: Number(amount) || 0,
    status: "PROCESSING",
    created_at: new Date().toISOString()
  };

  orders.unshift(newOrder);
  res.status(201).json(newOrder);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[BACKEND STARTED] Server running on http://0.0.0.0:${PORT}`);
  console.log(`[SECURITY] Process UID: ${typeof process.getuid === 'function' ? process.getuid() : 'N/A'}`);
});
