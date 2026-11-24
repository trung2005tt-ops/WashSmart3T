/**
 * WashSmart 3T - VN Address Autocomplete Component
 * Tự động gợi ý & hoàn tất địa chỉ chuẩn Việt Nam theo Provinces Open API & GPS Geocoding
 * Nguồn dữ liệu:
 * 1. Provinces Open API: https://provinces.open-api.vn/api/ (Tỉnh/Thành, Quận/Huyện, Phường/Xã mới nhất 2026)
 * 2. OpenStreetMap Nominatim Vietnam (Nhận diện số nhà, tên đường, tòa nhà & tọa độ GPS thực tế)
 * 3. Bộ nhớ đệm danh mục hành chính TP.HCM & Hà Nội sẵn có cho phản hồi siêu tốc (<5ms)
 */

(function (window, document) {
  'use strict';

  // Bộ nhớ đệm toàn cục đơn vị hành chính
  const CACHE_KEY_PROVINCES = 'ws3t_vn_provinces_cache_v2';
  const CACHE_KEY_HCM_WARDS = 'ws3t_vn_hcm_wards_cache_v2';

  // Danh mục quận huyện TP.HCM & mốc GPS mặc định (phản hồi tức thì)
  const PRESET_ADMIN_LOCATIONS = [
    // Quận Tân Phú
    { name: 'Phường Tây Thạnh', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.8070, lng: 106.6287 },
    { name: 'Phường Sơn Kỳ', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.8055, lng: 106.6180 },
    { name: 'Phường Tân Sơn Nhì', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.8020, lng: 106.6320 },
    { name: 'Phường Tân Quý', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7950, lng: 106.6200 },
    { name: 'Phường Tân Thành', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7910, lng: 106.6300 },
    { name: 'Phường Phú Thọ Hòa', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7820, lng: 106.6280 },
    { name: 'Phường Phú Thạnh', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7780, lng: 106.6260 },
    { name: 'Phường Phú Trung', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7720, lng: 106.6400 },
    { name: 'Phường Hòa Thạnh', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7740, lng: 106.6320 },
    { name: 'Phường Hiệp Tân', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7680, lng: 106.6280 },
    { name: 'Phường Tân Thới Hòa', district: 'Quận Tân Phú', province: 'Thành phố Hồ Chí Minh', lat: 10.7620, lng: 106.6310 },

    // Quận 7
    { name: 'Phường Tân Quy', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7425, lng: 106.7050 },
    { name: 'Phường Tân Kiểng', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7490, lng: 106.7080 },
    { name: 'Phường Tân Hưng', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7480, lng: 106.7020 },
    { name: 'Phường Tân Thuận Đông', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7610, lng: 106.7320 },
    { name: 'Phường Tân Thuận Tây', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7550, lng: 106.7180 },
    { name: 'Phường Bình Thuận', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7460, lng: 106.7210 },
    { name: 'Phường Phú Thuận', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7320, lng: 106.7380 },
    { name: 'Phường Phú Mỹ', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7180, lng: 106.7260 },
    { name: 'Phường Tân Phú', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7310, lng: 106.7210 },
    { name: 'Phường Tân Phong', district: 'Quận 7', province: 'Thành phố Hồ Chí Minh', lat: 10.7300, lng: 106.7080 },

    // Quận 1
    { name: 'Phường Bến Nghé', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7760, lng: 106.7020 },
    { name: 'Phường Bến Thành', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7725, lng: 106.6980 },
    { name: 'Phường Đa Kao', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7890, lng: 106.6990 },
    { name: 'Phường Tân Định', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7910, lng: 106.6900 },
    { name: 'Phường Phạm Ngũ Lão', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7680, lng: 106.6920 },
    { name: 'Phường Nguyễn Cư Trinh', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7620, lng: 106.6880 },
    { name: 'Phường Nguyễn Thái Bình', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7690, lng: 106.7000 },
    { name: 'Phường Cầu Ông Lãnh', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7640, lng: 106.6980 },
    { name: 'Phường Cô Giang', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7600, lng: 106.6930 },
    { name: 'Phường Cầu Kho', district: 'Quận 1', province: 'Thành phố Hồ Chí Minh', lat: 10.7570, lng: 106.6890 },

    // Quận Tân Bình
    { name: 'Phường 2', district: 'Quận Tân Bình', province: 'Thành phố Hồ Chí Minh', lat: 10.8080, lng: 106.6660 },
    { name: 'Phường 13', district: 'Quận Tân Bình', province: 'Thành phố Hồ Chí Minh', lat: 10.8040, lng: 106.6430 },
    { name: 'Phường 15', district: 'Quận Tân Bình', province: 'Thành phố Hồ Chí Minh', lat: 10.8220, lng: 106.6340 },

    // Quận Bình Thạnh
    { name: 'Phường 22', district: 'Quận Bình Thạnh', province: 'Thành phố Hồ Chí Minh', lat: 10.7930, lng: 106.7215 },
    { name: 'Phường 25', district: 'Quận Bình Thạnh', province: 'Thành phố Hồ Chí Minh', lat: 10.8080, lng: 106.7160 },

    // TP. Thủ Đức
    { name: 'Phường Thảo Điền', district: 'Thành phố Thủ Đức', province: 'Thành phố Hồ Chí Minh', lat: 10.8020, lng: 106.7350 },
    { name: 'Phường An Phú', district: 'Thành phố Thủ Đức', province: 'Thành phố Hồ Chí Minh', lat: 10.7940, lng: 106.7450 },
    { name: 'Phường Linh Trung', district: 'Thành phố Thủ Đức', province: 'Thành phố Hồ Chí Minh', lat: 10.8650, lng: 106.7760 }
  ];

  // Danh mục các điểm mốc nổi tiếng thường xuyên giặt sấy giao nhận
  const PRESET_LANDMARKS = [
    { title: '140 Lê Trọng Tấn', subtitle: 'Trường Đại học Công Thương TP.HCM, P. Tây Thạnh, Q. Tân Phú', full: '140 Lê Trọng Tấn, Phường Tây Thạnh, Quận Tân Phú, Thành phố Hồ Chí Minh', lat: 10.8070, lng: 106.6287 },
    { title: '2 Nguyễn Sỹ Sách', subtitle: 'P. Tân Sơn (gần Chợ Tân Trụ), Q. Tân Bình, TP.HCM', full: '2 Nguyễn Sỹ Sách, Phường 15, Quận Tân Bình, Thành phố Hồ Chí Minh', lat: 10.8193, lng: 106.6346 },
    { title: '123 Nguyễn Thị Thập', subtitle: 'P. Tân Phú, Quận 7, TP.HCM (Trụ sở CS1 WashSmart 3T)', full: '123 Nguyễn Thị Thập, Phường Tân Phú, Quận 7, Thành phố Hồ Chí Minh', lat: 10.7380, lng: 106.7130 },
    { title: '150 Đường Số 79', subtitle: 'P. Tân Quy, Quận 7, TP.HCM', full: '150 Đường Số 79, Phường Tân Quy, Quận 7, Thành phố Hồ Chí Minh', lat: 10.7425, lng: 106.7050 },
    { title: 'Chợ Bến Thành', subtitle: 'Đường Lê Lợi, Phường Bến Thành, Quận 1, TP.HCM', full: 'Chợ Bến Thành, Đường Lê Lợi, Phường Bến Thành, Quận 1, Thành phố Hồ Chí Minh', lat: 10.7725, lng: 106.6980 },
    { title: 'Sunrise City', subtitle: 'Đường Nguyễn Hữu Thọ, Phường Tân Hưng, Quận 7, TP.HCM', full: 'Sunrise City, Đường Nguyễn Hữu Thọ, Phường Tân Hưng, Quận 7, Thành phố Hồ Chí Minh', lat: 10.7550, lng: 106.7010 },
    { title: 'Vinhomes Central Park', subtitle: '208 Nguyễn Hữu Cảnh, Phường 22, Quận Bình Thạnh, TP.HCM', full: '208 Nguyễn Hữu Cảnh, Phường 22, Quận Bình Thạnh, Thành phố Hồ Chí Minh', lat: 10.7930, lng: 106.7215 },
    { title: 'Aeon Mall Tân Phú Celadon', subtitle: '30 Bờ Bao Tân Thắng, Phường Sơn Kỳ, Quận Tân Phú, TP.HCM', full: '30 Bờ Bao Tân Thắng, Phường Sơn Kỳ, Quận Tân Phú, Thành phố Hồ Chí Minh', lat: 10.8010, lng: 106.6170 },
    { title: 'Chợ Tân Bình', subtitle: 'Đường Lý Thường Kiệt, Phường 8, Quận Tân Bình, TP.HCM', full: 'Chợ Tân Bình, Đường Lý Thường Kiệt, Phường 8, Quận Tân Bình, Thành phố Hồ Chí Minh', lat: 10.7895, lng: 106.6535 },
    { title: 'Lotte Mart Quận 7', subtitle: '469 Nguyễn Hữu Thọ, Phường Tân Hưng, Quận 7, TP.HCM', full: '469 Nguyễn Hữu Thọ, Phường Tân Hưng, Quận 7, Thành phố Hồ Chí Minh', lat: 10.7420, lng: 106.7010 }
  ];

  let adminDb = [...PRESET_ADMIN_LOCATIONS];
  let isDbLoaded = false;

  // Chuẩn hóa chuỗi tiếng Việt không dấu để so khớp nhanh
  function stripAccents(str) {
    if (!str) return '';
    return str
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/đ/g, 'd')
      .trim();
  }

  // Tải danh mục tỉnh thành & phường xã từ Provinces Open API ngầm (asynchronous)
  async function loadProvincesApiData() {
    if (isDbLoaded) return;
    try {
      const cached = sessionStorage.getItem(CACHE_KEY_HCM_WARDS);
      if (cached) {
        const parsed = JSON.parse(cached);
        if (Array.isArray(parsed) && parsed.length > 0) {
          adminDb = parsed;
          isDbLoaded = true;
          return;
        }
      }

      // Tải danh sách đơn vị hành chính TP.HCM (depth 3: Tỉnh -> Quận -> Phường)
      const res = await fetch('https://provinces.open-api.vn/api/p/79?depth=3');
      if (res.ok) {
        const hcm = await res.json();
        const fullList = [];
        if (hcm && Array.isArray(hcm.districts)) {
          hcm.districts.forEach(dist => {
            const dName = dist.name;
            if (Array.isArray(dist.wards)) {
              dist.wards.forEach(w => {
                fullList.push({
                  name: w.name,
                  district: dName,
                  province: 'Thành phố Hồ Chí Minh'
                });
              });
            }
          });
        }
        if (fullList.length > 0) {
          // Bổ sung các mốc GPS đã có
          fullList.forEach(item => {
            const match = PRESET_ADMIN_LOCATIONS.find(p => p.name === item.name && p.district === item.district);
            if (match) {
              item.lat = match.lat;
              item.lng = match.lng;
            }
          });
          adminDb = fullList;
          isDbLoaded = true;
          sessionStorage.setItem(CACHE_KEY_HCM_WARDS, JSON.stringify(fullList));
        }
      }
    } catch (e) {
      // Fallback về danh sách preset an toàn
      adminDb = [...PRESET_ADMIN_LOCATIONS];
    }
  }

  // Khởi động nạp dữ liệu nền
  loadProvincesApiData();

  // Tìm kiếm địa chỉ bằng OpenStreetMap Nominatim
  async function searchNominatim(query) {
    if (!query || query.length < 3) return [];
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 2000);
      const url = 'https://nominatim.openstreetmap.org/search?format=json&countrycodes=vn&addressdetails=1&limit=4&q=' + encodeURIComponent(query);
      const res = await fetch(url, {
        headers: { 'User-Agent': 'WashSmart3T/1.0' },
        signal: controller.signal
      });
      clearTimeout(timer);
      if (!res.ok) return [];
      const data = await res.json();
      return (data || []).map(item => {
        const a = item.address || {};
        const house = a.house_number || '';
        const road = a.road || a.pedestrian || a.street || '';
        const quarter = a.quarter || a.suburb || a.neighbourhood || '';
        const ward = quarter.startsWith('Phường') || quarter.startsWith('Xã') ? quarter : (a.quarter || a.suburb || '');
        const district = a.city_district || a.district || a.county || '';
        const city = a.city || a.state || 'Thành phố Hồ Chí Minh';

        // Tên hiển thị gọn gàng chuẩn Việt Nam
        let cleanName = item.display_name.split(',').slice(0, 4).join(',').trim();
        cleanName = cleanName.replace(/, Việt Nam$/, '').replace(/, [0-9]{5,6}/, '');

        return {
          title: [house, road].filter(Boolean).join(' ') || item.name || cleanName,
          subtitle: [ward, district, city].filter(Boolean).join(', ') || cleanName,
          full: cleanName,
          lat: parseFloat(item.lat),
          lng: parseFloat(item.lon),
          source: 'nominatim'
        };
      });
    } catch (_) {
      return [];
    }
  }

  // Tìm kiếm theo API Tỉnh/Thành Open API (Online Search)
  async function searchProvincesApiOnline(keyword) {
    if (!keyword || keyword.length < 2) return [];
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 1800);
      const url = 'https://provinces.open-api.vn/api/w/search/?q=' + encodeURIComponent(keyword);
      const res = await fetch(url, { signal: controller.signal });
      clearTimeout(timer);
      if (!res.ok) return [];
      const wards = await res.json();
      return (wards || []).slice(0, 3).map(w => ({
        name: w.name,
        code: w.code,
        source: 'provinces_api'
      }));
    } catch (_) {
      return [];
    }
  }

  // Bộ máy tìm kiếm tổng hợp: Local + Provinces API + Nominatim
  async function queryAddressSuggestions(rawQuery) {
    const q = (rawQuery || '').trim();
    if (q.length < 2) return [];

    const qNorm = stripAccents(q);
    const results = [];
    const seenFull = new Set();

    // 1. Phân tách tiền tố số nhà/tên đường nếu người dùng nhập dấu phẩy
    // Ví dụ: "140 Lê Trọng Tấn, Phường Tây" -> prefix="140 Lê Trọng Tấn", searchPart="Phường Tây"
    let prefix = '';
    let searchPart = q;
    if (q.includes(',')) {
      const parts = q.split(',');
      prefix = parts.slice(0, parts.length - 1).join(',').trim();
      searchPart = parts[parts.length - 1].trim();
    }
    const searchPartNorm = stripAccents(searchPart);

    // 2. Tra cứu điểm mốc nổi tiếng (Preset Landmarks)
    PRESET_LANDMARKS.forEach(lm => {
      const lmNorm = stripAccents(lm.title + ' ' + lm.subtitle + ' ' + lm.full);
      if (lmNorm.includes(qNorm) || (searchPartNorm && lmNorm.includes(searchPartNorm))) {
        if (!seenFull.has(lm.full)) {
          seenFull.add(lm.full);
          results.push({
            title: lm.title,
            subtitle: lm.subtitle,
            full: lm.full,
            lat: lm.lat,
            lng: lm.lng,
            isLandmark: true
          });
        }
      }
    });

    // 3. Tra cứu từ cơ sở dữ liệu hành chính chuẩn (Provinces DB)
    const matchedAdmin = adminDb.filter(loc => {
      const locNorm = stripAccents(`${loc.name} ${loc.district} ${loc.province}`);
      return locNorm.includes(searchPartNorm) || (qNorm.length > 3 && locNorm.includes(qNorm));
    });

    matchedAdmin.slice(0, 5).forEach(m => {
      const fullAddr = prefix
        ? `${prefix}, ${m.name}, ${m.district}, ${m.province}`
        : `${m.name}, ${m.district}, ${m.province}`;
      if (!seenFull.has(fullAddr)) {
        seenFull.add(fullAddr);
        results.push({
          title: prefix ? `${prefix}, ${m.name}` : m.name,
          subtitle: `${m.district}, ${m.province}`,
          full: fullAddr,
          lat: m.lat || null,
          lng: m.lng || null,
          isAdmin: true
        });
      }
    });

    // 4. Nếu kết quả chưa đủ 4 mục, gọi đồng thời OpenStreetMap Nominatim
    if (results.length < 5 && q.length >= 3) {
      try {
        const osmResults = await searchNominatim(q);
        osmResults.forEach(item => {
          if (!seenFull.has(item.full)) {
            seenFull.add(item.full);
            results.push(item);
          }
        });
      } catch (_) {}
    }

    return results.slice(0, 6);
  }

  // Thành phần Giao diện Dropdown Gợi ý (Floating UI)
  class VnAddressAutocompleteInput {
    constructor(inputEl, options = {}) {
      this.input = inputEl;
      this.options = Object.assign({
        onSelect: null,
        minChars: 2,
        debounceMs: 250,
        placeholderTitle: 'Gợi ý địa chỉ chuẩn Việt Nam'
      }, options);

      this.dropdown = null;
      this.items = [];
      this.activeIndex = -1;
      this.debounceTimer = null;
      this.isOpen = false;

      this.init();
    }

    init() {
      // Bọc input hoặc đặt dropdown trong relative wrapper
      const wrapper = document.createElement('div');
      wrapper.className = 'relative w-full vn-address-autocomplete-wrapper';
      this.input.parentNode.insertBefore(wrapper, this.input);
      wrapper.appendChild(this.input);

      // Tạo dropdown DOM
      this.dropdown = document.createElement('div');
      this.dropdown.className = [
        'vn-autocomplete-dropdown',
        'absolute left-0 right-0 top-full mt-1.5 z-[9999]',
        'bg-white rounded-xl shadow-2xl border border-slate-200/90',
        'overflow-hidden hidden flex-col',
        'transition-all duration-150 ease-out'
      ].join(' ');
      wrapper.appendChild(this.dropdown);

      // Lắng nghe sự kiện
      this.input.addEventListener('input', (e) => this.onInput(e));
      this.input.addEventListener('keydown', (e) => this.onKeyDown(e));
      this.input.addEventListener('focus', () => {
        if (this.input.value.trim().length >= this.options.minChars && this.items.length > 0) {
          this.showDropdown();
        }
      });

      // Đóng khi click ngoài
      document.addEventListener('click', (e) => {
        if (!wrapper.contains(e.target)) {
          this.hideDropdown();
        }
      });
    }

    onInput(e) {
      clearTimeout(this.debounceTimer);
      const val = (e.target.value || '').trim();
      if (val.length < this.options.minChars) {
        this.hideDropdown();
        return;
      }

      this.debounceTimer = setTimeout(async () => {
        this.renderLoading();
        this.showDropdown();
        try {
          const suggestions = await queryAddressSuggestions(val);
          this.items = suggestions;
          this.renderSuggestions(suggestions, val);
        } catch (_) {
          this.hideDropdown();
        }
      }, this.options.debounceMs);
    }

    onKeyDown(e) {
      if (!this.isOpen || this.items.length === 0) return;

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        this.activeIndex = (this.activeIndex + 1) % this.items.length;
        this.updateActiveItem();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        this.activeIndex = (this.activeIndex - 1 + this.items.length) % this.items.length;
        this.updateActiveItem();
      } else if (e.key === 'Enter') {
        if (this.activeIndex >= 0 && this.activeIndex < this.items.length) {
          e.preventDefault();
          this.selectItem(this.items[this.activeIndex]);
        }
      } else if (e.key === 'Escape') {
        this.hideDropdown();
      }
    }

    renderLoading() {
      this.dropdown.innerHTML = `
        <div class="px-3 py-2.5 text-xs text-slate-500 flex items-center gap-2 bg-slate-50/70 border-b border-slate-100">
          <span class="w-3.5 h-3.5 border-2 border-primary border-t-transparent rounded-full animate-spin"></span>
          <span>Đang tra cứu cơ sở dữ liệu Tỉnh/Thành Việt Nam & GPS...</span>
        </div>
      `;
    }

    renderSuggestions(suggestions, query) {
      if (!suggestions || suggestions.length === 0) {
        this.dropdown.innerHTML = `
          <div class="px-3.5 py-3 text-xs text-slate-500 text-center">
            <p class="font-medium">Không tìm thấy địa chỉ phù hợp.</p>
            <p class="text-[11px] text-slate-400 mt-0.5">Bạn có thể tiếp tục nhập số nhà, tên đường hoặc phường/quận.</p>
          </div>
        `;
        return;
      }

      let html = `
        <div class="px-3 py-1.5 bg-slate-50 border-b border-slate-100 flex items-center justify-between text-[10px] text-slate-500 font-bold uppercase tracking-wider">
          <span class="flex items-center gap-1 text-primary">
            <span class="material-symbols-outlined text-xs">pin_drop</span>
            Gợi ý địa chỉ (API Tỉnh Thành & GPS VN)
          </span>
          <span class="text-slate-400 font-normal">Bấm hoặc dùng phím ↑ ↓ để chọn</span>
        </div>
        <div class="max-h-60 overflow-y-auto divide-y divide-slate-100">
      `;

      suggestions.forEach((item, index) => {
        html += `
          <div class="autocomplete-item px-3.5 py-2.5 cursor-pointer hover:bg-primary/5 transition-colors flex items-start gap-2.5" data-index="${index}">
            <div class="w-7 h-7 rounded-lg bg-primary/10 text-primary flex items-center justify-center shrink-0 mt-0.5">
              <span class="material-symbols-outlined text-base">location_on</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-xs font-bold text-slate-800 truncate">${escapeHtml(item.title || item.full)}</p>
              <p class="text-[11px] text-slate-500 truncate mt-0.5">${escapeHtml(item.subtitle || item.full)}</p>
            </div>
            ${item.lat && item.lng ? `
              <span class="text-[10px] text-emerald-700 bg-emerald-50 border border-emerald-200 px-1.5 py-0.5 rounded font-mono shrink-0">
                GPS
              </span>
            ` : ''}
          </div>
        `;
      });

      html += '</div>';
      this.dropdown.innerHTML = html;
      this.activeIndex = -1;

      // Gắn sự kiện click
      this.dropdown.querySelectorAll('.autocomplete-item').forEach(el => {
        el.addEventListener('click', () => {
          const idx = parseInt(el.getAttribute('data-index'), 10);
          if (!isNaN(idx) && this.items[idx]) {
            this.selectItem(this.items[idx]);
          }
        });
      });
    }

    updateActiveItem() {
      const domItems = this.dropdown.querySelectorAll('.autocomplete-item');
      domItems.forEach((el, idx) => {
        if (idx === this.activeIndex) {
          el.classList.add('bg-primary/10');
          el.scrollIntoView({ block: 'nearest' });
        } else {
          el.classList.remove('bg-primary/10');
        }
      });
    }

    selectItem(item) {
      if (!item) return;
      const chosenText = item.full || item.title;
      this.input.value = chosenText;
      this.hideDropdown();

      // Kích hoạt sự kiện input & change
      this.input.dispatchEvent(new Event('input', { bubbles: true }));
      this.input.dispatchEvent(new Event('change', { bubbles: true }));

      // Gọi callback tùy biến
      if (typeof this.options.onSelect === 'function') {
        this.options.onSelect(item);
      }
    }

    showDropdown() {
      this.dropdown.classList.remove('hidden');
      this.dropdown.classList.add('flex');
      this.isOpen = true;
    }

    hideDropdown() {
      this.dropdown.classList.add('hidden');
      this.dropdown.classList.remove('flex');
      this.isOpen = false;
      this.activeIndex = -1;
    }
  }

  function escapeHtml(text) {
    if (!text) return '';
    const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    return text.toString().replace(/[&<>"']/g, m => map[m]);
  }

  // API xuất khẩu
  const VnAddressAutocomplete = {
    attach: function (elementOrSelector, options = {}) {
      const el = typeof elementOrSelector === 'string'
        ? document.querySelector(elementOrSelector)
        : elementOrSelector;
      if (!el) return null;
      return new VnAddressAutocompleteInput(el, options);
    },
    query: queryAddressSuggestions
  };

  window.VnAddressAutocomplete = VnAddressAutocomplete;

  // Tự động gắn vào các input mang thuộc tính data-vn-address hoặc các ô địa chỉ trọng tâm
  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-vn-address="true"], input[name="address"], textarea[name="address"]').forEach(input => {
      VnAddressAutocomplete.attach(input);
    });
  });

})(window, document);
