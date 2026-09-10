/**
 * ⚠️ VULNERABLE SAMPLE FILE - FOR DEVSECOPS SECURITY GATE SENSITIVITY TESTING ONLY!
 * WARNING: DO NOT RUN THIS IN PRODUCTION!
 *
 * This file intentionally contains classical OWASP Top 10 vulnerabilities and hardcoded secrets
 * to verify that our Security Gates (Gate 1: Secret Scan, Gate 2: SAST) properly detect and block
 * dangerous code changes before merge.
 */

const express = require('express');
const { exec } = require('child_process');

const app = express();
app.use(express.json());

// =========================================================================
// [VULNERABILITY 1 - GATE 1 DETECTION: HARDCODED CLOUD & API SECRETS]
// =========================================================================
// CRITICAL: Hardcoded AWS credentials in source code (Violation of CIS & AWS Security Best Practices)
const AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE";
const AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";

// CRITICAL: Hardcoded Third-Party API Key (Payment Gateway Secret)
const STRIPE_SECRET_KEY = "sk_live_51M0abcdef1234567890abcdef1234567890";
const JWT_SECRET = "company_super_secret_jwt_key_2026";

// =========================================================================
// [VULNERABILITY 2 - GATE 2 DETECTION: SQL INJECTION (A03:2021-Injection)]
// =========================================================================
// LỖI: Ghép chuỗi trực tiếp từ user input vào câu truy vấn database thay vì dùng Parameterized Queries.
// Kẻ tấn công có thể truyền: username = "admin' OR '1'='1" để bypass xác thực hoặc dump toàn bộ DB.
app.get('/api/v1/insecure/users', (req, res) => {
  const userInput = req.query.username;
  const sqlQuery = "SELECT * FROM users WHERE username = '" + userInput + "'";
  
  console.log(`[SQLi VULNERABLE] Executing raw query: ${sqlQuery}`);
  res.json({ executedQuery: sqlQuery, warning: "VULNERABLE TO SQL INJECTION" });
});

// =========================================================================
// [VULNERABILITY 3 - GATE 2 DETECTION: COMMAND INJECTION (RCE)]
// =========================================================================
// LỖI: Nhận tham số từ query param và ném trực tiếp vào shell command thông qua child_process.exec()
// Kẻ tấn công có thể truyền: host = "8.8.8.8; cat /etc/passwd" hoặc "8.8.8.8; rm -rf /"
app.get('/api/v1/insecure/network-check', (req, res) => {
  const host = req.query.host;

  exec(`ping -c 1 ${host}`, (error, stdout, stderr) => {
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    res.json({ output: stdout });
  });
});

// =========================================================================
// [VULNERABILITY 4 - GATE 2 DETECTION: DANGEROUS EVAL() USAGE]
// =========================================================================
// LỖI: Sử dụng eval() với input của người dùng cho phép thực thi mã tùy ý trên server.
app.post('/api/v1/insecure/calculate', (req, res) => {
  const expression = req.body.expression;
  try {
    const result = eval(expression); // Code Injection vulnerability
    res.json({ result });
  } catch (err) {
    res.status(400).json({ error: "Calculation failed" });
  }
});

module.exports = app;
