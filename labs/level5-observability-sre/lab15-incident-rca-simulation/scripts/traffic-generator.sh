#!/bin/bash
# Mô phỏng bão giao dịch Black Friday dồn dập vào Payment Vault
TARGET_URL="http://localhost:8082/api/v1/charge"

echo "🚀 Đang bắn 60 giao dịch liên tiếp vào Payment Vault để kích nổ sự cố..."

for i in {1..60}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TARGET_URL")
  if [ "$STATUS" == "200" ]; then
    echo "   [Request $i] Mã HTTP: $STATUS (Thành công ✅)"
  else
    echo "   [Request $i] Mã HTTP: $STATUS (SẬP HỆ THỐNG ❌)"
  fi
  sleep 0.1 # Bắn dồn dập 10 request/giây
done

echo "💥 Đã hoàn tất đợt bơm bão traffic!"
