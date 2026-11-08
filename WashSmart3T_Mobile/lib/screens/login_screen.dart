import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'shipper_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final Color surfaceColor = const Color(0xFFFFF8F7);
  final Color primaryColor = const Color(0xFFB90538);
  final Color primaryContainer = const Color(0xFFDC2C4F);
  final Color surfaceContainerLow = const Color(0xFFFFF0F0);
  final Color onSurface = const Color(0xFF370C14);
  final Color outlineColor = const Color(0xFF8F6F71);
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Phần Header & Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_laundry_service_rounded,
                  size: 40,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Badge 3T (Đã bọc FittedBox chống vỡ chữ)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE1E3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: primaryColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '3T: TẬN TÂM • TINH TƯƠM • TIỆN LỢI',
                        style: GoogleFonts.plusJakartaSans(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tiêu đề chào mừng
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Mừng bạn quay lại! ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đăng nhập để theo dõi trạng thái giặt sấy trực tiếp & nhận tích lũy WashPoints 3T.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF5B4041),
                ),
              ),
              const SizedBox(height: 32),

              // 2. Thẻ Form Đăng Nhập
              Container(
                padding: const EdgeInsets.all(
                  20,
                ), // Thu nhỏ padding một chút để tiết kiệm diện tích
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột Số điện thoại/Email
                    Text(
                      'Số điện thoại hoặc Email',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: surfaceContainerLow,
                        prefixIcon: Icon(
                          Icons.alternate_email,
                          color: primaryColor,
                        ),
                        hintText: '0908 xxx xxx',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: outlineColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cột Mật khẩu
                    Text(
                      'Mật khẩu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: surfaceContainerLow,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: primaryColor,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: outlineColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        hintText: '••••••••',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: outlineColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ghi nhớ & Quên mật khẩu (Đã bọc FittedBox)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ghi nhớ tài khoản',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF5B4041),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20), // Tạo khoảng cách an toàn
                          Text(
                            'Quên mật khẩu?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nút Đăng nhập
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Đăng nhập ngay'),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Nút Face ID / Vân tay
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton.icon(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          backgroundColor: surfaceContainerLow,
                          foregroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(Icons.fingerprint),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Đăng nhập bằng Face ID / Vân tay',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hoặc tiếp tục với
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xFFFFD9DC)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'HOẶC TIẾP TỤC VỚI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: outlineColor,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFFFD9DC)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mạng xã hội (Đã chia tỉ lệ bằng Expanded tự động co giãn)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSocialButton(
                            Icons.g_mobiledata,
                            'Google',
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSocialButton(
                            Icons.apple,
                            'Apple',
                            Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSocialButton(
                            Icons.facebook,
                            'Facebook',
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Thẻ Khuyến mãi Đăng ký
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.redeem, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Text(
                                  'ƯU ĐÃI THÀNH VIÊN MỚI',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB4136D),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 14,
                                  color: Color(0xFFB4136D),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Tặng ngay voucher 50.000đ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chưa có tài khoản? Nhận ngay 100 WashPoints và lượt ủi thơm đầu tiên miễn phí.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF5B4041),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ĐOẠN ĐÃ ĐƯỢC THÊM LỆNH CHUYỂN TRANG
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Đăng ký tài khoản ngay',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Footer (Cam kết 3T - Đã bọc FittedBox chống vỡ)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFooterItem(
                      Icons.sanitizer,
                      'Khử khuẩn UV\n99.9%',
                      const Color(0xFF006577),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '•',
                        style: TextStyle(color: Color(0xFF8F6F71)),
                      ),
                    ),
                    _buildFooterItem(
                      Icons.security,
                      'Bảo mật chuẩn\nISO',
                      primaryColor,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '•',
                        style: TextStyle(color: Color(0xFF8F6F71)),
                      ),
                    ),
                    _buildFooterItem(
                      Icons.local_shipping,
                      'Giao nhận\ntận nơi',
                      const Color(0xFFB4136D),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Bảo hộ bản quyền © WashSmart 3T - Giải pháp chăm sóc vải vóc thông minh & tinh tươm.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: outlineColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Đã bỏ thuộc tính `width` cứng để nút tự co giãn linh hoạt
  Widget _buildSocialButton(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF5B4041),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String text, Color iconColor) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
        ),
      ],
    );
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại và mật khẩu.'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiService.login(phone: phone, password: password);

      final token = data['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('API không trả về token.');
      }

      final userData = data['user'];

      if (userData is! Map) {
        throw Exception('API không trả về thông tin tài khoản.');
      }

      final role = userData['role']?.toString().trim().toLowerCase();

      if (role == null || role.isEmpty) {
        throw Exception('Không xác định được vai trò tài khoản.');
      }

      await AuthService.saveSession(token: token.toString(), role: role);

      if (!mounted) return;

      final Widget destination;

      switch (role) {
        case 'shipper':
          destination = const ShipperScreen();
          break;

        case 'customer':
          destination = const HomeScreen();
          break;

        case 'admin':
        case 'staff':
          // Tạm thời giữ màn hình hiện có.
          // Sẽ nối sang màn hình quản lý riêng sau.
          destination = const HomeScreen();
          break;

        default:
          throw Exception('Vai trò tài khoản không hợp lệ: $role');
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
