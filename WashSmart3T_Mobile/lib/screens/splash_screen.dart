import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Đã thêm thư viện Google Fonts
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        // Tạo dải màu nền Gradient dọc y hệt file HTML
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF9F1239), // Màu đỏ đô đậm (tương đương from-[#9f1239])
              Color(0xFF881337), // Màu trung gian (via-[#881337])
              Color(0xFF4C0519), // Màu đỏ mận đáy (to-[#4c0519])
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            // Lề dưới (bottom) để 16.0 giúp chữ ép sát đáy màn hình
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 48.0,
              bottom: 16.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Dải chữ "Tận tâm - Tinh tươm - Tiện lợi" ở trên cùng
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1,
                    ), // Nền kính mờ (glassmorphism)
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.pink[200],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TẬN TÂM • TINH TƯƠM • TIỆN LỢI',
                        style: GoogleFonts.plusJakartaSans(
                          // Sử dụng GoogleFonts
                          color: Colors.pink[100],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Nội dung trung tâm: Logo, Tên App và Trạng thái
                Column(
                  children: [
                    // Khung tròn chứa Logo có hiệu ứng đổ bóng
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const ClipOval(
                        // Tạm dùng icon máy giặt
                        child: Icon(
                          Icons.local_laundry_service_rounded,
                          size: 80,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tên ứng dụng WashSmart 3T
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          // Sử dụng GoogleFonts
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        children: const [
                          TextSpan(text: 'WashSmart '),
                          TextSpan(
                            text: '3T',
                            style: TextStyle(
                              color: Color(0xFFFDA4AF),
                            ), // Màu chữ "3T" hồng nhạt
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Slogan
                    Text(
                      'Giặt Ủi Tinh Tươm',
                      style: GoogleFonts.plusJakartaSans(
                        // Sử dụng GoogleFonts
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.pink[100]?.withOpacity(0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

                // 3. Phần nút bấm dưới cùng
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Xử lý chuyển sang trang Đăng nhập tại đây
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(
                            0xFF9F1239,
                          ), // Màu chữ đỏ
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              30,
                            ), // Bo tròn thành viên thuốc
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Bắt đầu ngay',
                              style: GoogleFonts.plusJakartaSans(
                                // Sử dụng GoogleFonts
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                    ),
                    // ĐÃ SỬA: Dùng SizedBox có độ cao cố định thay vì Spacer() để tránh lỗi biến mất UI
                    const SizedBox(height: 24),
                    // Chân trang (Footer)
                    Text(
                      'WashSmart 3T 2026',
                      style: GoogleFonts.plusJakartaSans(
                        // Sử dụng GoogleFonts
                        fontSize: 12,
                        color: Colors.pink[200]?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
