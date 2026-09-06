// app/frontend/app.js

// Tự động nhận diện host: nếu chạy cùng container thì trỏ về chính nó, nếu tách riêng thì cổng 5000
const API_BASE_URL = window.location.port === '5000' 
  ? window.location.origin 
  : `http://${window.location.hostname}:5000`;

document.addEventListener('DOMContentLoaded', () => {
  fetchSecurityStatus();
  fetchOrders();

  // Đăng ký sự kiện submit form tạo đơn hàng
  const orderForm = document.getElementById('order-form');
  orderForm.addEventListener('submit', handleCreateOrder);

  // Đăng ký nút làm mới
  const btnRefresh = document.getElementById('btn-refresh');
  btnRefresh.addEventListener('click', () => {
    fetchSecurityStatus();
    fetchOrders();
  });
});

// 1. Gọi API lấy thông tin Security Context từ Container Runtime
async function fetchSecurityStatus() {
  const statusEl = document.getElementById('connection-status');
  const panelEl = document.getElementById('security-panel');
  const badgeEl = document.getElementById('security-badge');
  const alertBox = document.getElementById('security-alert-box');
  const messageEl = document.getElementById('security-message');

  try {
    const res = await fetch(`${API_BASE_URL}/api/security`);
    if (!res.ok) throw new Error('Không thể kết nối Backend');

    const data = await res.json();
    const sec = data.runtime_security;
    const sys = data.system_metrics;

    // Cập nhật các chỉ số
    document.getElementById('sec-uid').textContent = sec.uid;
    document.getElementById('sec-gid').textContent = sec.gid;
    document.getElementById('sec-user').textContent = sec.username;
    document.getElementById('sec-hostname').textContent = sys.hostname;
    document.getElementById('sec-memory').textContent = `${sys.memory_rss_mb} MB`;

    statusEl.textContent = `Đã kết nối (${sys.hostname})`;
    messageEl.textContent = sec.message;

    // Thay đổi màu sắc giao diện theo mức độ an ninh: ROOT (Đỏ) vs NON-ROOT (Xanh lá)
    if (sec.is_root) {
      panelEl.className = 'card security-card danger';
      badgeEl.className = 'badge badge-danger';
      badgeEl.textContent = 'CRITICAL: ROOT (UID 0)';
      alertBox.className = 'security-alert';
    } else {
      panelEl.className = 'card security-card secure';
      badgeEl.className = 'badge badge-success';
      badgeEl.textContent = `SECURE: NON-ROOT (UID ${sec.uid})`;
      alertBox.className = 'security-alert secure';
    }
  } catch (err) {
    statusEl.textContent = 'Mất kết nối Backend';
    messageEl.textContent = `Lỗi kết nối tới ${API_BASE_URL}: Hãy chắc chắn Backend API đang chạy!`;
  }
}

// 2. Lấy danh sách đơn hàng
async function fetchOrders() {
  const orderList = document.getElementById('order-list');
  const orderCount = document.getElementById('order-count');

  try {
    const res = await fetch(`${API_BASE_URL}/api/orders`);
    if (!res.ok) throw new Error('Failed to load orders');

    const result = await res.json();
    const orders = result.data;

    orderCount.textContent = orders.length;

    if (orders.length === 0) {
      orderList.innerHTML = '<tr><td colspan="5" class="text-center">Chưa có đơn hàng nào</td></tr>';
      return;
    }

    orderList.innerHTML = orders.map(order => `
      <tr>
        <td class="mono"><strong>${order.id}</strong></td>
        <td>${order.customer}</td>
        <td>${order.item}</td>
        <td class="mono">$${order.amount.toFixed(2)}</td>
        <td><span class="badge ${order.status === 'COMPLETED' ? 'badge-success' : 'badge-warning'}">${order.status}</span></td>
      </tr>
    `).join('');
  } catch (err) {
    orderList.innerHTML = '<tr><td colspan="5" class="text-center text-danger">Không tải được danh sách đơn hàng</td></tr>';
  }
}

// 3. Xử lý tạo đơn hàng
async function handleCreateOrder(e) {
  e.preventDefault();
  const customerInput = document.getElementById('customer');
  const itemInput = document.getElementById('item');
  const amountInput = document.getElementById('amount');
  const btnSubmit = document.getElementById('btn-submit');

  const payload = {
    customer: customerInput.value.trim(),
    item: itemInput.value.trim(),
    amount: amountInput.value
  };

  btnSubmit.disabled = true;
  btnSubmit.textContent = 'Đang xử lý...';

  try {
    const res = await fetch(`${API_BASE_URL}/api/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) throw new Error('Tạo đơn thất bại');

    // Reset form & reload danh sách
    customerInput.value = '';
    itemInput.value = '';
    amountInput.value = '';
    await fetchOrders();
  } catch (err) {
    alert('Có lỗi khi tạo đơn hàng. Vui lòng kiểm tra backend.');
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.textContent = '+ Tạo Đơn Hàng';
  }
}
