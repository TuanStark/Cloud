# 📘 CẨM NANG THỰC CHIẾN: TERRAFORM MODULES CHUẨN ENTERPRISE & MULTI-ENVIRONMENT ARCHITECTURE
> **Lab 04:** Viết Terraform Module chuẩn Enterprise cho AWS Network  
> **Cấu trúc chuẩn 5 phần:**  
> 1. Service / Khái niệm ➔ 2. **Định nghĩa kỹ thuật chuẩn (Formal Definition)** ➔ 3. **Giải thích dễ hiểu / Ẩn dụ** ➔ 4. **Cách dùng thực tế (Production)** ➔ 5. **Bài học xương máu & Lưu ý**  

---

## 🧱 1. TERRAFORM CHILD MODULES (KHUÔN MẪU HẠ TẦNG TÁI SỬ DỤNG)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Child Module** là một tập hợp các file cấu hình Terraform (`.tf`) được đóng gói độc lập trong một thư mục chuyên biệt, được gọi từ một cấu hình khác (Root Module) thông qua khối lệnh `module "..."`.
* **Nguyên lý đóng gói (Encapsulation):** Module chỉ giao tiếp với thế giới bên ngoài thông qua hai cửa ngõ:
  - **Inputs:** Được khai báo trong `variables.tf`.
  - **Outputs:** Được khai báo trong `outputs.tf`.
  - Toàn bộ tài nguyên bên trong (`main.tf`) là "hộp đen" (Black Box) đối với bên ngoài.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Child Module giống như **"Khối động cơ ô tô được sản xuất hàng loạt trong nhà máy"**:
  * Động cơ có các đầu dây cắm chuẩn: ống dẫn xăng (Variables) và trục truyền động (Outputs).
  * Bạn có thể lắp khối động cơ này vào xe chạy thử nghiệm (Dev) hoặc xe bọc thép tổng thống (Prod). Không ai tự tay hàn từng con ốc của động cơ mỗi khi làm một chiếc xe mới.

### 🛠️ Cách dùng trong thực tế:
* **Quy chuẩn cấu trúc thư mục của Enterprise:**
  ```
  modules/vpc/
  ├── main.tf        # Định nghĩa tài nguyên: VPC, Subnet, IGW, NAT, Endpoints
  ├── variables.tf   # Đầu vào kèm Validation nghiêm ngặt
  ├── outputs.tf     # Đầu ra phong phú cho các tầng sau (EKS, RDS, ALB)
  └── versions.tf    # Khóa phiên bản Terraform CLI và Providers
  ```
* **Quản lý phiên bản (Versioning):** Trong các tập đoàn lớn, các Child Module được đưa lên Git Repository riêng và gán Semantic Versioning:
  ```hcl
  module "vpc" {
    source = "git::https://github.com/my-org/terraform-aws-vpc.git?ref=v1.2.0"
    ...
  }
  ```

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Tránh biến Module thành "Spaghetti Code":** Không cố nhét toàn bộ thế giới (VPC + EKS + RDS) vào 1 module duy nhất. Mỗi module chỉ nên đảm nhận **duy nhất một trách nhiệm hạ tầng (Single Responsibility)**.
2. **Không hardcode bất kỳ thông số nào:** Bất kỳ giá trị nào có khả năng thay đổi giữa các môi trường (CIDR, số lượng AZ, tên tài nguyên, tags) đều **bắt buộc** phải đưa ra `variables.tf`.

---

## 🛡️ 2. STRICT INPUT VALIDATION (KIỂM THỰC DỮ LIỆU ĐẦU VÀO TRONG IAC)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Input Validation** là cơ chế của Terraform (hỗ trợ từ v0.13+) cho phép gán khối `validation { condition = ... error_message = ... }` bên trong từng `variable`.
* Được đánh giá ngay trong giai đoạn **`terraform plan` (Shift-Left Validation)** trước khi bất kỳ lệnh gọi API nào được gửi lên Cloud Provider.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Input Validation giống như **"Cổng kiểm tra an ninh trước khi lên máy bay"**:
  * Nếu vé của bạn sai ngày hoặc hành lý quá cân (CIDR sai định dạng, số lượng Subnet không khớp với AZ), bạn bị chặn lại ngay tại cửa sân bay.
  * Tránh tình trạng máy bay đã bay lên trời (đang chạy `apply` dở chừng) mới phát hiện ra lỗi và phải rơi tự do.

### 🛠️ Cách dùng trong thực tế:
* **Bắt lỗi định dạng CIDR:**
  ```hcl
  variable "vpc_cidr" {
    type = string
    validation {
      condition     = can(cidrhost(var.vpc_cidr, 1))
      error_message = "vpc_cidr phải là một dải CIDR IPv4 hợp lệ (ví dụ: 10.0.0.0/16)."
    }
  }
  ```
* **Bắt lỗi tính toàn vẹn (Độ dài Subnet phải bằng số lượng AZ):**
  ```hcl
  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Số lượng public_subnet_cidrs phải khớp với số lượng availability_zones."
  }
  ```

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Lỗi "Hạ tầng dở dang" (Dangling Resources):** Nếu không có validation, bạn gõ nhầm CIDR `10.0.1.0/35`. Terraform apply tạo xong VPC, tạo xong IGW, đến lúc tạo Subnet thì AWS báo lỗi cú pháp. Lúc này hạ tầng bị treo ở trạng thái nửa vời, rất mất thời gian để dọn dẹp (Rollback).
2. **Hàm `can()` là vũ khí tối thượng:** Dùng `can(expression)` để bẫy các hàm dễ văng lỗi (như `cidrhost()`, `regex()`). Nếu biểu thức bên trong ném lỗi, `can()` sẽ trả về `false` một cách an toàn mà không làm crash Terraform CLI.

---

## 🔄 3. MULTI-ENVIRONMENT ARCHITECTURE & NGUYÊN TẮC DRY (DEV VS PROD)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Multi-Environment Architecture** là kiến trúc tổ chức mã nguồn IaC phân tách theo từng môi trường độc lập (`dev`, `staging`, `prod`) làm các **Root Modules**, cùng gọi chung các **Child Modules** với bộ tham số đầu vào khác nhau.
* Tuân thủ triệt để nguyên tắc **DRY (Don't Repeat Yourself)**: Mã nguồn kiến trúc chỉ viết một lần duy nhất, sự khác biệt được định nghĩa trong file dữ liệu cấu hình (`terraform.tfvars`).

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Giống như **"Khuôn đúc bánh và công thức nêm nếm"**:
  * Module là chiếc khuôn đúc bánh duy nhất.
  * Bánh cho trẻ em ăn thử (Dev) dùng bột mì giá rẻ, 1 lớp sốt (1 NAT Gateway).
  * Bánh tiệc cung đình (Prod) dùng nguyên liệu cao cấp, 2 lớp bơ dày độc lập (Multi-AZ NAT Gateway) để nếu hỏng lớp này vẫn còn lớp kia.
  * Nhưng cả 2 đều dùng chung một khuôn đúc, kích thước chuẩn xác như nhau.

### 🛠️ Cách dùng trong thực tế:
* File `environments/dev/main.tf` và `environments/prod/main.tf` **giống hệt nhau từng ký tự**:
  ```hcl
  module "vpc" {
    source               = "../../modules/vpc"
    vpc_cidr             = var.vpc_cidr
    single_nat_gateway   = var.single_nat_gateway
    ...
  }
  ```
* **Sự khác biệt 100% nằm trong `terraform.tfvars`:**
  * **Dev:** `vpc_cidr = "10.10.0.0/16"`, `single_nat_gateway = true`, `Environment = "dev"`.
  * **Prod:** `vpc_cidr = "10.20.0.0/16"`, `single_nat_gateway = false`, `Environment = "prod"`.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Sự cố "Cơn bão Configuration Drift":** Tuyệt đối không copy paste code VPC sang từng thư mục môi trường. Sau 6 tháng, Dev sửa nóng ở file này nhưng quên sửa ở file kia, khi sự cố xảy ra không một ai biết môi trường Prod đang chạy phiên bản nào.
2. **Tách dải IP giữa các môi trường:** Đừng bao giờ đặt Dev là `10.0.0.0/16` và Prod cũng là `10.0.0.0/16`. Khi công ty cần mở rộng kết nối mạng nội bộ giữa Dev và Prod (VPC Peering) hoặc kết nối về On-Premise, hai mạng sẽ bị **trùng dải IP (IP Overlapping)** $\rightarrow$ Bắt buộc phải đập bỏ toàn bộ VPC để làm lại từ đầu!

---

## 💥 4. BLAST RADIUS ISOLATION (THU HẸP VÙNG ẢNH HƯỞNG TRONG SỰ CỐ)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Blast Radius (Bán kính nổ / Vùng ảnh hưởng)** là phạm vi thiệt hại tối đa mà một sự cố vận hành, lỗi cấu hình hoặc lệnh thực thi sai có thể gây ra cho toàn bộ hệ thống.
* **Blast Radius Reduction** trong IaC đạt được bằng cách chia nhỏ các file State (`.tfstate`) theo môi trường và theo từng tầng dịch vụ (Network State riêng, Database State riêng, K8s Cluster State riêng).

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Blast Radius giống như **"Vách ngăn chống chìm trên thân tàu thủy Titanic"**:
  * Thân tàu được chia thành các khoang độc lập có cửa đóng kín.
  * Nếu khoang Dev bị thủng (dev chạy nhầm `terraform destroy`), nước chỉ tràn vào khoang Dev. Khoang Prod và Database nằm ở các vách ngăn khác, hoàn toàn không bị ảnh hưởng.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Cơn ác mộng "Monolithic State":** Gom chung toàn bộ VPC, EC2, RDS, EKS vào một file state duy nhất là hành vi "tự sát". Chỉ cần 1 dòng lệnh gõ nhầm khi test hoặc 1 lần state lock bị kẹt, toàn bộ hệ thống của công ty sẽ bị đóng băng hoặc xóa sổ.
2. **Nguyên tắc phân quyền IAM:** Developer chỉ được phép có quyền Apply ở thư mục `environments/dev`. Tuyệt đối không cấp quyền AWS credentials chạy `apply` vào `prod` từ máy cá nhân; việc apply Prod phải do hệ thống CI/CD (GitHub Actions) đảm nhận sau khi đã qua bước Review.

---

## ⚠️ 5. TOP 4 CẠM BẪY TERRAFORM KINH ĐIỂN CẦN TRÁNH (SENIOR GOTCHAS)

| STT | Cạm bẫy thực chiến | Triệu chứng & Hậu quả | Giải pháp chuẩn Production |
| :--- | :--- | :--- | :--- |
| **1** | **`for_each` dùng attribute chưa tồn tại** | Dùng `for_each = toset(aws_subnet.public[*].id)`. Lỗi ngay lúc `plan`: *"Keys cannot be determined until apply"*. | Dùng `count = length(var.public_subnet_cidrs)` khi tạo association, đồng bộ với resource tạo bằng count. |
| **2** | **Ternary Index Out of Bounds** | Viết `single_nat ? nat[0].id : nat[count.index].id`. Khi `single_nat = true`, `count.index = 1` vẫn bị đánh giá văng lỗi `Index out of bounds`. | Dùng hàm `element(aws_nat_gateway.main[*].id, var.single_nat_gateway ? 0 : count.index)`. |
| **3** | **Commit nhầm `*.tfstate` lên Git** | Mật khẩu database, API token bị lộ dạng plaintext trên GitHub. Hacker quét trong 3 giây. | Đưa ngay `*.tfstate*` vào `.gitignore`. Sử dụng S3 Remote Backend có mã hóa KMS (Lab 5). |
| **4** | **Ignore file `.terraform.lock.hcl`** | Bỏ qua lockfile khiến máy đồng nghiệp tải provider phiên bản mới hơn, gây lệch schema và phá vỡ cấu hình chạy. | **Bắt buộc commit `.terraform.lock.hcl`** lên Git để đảm bảo 100% môi trường dùng chung phiên bản provider. |
