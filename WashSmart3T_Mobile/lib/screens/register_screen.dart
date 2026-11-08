import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  // Biến trạng thái ẩn/hiện mật khẩu
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Trạng thái checkbox
  bool _agreedToTerms = true;

  // Controllers để theo dõi nội dung nhập liệu
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // Biến đánh giá sức mạnh mật khẩu (0: Chưa nhập, 1: Yếu, 2: Trung bình, 3: Mạnh)
  int _passwordStrength = 0;
  bool _isPasswordMatch = false;

  // Bảng màu hệ thống
  final Color surfaceColor = const Color(0xFFFFF8F7);
  final Color primaryColor = const Color(0xFFB90538);
  final Color surfaceContainerLow = const Color(0xFFFFF0F0);
  final Color surfaceContainerHighest = const Color(0xFFFFD9DC);
  final Color onSurface = const Color(0xFF370C14);
  final Color outlineColor = const Color(0xFF8F6F71);

  @override
  void initState() {
    super.initState();
    // Lắng nghe sự thay đổi của text để cập nhật UI thời gian thực
    _passController.addListener(_checkPassword);
    _confirmController.addListener(_checkPassword);
  }

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Thuật toán kiểm tra độ mạnh mật khẩu dựa theo code HTML gốc
  void _checkPassword() {
    String val = _passController.text;
    String confirmVal = _confirmController.text;

    int strength = 0;
    if (val.isNotEmpty) {
      if (val.length >= 6) strength = 1;
      if (val.length >= 8 &&
          RegExp(r'[0-9]').hasMatch(val) &&
          RegExp(r'[a-zA-Z]').hasMatch(val))
        strength = 2;
      if (val.length >= 10 && RegExp(r'[^a-zA-Z0-9]').hasMatch(val))
        strength = 3;
    }

    setState(() {
      _passwordStrength = strength;
      _isPasswordMatch =
          (val.isNotEmpty && confirmVal.isNotEmpty && val == confirmVal);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header cố định trên cùng
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút Quay lại
                  InkWell(
                    onTap: () =>
                        Navigator.pop(context), // Quay về trang Đăng nhập
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, color: onSurface, size: 20),
                    ),
                  ),
                  Text(
                    'Tạo tài khoản mới',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Icon(
                    Icons.local_laundry_service,
                    color: primaryColor,
                    size: 24,
                  ),
                ],
              ),
            ),

            // Phần nội dung cuộn được
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thẻ Ưu đãi Tân thủ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE9EA), Color(0xFFFFF0F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFDADB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.local_laundry_service_rounded,
                                  color: primaryColor,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.card_giftcard,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ƯU ĐÃI TÂN THỦ',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Gia nhập đại gia đình 3T 🎁',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Tận Tâm • Tinh Tươm • Tiện Lợi',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF5B4041),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD9E4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.card_giftcard,
                                    color: Color(0xFFB4136D),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF600037),
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Tặng gói giặt sấy ',
                                        ),
                                        TextSpan(
                                          text: '50.000đ',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(
                                          text:
                                              ' + Miễn phí vận chuyển đơn đầu tiên cho thành viên mới.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Đăng ký
                    _buildLabel('Họ và tên đầy đủ', true),
                    _buildTextField(
                      controller: _fullNameController,
                      hint: 'Ví dụ: Lê Hoàng Lan Anh',
                      icon: Icons.person,
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Số điện thoại', true),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Bắt buộc xác thực OTP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFF5B4041),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildTextField(
                      controller: _phoneController,
                      hint: 'Ví dụ: 0908 123 456',
                      icon: Icons.phone_iphone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),
                    _buildLabel('Email cá nhân (Nhận hóa đơn điện tử)', false),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'lananh@gmail.com',
                      icon: Icons.mail,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    // Mật khẩu có thanh đo sức mạnh
                    const SizedBox(height: 16),
                    _buildLabel('Mật khẩu bảo vệ', true),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Tối thiểu 8 ký tự (có chữ & số)',
                      icon: Icons.lock,
                      isPassword: true,
                      obscureState: _obscurePassword,
                      onToggleVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 8),
                    _buildStrengthMeter(),

                    // Xác nhận mật khẩu
                    const SizedBox(height: 16),
                    _buildLabel('Xác nhận mật khẩu', true),
                    _buildTextField(
                      hint: 'Nhập lại mật khẩu vừa tạo',
                      icon: Icons.enhanced_encryption,
                      isPassword: true,
                      obscureState: _obscureConfirm,
                      controller: _confirmPasswordController,
                      showMatchIcon: true,
                      onToggleVisibility: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Mã người giới thiệu', false),
                        Text(
                          '+50 WashPoints',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB4136D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildTextField(
                      hint: 'Nhập mã ưu đãi (tùy chọn)',
                      icon: Icons.confirmation_number,
                    ),

                    // Điều khoản dịch vụ
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            activeColor: primaryColor,
                            onChanged: (val) =>
                                setState(() => _agreedToTerms = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF5B4041),
                              ),
                              children: [
                                const TextSpan(text: 'Tôi đồng ý với '),
                                TextSpan(
                                  text: 'Điều khoản dịch vụ',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' và '),
                                TextSpan(
                                  text: 'Chính sách bảo hiểm trang phục',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' WashSmart 3T Care.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Nút Đăng ký
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: outlineColor.withOpacity(
                            0.3,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
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
                                  Text(
                                    'Tạo tài khoản & Nhận quà 50K',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),

                    // Link về Đăng nhập
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bạn đã có tài khoản rồi? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF5B4041),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Đăng nhập ngay',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    // Trust Badges
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTrustBadge(
                            Icons.verified_user,
                            'Bảo Mật 100%',
                            'Chuẩn OTP an toàn',
                            const Color(0xFF006577),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: outlineColor.withOpacity(0.3),
                          ),
                          _buildTrustBadge(
                            Icons.sanitizer,
                            'Khử Khuẩn UV',
                            'Sạch thơm tinh tươm',
                            const Color(0xFFB4136D),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tiện ích vẽ Nhãn (Label)
  Widget _buildLabel(String text, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5B4041),
            ),
          ),
          if (isRequired)
            Text(
              ' *',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // Tiện ích vẽ Ô nhập liệu
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureState = false,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    VoidCallback? onToggleVisibility,
    bool showMatchIcon = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureState,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: surfaceContainerLow,
        prefixIcon: Icon(icon, color: outlineColor),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: outlineColor.withOpacity(0.6),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureState ? Icons.visibility_off : Icons.visibility,
                  color: outlineColor,
                ),
                onPressed: onToggleVisibility,
              )
            : (showMatchIcon && _isPasswordMatch)
            ? const Icon(Icons.check_circle, color: Color(0xFF006577))
            : null,
      ),
    );
  }

  // Thanh đo độ mạnh mật khẩu
  Widget _buildStrengthMeter() {
    String label = 'Chưa nhập';
    Color strengthColor = outlineColor;

    if (_passwordStrength == 1) {
      label = 'Yếu';
      strengthColor = const Color(0xFFBA1A1A);
    } else if (_passwordStrength == 2) {
      label = 'Trung bình';
      strengthColor = const Color(0xFFFD56A7);
    } else if (_passwordStrength == 3) {
      label = 'Mạnh & An toàn';
      strengthColor = const Color(0xFF006577);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Độ mạnh mật khẩu:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: outlineColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: _passwordStrength >= 1
                      ? strengthColor
                      : surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: _passwordStrength >= 2
                      ? strengthColor
                      : surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: _passwordStrength >= 3
                      ? strengthColor
                      : surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget Footer Trust
  Widget _buildTrustBadge(
    IconData icon,
    String title,
    String sub,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: const Color(0xFF5B4041),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Kiểm tra dữ liệu
    if (fullName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin.')),
      );

      return;
    }

    // Kiểm tra mật khẩu
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp.')),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.register(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng ký thành công!')));

      // Quay về màn hình Login
      Navigator.pop(context);
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
