/**
 * ============================================================================
 * CIRCUIT BREAKER PATTERN (BỘ NGẮT MẠCH & BẢO VỆ FAST-FAIL)
 * Battleground 01: SRE Hardening & Resilience Defense Layer
 * ============================================================================
 * Finite State Machine chuẩn Enterprise:
 * 1. CLOSED: Mọi request được lưu thông bình thường. Đếm lỗi trong rolling window.
 * 2. OPEN: Khi tỉ lệ lỗi hoặc số lần lỗi liên tiếp vượt ngưỡng:
 *    - Ngắt mạch ngay lập tức.
 *    - TẤT CẢ các request tiếp theo lập tức Fail-Fast (< 1ms) với HTTP 503
 *      hoặc kích hoạt Fallback / Graceful Degradation.
 *    - Không cho phép request treo chờ timeout làm cạn kiệt Connection Pool.
 * 3. HALF-OPEN: Sau thời gian Cooldown, cho phép 1-2 request thăm dò (Canary).
 *    - Nếu thành công -> Tự động ĐÓNG mạch (CLOSED).
 *    - Nếu thất bại -> Lập tức MỞ mạch lại (OPEN).
 */

const STATES = {
  CLOSED: 'CLOSED',
  OPEN: 'OPEN',
  HALF_OPEN: 'HALF_OPEN',
};

class CircuitBreaker {
  constructor(name, options = {}) {
    this.name = name;
    this.failureThreshold = options.failureThreshold || 5;       // Số lỗi liên tiếp để ngắt
    this.cooldownPeriodMs = options.cooldownPeriodMs || 8000;     // Thời gian mở mạch trước khi thử lại (8s)
    this.halfOpenSuccessThreshold = options.halfOpenSuccessThreshold || 2; // Số canary thành công để đóng lại

    this.state = STATES.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.lastStateChangeTime = Date.now();
    this.totalTrippedCount = 0;
  }

  /**
   * Thực thi function fn thông qua Circuit Breaker
   * @param {Function} action - Async function cần bảo vệ
   * @param {Function} fallback - Async function dự phòng khi mạch mở (tùy chọn)
   */
  async execute(action, fallback = null) {
    const now = Date.now();

    // 1. Kiểm tra trạng thái OPEN -> kiểm tra xem đã hết thời gian Cooldown chưa
    if (this.state === STATES.OPEN) {
      if (now - this.lastStateChangeTime > this.cooldownPeriodMs) {
        this.transitionTo(STATES.HALF_OPEN);
      } else {
        // Mạch đang mở -> Fail-Fast ngay lập tức
        if (fallback) {
          return await fallback(new Error(`Circuit Breaker [${this.name}] is OPEN (Fast-Fail)`));
        }
        const err = new Error(`Circuit Breaker [${this.name}] is OPEN. Hệ thống đang bảo vệ và cách ly lỗi.`);
        err.code = 'CIRCUIT_BREAKER_OPEN';
        err.statusCode = 503;
        throw err;
      }
    }

    // 2. Thực thi action
    try {
      const result = await action();
      this.onSuccess();
      return result;
    } catch (err) {
      this.onFailure(err);
      if (fallback) {
        return await fallback(err);
      }
      throw err;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    if (this.state === STATES.HALF_OPEN) {
      this.successCount++;
      if (this.successCount >= this.halfOpenSuccessThreshold) {
        this.transitionTo(STATES.CLOSED);
      }
    }
  }

  onFailure(err) {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.state === STATES.HALF_OPEN) {
      // Trong trạng thái thăm dò mà lỗi -> Mở mạch ngay lập tức
      this.transitionTo(STATES.OPEN);
    } else if (this.state === STATES.CLOSED && this.failureCount >= this.failureThreshold) {
      // Vượt quá ngưỡng lỗi -> Ngắt mạch
      this.transitionTo(STATES.OPEN);
    }
  }

  transitionTo(newState) {
    const oldState = this.state;
    this.state = newState;
    this.lastStateChangeTime = Date.now();

    if (newState === STATES.OPEN) {
      this.totalTrippedCount++;
      console.warn(`⚡ [CircuitBreaker:${this.name}] TRIP TO OPEN! Cách ly phụ thuộc để bảo vệ hệ thống.`);
    } else if (newState === STATES.CLOSED) {
      this.successCount = 0;
      this.failureCount = 0;
      console.log(`✅ [CircuitBreaker:${this.name}] RESTORED TO CLOSED! Dịch vụ đã phục hồi hoàn toàn.`);
    } else if (newState === STATES.HALF_OPEN) {
      this.successCount = 0;
      console.log(`🔍 [CircuitBreaker:${this.name}] ENTER HALF_OPEN. Đang gửi request thăm dò (Canary)...`);
    }
  }

  getMetrics() {
    return {
      name: this.name,
      state: this.state,
      failureCount: this.failureCount,
      consecutiveSuccesses: this.successCount,
      totalTrippedCount: this.totalTrippedCount,
      lastStateChange: new Date(this.lastStateChangeTime).toISOString(),
    };
  }
}

module.exports = {
  CircuitBreaker,
  STATES,
};
