# Đúc kết Kiến thức & Kinh nghiệm Thực chiến: Alerting, SLO/SLI & Alertmanager (Lab 14)

---

## 🎯 1. 3 Quy tắc Vàng về Cảnh báo của Google SRE (Golden Rules of Alerting)

Để triệt tiêu hội chứng kiệt sức vì cảnh báo (**Alert Fatigue**):

1. **Mọi cảnh báo réo chuông (Page) đều phải CẦN HÀNH ĐỘNG CỦA CON NGƯỜI (Actionable)**:
   * Nếu nhận một cảnh báo mà kỹ sư chỉ nhìn rồi tặc lưỡi bỏ qua ➔ Đó là **Cảnh báo rác (Noise)**, phải xóa bỏ ngay!
2. **Nếu một sự cố có thể giải quyết bằng kịch bản lập trình ➔ HÃY TỰ ĐỘNG HÓA NÓ**:
   * Nếu giải pháp là "Restart Pod", hãy để Kubernetes Liveness Probe hoặc Self-Healing tự khởi động lại. Tuyệt đối không đánh thức con người dậy lúc 2h sáng chỉ để gõ lệnh `kubectl restart`!
3. **Chỉ gọi điện (Page) cho các sự cố KHẨN CẤP VÀ TỨC THÌ**:
   * Nếu sự cố có thể đợi đến 9h sáng hôm sau mà không ảnh hưởng tới khách hàng ➔ Hãy gửi vào kênh Chat hoặc tạo Jira Ticket, không bao giờ réo PagerDuty!

---

## 🧮 2. Bản chất Toán học của Burn Rate trong SRE

### Tại sao cảnh báo theo ngưỡng tĩnh (Static Thresholds) lại thất bại?
* Giả sử em đặt cảnh báo: *"Nếu Error Rate > 1% trong 5 phút ➔ Báo động P1"*.
  * Nếu lúc đó là 3h sáng, lưu lượng chỉ có 10 request/phút, 1 request lỗi ➔ Error rate là 10%! Cảnh báo nổ tung, đánh thức kỹ sư dậy, nhưng thực tế chỉ có 1 khách hàng bị lỗi nhẹ.
* Ngược lại, vào giờ cao điểm Flash Sale với 50,000 request/giây, lỗi 0.5% (chưa chạm ngưỡng 1%) nhưng làm hàng nghìn khách hàng mất tiền ➔ Cảnh báo lại im lìm!

### Google SRE giải quyết bằng: Multi-Window Multi-Burn-Rate Alerting
Cảnh báo dựa trên **tốc độ đốt ngân sách lỗi (Burn Rate)**:
$$\text{Burn Rate} = \frac{\text{Tỷ lệ lỗi thực tế}}{\text{Ngân sách lỗi cho phép (ví dụ 0.1\%) ví dụ}}$$

* **14.4x Burn Rate trong 1 giờ:** Đốt sạch $2\%$ ngân sách của cả tháng chỉ trong 60 phút ➔ **Báo động Đỏ P1 ngay lập tức!**
* **6x Burn Rate trong 6 giờ:** Đốt sạch $5\%$ ngân sách sau 6 tiếng ➔ **Báo động Vàng P2 vào kênh chat.**

---

## ⚙️ 3. Phân biệt Bộ Ba Tham số Gom Nhóm trong Alertmanager

| Tham số | Ý nghĩa kỹ thuật | Khuyên dùng trong Production |
| :--- | :--- | :--- |
| **`group_wait`** | Thời gian tạm giữ các cảnh báo đầu tiên để chờ gom thêm các cảnh báo xảy ra cùng lúc. | `10s – 30s` (Đủ nhanh để cấp cứu nhưng không gửi tin nhắn lẻ tẻ). |
| **`group_interval`** | Khoảng thời gian chờ trước khi gửi bản tin cập nhật nếu có thêm alert mới gia nhập vào nhóm đã gửi. | `1m – 5m` |
| **`repeat_interval`** | Chu kỳ nhắc lại nếu sự cố vẫn tiếp diễn chưa được dập tắt. | `1h – 4h` (Tránh làm cháy máy điện thoại của kỹ sư khi đang tập trung gõ code sửa lỗi). |

---

## 🔇 4. Nguyên lý Ức chế Cảnh báo (Inhibition Rules)

Khi sự cố ở tầng gốc xảy ra (ví dụ: mất điện cả Data Center hoặc Node EKS chết), hàng trăm dịch vụ con bên trên sẽ đồng loạt gào thét.

* **Inhibition Rule** thiết lập mối quan hệ Cha - Con:
  ```yaml
  inhibit_rules:
    - source_match:
        alertname: 'NodeDown'       # Cảnh báo Cha
      target_match:
        alertname: 'PodDown'        # Cảnh báo Con
      equal: ['node']
  ```
* **Kết quả:** Kỹ sư chỉ nhận được 1 thông báo duy nhất: *"Node EC2 đang chết!"*. Hàng chục cảnh báo Pod con bị tắt tiếng, giúp đội ngũ tập trung cứu node thay vì đi điều tra từng pod.

---

## ❓ 5. Bộ câu hỏi Phỏng vấn Senior SRE / DevOps Q&A

### Q1: "Làm thế nào bạn ngăn chặn hiện tượng Alert Fatigue trong đội ngũ vận hành?"
> **Trả lời:** "Chúng tôi áp dụng 4 nguyên tắc SRE chuẩn Google:
> 1. **Chuyển dịch sang SLO-based Alerting:** Cảnh báo dựa trên trải nghiệm khách hàng (Availability, Latency) và tốc độ đốt ngân sách (Burn Rate), loại bỏ các cảnh báo tĩnh vô nghĩa như CPU > 80%.
> 2. **Sử dụng bộ lọc thời gian trễ (`for: 1m-5m`):** Trong Prometheus rules để loại bỏ 95% nhiễu do mạng giật ngắn hạn.
> 3. **Tận dụng tối đa Alertmanager Grouping & Inhibition:** Gom các alert cùng service thành 1 bản tin và ức chế các cảnh báo con khi dịch vụ cha bị sập.
> 4. **Văn hóa Alert Hygiene:** Định kỳ hàng tháng rà soát các alert bị mute hoặc không có hành động để xóa bỏ hoặc nâng ngưỡng."

### Q2: "Nếu Error Budget của dịch vụ thanh toán bị tiêu thụ hết 100% trong 15 ngày đầu tháng, bạn sẽ làm gì với tư cách là Lead SRE?"
> **Trả lời:** "Theo chính sách **Error Budget Policy** đã thống nhất với Ban Giám đốc và đội Product:
> 1. Chúng tôi sẽ lập tức kích hoạt trạng thái **Feature Freeze (Đóng băng phát hành tính năng)**.
> 2. Mọi pull request phát triển tính năng mới cho dịch vụ thanh toán sẽ bị hoãn lại cho tới tháng tiếp theo.
> 3. 100% nhân lực của đội ngũ phát triển và SRE sẽ được điều chuyển sang gia cố hạ tầng, tối ưu database query, bổ sung automated tests và xử lý các lỗi rò rỉ bộ nhớ.
> 4. Mục tiêu là phục hồi độ tin cậy của hệ thống trước khi ngân sách bước sang chu kỳ mới."
