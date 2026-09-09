const express = require('express');
const cors = require('cors');
const os = require('os');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const app = express();
const PORT = process.env.PORT || 5000;
const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'company-invoices-dev';
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

// 1. Cờ kiểm soát trạng thái phục vụ (Zero-Downtime / Readiness Probe)
let isShuttingDown = false;

// 2. Khởi tạo AWS S3 Client
// Trong môi trường EKS có IRSA, AWS SDK tự động nạp OIDC Token từ Projected SA Token
const s3Config = {
  region: AWS_REGION,
};
if (process.env.S3_ENDPOINT) {
  s3Config.endpoint = process.env.S3_ENDPOINT;
  s3Config.forcePathStyle = true;
}
const s3 = new S3Client(s3Config);

app.use(cors());
app.use(express.json());

// In-memory mock database
const orders = [
  { id: "ORD-1001", customer: "Nguyễn Văn A", item: "AWS Cloud Architecture Book", amount: 45.0, status: "COMPLETED", invoice_s3: "invoices/ORD-1001.json" },
  { id: "ORD-1002", customer: "Trần Thị B", item: "Kubernetes Production Guide", amount: 65.0, status: "PROCESSING", invoice_s3: "invoices/ORD-1002.json" },
  { id: "ORD-1003", customer: "Lê Công Tuấn", item: "DevSecOps Masterclass", amount: 99.0, status: "PENDING", invoice_s3: "invoices/ORD-1003.json" }
];

// ==============================================================================
// KUBERNETES PROBES (Chuẩn Production Enterprise)
// ==============================================================================

// Liveness Probe: Báo cho K8s biết tiến trình Node.js còn sống không
app.get('/healthz', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime_seconds: Math.floor(process.uptime())
  });
});

// Backward-compatible alias
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'healthy', uptime_seconds: Math.floor(process.uptime()) });
});

// Readiness Probe: Báo cho K8s biết Pod có sẵn sàng nhận traffic không
// Khi nhận tín hiệu SIGTERM để tắt máy, isShuttingDown = true -> lập tức trả về 503
// để Kubernetes Service và Ingress ngắt traffic tới Pod này, không làm rớt request của khách!
app.get('/ready', (req, res) => {
  if (isShuttingDown) {
    return res.status(503).json({
      status: 'shutting_down',
      message: 'Pod đang trong quá trình graceful shutdown, từ chối traffic mới.'
    });
  }
  res.status(200).json({
    status: 'ready',
    database: 'connected',
    s3_configured: Boolean(BUCKET_NAME)
  });
});

// ==============================================================================
// SECURITY CONTEXT MONITORING (Kiểm toán bảo mật Runtime từ Lab 07)
// ==============================================================================
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
    cloud_identity: {
      irsa_role_arn: process.env.AWS_ROLE_ARN || 'Không phát hiện (Chưa gán ServiceAccount IRSA)',
      token_file: process.env.AWS_WEB_IDENTITY_TOKEN_FILE || 'N/A',
      s3_bucket: BUCKET_NAME
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

// ==============================================================================
// BUSINESS LOGIC: ORDERS & S3 IRSA INTEGRATION
// ==============================================================================
app.get('/api/orders', (req, res) => {
  res.json({
    total: orders.length,
    bucket: BUCKET_NAME,
    data: orders
  });
});

app.post('/api/orders', async (req, res) => {
  const { customer, item, amount } = req.body;
  if (!customer || !item) {
    return res.status(400).json({ error: "Vui lòng nhập tên khách hàng và sản phẩm!" });
  }

  const orderId = `ORD-${1000 + orders.length + 1}`;
  const s3Key = `invoices/${orderId}.json`;

  const newOrder = {
    id: orderId,
    customer,
    item,
    amount: Number(amount) || 0,
    status: "PROCESSING",
    created_at: new Date().toISOString(),
    invoice_s3: s3Key,
    s3_upload_status: "PENDING"
  };

  // Upload hóa đơn JSON lên AWS S3 bằng quyền của IRSA
  try {
    const putCommand = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: s3Key,
      Body: JSON.stringify(newOrder, null, 2),
      ContentType: "application/json",
      Metadata: {
        orderId: orderId,
        customer: customer
      }
    });

    await s3.send(putCommand);
    newOrder.s3_upload_status = "SUCCESS";
    console.log(`[S3 SUCCESS] Hóa đơn ${orderId} đã được upload an toàn lên s3://${BUCKET_NAME}/${s3Key}`);
  } catch (err) {
    newOrder.s3_upload_status = "FAILED";
    newOrder.s3_error = err.message;
    console.error(`[S3 ERROR] Lỗi upload hóa đơn ${orderId} lên S3:`, err.message);
  }

  orders.unshift(newOrder);
  res.status(201).json(newOrder);
});

// ==============================================================================
// SERVER INITIALIZATION & GRACEFUL SHUTDOWN
// ==============================================================================
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[BACKEND STARTED] Server running on http://0.0.0.0:${PORT}`);
  console.log(`[SECURITY] Process UID: ${typeof process.getuid === 'function' ? process.getuid() : 'N/A'}`);
  console.log(`[IRSA CLOUD] Target S3 Bucket: ${BUCKET_NAME}`);
});

// Xử lý tín hiệu dừng hệ thống (SIGTERM từ Kubernetes, SIGINT từ Ctrl+C)
function handleShutdown(signal) {
  console.log(`\n[${signal}] Nhận tín hiệu dừng từ Kubernetes / OS, bắt đầu quy trình Graceful Shutdown...`);
  isShuttingDown = true;

  // Chờ 5 giây để Ingress Controller rút IP Pod khỏi Target Group / Endpoints
  const DRAIN_TIME_MS = 5000;
  console.log(`[DRAINING] Đang chờ ${DRAIN_TIME_MS / 1000}s để hoàn tất các request dở dang...`);

  setTimeout(() => {
    server.close(() => {
      console.log('[SHUTDOWN COMPLETE] Toàn bộ kết nối HTTP đã đóng an toàn. Tiến trình kết thúc sạch sẽ (Exit 0).');
      process.exit(0);
    });
  }, DRAIN_TIME_MS);
}

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));