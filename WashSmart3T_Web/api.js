// ============================================================
// WashSmart 3T — API helper dùng chung cho trang quản lý web
// Lưu token JWT + role vào localStorage, tự đính kèm Authorization.
// ============================================================

const API_BASE = 'http://localhost:5085/api';

const Auth = {
  save(token, role, fullName) {
    localStorage.setItem('ws_token', token);
    localStorage.setItem('ws_role', role || 'Customer');
    localStorage.setItem('ws_fullname', fullName || '');
  },

  getToken() { return localStorage.getItem('ws_token'); },
  getRole() { return localStorage.getItem('ws_role'); },
  getFullName() { return localStorage.getItem('ws_fullname'); },

  logout() {
    localStorage.removeItem('ws_token');
    localStorage.removeItem('ws_role');
    localStorage.removeItem('ws_fullname');
    window.location.href = 'login.html';
  },

  // Đăng nhập qua backend (dùng chung cho mọi vai trò)
  async login(phone, password) {
    const res = await fetch(`${API_BASE}/Auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || 'Đăng nhập thất bại');

    // Shipper phải đăng nhập qua API riêng
    if (data.user?.role === 'Shipper') {
      throw new Error('Tài khoản Shipper không được đăng nhập trang quản lý. Vui lòng dùng App Shipper.');
    }

    // Chỉ Admin/Staff được vào trang quản lý
    if (data.user?.role !== 'Admin' && data.user?.role !== 'Staff') {
      throw new Error('Tài khoản của bạn không có quyền truy cập trang quản lý.');
    }

    Auth.save(data.token, data.user.role, data.user.fullName);
    return data;
  },

  // Bảo vệ trang: nếu chưa đăng nhập hoặc không đủ quyền thì đá về login
  async requireAdminOrStaff() {
    const token = Auth.getToken();
    if (!token) {
      window.location.href = 'login.html';
      return null;
    }

    const savedRole = String(Auth.getRole() || '').trim().toLowerCase();
    const savedName = Auth.getFullName() || '';

    try {
      const res = await fetch(`${API_BASE}/Auth/me`, {
        headers: { 'Authorization': 'Bearer ' + token },
      });

      // Only a definite auth rejection clears the saved session.
      if (res.status === 401 || res.status === 403) {
        Auth.logout();
        return null;
      }

      // A server/network problem is not proof that the token is invalid.
      if (!res.ok) {
        if (savedRole === 'admin' || savedRole === 'staff') {
          return { role: savedRole === 'admin' ? 'Admin' : 'Staff', fullName: savedName, sessionRestored: true };
        }
        throw new Error(`Không xác thực được phiên (${res.status})`);
      }

      const me = await res.json();
      const role = String(me.role ?? me.Role ?? savedRole).trim().toLowerCase();
      const fullName = me.fullName ?? me.FullName ?? savedName;

      if (role !== 'admin' && role !== 'staff') {
        Auth.logout();
        return null;
      }

      const canonicalRole = role === 'admin' ? 'Admin' : 'Staff';
      Auth.save(token, canonicalRole, fullName);
      return { ...me, role: canonicalRole, fullName };
    } catch (e) {
      if (savedRole === 'admin' || savedRole === 'staff') {
        console.warn('Không kiểm tra lại được phiên; giữ phiên đã lưu:', e);
        return { role: savedRole === 'admin' ? 'Admin' : 'Staff', fullName: savedName, sessionRestored: true };
      }
      console.error('Không xác thực được phiên:', e);
      return null;
    }
  },
};

const Api = {
  headers() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + Auth.getToken(),
    };
  },

  async get(path) {
    const res = await fetch(API_BASE + path, { headers: Api.headers() });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || `Lỗi ${res.status}`);
    return data;
  },

  async post(path, body) {
    const res = await fetch(API_BASE + path, {
      method: 'POST',
      headers: Api.headers(),
      body: JSON.stringify(body || {}),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || `Lỗi ${res.status}`);
    return data;
  },

  async put(path, body) {
    const res = await fetch(API_BASE + path, {
      method: 'PUT',
      headers: Api.headers(),
      body: JSON.stringify(body || {}),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || `Lỗi ${res.status}`);
    return data;
  },

  // Đơn hàng
  Orders: {
    // Lấy toàn bộ đơn (Admin/Staff xem TẤT CẢ đơn kể cả Pending từ app)
    async all() {
      // Endpoint đã kiểm tra thành công trên Swagger dành cho Admin/Staff.
      return Api.get('/Orders/management');
    },

    // Dành riêng cho shipper: đơn Confirmed/Ready chưa có shipper + đơn đã giao cho shipper
    async shipperOrders() {
      return Api.get('/Orders/shipper-orders');
    },

    async updateStatus(orderId, status, note) {
      return Api.put(`/Orders/${orderId}/status`, { status, note: note || '' });
    },

    // Admin/Staff điều phối: gán shipper cho đơn
    async assignShipper(orderId, shipperId) {
      return Api.post(`/Orders/${orderId}/assign-shipper`, { shipperId });
    },

    // Admin/Staff điều phối: ghép mẻ nhiều đơn cho shipper
    async batchAssignShipper(orderIds, shipperId) {
      return Api.post('/Orders/batch-assign-shipper', { orderIds, shipperId });
    },

    // Gỡ shipper khỏi đơn (đặt ShipperId = null)
    async unassignShipper(orderId) {
      return Api.post(`/Orders/${orderId}/unassign-shipper`, {});
    },

    // Danh sách shipper đang hoạt động để điều phối
    async availableShippers() {
      // Endpoint quản lý danh sách shipper dành cho Admin/Staff.
      return Api.get('/Orders/management/shippers');
    },
  },

  // Dịch vụ
  Services: {
    async all() {
      return Api.get('/Services');
    },
    async create(payload) {
      return Api.post('/Services', payload);
    },
    async update(id, payload) {
      return Api.put(`/Services/${id}`, payload);
    },
    async updatePrice(id, payload) {
      return Api.put(`/Services/${id}/price`, payload);
    },
    async setActive(id, isActive) {
      const res = await fetch(`${API_BASE}/Services/${id}/status?isActive=${isActive}`, {
        method: 'PATCH',
        headers: Api.headers(),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.message || `Lỗi ${res.status}`);
      return data;
    },
  },

  // Cấu hình Cửa hàng & Bảng cước vận chuyển
  StoreConfig: {
    async get() {
      const token = Auth.getToken();
      const role = String(Auth.getRole() || '').trim().toLowerCase();
      if (token && role === 'admin') {
        try {
          return await Api.get('/StoreConfig/admin');
        } catch (_) {}
      }
      return Api.get('/StoreConfig');
    },
    async update(payload) {
      return Api.put('/StoreConfig', payload);
    },
    async reset() {
      return Api.post('/StoreConfig/reset', {});
    },
    async testSms(phone) {
      return Api.post('/StoreConfig/test-sms', { phone });
    },
  },

  // Quản lý Người dùng & Nhân viên & Khách hàng
  Users: {
    async all(role = '', search = '') {
      let q = [];
      if (role && role !== 'all') q.push(`role=${encodeURIComponent(role)}`);
      if (search) q.push(`search=${encodeURIComponent(search)}`);
      const qs = q.length ? '?' + q.join('&') : '';
      return Api.get(`/Users${qs}`);
    },
    async customers(search = '') {
      const qs = search ? `?search=${encodeURIComponent(search)}` : '';
      return Api.get(`/Users/customers${qs}`);
    },
    async upgradeTier(id, tier) {
      return Api.post(`/Users/customers/${id}/upgrade-tier`, { tier });
    },
    async adjustPoints(id, pointsDelta) {
      return Api.post(`/Users/customers/${id}/adjust-points`, { pointsDelta });
    },
    async searchByPhone(phone) {
      return Api.get(`/Users/search?phone=${encodeURIComponent(phone)}`);
    },
    async create(payload) {
      return Api.post('/Users', payload);
    },
    async update(id, payload) {
      return Api.put(`/Users/${id}`, payload);
    },
    async delete(id) {
      return Api.delete(`/Users/${id}`);
    },
    async resetPassword(id, newPassword = '123456') {
      return Api.post(`/Users/${id}/reset-password`, { newPassword });
    },
    async resetAllPasswords(newPassword = '123456') {
      return Api.post('/Users/reset-all-passwords', { newPassword });
    },
  },

  // Quản lý Khiếu nại & Bảo hiểm 3T
  Complaints: {
    async all(status = 'all', search = '') {
      let q = [];
      if (status && status !== 'all') q.push(`status=${encodeURIComponent(status)}`);
      if (search) q.push(`search=${encodeURIComponent(search)}`);
      const qs = q.length ? '?' + q.join('&') : '';
      return Api.get(`/Complaints${qs}`);
    },
    async get(id) {
      return Api.get(`/Complaints/${id}`);
    },
    async create(payload) {
      return Api.post('/Complaints', payload);
    },
    async resolve(id, payload) {
      return Api.put(`/Complaints/${id}/resolve`, payload);
    },
  },

  // Ưu đãi & Vouchers
  Promotions: {
    async all(category = 'all') {
      const qs = category && category !== 'all' ? `?category=${encodeURIComponent(category)}` : '';
      return Api.get(`/Promotions${qs}`);
    },
    async create(payload) {
      return Api.post('/Promotions', payload);
    },
    async verify(code, orderAmount) {
      return Api.post('/Promotions/verify', { code, orderAmount });
    },
  },
};

// Sinh mã đơn hiển thị WS3T-XXXX từ ID đơn
function orderCode(orderId) {
  return 'WS3T-' + String(orderId).padStart(4, '0');
}

// Định dạng tiền VNĐ
function formatMoney(amount) {
  return new Intl.NumberFormat('vi-VN').format(Math.round(amount)) + 'đ';
}

// Expose helpers for pages that check window.Api/window.Auth.
// Keep the existing global names available for classic-script pages.
window.Api = Api;
window.Auth = Auth;

// ============================================================
// HÀM TÁCH GHI CHÚ ĐƠN HÀNG THÀNH TỪNG PHẦN RÕ RÀNG
// ============================================================
function parseOrderNote(rawNote) {
  if (!rawNote || !rawNote.trim()) return null;
  const lines = rawNote.split('\n').map(l => l.trim()).filter(Boolean);
  const result = {
    garments: '',
    otherGarments: '',
    addons: '',
    addonFee: '',
    schedule: '',
    shipping: '',
    positionNote: '',
    userNote: '',
    voucher: '',
    estimatedTotal: '',
    extraNotes: []
  };

  for (const line of lines) {
    if (line.startsWith('Loại đồ cần giặt:')) {
      result.garments = line.replace('Loại đồ cần giặt:', '').trim();
    } else if (line.startsWith('Loại đồ khác:')) {
      result.otherGarments = line.replace('Loại đồ khác:', '').trim();
    } else if (line.startsWith('Dịch vụ & tiện ích phụ phí:')) {
      result.addons = line.replace('Dịch vụ & tiện ích phụ phí:', '').trim();
    } else if (line.startsWith('Phụ phí tiện ích dự kiến:')) {
      result.addonFee = line.replace('Phụ phí tiện ích dự kiến:', '').trim();
    } else if (line.startsWith('Lịch Shipper tới lấy:')) {
      result.schedule = line.replace('Lịch Shipper tới lấy:', '').trim();
    } else if (line.startsWith('Phí giao nhận dự kiến:') || line.startsWith('Phí giao nhận:')) {
      result.shipping = line.replace(/^Phí giao nhận( dự kiến)?:/, '').trim();
    } else if (line.startsWith('Ghi chú vị trí:')) {
      result.positionNote = line.replace('Ghi chú vị trí:', '').trim();
    } else if (line.startsWith('Ghi chú khách hàng:')) {
      result.userNote = line.replace('Ghi chú khách hàng:', '').trim();
    } else if (line.startsWith('Mã voucher khách chọn:') || line.startsWith('Voucher khách nhập:')) {
      result.voucher = line.replace(/^(Mã voucher khách chọn|Voucher khách nhập):/, '').trim();
    } else if (line.startsWith('Khách đặt tạm tính:')) {
      result.estimatedTotal = line.replace('Khách đặt tạm tính:', '').trim();
    } else if (!line.startsWith('Lưu ý:')) {
      result.extraNotes.push(line);
    }
  }
  return result;
}

function renderOrderNoteHtml(rawNote) {
  const p = parseOrderNote(rawNote);
  if (!p) {
    return '<span class="text-secondary italic">Không có ghi chú đặc biệt</span>';
  }

  let html = '<div class="space-y-2.5 text-xs">';

  if (p.garments) {
    html += `
      <div class="flex items-start gap-2 bg-pink-50/70 border border-pink-100 p-2.5 rounded-lg">
        <span class="material-symbols-outlined text-primary text-base shrink-0 mt-0.5">checkroom</span>
        <div>
          <strong class="text-on-surface text-[11px] uppercase tracking-wide text-primary">Loại đồ gửi giặt:</strong>
          <p class="font-medium text-on-surface mt-0.5">${escapeHtml(p.garments)}</p>
          ${p.otherGarments ? `<p class="text-secondary mt-0.5">Đồ khác: ${escapeHtml(p.otherGarments)}</p>` : ''}
        </div>
      </div>`;
  }

  if (p.addons) {
    html += `
      <div class="flex items-start gap-2 bg-amber-50/70 border border-amber-100 p-2.5 rounded-lg">
        <span class="material-symbols-outlined text-amber-700 text-base shrink-0 mt-0.5">auto_awesome</span>
        <div>
          <strong class="text-amber-800 text-[11px] uppercase tracking-wide">Tiện ích & Phụ phí:</strong>
          <p class="font-medium text-on-surface mt-0.5">${escapeHtml(p.addons)}</p>
        </div>
      </div>`;
  }

  if (p.schedule) {
    html += `
      <div class="flex items-start gap-2 bg-blue-50/70 border border-blue-100 p-2.5 rounded-lg">
        <span class="material-symbols-outlined text-blue-700 text-base shrink-0 mt-0.5">schedule</span>
        <div>
          <strong class="text-blue-800 text-[11px] uppercase tracking-wide">Lịch Shipper tới lấy:</strong>
          <p class="font-semibold text-blue-900 mt-0.5">${escapeHtml(p.schedule)}</p>
        </div>
      </div>`;
  }

  if (p.shipping) {
    html += `
      <div class="flex items-start gap-2 bg-emerald-50/70 border border-emerald-100 p-2.5 rounded-lg">
        <span class="material-symbols-outlined text-emerald-700 text-base shrink-0 mt-0.5">two_wheeler</span>
        <div>
          <strong class="text-emerald-800 text-[11px] uppercase tracking-wide">Cước phí giao nhận:</strong>
          <p class="font-medium text-emerald-900 mt-0.5">${escapeHtml(p.shipping)}</p>
        </div>
      </div>`;
  }

  if (p.positionNote || p.userNote) {
    html += `
      <div class="flex items-start gap-2 bg-purple-50/70 border border-purple-100 p-2.5 rounded-lg">
        <span class="material-symbols-outlined text-purple-700 text-base shrink-0 mt-0.5">chat_bubble</span>
        <div>
          <strong class="text-purple-800 text-[11px] uppercase tracking-wide">Ghi chú của khách:</strong>
          ${p.positionNote ? `<p class="text-on-surface font-medium mt-0.5">📍 Vị trí: ${escapeHtml(p.positionNote)}</p>` : ''}
          ${p.userNote ? `<p class="text-on-surface font-medium mt-0.5">💬 ${escapeHtml(p.userNote)}</p>` : ''}
        </div>
      </div>`;
  }

  if (p.extraNotes.length > 0) {
    html += `
      <div class="text-[11px] text-secondary p-2 bg-gray-50 rounded border border-gray-100">
        ${p.extraNotes.map(e => escapeHtml(e)).join('<br>')}
      </div>`;
  }

  html += '</div>';
  return html;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

window.parseOrderNote = parseOrderNote;
window.renderOrderNoteHtml = renderOrderNoteHtml;
window.escapeHtml = escapeHtml;
