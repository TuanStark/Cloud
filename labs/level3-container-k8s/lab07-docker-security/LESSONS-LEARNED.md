# 📚 BÀI HỌC KINH NGHIỆM: LEVEL 3 - LAB 07 (DOCKER SECURITY & CONTAINER HARDENING)

---

## 1. Dịch vụ & Khái niệm Cốt lõi (Core Concepts)

Trong kiến trúc Cloud-Native và Kubernetes (AWS EKS), Container Image là đơn vị đóng gói và phân phối phần mềm cơ bản nhất. Tuy nhiên, một ngộ nhận phổ biến là coi container như một "máy ảo thu nhỏ an toàn độc lập". Thực tế, **container chia sẻ chung Linux Kernel với máy chủ Host**. Do đó, một container được cấu hình lỏng lẻo sẽ trở thành bàn đạp lý tưởng để kẻ tấn công chiếm quyền điều khiển toàn bộ cụm hạ tầng.

Bài lab này đúc kết toàn diện các nguyên lý và kỹ thuật bảo vệ Container chuẩn mực:
1. **Container Isolation & Threat Model:** Hiểu rõ cơ chế chia sẻ nhân Linux Kernel (Namespaces, Cgroups) và rủi ro Container Breakout.
2. **Multi-Stage Builds:** Kỹ thuật tách rời môi trường biên dịch (Build) và môi trường thực thi (Runtime) để giảm thiểu Attack Surface.
3. **Least Privilege & Non-Root Execution:** Nguyên tắc ép buộc tiến trình chạy dưới quyền người dùng không đặc quyền (`UID >= 1000`).
4. **Minimal Base Images (Alpine, Google Distroless, Chainguard):** Triệt tiêu các công cụ tấn công (shell, package manager, curl, gcc) trong môi trường Production.
5. **Vulnerability Scanning (Trivy):** Kiểm toán tự động các lỗ hổng phần mềm (CVEs) và bí mật rò rỉ (Secrets) trong image layers.
6. **Container Runtime Defense:** Khóa cứng hệ thống tệp chỉ đọc (`--read-only`) và tước bỏ toàn bộ Linux Kernel Capabilities (`--cap-drop=ALL`).

---

## 2. Định nghĩa Kỹ thuật Chuẩn (Formal Definition)

### A. Cơ chế Container Isolation (Namespaces & Cgroups)
- **Định nghĩa:** Khác với Máy Ảo (VM) có Hypervisor và Guest OS riêng biệt, Container chỉ là các tiến trình Linux thông thường được cô lập nhờ hai tính năng cốt lõi của Linux Kernel:
  - **Linux Namespaces:** Cô lập góc nhìn của tiến trình về hệ thống (PID namespace cô lập tiến trình, NET namespace cô lập card mạng, MNT namespace cô lập mount point, USER namespace cô lập UID/GID).
  - **Control Groups (cgroups):** Giới hạn và đo lường tài nguyên phần cứng (CPU, Memory, Disk I/O, Network bandwidth).
- **Rủi ro cốt tử:** Nếu tiến trình trong container chạy dưới quyền `UID 0` (root), nó sở hữu cùng UID với `root` trên máy chủ Host. Khi xuất hiện lỗ hổng kernel (Kernel Exploit) hoặc cấu hình sai (Mounting Docker Socket `/var/run/docker.sock`), kẻ tấn công có thể bẻ gãy ranh giới cô lập để thoát ra ngoài (**Container Escape**).

### B. Multi-Stage Build & OCI Layer Immutability
- **Định nghĩa:** Theo chuẩn OCI (Open Container Initiative), image được cấu tạo từ các lớp (Layers) chỉ đọc xếp chồng lên nhau (Union File System / Overlay2). Mỗi chỉ thị (`RUN`, `COPY`, `ADD`) trong Dockerfile tạo ra một immutable layer.
- **Cơ chế Multi-Stage Build:** Cho phép khai báo nhiều mệnh đề `FROM` trong cùng một Dockerfile. Các artifacts hoặc binaries được biên dịch ở Stage trước (`builder`) có thể được chọn lọc copy sang Stage sau (`runner`), trong khi toàn bộ SDK, compilers, build caches và mã nguồn thô bị loại bỏ hoàn toàn khỏi image cuối cùng.

### C. The PID 1 Problem in Containers
- **Định nghĩa:** Trong Linux, tiến trình mang `PID 1` là tiến trình gốc (Init System như `systemd` hoặc `init`). Nó có 2 trách nhiệm đặc thù của kernel:
  1. Thu dọn các tiến trình con mồ côi (Reaping Zombie Processes) để tránh cạn kiệt bảng Process Table của OS.
  2. Tiếp nhận và điều hướng các tín hiệu hệ điều hành (`SIGTERM`, `SIGINT`, `SIGHUP`).
- **Vấn đề:** Các ứng dụng runtime như Node.js, Python, Java không được thiết kế để làm init process. Khi Kubernetes gửi tín hiệu `SIGTERM` yêu cầu dừng Pod, ứng dụng ở PID 1 thường phớt lờ, khiến container không thể Graceful Shutdown và bị hạ sát thô bạo bởi `SIGKILL` sau thời gian chờ (30 giây).

---

## 3. Giải thích Dễ hiểu & Ẩn dụ Thực tế (Metaphors)

| Khái niệm | Ẩn dụ Đời sống | Ý nghĩa trong Container Security |
| :--- | :--- | :--- |
| **Fat Image (`node:18`)** | Thuê một phòng trọ nhưng dọn theo cả kho đồ nghề: búa tạ, cưa máy, xà beng, thuốc nổ dù chỉ vào để ngủ. | Mang theo cả hệ điều hành Debian chứa `gcc`, `curl`, `python`, `netcat`. Nếu trộm đột nhập, chúng có sẵn công cụ để đập phá và tấn công phòng bên cạnh. |
| **Slim / Distroless Image** | Khách sạn tối giản kiểu Nhật: Chỉ có đúng một tấm nệm để ngủ, không có bất kỳ đồ vật thừa thãi nào. | Chỉ chứa đúng binary thực thi của ứng dụng và thư viện C cần thiết. Không có bash, không có shell, trộm vào không có công cụ để làm gì. |
| **Chạy Container bằng `root`** | Trao chìa khóa vạn năng (Master Key) của cả tòa chung cư cho một shipper giao trà sữa. | Cho web app chạy quyền root (`UID 0`). Khi app bị lỗi injection, hacker có quyền tối cao can thiệp vào kernel máy chủ. |
| **Chạy bằng `Non-Root User`** | Chỉ phát thẻ khách vãng lai: chỉ được bấm thang máy lên đúng tầng của mình, không được vào phòng kỹ thuật hay tầng hầm. | Ép container chạy bằng `USER node` (UID 1000) hoặc UID 10001. Có bị chiếm quyền cũng không thể đọc file nhạy cảm của OS. |
| **`RUN rm .env` ở Layer sau** | Viết mật khẩu két sắt lên tường phòng trọ, rồi lấy một tờ giấy dán đè lên và nghĩ là không ai thấy. | Docker layer mang tính vĩnh cửu. Dù xóa ở layer sau, hacker chỉ cần lột tờ giấy ra (`docker history`) là đọc trọn vẹn password. |

---

## 4. Cách Dùng Thực Tế trong Môi Trường Production

### 1. File `.dockerignore` Chuẩn Doanh Nghiệp
Đặt file `.dockerignore` tại thư mục gốc ngữ cảnh build để ngăn chặn việc đưa rác và dữ liệu nhạy cảm vào Build Context:
```text
# Dependencies local không tương thích với OS container
node_modules
npm-debug.log

# Quản lý mã nguồn & tài liệu nội bộ
.git
.gitignore
.github
*.md

# Secrets & Environment Variables (CỰC KỲ NGUY HIỂM)
.env
.env.*
*.pem
*.key

# Docker & CI/CD artifacts
Dockerfile*
.dockerignore
```

---

### 2. Mẫu Dockerfile Chuẩn Hardening Đỉnh Cao (Production Multi-Stage)
```dockerfile
# ==============================================================================
# GIAI ĐOẠN 1: BUILDER (Biên dịch và cài đặt thư viện)
# ==============================================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Tận dụng triệt để Docker Layer Cache cho dependencies
COPY package*.json ./

# Cài đặt sạch sẽ, loại bỏ toàn bộ devDependencies
RUN npm ci --omit=dev

# ==============================================================================
# GIAI ĐOẠN 2: RUNTIME (Môi trường thực thi tối giản & an toàn)
# ==============================================================================
FROM node:18-alpine AS runner

# Khắc phục PID 1 Problem: Cài đặt init system siêu nhẹ
RUN apk add --no-cache dumb-init

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

# TUYỆT KỸ: Dùng cờ --chown trực tiếp trong COPY để tránh nhân đôi layer
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node server.js ./

# PHÒNG VỆ CHỦ ĐỘNG: Chuyển sang Non-Root User (UID 1000)
USER node

EXPOSE 5000

# Khởi động qua dumb-init để xử lý signals và dọn dẹp zombie processes chuẩn mực
CMD ["dumb-init", "node", "server.js"]
```

---

### 3. Sáu "Tuyệt Kỹ Ngầm" Của Chuyên Gia DevSecOps (Enterprise Secrets)

#### 🔥 Tuyệt kỹ 1: Tránh Bẫy Nhân Đôi Dung Lượng Từ `RUN chown -R`
- **Sai lầm phổ biến:** `COPY . .` rồi chạy `RUN chown -R appuser:appuser /app`.
- **Hậu quả:** Lệnh `RUN chown` tạo ra một Layer mới copy toàn bộ metadata và dữ liệu của cả thư mục. Nếu `node_modules` nặng 300MB, image bị đội lên thêm 300MB một cách vô ích.
- **Giải pháp chuyên gia:** Luôn dùng thuộc tính `--chown=user:group` ngay trong lệnh `COPY` để quyền sở hữu được áp dụng ngay lúc ghi layer.

#### 🔥 Tuyệt kỹ 2: Google Distroless & Chainguard ("No Shell, No Attack Tools")
- Thay vì `node:18-alpine` (vẫn còn `/bin/sh` và `apk`), các hệ thống tài chính chuyển sang **Distroless**:
  ```dockerfile
  FROM gcr.io/distroless/nodejs18-debian12
  WORKDIR /app
  COPY --from=builder /app /app
  USER nonroot:nonroot
  CMD ["server.js"]
  ```
- **Giá trị thực tế:** Không có shell để thực thi lệnh; kẻ tấn công dù có lỗ hổng RCE cũng không thể mở Reverse Shell hoặc tải mã độc.

#### 🔥 Tuyệt kỹ 3: BuildKit Secret & Cache Mounts (Tốc Độ x10 & 0% Lộ Token)
Khi cần Private NPM Token hoặc SSH Key để pull module nội bộ trong lúc build:
```dockerfile
# Secret chỉ tồn tại trên RAM tạm thời trong lúc chạy lệnh RUN, không lưu vào image layer
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev
```

#### 🔥 Tuyệt kỹ 4: Xử Lý "PID 1 Problem" Bằng `dumb-init` / `tini`
- Bọc ứng dụng qua `dumb-init` hoặc `tini`.
- Khi Kubernetes scale-down Pod, `dumb-init` nhận `SIGTERM` từ Linux Kernel và chuyển tiếp chính xác đến tiến trình con Node.js, cho phép ứng dụng đóng toàn bộ kết nối cơ sở dữ liệu dở dang trước khi thoát (**Graceful Shutdown**).

#### 🔥 Tuyệt kỹ 5: Khóa Cứng Hệ Thống Tệp Chỉ Đọc (`--read-only`)
- Khi chạy container trên Docker hoặc Kubernetes Pod:
  ```bash
  docker run -d --read-only --tmpfs /tmp:rw,noexec,nosuid,size=64m -p 5000:5000 my-image:latest
  ```
- **Cờ `noexec`:** Ngăn chặn tuyệt đối việc kẻ tấn công tải tệp nhị phân độc hại vào `/tmp` rồi cấp quyền thực thi (`chmod +x`).

#### 🔥 Tuyệt kỹ 6: Tước Bỏ Toàn Bộ Linux Capabilities (`--cap-drop=ALL`)
- Mặc định container được cấp quyền can thiệp mạng thô (`CAP_NET_RAW`), thay đổi quyền file (`CAP_CHOWN`)...
- Khi chạy ứng dụng microservice không cần đặc quyền hệ điều hành:
  ```bash
  docker run --cap-drop=ALL -p 5000:5000 my-image:latest
  ```
- Vô hiệu hóa hầu hết các vector tấn công leo thang đặc quyền (Privilege Escalation).

---

## 5. Bài Học Xương Máu & Điều Cần Lưu Ý (Hard-won Lessons)

### 💀 Horror Story 1: Thảm Họa Container Breakout Chiếm Cả Worker Node
- **Sự cố:** Một dịch vụ xử lý ảnh cho phép người dùng upload ảnh và dùng tiện ích hệ thống để chuyển đổi. Ứng dụng dính lỗ hổng Command Injection và chạy dưới quyền `root` bên trong container. Kẻ tấn công lợi dụng lỗ hổng nhân Linux (tương tự Dirty COW / Dirty Pipe) để ghi đè bộ nhớ của Kernel và thoát ra ngoài máy chủ Host EC2, nắm trọn quyền root toàn bộ máy chủ worker của cụm EKS!
- **Biện pháp phòng ngừa bất biến:** Luôn khai báo `USER <non-root>` trong Dockerfile và cấu hình `runAsNonRoot: true` trong Kubernetes SecurityContext.

### 💀 Horror Story 2: Lộ Cloud Credentials Qua Ảo Tưởng "RUN rm .env"
- **Sự cố:** Một kỹ sư copy file `.env` chứa `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY` vào image để chạy build test, sau đó viết thêm dòng `RUN rm -f .env` ở cuối Dockerfile. Image được đẩy lên Docker Hub public. Vài giờ sau, tài khoản AWS bị hacker đột nhập, tạo hàng loạt máy chủ EC2 cấu hình khủng để đào Bitcoin, phát sinh hóa đơn hơn 50,000 USD!
- **Nguyên nhân:** Kẻ tấn công chỉ cần chạy lệnh:
  ```bash
  docker history --no-trunc <image-name>
  ```
  Hoặc trích xuất layer tarball là khôi phục lại 100% file `.env` đã bị "xóa".

### 💀 Horror Story 3: Lỗi 504 Gateway Timeout Do Slow Cold Start Của Fat Image (1.2GB)
- **Sự cố:** Một đợt Flash Sale diễn ra, lượng truy cập tăng vọt gấp 20 lần. Kubernetes HPA (Horizontal Pod Autoscaler) ra lệnh scale từ 5 Pods lên 50 Pods trên các Node mới. Do image backend nặng 1.2GB, mỗi Node mới mất hơn 2 phút để kéo image từ AWS ECR về qua đường truyền mạng. Khách hàng liên tục nhận lỗi 504 Gateway Timeout, hệ thống tê liệt suốt 15 phút đầu chiến dịch.
- **Khắc phục:** Sau khi chuyển sang Multi-Stage Build + Alpine, image giảm từ 1.2GB xuống **58MB**. Thời gian kéo image giảm từ 120 giây xuống **3 giây**, Pods scale thần tốc và chịu tải mượt mà.

---

### 💡 Bảng Đối Chiếu: Vulnerable vs Hardened Image

| Tiêu Chí So Sánh | Dockerfile "Ngây Thơ" (Vulnerable) | Dockerfile "Chuẩn Hóa" (Hardened) | Lợi Ích Mang Lại |
| :--- | :--- | :--- | :--- |
| **Base Image** | `node:18` (Debian đầy đủ) | `node:18-alpine` hoặc `Distroless` | Giảm thiểu 95% Attack Surface |
| **Dung Lượng Image** | **~1.1 GB** | **~50 - 80 MB** | Tiết kiệm băng thông, scale Pods cực nhanh |
| **Số Lượng CVEs (Trivy)** | **500+ Lỗ hổng** (hàng chục Critical/High) | **0 Lỗ hổng Critical / High** | Đạt chuẩn kiểm toán PCI-DSS, SOC 2 |
| **Tiến Trình Chạy (User)** | `root` (`UID 0`) | `node` (`UID 1000`) hoặc `UID 10001` | Chặn đứng nguy cơ Container Escape |
| **Công Cụ Tấn Công Sẵn Có** | Có sẵn `curl`, `wget`, `gcc`, `python`, `sh` | Đã loại bỏ toàn bộ compilers & network tools | Kẻ xâm nhập không có công cụ để leo thang |
| **Xử Lý Tín Hiệu (PID 1)** | Node.js chạy trực tiếp ở PID 1 (lờ SIGTERM) | Bọc qua `dumb-init` / `tini` | Đảm bảo Graceful Shutdown không mất dữ liệu |
| **Bảo Vệ Tệp Tin Lúc Chạy** | Cho phép ghi đè mọi thư mục | Read-Only Root Filesystem | Chống cài cắm webshell, backdoor, virus |
