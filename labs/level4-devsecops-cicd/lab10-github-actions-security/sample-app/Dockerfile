# =========================================================================
# 🛡️ HARDENED PRODUCTION DOCKERFILE (CIS BENCHMARK COMPLIANT)
# =========================================================================
# Standard: CIS Docker Benchmark 4.1, 4.2, 4.3, 4.6, 4.8
# Multi-Stage Build, Minimal Attack Surface, Non-Root User, Dumb-Init PID 1

# -------------------------------------------------------------------------
# Stage 1: Build & Dependencies Resolution
# -------------------------------------------------------------------------
FROM node:20.18-alpine3.20 AS dependencies

WORKDIR /build

# Chỉ copy manifest file để tối ưu Docker Layer Caching
COPY package.json ./

# Cài đặt chỉ các production dependencies, bỏ qua devDependencies và scripts
RUN npm install --omit=dev --ignore-scripts --no-audit && \
    npm cache clean --force

# -------------------------------------------------------------------------
# Stage 2: Minimal Production Runtime
# -------------------------------------------------------------------------
FROM node:20.18-alpine3.20 AS runner

# Ghi nhãn metadata phục vụ kiểm toán bảo mật (Software Bill of Materials)
LABEL maintainer="Le Cong Tuan <tuanstark>" \
      security.hardened="true" \
      cis.benchmark.compliant="true" \
      version="1.0.0"

WORKDIR /app

# Cài đặt dumb-init để xử lý PID 1 signal forwarding (SIGTERM, SIGINT)
# Nâng cấp các gói hệ điều hành để vá CVEs (openssl, musl, zlib)
# Và XÓA BỎ npm, npx, corepack (Build tools) khỏi runtime image
# 🛡️ SENIOR DEVSECOPS HARDENING: 
# 1. 'apk upgrade' cập nhật các bản vá bảo mật hệ điều hành
# 2. Xóa bỏ 'npm' loại bỏ toàn bộ bề mặt tấn công của build tools trong production
RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init=1.2.5-r3 && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

# Copy production dependencies từ stage 1
COPY --from=dependencies --chown=node:node /build/node_modules ./node_modules

# Copy mã nguồn ứng dụng với quyền sở hữu thuộc user non-root "node"
COPY --chown=node:node server.js package.json ./

# CIS 4.1: Chuyển đổi sang non-root user (UID 1000: node có sẵn trong image Node Alpine)
USER node

# Môi trường chạy production
ENV NODE_ENV=production \
    PORT=8080

EXPOSE 8080

# CIS 4.6: Khai báo HEALTHCHECK để Docker/K8s tự động giám sát sức khỏe container
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

# Sử dụng dumb-init làm init system (PID 1) để nhận và chuyển tiếp tín hiệu graceful shutdown
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
