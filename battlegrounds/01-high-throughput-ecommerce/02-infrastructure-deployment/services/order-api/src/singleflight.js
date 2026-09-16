/**
 * ============================================================================
 * SINGLEFLIGHT PATTERN (REQUEST COALESCING / MUTEX LOCK)
 * Battleground 01: SRE Hardening & Resilience Defense Layer
 * ============================================================================
 * Mục đích: Triệt tiêu hoàn toàn hiện tượng Cache Stampede (Dogpile Effect).
 * Khi Cache Miss hoặc Key bị Expire giữa đỉnh tải 3,000 - 10,000 RPS:
 * - Thay vì cho phép hàng ngàn requests cùng lúc dồn xuống Database làm cạn kiệt
 *   Connection Pool và sập PostgreSQL,
 * - Singleflight chỉ cho phép ĐÚNG 1 QUERY duy nhất chạm vào Database.
 * - Tất cả các requests đồng thời khác đang chờ cùng một key sẽ được gom lại
 *   và chia sẻ chung kết quả của query duy nhất đó.
 */

class Singleflight {
  constructor() {
    this.inFlight = new Map();
    this.stats = {
      totalRequests: 0,
      coalescedRequests: 0, // Số request được gom (không phải truy vấn DB)
      executedQueries: 0,   // Số query thực tế gửi tới DB
    };
  }

  /**
   * Thực thi function fn theo key, nếu key đang có query in-flight thì chia sẻ kết quả
   * @param {string} key - Định danh tài nguyên (ví dụ: product_id)
   * @param {Function} fn - Async function thực hiện truy vấn Database
   * @returns {Promise<any>}
   */
  async do(key, fn) {
    this.stats.totalRequests++;

    if (this.inFlight.has(key)) {
      this.stats.coalescedRequests++;
      return this.inFlight.get(key);
    }

    this.stats.executedQueries++;

    const promise = (async () => {
      try {
        return await fn();
      } finally {
        this.inFlight.delete(key);
      }
    })();

    this.inFlight.set(key, promise);
    return promise;
  }

  getMetrics() {
    const savedPercentage = this.stats.totalRequests > 0
      ? ((this.stats.coalescedRequests / this.stats.totalRequests) * 100).toFixed(2)
      : '0.00';

    return {
      totalRequests: this.stats.totalRequests,
      executedQueries: this.stats.executedQueries,
      coalescedRequests: this.stats.coalescedRequests,
      dbLoadReductionPercentage: `${savedPercentage}%`,
      activeInFlightCount: this.inFlight.size,
    };
  }
}

module.exports = new Singleflight();
