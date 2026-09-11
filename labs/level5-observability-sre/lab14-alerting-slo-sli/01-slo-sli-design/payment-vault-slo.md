# 📋 Service Level Objectives (SLO) & Error Budget Policy
**Dịch vụ (Service):** Payment Vault Microservice (Cổng xử lý giao dịch thanh toán)  
**Phân loại hệ thống (Tier):** **Tier-1 Critical Financial Service**  
**Đội ngũ sở hữu (Owners):** SRE Team & Fintech Core Team  
**Chu kỳ đánh giá (Evaluation Window):** 30 ngày dạng cuốn chiếu (30-day Rolling Window)  
**Tài liệu tham chiếu:** Google SRE Book - Designing & Implementing SLOs  

---

## 🧭 1. Bối cảnh Nghiệp vụ & Hành trình Người dùng Cốt lõi (Critical User Journeys - CUJs)

Đối với dịch vụ thanh toán tài chính, khách hàng chỉ quan tâm đến 2 trải nghiệm cơ bản:
1. **CUJ-1: Quẹt thẻ thanh toán thành công (Successful Authorization)**: Khách hàng nhấn "Thanh toán", giao dịch không được bị lỗi máy chủ (5xx) và tiền không bị trừ oan.
2. **CUJ-2: Tốc độ phản hồi nhanh (Low Latency Checkout)**: Khách hàng không phải đứng chờ quá 2 giây tại quầy thanh toán hoặc trên ứng dụng di động.

---

## 🎯 2. Đặc tả Chi tiết Các Chỉ số Đo lường (SLI Specifications)

Theo chuẩn Google SRE, mọi SLI đều tuân theo công thức:
$$\text{SLI} = \frac{\text{Số sự kiện tốt (Good Events)}}{\text{Tổng số sự kiện hợp lệ (Valid Events)}} \times 100\%$$

### 🟢 SLI 1: Availability SLI (Tính sẵn sàng của dịch vụ)
* **Định nghĩa Good Events:** Các HTTP request trả về mã trạng thái thành công hoặc lỗi do khách hàng (mã HTTP < 500, ví dụ 200, 201, hoặc 400/404 do nhập sai mã thẻ).
* **Định nghĩa Bad Events:** Các HTTP request bị lỗi nội bộ máy chủ (mã HTTP 5xx: 500, 502, 503, 504).
* **Công thức PromQL đo lường:**
  ```promql
  sum(rate(http_requests_total{app="payment-vault", status!~"5.."}[30d]))
  /
  sum(rate(http_requests_total{app="payment-vault"}[30d])) * 100
  ```

---

### 🟡 SLI 2: Latency SLI (Độ trễ xử lý giao dịch)
* **Định nghĩa Good Events:** Các request được xử lý và trả về cho khách hàng trong thời gian $\le 200\text{ms}$ ($0.2\text{s}$).
* **Định nghĩa Bad Events:** Các request xử lý chậm chạp $> 200\text{ms}$.
* **Công thức PromQL đo lường:**
  ```promql
  sum(rate(http_request_duration_seconds_bucket{app="payment-vault", le="0.25"}[30d]))
  /
  sum(rate(http_request_duration_seconds_count{app="payment-vault"}[30d])) * 100
  ```

---

## 🧮 3. Mục tiêu Cam kết (SLO Targets) & Tính toán Ngân sách Lỗi (Error Budget)

### Bảng đối chiếu SLA (Pháp lý) vs SLO (Nội bộ):

| Cấp độ cam kết | Uptime Uỷ thác | Ngân sách Lỗi cho phép (Trong 30 ngày) | Ý nghĩa vận hành |
| :--- | :--- | :--- | :--- |
| **SLA (Cam kết với Khách hàng)** | **99.5%** | **0.5%** ($216\text{ phút lỗi/tháng}$) | Nếu tụt dưới mốc này, công ty phải đền tiền hợp đồng cho đối tác. |
| **SLO (Mục tiêu Kỹ thuật Nội bộ)** | **99.9%** | **0.1%** ($\mathbf{43.2\text{ phút lỗi/tháng}}$) | Vùng đệm an toàn nội bộ. Báo động đỏ khi vượt quá để sửa ngay. |
| **Vùng đệm An toàn (Safety Margin)** | **+0.4%** | **172.8 phút dự phòng** | Khoảng cách an toàn bảo vệ công ty không bao giờ bị phạt SLA! |

---

### Toán học Ngân sách Lỗi (Error Budget Math):
1. **Tổng thời gian trong chu kỳ 30 ngày:**
   $$30\text{ ngày} \times 24\text{ giờ} \times 60\text{ phút} = 43,200\text{ phút}$$
2. **Ngân sách lỗi của Availability (0.1%):**
   $$\text{Error Budget} = 43,200 \times 0.001 = \mathbf{43.2\text{ phút gián đoạn tối đa/tháng}}$$
3. **Ngân sách lỗi của Latency (5%):**
   * Cho phép tối đa $5\%$ tổng số giao dịch trong tháng được phép có độ trễ $> 200\text{ms}$ (dành cho các khung giờ cao điểm Black Friday/Flash Sale).

---

## 🚦 4. Chính sách Quản trị Ngân sách Lỗi (Error Budget Policy)

Ngân sách lỗi là **"Chiếc phanh an toàn"** điều hòa mối quan hệ giữa đội Lập trình (muốn release tính năng nhanh) và đội SRE (muốn hệ thống ổn định):

```
[ Error Budget còn > 50% ] ──> Tự do Release tính năng mới (Normal Velocity)
[ Error Budget còn 25% - 50% ] ──> Tăng cường kiểm thử, cần Tech Lead phê duyệt PR
[ Error Budget còn < 25% ] ──> Cảnh báo vàng: Hoãn các feature có độ rủi ro cao
[ Error Budget chạm 0% ] ──> 🛑 FEATURE FREEZE (ĐÓNG BĂNG TÍNH NĂNG TOÀN DIỆN)!
```

### Quy tắc khi chạm mốc 0% (Feature Freeze Protocol):
1. **Dừng toàn bộ:** Không release bất kỳ tính năng nghiệp vụ mới nào trong Sprint kế tiếp.
2. **Dồn 100% nhân lực:** Đội ngũ phát triển cùng SRE tập trung vào:
   * Vá lỗi rò rỉ bộ nhớ (Memory Leaks), tối ưu câu truy vấn Database.
   * Viết thêm Unit Test / Integration Test tự động.
   * Nâng cấp hạ tầng và gia cố tính chịu tải.
3. **Mở băng khi nào:** Chỉ khi chu kỳ 30 ngày trôi qua và Error Budget hồi phục lên mức an toàn ($> 50\%$).

---

## 🔥 5. Chiến lược Cảnh báo theo Tốc độ Đốt Ngân sách (Burn Rate Alerting)

Thay vì cảnh báo ngưỡng tĩnh gây kiệt sức (Alert Fatigue), Google SRE đưa ra bảng cảnh báo dựa trên **Burn Rate** (Tốc độ tiêu thụ ngân sách lỗi):

$$\text{Burn Rate} = \frac{\text{Tỷ lệ lỗi thực tế}}{\text{Tỷ lệ lỗi cho phép của SLO (0.1\%)}}$$

| Mức độ Burn Rate | Tốc độ tiêu thụ Ngân sách | Thời gian đốt sạch 100% Budget | Hành động của Hệ thống | Kênh cảnh báo |
| :--- | :--- | :--- | :--- | :--- |
| **Burn Rate = 1** | Bình thường | Đúng 30 ngày mới hết | Không làm phiền kỹ sư, chỉ ghi nhận báo cáo | Dashboard / Weekly Report |
| **Burn Rate = 6** | Cháy nhanh | Hết sạch ngân sách sau **5 ngày** | Gửi ticket thông báo cho đội trực ban ban ngày | Slack Channel `#alerts-fintech` |
| **Burn Rate = 14.4** | **Cháy cực nhanh (Emergency)** | Đốt sạch **2% ngân sách chỉ trong 1 giờ**! | 🚨 **Báo động Đỏ P1**: Đánh thức On-call Engineer ngay lập tức! | PagerDuty / Hotline tự động gọi điện |
