# ==========================================
# STAGE 1: BUILDER (Cài đặt dependencies)
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copy riêng package.json để tận dụng Docker Layer Cache
COPY app/backend/package*.json ./

# Cài đặt sạch sẽ (chỉ lấy production dependencies)
RUN npm ci --omit=dev

# ==========================================
# STAGE 2: RUNTIME (Môi trường chạy tối giản)
# ==========================================
FROM node:18-alpine AS runner

WORKDIR /app

# Thiết lập biến môi trường production
ENV NODE_ENV=production
ENV PORT=5000

# Copy node_modules từ stage builder sang
COPY --from=builder /app/node_modules ./node_modules

# Copy mã nguồn server
COPY app/backend/server.js ./

# PHÒNG THỦ: Đổi quyền sở hữu thư mục cho user 'node' và kích hoạt non-root
RUN chown -R node:node /app
USER node

EXPOSE 5000

CMD ["node", "server.js"]
