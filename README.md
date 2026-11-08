# ĐỒ ÁN TỐT NGHIỆP: HỆ THỐNG QUẢN LÝ & ĐIỀU PHỐI GIẶT ỦI THÔNG MINH (WASHSMART 3T)

## Giới Thiệu Tổng Quan
Hệ sinh thái **WashSmart 3T** là giải pháp số hóa toàn diện quy trình giặt ủi công nghệ cao, kết nối thời gian thực giữa Khách hàng, Shipper giao nhận, Nhân viên quầy và Ban quản trị hệ thống:
1. **Backend Web API (.NET 8)**: Cung cấp toàn bộ RESTful API, quản lý logic giặt sấy, định tuyến OSRM, VietQR Napas 247 và cơ chế bảo hiểm 3T Care.
2. **Web Portal Quản Trị & POS Quầy (HTML5 / Tailwind CSS / ES6)**: Dashboard chỉ số KPI thời gian thực, Tiếp nhận đơn quầy tích hợp cân điện tử, Bản đồ điều phối gom/giao đơn cho Shipper, và Trung tâm xử lý khiếu nại bồi hoàn.
3. **Mobile App (Flutter / Dart)**: Ứng dụng di động dành cho Khách hàng (đặt lịch giặt, theo dõi tiến độ, thanh toán VietQR) và Shipper (nhận ca giao nhận, ghép đơn thông minh, cân đo tại chỗ).

---

## Cấu Trúc Mã Nguồn Chuẩn Đồ Án Tốt Nghiệp

```
DoAnTotNghiep/
├── WashSmart3T_Backend/                    # Backend C# ASP.NET Core 8 Web API
│   ├── Controllers/                        # Payments, Orders, Complaints, StoreConfig...
│   ├── Models/ & Data/                     # Entity Framework Core DbContext & Models
│   ├── Services/                           # SmsService, OtpManager, VietQR...
│   ├── store_config.json                   # Cấu hình cửa hàng, tài khoản ngân hàng thật
│   ├── WashSmart.API.sln                   # Visual Studio Solution
│   ├── WashSmart.API.csproj                # C# Project file
│   └── Program.cs                          # Cấu hình dependency injection, CORS, JWT
├── WashSmart3T_Web/                        # Web Portal Quản Trị, Thu Ngân & Điều Phối
│   ├── index.html                          # Dashboard phân tích doanh thu & hiệu suất
│   ├── pos.html                            # Tiếp nhận đơn quầy & VietQR động
│   ├── dispatch.html                       # Bản đồ định tuyến đường ngắn nhất & ghép đơn
│   ├── complaints.html                     # Xử lý khiếu nại & hướng giải quyết bồi hoàn
│   ├── store-settings.html                 # Cấu hình tài khoản ngân hàng thật & phí ship
│   ├── orders.html, accounts.html, ...     # Quản lý đơn hàng, tài khoản, dịch vụ
│   └── api.js                              # Client SDK kết nối đồng bộ Backend API
├── WashSmart3T_Mobile/                     # Mobile App Flutter đa nền tảng (Khách & Shipper)
│   ├── lib/                                # Mã nguồn Dart (screens, models, services...)
│   ├── android/ & ios/                     # Cấu hình nền tảng Native
│   └── pubspec.yaml                        # Danh mục dependencies Flutter
├── Database/                               # Kịch bản cơ sở dữ liệu
│   └── WashSmart3T_Database_Schema.sql     # Script khởi tạo SQL Server đầy đủ
└── README.md                               # Tài liệu hướng dẫn cài đặt & vận hành
```

---

## Hướng Dẫn Khởi Chạy Nhanh

### 1. Khởi Chạy Backend API (C# .NET 8)
- **Yêu cầu**: .NET 8 SDK, SQL Server Express (`localhost\SQLEXPRESS`).
- **Lệnh chạy qua Terminal**:
  ```powershell
  cd WashSmart3T_Backend
  dotnet run --urls "http://localhost:5085"
  ```
- **Hoặc qua Visual Studio**: Mở `WashSmart3T_Backend\WashSmart.API.sln` và bấm `F5` / `Ctrl + F5`.
- **Swagger UI**: Truy cập `http://localhost:5085/swagger` để kiểm tra tài liệu API.

### 2. Khởi Chạy Web Quản Trị & POS
- **Yêu cầu**: Mở thư mục `WashSmart3T_Web` trong VS Code -> Chuột phải vào `index.html` chọn **Open with Live Server** (Cổng `5500`).
- **Hoặc chạy lệnh serve**:
  ```powershell
  cd WashSmart3T_Web
  npx serve -l 5500
  ```
- **Địa chỉ truy cập**: `http://127.0.0.1:5500/index.html` hoặc `http://127.0.0.1:5500/pos.html`.

### 3. Khởi Chạy Mobile App (Flutter)
- **Yêu cầu**: Flutter SDK >= 3.x, Android Studio / Emulator.
- **Lệnh chạy**:
  ```powershell
  cd WashSmart3T_Mobile
  flutter pub get
  flutter run
  ```

---

## Tài Khoản Thử Nghiệm Hệ Thống (Demo Accounts)

| Vai Trò | Số Điện Thoại | Mật Khẩu | Tên Người Dùng | Mục Đích Sử Dụng |
| :--- | :--- | :--- | :--- | :--- |
| **Quản trị viên (Admin)** | `0900000000` | `123456` | Nguyễn Kiều Như | Toàn quyền Dashboard, POS, Phê duyệt bồi hoàn |
| **Shipper Giao Nhận** | `0922222222` | `123456` | Lê Minh Hoàng | Nhận đơn giao, quét QR thu hộ COD, chụp ảnh minh chứng |
| **Khách Hàng (Customer)**| `0999222111` | `123456` | Như Nguyễn | Đặt dịch vụ, theo dõi tiến trình đơn hàng, gửi khiếu nại |

---

## Điểm Nhấn Công Nghệ Của Đồ Án
1. **VietQR NAPAS 247 Động**: Tạo mã QR chuẩn EMVCo tự động khóa số tiền và nội dung đơn hàng `#WS3T-XXXX`, chống chuyển sai sót, đồng bộ tài khoản thật động từ `store_config.json`.
2. **Bản Đồ Điều Phối & Ghép Đơn Thông Minh (Dispatch Engine)**: Tích hợp OpenStreetMap và giải thuật tối ưu hóa đường đi ngắn nhất (OSRM TSP) giúp shipper tối ưu cung đường giao nhiều đơn cùng lúc.
3. **Quy Chuẩn Bảo Hiểm 3T Care**: Quy trình xử lý sự cố đồ giặt minh bạch 4 bước (Tiếp nhận -> Đối soát Seal/IoT -> Lựa chọn hướng giải quyết: Giặt lại / Hoàn tiền / Đền bù / Voucher -> Chốt biên bản bồi hoàn).
