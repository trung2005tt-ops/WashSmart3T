# Antigravity Rules for WashSmart 3T

## Git & Version Control Policy
- **Tự động đẩy lên Git**: Sau mỗi lần hoàn tất chỉnh sửa mã nguồn hoặc giải quyết yêu cầu lập trình từ người dùng, luôn tự động thực hiện:
  1. `git add -A`
  2. `git commit -m "<mô tả rõ ràng theo chuẩn conventional commit>"`
  3. `git push origin main`
- Đảm bảo kiểm tra cú pháp và build không có lỗi trước khi commit.
