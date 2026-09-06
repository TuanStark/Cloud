# 📘 CẨM NANG THỰC CHIẾN: TERRAFORM STATE MANAGEMENT, REMOTE BACKEND & CONCURRENCY LOCKING
> **Lab 05:** Terraform State Management (S3 Remote Backend, DynamoDB State Locking & Workspaces)  
> **Cấu trúc chuẩn 5 phần:**  
> 1. Service / Khái niệm ➔ 2. **Định nghĩa kỹ thuật chuẩn (Formal Definition)** ➔ 3. **Giải thích dễ hiểu / Ẩn dụ** ➔ 4. **Cách dùng thực tế (Production)** ➔ 5. **Bài học xương máu & Lưu ý**  

---

## 💾 1. BẢN CHẤT CỦA TERRAFORM STATE (THE TRUTH BEHIND `terraform.tfstate`)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Terraform State (`terraform.tfstate`)** là một cơ sở dữ liệu dạng JSON đóng vai trò là **nguồn chân lý duy nhất (Single Source of Truth)** ánh xạ giữa:
  1. Các định nghĩa tài nguyên khai báo trong mã nguồn HCL (`main.tf`).
  2. Các thực thể tài nguyên thực tế tồn tại trên hạ tầng Cloud (AWS Resource IDs, ARNs, VPC endpoints).
* **3 Chức năng sống còn của State:**
  - **Mapping (Ánh xạ ID):** Giúp Terraform biết `aws_s3_bucket.app` trong code tương ứng với bucket `tuanstark-dev-app-storage` nào trên AWS.
  - **Metadata & Dependency Tracking:** Lưu lại đồ thị phụ thuộc ngầm (DAG - Directed Acyclic Graph) để biết tài nguyên nào phải tạo trước, tài nguyên nào xóa sau.
  - **Performance Cache:** Lưu lại trạng thái của hàng ngàn tài nguyên để tránh việc mỗi lần chạy lệnh phải gửi hàng ngàn request API lên AWS để kiểm tra (tránh bị Cloud Provider Rate-Limit).

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Terraform State giống như **"Cuốn sổ đỏ và bản vẽ hoàn công của một tòa nhà"**:
  * Mã code HCL là **Bản thiết kế kiến trúc trên giấy**.
  * Hạ tầng trên AWS là **Tòa nhà bê tông cốt thép ngoài đời thực**.
  * File State chính là **Cuốn sổ đỏ ghi rõ**: Căn hộ số 101 thực tế đang do ai đứng tên, hệ thống ống nước ngầm nằm ở tọa độ nào. Nếu bạn làm mất cuốn sổ đỏ này, bạn vẫn thấy tòa nhà đứng đó nhưng không có quyền pháp lý để sửa đổi hay bán lại từng căn hộ!

### 🛠️ Cách dùng trong thực tế:
* **Local State (Chỉ dùng cho học tập cá nhân):** Lưu file `terraform.tfstate` ngay trong thư mục code trên máy tính.
* **Remote State (Chuẩn Enterprise 100%):** Lưu trữ tập trung tại **AWS S3** có bật mã hóa, bật versioning và bảo vệ quyền truy cập theo nguyên tắc Least Privilege.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Thảm họa rò rỉ dữ liệu nhạy cảm (Plaintext Secret Hazard):**  
   File state lưu trữ **TẤT CẢ** thuộc tính của tài nguyên ở dạng **văn bản thuần không mã hóa (Plaintext)**. Nếu bạn tạo một database RDS, mật khẩu `admin_password` sẽ nằm lộ liễu 100% trong file `.tfstate`. Nếu đẩy file này lên GitHub, toàn bộ hệ thống bị xâm nhập trong vòng vài phút.
2. **Hạ tầng vô chủ (Orphaned Infrastructure):**  
   Nếu xóa mất file state trong khi hạ tầng trên AWS vẫn đang chạy, Terraform sẽ coi như hệ thống chưa có gì và cố tạo mới đè lên $\rightarrow$ Ném lỗi `ResourceAlreadyExistsException`. Cả team sẽ mất hàng tuần ngồi dùng lệnh `terraform import` để nhặt lại từng ID tài nguyên.

---

## 🔒 2. STATE LOCKING VỚI AMAZON DYNAMODB (CONCURRENCY CONTROL)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **State Locking** là cơ chế kiểm soát đồng thời (Distributed Concurrency Control) ngăn chặn nhiều tiến trình hoặc nhiều kỹ sư cùng thực thi các thao tác ghi (`terraform apply`, `terraform destroy`, hoặc `terraform plan`) lên cùng một file State tại một thời điểm.
* **Cơ chế hoạt động bên dưới của DynamoDB:**
  - Bảng DynamoDB bắt buộc phải có Partition Key tên chính xác là **`LockID` (kiểu String - S)**.
  - Khi một kỹ sư gõ lệnh, Terraform thực hiện lệnh **`PutItem` có điều kiện (Conditional Write)**:
    $$\text{Condition: } \mathbf{attribute\_not\_exists(LockID)}$$
  - Thao tác này là một **Atomic Transaction (Giao dịch nguyên tử)** ở cấp độ phần cứng lưu trữ của DynamoDB.

```
                    [ KỸ SƯ A ]                                   [ KỸ SƯ B ]
                         │                                             │
             Gõ: `terraform apply`                         Gõ: `terraform apply`
                         │                                             │
                         ▼                                             ▼
          DynamoDB PutItem(LockID)                      DynamoDB PutItem(LockID)
       (attribute_not_exists(LockID))                (attribute_not_exists(LockID))
                         │                                             │
                         ├─────────────────────────────────────────────┤
                         ▼                                             ▼
             [ CHẤP THUẬN (THÀNH CÔNG) ]                  [ TỪ CHỐI NGAY LẬP TỨC ]
              Ghi bản ghi khóa thành công               Ném lỗi: ConditionalCheckFailed
              Tiến hành tạo hạ tầng AWS                 DỪNG TIẾN TRÌNH TRONG 0.1 GIÂY!
```

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* State Locking giống như **"Chốt khóa cửa phòng phẫu thuật"**:
  * Bác sĩ A bước vào phòng phẫu thuật, gạt chốt cửa lại (Đèn đỏ bật sáng).
  * Bác sĩ B đến sau, thấy cửa khóa và đèn đỏ thì phải đứng chờ bên ngoài.
  * Nếu không có chốt khóa, cả 2 bác sĩ cùng xông vào mổ một bệnh nhân cùng lúc, mỗi người mổ một kiểu $\rightarrow$ Bệnh nhân tử vong ngay trên bàn mổ (State Corruption)!

### 🛠️ Cấu trúc bản ghi Lock bên trong DynamoDB:
Khi hệ thống bị khóa, một record JSON thực tế sẽ xuất hiện trong bảng `tuanstark-tfstate-locks`:
```json
{
  "LockID": "tuanstark-tfstate-f8m8ns/dev/terraform.tfstate-md5",
  "Info": "{\"ID\":\"e37d5cb1-2034-7a31-9f93-c3c2b8109312\",\"Operation\":\"OperationTypeApply\",\"Who\":\"stark@stark-laptop\",\"Version\":\"1.9.8\",\"Created\":\"2026-09-06T07:10:01Z\",\"Path\":\"dev/terraform.tfstate\"}"
}
```

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Thông báo lỗi kinh điển khi bị đụng độ (Collision):**
   ```text
   Acquiring state lock. This may take a few moments...
   Error: Error acquiring the state lock: ConditionalCheckFailedException
   Lock Info:
     ID:        e37d5cb1-2034-7a31-9f93-c3c2b8109312
     Path:      dev/terraform.tfstate
     Who:       stark@stark-laptop
   ```
2. **Thảm họa "Khóa Ma" (Zombie Lock):**  
   Khi kỹ sư đang chạy apply thì mất điện, đứt mạng hoặc tiến trình CI/CD bị Cancel đột ngột: Terraform chưa kịp gửi lệnh `DeleteItem` để mở khóa. Cả công ty sẽ bị chặn đứng không thể deploy.
3. **Lệnh giải cứu khẩn cấp:**
   ```bash
   terraform force-unlock <LOCK_ID>
   ```
   *Cảnh báo an toàn:* Chỉ chạy lệnh này sau khi đã xác nhận 100% với người có tên trong trường `Who` rằng tiến trình của họ đã thực sự chết, không còn chạy ngầm!

---

## 🛡️ 3. TIÊU CHUẨN BẢO MẬT BẮT BUỘC CHO S3 STATE BUCKET (ZERO-TRUST COMPLIANCE)

S3 Bucket chứa State là **tài nguyên nhạy cảm số 1** trong toàn bộ tài khoản AWS của doanh nghiệp. Để đạt chuẩn PCI-DSS, ISO 27001 và SOC2, bucket này bắt buộc phải có **4 lớp bảo vệ**:

| Lớp bảo mật | Cấu hình Terraform | Rủi ro nếu thiếu |
| :--- | :--- | :--- |
| **1. S3 Versioning** | `aws_s3_bucket_versioning` (`status = "Enabled"`) | Nếu một lệnh apply sai làm hỏng file state, bạn **mất trắng**. Khi có versioning, bạn quay xe lại phiên bản trước trong 1 cú click chuột. |
| **2. Server-Side Encryption (SSE)** | `sse_algorithm = "AES256"` (hoặc KMS Key riêng) | Tránh rò rỉ dữ liệu nhạy cảm (DB password, Private Key) khi lưu trữ ở tầng đĩa cứng vật lý của AWS datacenter. |
| **3. Block Public Access (100%)** | `aws_s3_bucket_public_access_block` (Cả 4 cờ `true`) | Ngăn chặn bất kỳ ai vô tình biến bucket này thành public, làm lộ toàn bộ bí mật công ty ra Internet. |
| **4. Enforce TLS/HTTPS (SSL Only)** | S3 Bucket Policy từ chối request `aws:SecureTransport = false` | Chặn đứng các cuộc tấn công nghe lén (Man-in-the-Middle) trên đường truyền mạng khi kỹ sư kéo state về máy. |

---

## ⚖️ 4. CUỘC TRANH LUẬN LỚN: TERRAFORM WORKSPACES VS DIRECTORY-BASED?

Đây là câu hỏi phỏng vấn phân loại kỹ sư Junior và Senior cực kỳ phổ biến:

> *"Khi nào nên dùng Terraform Workspace? Tại sao không nên dùng Workspace để chia môi trường Dev và Production?"*

### So sánh chi tiết:

```
[ CÁCH 1: WORKSPACES (Chung 1 thư mục code) ]
└── main.tf ──> terraform workspace select dev (State: env:/dev/terraform.tfstate)
            ──> terraform workspace select prod (State: env:/prod/terraform.tfstate)

[ CÁCH 2: DIRECTORY-BASED (Khuyên dùng cho Enterprise) ]
├── environments/dev/  ──> Backend S3 Key: dev/terraform.tfstate (AWS Account Dev)
└── environments/prod/ ──> Backend S3 Key: prod/terraform.tfstate (AWS Account Prod)
```

| Tiêu chí | Dùng Thư mục riêng (`environments/dev` & `prod`) | Dùng Workspace (`terraform workspace`) |
| :--- | :--- | :--- |
| **Bán kính nổ (Blast Radius)** | **Tối thiểu:** Dev và Prod tách biệt vật lý. Sửa ở Dev không bao giờ chạm được vào Prod. | **Cực lớn:** Chỉ cần quên chưa chuyển workspace (`workspace select`), bạn gõ `destroy` là xóa sạch Prod! |
| **Phân quyền bảo mật (IAM)** | **Dễ dàng & Tuyệt đối:** Dev chỉ có quyền vào thư mục/account Dev. CI/CD quản lý Prod. | **Không thể:** Cùng chung 1 cấu hình backend và quyền truy cập Cloud, ai vào được dev là vào được prod. |
| **Đa tài khoản Cloud (Multi-Account)** | Hỗ trợ hoàn hảo: Dev trỏ AWS Account A, Prod trỏ AWS Account B. | Không hỗ trợ tự nhiên, phải viết code logic phức tạp để switch role. |
| **Độ phức tạp của Code** | Code sạch, biến truyền qua `terraform.tfvars` rõ ràng. | Phải lạm dụng hàm `terraform.workspace == "prod" ? ... : ...` gây rối mã nguồn. |

👉 **KẾT LUẬN CỦA VETERAN CLOUD ENGINEER:**
* **KHÔNG DÙNG WORKSPACE** để chia các môi trường chính (`dev`, `staging`, `prod`).
* **CHỈ DÙNG WORKSPACE** cho các môi trường tạm thời chạy kiểm thử (Ephemeral Environments) sinh ra theo nhánh Git hoặc Pull Request (ví dụ: `pr-105`, `feature-auth-test` sinh ra trong AWS Dev Account và bị xóa sổ sau khi test xong).

---

## 🐔🥚 5. BÀI TOÁN "CON GÀ & QUẢ TRỨNG" (THE BOOTSTRAP PATTERN)

> [!IMPORTANT]
> **QUY TẮC BẮT BUỘC SỐ 1 (PREREQUISITE WORKFLOW):**  
> **TRƯỚC KHI TRIỂN KHAI BẤT KỲ HẠ TẦNG NÀO (VPC, EKS, RDS, Compute...)**, bước đầu tiên trong vòng đời của một dự án Cloud **BẮT BUỘC PHẢI LÀ CHẠY `bootstrap/` TRƯỚC TIÊN**.  
> Tuyệt đối không bao giờ dựng hạ tầng ứng dụng trước khi có nơi lưu trữ State tập trung và khóa phân tán. Nếu làm ngược lại, bạn sẽ bị kẹt vào bẫy Local State và phải migrate State cực kỳ rủi ro sau này.

### Bản chất bài toán:
Terraform cần S3 Bucket và DynamoDB Table để lưu State. Nhưng S3 và DynamoDB đó lại do chính ai tạo ra? 

### Quy trình chuẩn Enterprise 2 giai đoạn (Thứ tự sống còn):

```
[ BƯỚC 1: BOOTSTRAP (BẮT BUỘC ĐI ĐẦU TIÊN) ]
├── Chạy tại: `bootstrap/` với Local State
└── Tạo ra: S3 Bucket (Versioning + Encryption) & DynamoDB Lock Table
       │
       ▼
[ BƯỚC 2: TRIỂN KHAI HẠ TẦNG ỨNG DỤNG (PRODUCTION WORKLOADS) ]
├── environments/dev/   ──> backend "s3" trỏ về S3 & DynamoDB vừa tạo
├── environments/prod/  ──> backend "s3" trỏ về S3 & DynamoDB vừa tạo
└── modules/network, eks, rds...
```

1. **Giai đoạn 1 (Bootstrap - Khởi tạo nền tảng):**
   * Tạo thư mục độc lập `bootstrap/`.
   * Chạy `terraform apply` với **Local State** trên máy của Lead/Administrator **duy nhất một lần** khi bắt đầu dự án để sinh ra S3 Bucket và DynamoDB Lock Table.
   * File `.tfstate` cục bộ của thư mục `bootstrap/` sau khi tạo xong phải được lưu trữ và sao lưu an toàn (Password Manager / Kho bảo mật nội bộ), **không bao giờ xóa đi**.
2. **Giai đoạn 2 (Production Workloads - Triển khai thực tế):**
   * Sau khi Bootstrap hoàn tất và xuất ra `s3_bucket_name` cùng `dynamodb_table_name`:
   * Tất cả các môi trường (`dev`, `prod`) và các tầng hạ tầng khác mới được phép khởi tạo, cấu hình block `backend "s3"` trỏ thẳng vào S3 bucket và DynamoDB table này ngay từ ngày đầu tiên!


---

## 🛠️ RUNBOOK XỬ LÝ SỰ CỐ DÀNH CHO KỸ SƯ ON-CALL (2 AM INCIDENT RESPONSE)

### Sự cố 1: Pipeline CI/CD bị kẹt Lock ("Error acquiring state lock")
1. Mở log CI/CD, copy chuỗi `Lock ID` (dạng UUID: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
2. Xác nhận với team xem có ai đang chạy apply song song không.
3. Chạy lệnh mở khóa cưỡng bức:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

### Sự cố 2: File State bị lỗi cú pháp JSON do chỉnh sửa thủ công
1. **Tuyệt đối không sửa trực tiếp file state:**
2. Truy cập vào **S3 Console** $\rightarrow$ Tìm bucket chứa state $\rightarrow$ Bật tính năng **Show Versions**.
3. Tải về phiên bản State ngay trước thời điểm xảy ra sự cố.
4. Dùng lệnh khôi phục trạng thái an toàn:
   ```bash
   terraform state push backup-state.json
   ```
