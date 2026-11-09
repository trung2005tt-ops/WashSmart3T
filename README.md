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
│   ├── Middleware/                         # SecurityValidationMiddleware (kiểm tra IsActive tươi)
│   ├── Models/ & Data/                     # Entity Framework Core DbContext & Models
│   ├── Services/                           # SmsService, OtpManager, AccountLockoutManager...
│   ├── store_config.json                   # Cấu hình cửa hàng & tài khoản VietQR
│   ├── appsettings.Example.json            # Mẫu cấu hình môi trường chuẩn
│   ├── WashSmart.API.sln                   # Visual Studio Solution
│   ├── WashSmart.API.csproj                # C# Project file
│   └── Program.cs                          # CORS an toàn, JWT Bearer, Rate Limiting & DI
├── WashSmart3T_Web/                        # Web Portal Quản Trị, Thu Ngân & Điều Phối
│   ├── index.html                          # Dashboard phân tích doanh thu & hiệu suất
│   ├── pos.html                            # Tiếp nhận đơn quầy & VietQR động
│   ├── dispatch.html                       # Bản đồ định tuyến đường ngắn nhất & ghép đơn
│   ├── complaints.html                     # Xử lý khiếu nại & hướng giải quyết bồi hoàn
│   ├── store-settings.html                 # Cấu hình tài khoản ngân hàng & bảo mật SMS
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

## Hướng Dẫn Cấu Hình Môi Trường & Bảo Mật

Hệ thống hỗ trợ nạp cấu hình qua Biến môi trường (Environment Variables) để bảo vệ tuyệt đối bí mật trong môi trường Production:

| Biến Môi Trường | Mô Tả | Giá Trị Mặc Định (Dev) |
| :--- | :--- | :--- |
| `JWT_SECRET_KEY` | Khóa bí mật ký JWT Token (tối thiểu 32 ký tự) | Lấy từ `appsettings.json` hoặc cấu hình riêng |
| `INITIAL_SEED_PASSWORD` | Mật khẩu tài khoản Seeder ban đầu | Tự sinh bằng BCrypt an toàn |
| `DB_CONNECTION_STRING` | Chuỗi kết nối SQL Server | `Server=localhost\SQLEXPRESS;Database=WashSmart3T;...` |

### Khởi Chạy Nhanh:

#### 1. Khởi Chạy Backend API (C# .NET 8)
- **Yêu cầu**: .NET 8 SDK, SQL Server Express (`localhost\SQLEXPRESS`).
- **Lệnh chạy qua Terminal**:
  ```powershell
  cd WashSmart3T_Backend
  dotnet run --urls "http://localhost:5085"
  ```
- **Swagger UI**: Truy cập `http://localhost:5085/swagger` để kiểm tra tài liệu API.

#### 2. Khởi Chạy Web Quản Trị & POS
- **Yêu cầu**: Mở thư mục `WashSmart3T_Web` trong VS Code -> Chuột phải vào `index.html` chọn **Open with Live Server** (Cổng `5500`).
- **Hoặc chạy lệnh serve**:
  ```powershell
  cd WashSmart3T_Web
  npx serve -l 5500
  ```
- **Địa chỉ truy cập**: `http://127.0.0.1:5500/index.html` hoặc `http://127.0.0.1:5500/pos.html`.

#### 3. Khởi Chạy Mobile App (Flutter)
- **Yêu cầu**: Flutter SDK >= 3.x, Android Studio / Emulator.
- **Lệnh chạy**:
  ```powershell
  cd WashSmart3T_Mobile
  flutter pub get
  flutter run
  ```

---

## Các Cơ Chế Bảo Mật Đã Triệt Để Khắc Phục (Security Hardening)
1. **Phân Quyền Tuyệt Đối StoreConfig & VietQR**: Toàn bộ endpoint thay đổi tài khoản ngân hàng (`PUT /api/StoreConfig`), reset mặc định (`POST /reset`), kiểm tra SMS (`POST /test-sms`) đều được bảo vệ nghiêm ngặt bằng `[Authorize(Roles = "Admin")]`.
2. **Triệt Tiêu Rò Rỉ Khóa Bí Mật SMS Gateway**: `GET /api/StoreConfig` chỉ trả về `StorePublicConfigDto` phục vụ hiển thị & mã thanh toán VietQR, loại bỏ hoàn toàn `SmsApiKey` và `SmsApiSecret`. Endpoint `test-sms` tuyệt đối không trả mã OTP trong response JSON.
3. **Bảo Mật Complaints (Khiếu Nại)**: Toàn bộ controller được gắn `[Authorize]`. Khách hàng chỉ có quyền xem khiếu nại của chính mình và chỉ được khiếu nại đơn hàng thuộc quyền sở hữu (`CustomerId == CurrentUserId`). Endpoint duyệt bồi hoàn `PUT /{id}/resolve` yêu cầu quyền `Admin,Staff` và danh tính người duyệt (`ResolvedBy`) được trích xuất trực tiếp từ Claims của server, cấm client tự khai khống.
4. **Xác Thực OTP Đăng Ký Tài Khoản**: Bổ sung endpoint `POST /api/Auth/send-registration-otp` tích hợp mã hóa OTP 6 số ngẫu nhiên thời hạn 5 phút, tối đa 5 lần thử chống brute-force và cooldown 60 giây chống spam SMS. Endpoint `POST /api/Auth/register` bắt buộc xác minh mã OTP hợp lệ trước khi tạo tài khoản.
5. **Chính Sách Khóa Tài Khoản (Account Lockout)**: Áp dụng `AccountLockoutManager` khóa tài khoản 15 phút nếu người dùng nhập sai mật khẩu quá 5 lần liên tiếp.
6. **Thu Hồi Phiên Làm Việc Tức Thời (Token Revocation)**: Bổ sung `SecurityValidationMiddleware` kiểm tra trạng thái `IsActive` của người dùng từ CSDL theo thời gian thực; khi quản trị viên khóa tài khoản, toàn bộ token hiện hữu của tài khoản đó lập tức bị vô hiệu hóa.
7. **CORS Hạn Chế Phạm Vi**: Giới hạn chính xác nguồn gốc máy trạm `localhost` và `127.0.0.1`, ngăn chặn triệt để tấn công Cross-Origin từ tên miền lạ.
