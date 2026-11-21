import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'orders_list_screen.dart';
import 'promotions_screen.dart';
import 'submit_claim_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Bảng màu thiết kế thương hiệu WashSmart 3T
  static const Color primaryColor = Color(0xFF8E0028);
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
  int _totalOrders = 0;
  int _promotionsCount = 3;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getMe();
      int ordersCount = 0;
      int promoCount = 3;

      try {
        final orders = await ApiService.getMyOrders();
        ordersCount = orders.length;
      } catch (_) {}

      try {
        final promos = await ApiService.getMyVouchers();
        promoCount = promos.length;
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _user = result;
        _totalOrders = ordersCount;
        _promotionsCount = promoCount;
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

  void _showToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: isError ? Colors.redAccent : const Color(0xFF4CD7F6),
              size: 18,
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Hộp thoại xác nhận Đăng xuất
  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Xác nhận đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản ${_user?['fullName'] ?? 'WashSmart 3T'} không?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF5B4041)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy bỏ',
              style: GoogleFonts.plusJakartaSans(color: outlineColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await AuthService.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // Mở BottomSheet chỉnh sửa thông tin cá nhân
  void _openEditProfileSheet(BuildContext context) {
    final nameController = TextEditingController(text: _user?['fullName'] ?? '');
    final emailController = TextEditingController(text: _user?['email'] ?? '');
    final phone = (_user?['phone'] ?? '').toString();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: outlineColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chỉnh sửa thông tin hồ sơ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Họ tên
              Text(
                'Họ và tên đầy đủ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceLow,
                  prefixIcon: const Icon(Icons.person, color: outlineColor, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Nhập họ và tên',
                ),
              ),
              const SizedBox(height: 14),

              // Email
              Text(
                'Địa chỉ Email (Nhận hóa đơn & OTP)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceLow,
                  prefixIcon: const Icon(Icons.mail, color: outlineColor, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'tenban@gmail.com',
                ),
              ),
              const SizedBox(height: 14),

              // Số điện thoại (read-only)
              Text(
                'Số điện thoại tài khoản (Không thể sửa)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: outlineColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: phone),
                enabled: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.phone_locked, color: Colors.grey, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nút Lưu
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          final newEmail = emailController.text.trim();

                          if (newName.isEmpty || newEmail.isEmpty) {
                            _showToast(context, 'Họ tên và email không được để trống.', isError: true);
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            await ApiService.updateProfile(
                              fullName: newName,
                              phone: phone,
                              email: newEmail,
                            );
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            _showToast(context, 'Cập nhật thông tin thành công!');
                            _loadProfile();
                          } catch (err) {
                            if (!mounted) return;
                            setModalState(() => isSaving = false);
                            _showToast(context, err.toString().replaceAll('Exception: ', ''), isError: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Lưu thông tin',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mở Hộp thoại QR Tích Điểm Tại Quầy
  void _openLoyaltyQrDialog(BuildContext context) {
    final name = _user?['fullName'] ?? 'Khách hàng';
    final phone = _user?['phone'] ?? '---';
    final points = _user?['loyaltyPoints'] ?? 0;
    final tier = _user?['membershipTier'] ?? 'Thành viên Mới';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.qr_code_scanner, color: primaryColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Mã Thẻ Thành Viên 3T',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hội viên: $name',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
            ),
            Text(
              'Đưa mã này cho nhân viên quầy khi giao đồ để tích điểm',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
            ),
            const SizedBox(height: 20),

            // Khung Giả Lập Mã QR Code sắc nét
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: Color(0xFF1F1F1F)),
                  const SizedBox(height: 8),
                  Text(
                    'WS3T-$phone',
                    style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 2,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hạng: $tier',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                  ),
                  Text(
                    '$points WashPoints',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                ),
                child: Text('Đóng', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mở Sổ Địa Chỉ Giao Nhận
  void _openAddressBookDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sổ địa chỉ giao & nhận đồ',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            _buildAddressItem(
              title: 'Nhà riêng (Mặc định)',
              address: '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM',
              isDefault: true,
            ),
            const SizedBox(height: 10),
            _buildAddressItem(
              title: 'Công ty / Cơ quan',
              address: 'Chợ Bến Thành, Đường Lê Lợi, Phường Bến Thành, Quận 1',
              isDefault: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showToast(context, 'Chức năng thêm địa chỉ mới đã sẵn sàng!');
                },
                icon: const Icon(Icons.add_location_alt, size: 18, color: primaryColor),
                label: Text(
                  '+ Thêm địa chỉ mới',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: primaryColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressItem({required String title, required String address, required bool isDefault}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault ? surfaceLow : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? primaryColor : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, color: isDefault ? primaryColor : outlineColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: onSurface)),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(6)),
                        child: Text('Mặc định', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(address, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF5B4041))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withValues(alpha: 0.9),
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
              'Tài Khoản & Hội Viên',
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
            icon: const Icon(Icons.refresh, color: onSurface, size: 22),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              _loadProfile();
              _showToast(context, 'Đã cập nhật lại thông tin tài khoản!');
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: primaryColor, size: 22),
            tooltip: 'Mã tích điểm',
            onPressed: () => _openLoyaltyQrDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Không thể đồng bộ dữ liệu mới nhất: $_error',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: primaryColor),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadProfile,
                        child: const Text('Thử lại', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              // 1. THẺ THÔNG TIN CÁ NHÂN & NÚT SỬA HỒ SƠ
              _buildUserProfileCard(context),
              const SizedBox(height: 14),

              // 2. THẺ HỘI VIÊN ĐIỆN TỬ VIP (3T DIGITAL MEMBERSHIP CARD)
              _buildDigitalMembershipCard(context),
              const SizedBox(height: 14),

              // 3. KHỐI THỐNG KÊ HOẠT ĐỘNG THỰC TẾ
              _buildStatsRow(context),
              const SizedBox(height: 20),

              // 4. MENU CÀI ĐẶT & DỊCH VỤ HOÀN CHỈNH
              Text(
                'Quản lý Đơn hàng & Ưu đãi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildOrdersSection(context),
              const SizedBox(height: 18),

              Text(
                'Cài đặt & Tiện ích Tài khoản',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingsMenu(context),
              const SizedBox(height: 24),

              // 5. NÚT ĐĂNG XUẤT AN TOÀN
              _buildLogoutSection(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. USER PROFILE CARD ---
  Widget _buildUserProfileCard(BuildContext context) {
    final name = (_user?['fullName'] ?? '').toString().trim();
    final phone = (_user?['phone'] ?? '').toString().trim();
    final email = (_user?['email'] ?? '').toString().trim();

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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
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
                initials.isEmpty ? 'TM' : initials,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoading ? 'Đang tải hồ sơ...' : (name.isEmpty ? 'Khách hàng' : name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _openEditProfileSheet(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit, size: 12, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Sửa',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_iphone, size: 13, color: outlineColor),
                    const SizedBox(width: 4),
                    Text(
                      phone.isEmpty ? 'Chưa có SĐT' : phone,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF5B4041)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.mail_outline, size: 13, color: primaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        email.isEmpty ? 'Chưa cập nhật email' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: email.isNotEmpty ? primaryColor : outlineColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 13, color: Color(0xFF1B6B40)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. THẺ HỘI VIÊN ĐIỆN TỬ VIP CARD ---
  Widget _buildDigitalMembershipCard(BuildContext context) {
    final tier = (_user?['membershipTier'] ?? 'Thành viên Mới').toString();
    final points = (_user?['loyaltyPoints'] ?? 0).toString();
    final phone = (_user?['phone'] ?? '---').toString();
    final isGoldOrDiamond = tier.toLowerCase().contains('gold') || tier.toLowerCase().contains('diamond') || tier.toLowerCase().contains('vàng');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isGoldOrDiamond
              ? [const Color(0xFF2C2416), const Color(0xFF8A6D3B)]
              : [const Color(0xFF8E0028), const Color(0xFFB4136D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isGoldOrDiamond ? const Color(0xFF8A6D3B) : primaryColor).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '3T MEMBER CLUB',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tier.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Số dư WashPoints:',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        points,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFFE082),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'xu (~$points.000đ)',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mã số thẻ: WS-$phone',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),

              ElevatedButton.icon(
                onPressed: () => _openLoyaltyQrDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.qr_code, size: 16),
                label: Text(
                  'Mã QR quầy',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. STATS ROW (DỮ LIỆU ĐỘNG THỰC TẾ) ---
  Widget _buildStatsRow(BuildContext context) {
    final points = (_user?['loyaltyPoints'] ?? 0).toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            value: '$points xu',
            label: 'WashPoints',
            icon: Icons.monetization_on,
            iconColor: const Color(0xFFD97706),
            onTap: () => _openLoyaltyQrDialog(context),
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _buildStatItem(
            value: '$_totalOrders đơn',
            label: 'Đơn giặt sấy',
            icon: Icons.local_laundry_service,
            iconColor: primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrdersListScreen()),
              );
            },
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _buildStatItem(
            value: '$_promotionsCount mã',
            label: 'Ví Voucher',
            icon: Icons.confirmation_number,
            iconColor: secondaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PromotionsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. NHÓM ĐƠN HÀNG & KHUYẾN MÃI ---
  Widget _buildOrdersSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.receipt_long,
            iconColor: primaryColor,
            title: 'Lịch sử đơn hàng & Hóa đơn điện tử',
            subtitle: 'Tra cứu tiến độ, biên lai và xuất VAT',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrdersListScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.card_giftcard,
            iconColor: secondaryColor,
            title: 'Kho Voucher & Ưu đãi thành viên',
            subtitle: 'Áp dụng mã giảm giá 15% - 50k khi đặt lịch',
            badgeText: 'HOT',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PromotionsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.report_problem,
            iconColor: const Color(0xFFD97706),
            title: 'Khiếu nại & Yêu cầu bồi thường',
            subtitle: 'Gửi yêu cầu kiểm tra đồ giặt, xử lý trong 24h',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubmitClaimScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 5. NHÓM CÀI ĐẶT & TIỆN ÍCH ---
  Widget _buildSettingsMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.location_on,
            iconColor: primaryColor,
            title: 'Sổ địa chỉ nhận & giao đồ',
            subtitle: '140 Lê Trọng Tấn, P. Tây Thạnh, Tân Phú',
            onTap: () => _openAddressBookDialog(context),
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.account_balance_wallet,
            iconColor: tertiaryColor,
            title: 'Phương thức thanh toán',
            subtitle: 'Chuyển khoản VietQR Auto, Tiền mặt COD',
            onTap: () => _showToast(context, 'Hệ thống hỗ trợ VietQR tự động và Tiền mặt khi shipper giao đồ.'),
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.verified_user,
            iconColor: const Color(0xFF1B6B40),
            title: 'Chính sách bảo hiểm đồ giặt 100%',
            subtitle: 'Cam kết bồi hoàn nếu xảy ra rủi ro thất lạc',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Cam kết Bảo hiểm Giặt Sấy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                  content: Text(
                    '1. WashSmart 3T cam kết giặt riêng từng mẻ đồ của mỗi khách hàng.\n'
                    '2. Sử dụng nước giặt xả cao cấp Omo/Comfort chính hãng.\n'
                    '3. Bồi hoàn 100% giá trị đồ nếu xảy ra lỗi do hệ thống.\n'
                    '4. Quy trình đóng gói túi khử khuẩn chuyên nghiệp trước khi giao trả.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                      child: const Text('Đã hiểu'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 60, color: surfaceLow),
          _buildMenuItem(
            icon: Icons.support_agent,
            iconColor: primaryColor,
            title: 'Hỗ trợ CSKH & Tổng đài',
            subtitle: '1900 3388 (07:00 - 22:00 hàng ngày)',
            badgeText: 'Miễn cước',
            onTap: () => _showToast(context, 'Tổng đài hỗ trợ: 1900 3388 (Miễn cước)'),
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: surfaceLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
            const Icon(Icons.chevron_right, color: Color(0xFFE3BDBF), size: 18),
          ],
        ),
      ),
    );
  }

  // --- 6. LOGOUT SECTION ---
  Widget _buildLogoutSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: surfaceLow,
              foregroundColor: primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
              ),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(
              'Đăng xuất tài khoản',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'WashSmart 3T • Đồ án Tốt nghiệp CNTT • v2.4.0',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: outlineColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
