import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

// 🚀 1. Import thêm màn hình Đăng nhập & AuthService
import 'login_screen.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Bảng màu thiết kế theo Brand Tokens WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);

  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ApiService.getMe();

      if (!mounted) return;

      setState(() {
        _user = result;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CD7F6), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF512128),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 🚀 2. Hàm xử lý Đăng xuất hoàn chỉnh
  Future<void> _handleLogout(BuildContext context) async {
    // Xóa Token và Role lưu dưới SharedPreferences
    await AuthService.logout();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đăng xuất tài khoản thành công!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Điều hướng về Trang đăng nhập và xóa toàn bộ Stack màn hình cũ
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.85),
        elevation: 0,
        scrolledUnderElevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.local_laundry_service_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tài Khoản',
              style: GoogleFonts.plusJakartaSans(
                color: onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: onSurface,
              size: 22,
            ),
            onPressed: () => _showToast(context, 'Không có thông báo mới'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. THẺ THÔNG TIN CÁ NHÂN (USER PROFILE CARD)
            _buildUserProfileCard(context),
            const SizedBox(height: 16),

            // 2. HÀNG THỐNG KÊ (3T XU, VOUCHER, ĐÃ GIẶT)
            _buildStatsRow(),
            const SizedBox(height: 20),

            // 3. MENU CÀI ĐẶT & DỊCH VỤ
            Text(
              'Cài đặt & Dịch vụ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingsMenu(context),
            const SizedBox(height: 24),

            // 4. NÚT ĐĂNG XUẤT & PHIÊN BẢN
            _buildLogoutSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- 1. USER PROFILE CARD ---

  Widget _buildUserProfileCard(BuildContext context) {
    final name = (_user?['fullName'] ?? '').toString().trim();
    final phone = (_user?['phone'] ?? '').toString().trim();

    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, Color(0xFFFD56A7)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading
                      ? 'Đang tải hồ sơ...'
                      : name.isEmpty
                      ? 'Chưa có tên tài khoản'
                      : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phone.isEmpty ? 'Chưa có số điện thoại' : phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: outlineColor,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Không tải được hồ sơ.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: primaryColor,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadProfile,
                    child: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. STATS ROW ---

  Widget _buildStatsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Thông tin điểm thưởng và ưu đãi sẽ được hiển thị '
        'khi hệ thống hỗ trợ dữ liệu tương ứng.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {bool isPrimary = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPrimary ? primaryColor : onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: outlineColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. SETTINGS MENU LIST ---
  Widget _buildSettingsMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.location_on,
            iconColor: primaryColor,
            title: 'Sổ địa chỉ nhận đồ',
            subtitle: 'Heritage Manor, Q.1',
            onTap: () => _showToast(context, 'Sổ địa chỉ nhận đồ'),
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.receipt_long,
            iconColor: secondaryColor,
            title: 'Lịch sử đơn hàng & Hóa đơn',
            subtitle: 'Tra cứu chi tiết & xuất hóa đơn VAT',
            onTap: () => _showToast(context, 'Chuyển đến Lịch sử đơn hàng'),
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.account_balance_wallet,
            iconColor: tertiaryColor,
            title: 'Phương thức thanh toán',
            subtitle: 'VietQR Auto, Ví MoMo',
            onTap: () => _showToast(context, 'Quản lý Phương thức thanh toán'),
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.support_agent,
            iconColor: primaryColor,
            title: 'Hỗ trợ & Tổng đài',
            subtitle: '1900 3388 (24/7)',
            badgeText: 'Miễn cước',
            onTap: () =>
                _showToast(context, 'Đang gọi 1900 3388 (Miễn cước)...'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surfaceLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: outlineColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFE3BDBF), size: 20),
          ],
        ),
      ),
    );
  }

  // --- 4. LOGOUT SECTION ---
  Widget _buildLogoutSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            // 🚀 Bấm nút Đăng xuất sẽ kích hoạt hàm _handleLogout
            onPressed: () => _handleLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: surfaceLow,
              foregroundColor: primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'WashSmart 3T v2.4.0',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: outlineColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
