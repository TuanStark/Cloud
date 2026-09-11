# Đúc kết Kiến thức & Kinh nghiệm Thực chiến: Alerting, SLO/SLI & Alertmanager (Lab 14)

---

## 🏛️ 1. Bóc Tách 5 Trụ Cột Cốt Lõi Của Tài Liệu Thiết Kế SLO/SLI Chuẩn Google SRE

Tài liệu thiết kế SLO không phải là một file giấy tờ thủ tục, mà là **bản hiến pháp vận hành** của toàn bộ tổ chức kỹ thuật. Dưới đây là 5 trụ cột tư duy của một Senior SRE / Principal Architect:

---

### 1.1. Tại sao phải bắt đầu từ "Hành trình Người dùng Cốt lõi" (Critical User Journeys - CUJs)?
* **Thói quen sai lầm của Junior DevOps:** Cắm cảnh báo vào các chỉ số hạ tầng (CPU > 80%, RAM > 85%, Disk I/O cao). 
  * *Hậu quả:* Máy chủ CPU 95% nhưng ứng dụng vẫn xử lý giao dịch mượt mà trong 50ms ➔ Chuông reo đánh thức kỹ sư dậy là **báo động giả (False Positive)**. Ngược lại, CPU 20% nhưng Database bị deadlock khiến 100% khách hàng không thanh toán được ➔ Không có cảnh báo nào kêu!
* **Tư duy của Senior SRE (Góc nhìn Blackbox):** Khách hàng không quan tâm máy chủ chạy CPU bao nhiêu %. Khách hàng chỉ quan tâm đến **kết quả trải nghiệm**:
  1. *Họ có quẹt được thẻ không?* ➔ **Availability SLI** (Đo bằng tỷ lệ mã HTTP không phải 5xx).
  2. *Họ chờ có lâu không?* ➔ **Latency SLI** (Đo bằng phân vị P95 / P99).
* **Kết luận:** Luôn đo lường từ ngoài vào trong (User-centric Metrics) thay vì từ trong ra ngoài (Infrastructure Metrics).

---

### 1.2. Vùng đệm An toàn: Phân cấp SLA vs SLO vs SLI
Mối quan hệ giữa 3 khái niệm này tạo nên lá chắn tài chính cho doanh nghiệp:

```
[ Khách hàng / Đối tác ] 
          ▲
          │ (Hợp đồng pháp lý SLA: 99.5% - Nếu tụt dưới mốc này sẽ bị phạt tiền)
          ▼
   ┌─────────────────────────────────────────────────────────────┐
   │ 🛡️ VÙNG ĐỆM AN TOÀN (SAFETY MARGIN): 0.4% = 172.8 PHÚT       │
   │    Khoảng cách cứu sinh giúp đội kỹ thuật sửa lỗi trước     │
   │    khi khách hàng kịp nhận ra hoặc phạt hợp đồng!           │
   └─────────────────────────────────────────────────────────────┘
          ▲
          │ (Mục tiêu Kỹ thuật Nội bộ SLO: 99.9%)
          ▼
[ Đội ngũ SRE & Lập trình viên ] ──(Đo đạc thực tế)──> SLI: Good Events / Total Events
```

* **SLA (Service Level Agreement - Cam kết Pháp lý):**
  * Là cam kết giữa công ty và khách hàng/đối tác. Vi phạm SLA đồng nghĩa với việc **đền bù tiền mặt hoặc giảm trừ phí dịch vụ**.
  * *Ví dụ:* Cổng thanh toán cam kết uptime **99.5%** mỗi tháng.
* **SLO (Service Level Objective - Mục tiêu Nội bộ):**
  * Là mục tiêu nội bộ khắt khe hơn do chính đội ngũ kỹ thuật tự đặt ra.
  * **Quy tắc vàng:** SLO luôn phải **cao hơn SLA ít nhất một bậc** (ví dụ SLA 99.5% ➔ SLO nội bộ phải là **99.9%**).
* **Vùng đệm An toàn (Safety Margin = SLO - SLA = 0.4%):**
  * Trong 1 tháng (43,200 phút), 0.4% tương đương với **172.8 phút dự phòng**.
  * Nếu hệ thống gặp sự cố kéo dài 30 phút, SLO nội bộ đã báo động đỏ để toàn bộ kỹ sư vào xử lý khẩn cấp, nhưng hệ thống vẫn nằm an toàn trên ngưỡng SLA của khách hàng, công ty **không bị mất một đồng tiền phạt nào**!
* **SLI (Service Level Indicator - Thước đo Thực tế):**
  * Là chỉ số thực tế đo được bằng PromQL theo thời gian thực:
    $$\text{SLI} = \frac{\text{Số sự kiện tốt (Good Events)}}{\text{Tổng số sự kiện hợp lệ (Valid Events)}} \times 100\%$$

---

### 1.3. Bản chất Kinh tế & Đổi mới của "Ngân sách Lỗi" (Error Budget)
* **Chân lý SRE:** Độ tin cậy 100% là một mục tiêu sai lầm và phản kinh tế! Để nâng hệ thống từ 99.9% lên 100%, chi phí hạ tầng và nhân sự sẽ tăng gấp 10 lần, nhưng người dùng bình thường trên mạng 4G/Wifi chập chờn sẽ không thể nhận ra sự khác biệt.
* **Công thức Ngân sách Lỗi:**
  $$\text{Error Budget} = 100\% - \text{SLO} = 100\% - 99.9\% = \mathbf{0.1\%}$$
* **Ý nghĩa toán học:** Trong chu kỳ 30 ngày ($30 \times 24 \times 60 = 43,200$ phút):
  $$\text{Thời gian gián đoạn tối đa cho phép} = 43,200 \times 0.1\% = \mathbf{43.2\text{ phút/tháng}}$$
* **Ý nghĩa vận hành:** Error Budget là **"Đồng tiền chung"** để giải quyết mâu thuẫn muôn thuở:
  * Đội Product / Dev: Luôn muốn release tính năng mới thật nhanh để cạnh tranh thị trường.
  * Đội SRE / Ops: Luôn muốn giữ hệ thống ổn định, sợ thay đổi sinh ra lỗi.
  * ➔ **Giải pháp:** Error Budget chính là "giấy phép rủi ro". Khi ngân sách lỗi còn dồi dào, đội Dev được toàn quyền release và thử nghiệm công nghệ mới!

---

### 1.4. Chính sách Đóng băng Release (Feature Freeze Policy)
Khi Error Budget bị tiêu thụ hết (chạm mốc 0%), chính sách này lập tức có hiệu lực tự động:
1. **Dừng toàn bộ:** Đóng băng toàn bộ việc release tính năng nghiệp vụ mới trong Sprint kế tiếp.
2. **Dồn 100% nhân lực:** Toàn bộ kỹ sư chuyển sang công tác **Reliability Engineering**:
   * Tối ưu hóa câu truy vấn Database chậm.
   * Xử lý rò rỉ bộ nhớ (Memory Leaks), vá các lỗi bảo mật.
   * Viết thêm Integration Test tự động và gia cố khả năng chịu tải.
3. **Mục đích:** Ngăn chặn việc các lập trình viên tiếp tục "đổ thêm dầu vào lửa" khi hệ thống đang kiệt quệ, bảo vệ công ty không bị trượt chân xuống dưới ngưỡng SLA.

---

### 1.5. Bản chất Toán học của Burn Rate & Multi-Window Alerting
* **Tại sao cảnh báo theo ngưỡng tĩnh (Static Threshold) lại thất bại hoàn toàn?**
  * *Tình huống 1 (Đêm 3h sáng):* Lưu lượng thấp, chỉ có 10 request/phút. 1 request bị lỗi timeout ➔ Tỷ lệ lỗi vọt lên **10%**! Cảnh báo ngưỡng tĩnh nổ chuông, đánh thức kỹ sư dậy lúc nửa đêm, nhưng thực tế chỉ có 1 khách hàng bị ảnh hưởng nhẹ.
  * *Tình huống 2 (Giờ Flash Sale):* Lưu lượng 50,000 request/giây. Tỷ lệ lỗi là **0.8%** (chưa chạm ngưỡng cảnh báo 1% tĩnh) ➔ Hệ thống im lặng, nhưng thực tế có tới **400 khách hàng bị mất tiền mỗi giây**!
* **Google SRE giải quyết bằng: Cảnh báo theo Tốc độ Đốt (Burn Rate Alerting)**:
  $$\text{Burn Rate} = \frac{\text{Tỷ lệ lỗi thực tế}}{\text{Tỷ lệ lỗi cho phép của SLO (0.1\%)}}$$
  * **Burn Rate = 1:** Đốt ngân sách lỗi với tốc độ bình thường, vừa khít 30 ngày mới hết ➔ Hệ thống ổn định, không làm phiền ai.
  * **Burn Rate = 6:** Đốt hết sạch ngân sách tháng chỉ sau **5 ngày** ➔ Bắn cảnh báo Warning P2 vào kênh chat ban ngày.
  * **Burn Rate = 14.4 (Emergency):** Đốt sạch **2% ngân sách của cả tháng chỉ trong 1 giờ**! Nếu không dập tắt ngay, toàn bộ ngân sách 30 ngày sẽ cháy sạch trong vòng 2 ngày ➔ **Kích hoạt Báo động Đỏ P1 đánh thức On-Call Engineer ngay lập tức!**

---

## 🎯 2. 3 Quy tắc Vàng về Cảnh báo của Google SRE (Golden Rules of Alerting)

Để triệt tiêu hội chứng kiệt sức vì cảnh báo (**Alert Fatigue**):

1. **Mọi cảnh báo réo chuông (Page) đều phải CẦN HÀNH ĐỘNG CỦA CON NGƯỜI (Actionable)**:
   * Nếu nhận một cảnh báo mà kỹ sư chỉ nhìn rồi tặc lưỡi bỏ qua ➔ Đó là **Cảnh báo rác (Noise)**, phải xóa bỏ ngay!
2. **Nếu một sự cố có thể giải quyết bằng kịch bản lập trình ➔ HÃY TỰ ĐỘNG HÓA NÓ**:
   * Nếu giải pháp là "Restart Pod", hãy để Kubernetes Liveness Probe hoặc Self-Healing tự khởi động lại. Tuyệt đối không đánh thức con người dậy lúc 2h sáng chỉ để gõ lệnh `kubectl restart`!
3. **Chỉ gọi điện (Page) cho các sự cố KHẨN CẤP VÀ TỨC THÌ**:
   * Nếu sự cố có thể đợi đến 9h sáng hôm sau mà không ảnh hưởng tới khách hàng ➔ Hãy gửi vào kênh Chat hoặc tạo Jira Ticket, không bao giờ réo PagerDuty!

---

## ⚙️ 3. Phân biệt Bộ Ba Tham số Gom Nhóm trong Alertmanager

| Tham số | Ý nghĩa kỹ thuật | Khuyên dùng trong Production |
| :--- | :--- | :--- |
| **`group_wait`** | Thời gian tạm giữ các cảnh báo đầu tiên để chờ gom thêm các cảnh báo xảy ra cùng lúc. | `10s – 30s` (Đủ nhanh để cấp cứu nhưng không gửi tin nhắn lẻ tẻ). |
| **`group_interval`** | Khoảng thời gian chờ trước khi gửi bản tin cập nhật nếu có thêm alert mới gia nhập vào nhóm đã gửi. | `1m – 5m` |
| **`repeat_interval`** | Chu kỳ nhắc lại nếu sự cố vẫn tiếp diễn chưa được dập tắt. | `1h – 4h` (Tránh làm cháy máy điện thoại của kỹ sư khi đang tập trung gõ code sửa lỗi). |

---

## 🔇 4. Nguyên lý Ức chế Cảnh báo (Inhibition Rules)

Khi sự cố ở tầng gốc xảy ra (ví dụ: máy chủ thanh toán bị sập hoàn toàn `PaymentVaultDown`), hàng loạt cảnh báo thứ cấp bên trên (như `High5xxErrorRate`, `P95LatencyBreached`) sẽ đồng loạt gào thét.

* **Inhibition Rule** thiết lập mối quan hệ Cha - Con:
  ```yaml
  inhibit_rules:
    - source_match:
        alertname: 'PaymentVaultDown'   # Cảnh báo Cha (Gốc)
        severity: 'critical'
      target_match:
        alertname: 'High5xxErrorRate'   # Cảnh báo Con (Ăn theo)
      equal: ['service']
  ```
* **Kết quả:** Kỹ sư chỉ nhận được 1 thông báo duy nhất: *"Dịch vụ Payment Vault bị sập!"*. Toàn bộ các cảnh báo con bị tắt tiếng, giúp đội ngũ tập trung dập đám cháy gốc thay vì bị phân tâm bởi các đám khói phụ.

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

### Q3: "Tại sao Prometheus Rule bắt buộc phải có trường `runbook_url` trong phần annotations?"
> **Trả lời:** "Trong môi trường Production, sự cố thường xảy ra vào đêm muộn (2h - 4h sáng). Một kỹ sư trực on-call khi bị đánh thức bất thình lình sẽ ở trạng thái căng thẳng và phản xạ chậm. Trường `runbook_url` dẫn thẳng tới tài liệu hướng dẫn từng bước (Step-by-step Standard Operating Procedure):
> * Mô tả ngắn gọn nguyên nhân sự cố là gì.
> * Các câu lệnh chẩn đoán nhanh (CLI/Logs).
> * Hướng dẫn khắc phục tức thời (Rollback, Scale up, Restart pod).
> Điều này giúp giảm thiểu thời gian trung bình để phục hồi hệ thống (MTTR - Mean Time to Recover) từ hàng chục phút xuống chỉ còn vài phút."
