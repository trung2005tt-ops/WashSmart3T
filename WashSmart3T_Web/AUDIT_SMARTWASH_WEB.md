# Báo cáo rà soát smartwash3T.Web

Ngày rà soát: 22/10/2026
Nguồn: 10 file web người dùng tải lên và API/controller C# trong project WashSmart hiện có.

## Tóm tắt

Không thể kết luận toàn bộ web đã hoàn thiện. Một số module đã đọc/ghi qua API, nhưng một số màn hình còn là giao diện mẫu với dữ liệu tĩnh và nút bấm chỉ hiện toast. Backend hiện có các controller `Auth`, `Orders`, `Services`, `Payments`, `Reviews`; không thấy controller/API quản lý Promotions/Vouchers, Customer CRM/points, Account directory CRUD hoặc Complaints/Refunds.

## Trạng thái theo trang

| Trang | Trạng thái khi rà soát | Hành động trong bản vá |
|---|---|---|
| `index.html` – Dashboard | Đọc đơn qua `GET /Orders/management`; doanh thu tính từ đơn trả về. Logic map enum trạng thái có lỗi: số 1 bị tính thành Washing, 2 bị tính Ready, 3 không được phân loại. Có thể làm sai số đơn đang xử lý/doanh thu theo trạng thái. | Sửa ánh xạ theo enum C#: 0 Pending, 1 Confirmed, 2 PickingUp, 3 Received, 4 Washing, 5 Ready, 6 Delivering, 7 Completed, 8 Cancelled. |
| `orders.html` – Quản lý đơn | Đọc đơn qua API và cập nhật trạng thái qua API. Cần kiểm tra backend trả đúng tổng tiền, chi tiết items và lịch sử trạng thái; chưa chạy end-to-end với DB thật. | Giữ luồng API hiện có; chưa xác nhận kiểm thử runtime. |
| `dispatch.html` – Điều phối shipper | Đọc đơn và shipper, gán/gỡ shipper qua API. | Giữ luồng API hiện có; chưa xác nhận kiểm thử runtime. |
| `services.html` – Dịch vụ/bảng giá | Trước bản vá: thẻ dịch vụ và giá viết cứng trong HTML; sửa giá/tạo dịch vụ/lưu phụ phí chỉ hiện toast, không lưu. | Thay danh sách bằng dữ liệu `GET /Services`; thêm tạo dịch vụ qua `POST /Services`, cập nhật giá qua `PUT /Services/{id}/price`, bật/tắt qua `PATCH /Services/{id}/status`. Phụ phí vẫn chưa có API nên không báo lưu thành công. |
| `pos.html` – POS | Tạo đơn qua `POST /Orders`, nhưng loại vải/đơn giá là lựa chọn tĩnh; code cũ đọc `s.prices` trong khi `ServicesController` hiện trả một object `Price`, và fallback `serviceId=1` có thể ghi sai dịch vụ. Thanh toán/QR, giảm VIP, phụ phí chưa được xác minh là luồng backend thật. | Sửa đọc cấu trúc `Price` và bỏ fallback service ID 1. POS sẽ từ chối tạo đơn nếu giá hiển thị không khớp bảng giá thật, thay vì âm thầm ghi sai dịch vụ. Cần làm tiếp để thay các lựa chọn tĩnh bằng dropdown dịch vụ/giá thật. |
| `customers.html` – Khách hàng/ưu đãi/điểm | Bảng khách hàng và số liệu là tĩnh. Phát voucher, chỉnh điểm và tạo khách hàng chỉ hiện toast; không có endpoint tương ứng trong backend hiện tại. | Thêm cảnh báo rõ đây chưa phải dữ liệu thật; ngăn thông báo thành công giả. Nút sao chép voucher chỉ sao chép mã, không phát hành/áp dụng ưu đãi. |
| `accounts.html` – Quản lý tài khoản | Bảng nhân viên tĩnh. Thêm/xóa chỉ thay DOM; sửa chỉ hiện toast. Backend hiện chỉ có `POST /Auth/create-shipper`, không có API liệt kê/sửa/xóa đầy đủ. | Thêm cảnh báo và ngăn thao tác giả làm thay đổi DOM rồi báo thành công. |
| `complaints.html` – Khiếu nại/bồi hoàn | Nội dung tĩnh; nút duyệt bồi hoàn giả lập thành công bằng `setTimeout`. Không có controller khiếu nại/bồi hoàn. | Loại bỏ giả lập thành công; cảnh báo rõ chưa kết nối API. |
| `login.html` | Đăng nhập gọi backend `POST /Auth/login`; vai trò được kiểm tra ở frontend. | Dùng chung `api.js` đã sửa cơ chế xác thực phiên. |
| `api.js` | Trước bản vá, bất kỳ lỗi mạng/API nào khi gọi `/Auth/me` đều xóa token và chuyển trang login. | Chỉ xóa phiên khi server trả 401/403; lỗi mạng/lỗi server tạm thời giữ phiên đã lưu. Bổ sung wrapper cho CRUD dịch vụ. |

## Các API backend hiện có được đối chiếu

- `POST /api/Auth/login`, `GET /api/Auth/me`, `POST /api/Auth/create-shipper`
- `GET /api/Orders/management`, `GET /api/Orders/management/shippers`, `POST /api/Orders/{id}/assign-shipper` hoặc endpoint gán shipper được frontend hiện dùng, `PUT /api/Orders/{id}/status`
- `GET /api/Services`, `GET /api/Services/{id}`, `POST /api/Services`, `PUT /api/Services/{id}`, `PATCH /api/Services/{id}/status`, `PUT /api/Services/{id}/price`
- `GET/POST /api/Payments/...`
- `GET/POST /api/Reviews/...`

Chưa tìm thấy API cho:
- Campaign/Promotion/Voucher: tạo chiến dịch, điều kiện áp dụng, thời hạn, phát cho khách, xác nhận sử dụng.
- Customer management: danh sách khách quản trị, chỉnh điểm, lịch sử điểm/voucher.
- Account management đầy đủ: danh sách tài khoản, cập nhật, khóa/mở khóa, xóa.
- Complaints/refunds: tạo khiếu nại, trạng thái xử lý, phê duyệt và ghi nhận hoàn tiền.

## Kiểm tra đã thực hiện

- Đã rà soát sự hiện diện của các API calls và handler trong 10 file HTML/JS.
- Đã chạy `node --check` với các script JavaScript nội tuyến trong 9 trang; không phát hiện lỗi cú pháp ở các script được kiểm tra.
- Đây là kiểm tra tĩnh, không phải kiểm thử tích hợp. Chưa kết nối được với API/database đang chạy trên máy người dùng nên chưa thể xác nhận đăng nhập, truy vấn SQL, lưu dữ liệu hoặc tính toán tiền thực tế.

## Việc cần làm để đạt mức hoàn thiện thật

1. Hoàn thiện POS: lấy danh mục và giá thật, tính tiền theo giá backend, bỏ giá mẫu, xử lý thanh toán thật.
2. Bổ sung model/database/migration và API cho khách hàng, điểm, voucher/khuyến mãi, tài khoản và khiếu nại/bồi hoàn.
3. Kết nối các trang tương ứng với API mới; chỉ hiện thông báo thành công sau phản hồi thành công từ server.
4. Kiểm thử tích hợp: tạo đơn → gán shipper → cập nhật cân nặng/dịch vụ → cập nhật trạng thái → dashboard doanh thu → kiểm tra dữ liệu sau F5.
5. Cấu hình `API_BASE` theo môi trường thay vì cố định `http://localhost:5085/api` khi triển khai ngoài máy phát triển.
