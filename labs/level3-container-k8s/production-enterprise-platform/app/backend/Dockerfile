# ==========================================
# STAGE 1: BUILDER (Cài đặt dependencies)
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

# ==========================================
# STAGE 2: RUNNER (Môi trường chạy tối giản)
# ==========================================
FROM node:18-alpine AS runner

# Cài đặt dumb-init để xử lý PID 1 và chuyển tiếp tín hiệu SIGTERM chuẩn mực
RUN apk add --no-cache dumb-init

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

# Copy dependencies và mã nguồn với quyền sở hữu của user 'node'
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node server.js ./

# Chuyển sang non-root user (UID 1000)
USER node

EXPOSE 5000

# Khởi chạy qua dumb-init
CMD ["dumb-init", "node", "server.js"]
