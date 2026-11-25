import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  // Bảng màu thiết kế chuẩn WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);

  // States dữ liệu động từ backend
  bool _isLoading = true;
  String _customerName = 'Khách hàng';
  String _membershipTier = 'Gold';
  int _loyaltyPoints = 1450;
  List<Map<String, dynamic>> _vouchers = [];

  final TextEditingController _promoInputController = TextEditingController();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadPromotionData();
  }

  Future<void> _loadPromotionData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getMyVouchers();
      if (!mounted) return;

      String name = res['customerName'] ?? 'Khách hàng';
      String tier = res['membershipTier'] ?? 'Gold';
      int points = (res['loyaltyPoints'] is num) ? (res['loyaltyPoints'] as num).toInt() : 1450;

      try {
        final user = await ApiService.getMe();
        if (user['fullName'] != null && user['fullName'].toString().isNotEmpty) {
          name = user['fullName'].toString();
        }
        if (user['membershipTier'] != null && user['membershipTier'].toString().isNotEmpty) {
          tier = user['membershipTier'].toString();
        }
        if (user['loyaltyPoints'] is num) {
          points = (user['loyaltyPoints'] as num).toInt();
        }
      } catch (_) {}

      final rawVouchers = res['vouchers'];
      List<Map<String, dynamic>> loadedVouchers = [];
      if (rawVouchers is List) {
        loadedVouchers = rawVouchers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        _customerName = name.isNotEmpty ? name : 'Chị Kiều Như';
        _membershipTier = tier;
        _loyaltyPoints = points;
        _vouchers = loadedVouchers;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _promoInputController.dispose();
    super.dispose();
  }

  String _formatTierTitle(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return 'Hạng Kim Cương (Diamond)';
      case 'gold':
        return 'Hạng Vàng (Gold)';
      case 'silver':
        return 'Hạng Bạc (Silver)';
      default:
        return 'Hạng Đồng (Bronze)';
    }
  }

  String _getNextTierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return 'Đạt cấp bậc cao nhất (VIP Diamond)';
      case 'gold':
        return 'Tiến trình lên hạng Kim Cương';
      case 'silver':
        return 'Tiến trình lên hạng Vàng';
      default:
        return 'Tiến trình lên hạng Bạc';
    }
  }

  int _getNextTierTarget(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return 2000;
      case 'gold':
        return 2000;
      case 'silver':
        return 1000;
      default:
        return 500;
    }
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  void _showPointsHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lịch Sử Tích Xu 3T',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: primaryColor, size: 20),
                ),
                title: Text(
                  'Tích lũy từ đơn giặt sấy hoàn thành',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Thanh toán thành công đơn hàng qua VietQR / Tiền mặt',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                ),
                trailing: Text(
                  '+145 Xu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars, color: Colors.amber, size: 20),
                ),
                title: Text(
                  'Thưởng nâng hạng ${_formatTierTitle(_membershipTier)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Đặc quyền cấp bậc thành viên thân thiết',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                ),
                trailing: Text(
                  '+1.000 Xu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard, color: primaryColor, size: 20),
                ),
                title: Text(
                  'Thưởng chào mừng thành viên mới',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kích hoạt tài khoản ứng dụng thành công',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                ),
                trailing: Text(
                  '+305 Xu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleApplyCode() async {
    final code = _promoInputController.text.trim();
    if (code.isEmpty) {
      _showToast('Vui lòng nhập mã ưu đãi.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final res = await ApiService.verifyPromotion(code: code, orderAmount: 200000);
      if (mounted) {
        setState(() => _isVerifying = false);
        final valid = res['valid'] == true;
        final msg = res['message'] ?? (valid ? 'Mã $code áp dụng thành công!' : 'Mã không hợp lệ.');
        _showToast(msg);
        if (valid) {
          Clipboard.setData(ClipboardData(text: code));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showToast('Mã $code: ${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleVouchers = _vouchers.where((v) => v['isAvailable'] == true).toList();
    final ineligibleVouchers = _vouchers.where((v) => v['isAvailable'] != true).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_laundry_service, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WASHSMART 3T',
                  style: GoogleFonts.plusJakartaSans(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Ưu Đãi',
                  style: GoogleFonts.plusJakartaSans(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: onSurface, size: 22),
            onPressed: () {},
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thẻ VIP Membership & Ví 3T Xu
                  _buildVipMembershipCard(),
                  const SizedBox(height: 16),

                  // 2. Ô nhập Mã Ưu đãi nhanh
                  _buildPromoCodeInputBar(),
                  const SizedBox(height: 16),

                  // 3. Tiêu đề Danh sách Voucher Đủ Điều Kiện
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Voucher bạn đủ điều kiện (${eligibleVouchers.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF15803D),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Chạm để sao chép mã',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (eligibleVouchers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Hiện chưa có voucher nào đủ điều kiện cho hạng ${_formatTierTitle(_membershipTier)}.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: outlineColor),
                      ),
                    )
                  else
                    ...eligibleVouchers.map((v) {
                      final code = (v['code'] ?? '').toString();
                      final title = (v['title'] ?? '').toString();
                      final desc = (v['description'] ?? '').toString();
                      final discountTag = (v['discountTag'] ?? 'GIẢM').toString();
                      final discountValue = (v['discountValue'] ?? '20k').toString();
                      final badgeText = (v['badgeText'] ?? 'TOÀN HỆ THỐNG').toString();
                      final expiry = (v['expiry'] ?? '31/12/2026').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildVoucherCoupon(
                          icon: Icons.local_laundry_service,
                          discountTag: discountTag,
                          discountValue: discountValue,
                          badgeText: badgeText,
                          badgeColor: const Color(0xFFFFDADB),
                          badgeTextColor: const Color(0xFF40000D),
                          title: title,
                          subBadge: '✓ Đủ điều kiện',
                          subBadgeBg: const Color(0xFFDCFCE7),
                          subBadgeTextColor: const Color(0xFF15803D),
                          desc: desc,
                          code: code,
                          expiry: expiry,
                          btnText: 'Dùng ngay',
                          isPrimaryBtn: true,
                          accentColor: primaryColor,
                        ),
                      );
                    }),

                  if (ineligibleVouchers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 18, color: outlineColor),
                        const SizedBox(width: 6),
                        Text(
                          'Voucher chưa đủ điều kiện (${ineligibleVouchers.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...ineligibleVouchers.map((v) {
                      final code = (v['code'] ?? '').toString();
                      final title = (v['title'] ?? '').toString();
                      final rawDesc = (v['description'] ?? '').toString();
                      final reason = (v['ineligibleReason'] ?? '').toString();
                      final desc = reason.isNotEmpty ? '$reason\n$rawDesc' : rawDesc;
                      final discountTag = (v['discountTag'] ?? 'GIẢM').toString();
                      final discountValue = (v['discountValue'] ?? '20k').toString();
                      final badgeText = (v['badgeText'] ?? 'CHƯA MỞ KHÓA').toString();
                      final expiry = (v['expiry'] ?? '31/12/2026').toString();

                      return Opacity(
                        opacity: 0.72,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildVoucherCoupon(
                            icon: Icons.lock_outline,
                            discountTag: discountTag,
                            discountValue: discountValue,
                            badgeText: badgeText,
                            badgeColor: surfaceHigh,
                            badgeTextColor: outlineColor,
                            title: title,
                            subBadge: 'Chưa đủ điều kiện',
                            subBadgeBg: const Color(0xFFF3E8E8),
                            subBadgeTextColor: const Color(0xFF93000A),
                            desc: desc,
                            code: code,
                            expiry: expiry,
                            btnText: 'Xem điều kiện',
                            isPrimaryBtn: false,
                            accentColor: outlineColor,
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),

                  // 5. Cửa Hàng Đổi 3T Xu Lấy Quà
                  _buildRedeemRewardsStore(),
                  const SizedBox(height: 20),

                  // 6. Banner Đại Tiệc
                  _buildCampaignBanner(),
                  const SizedBox(height: 20),

                  // 7. Cam Kết Vải Sợi
                  _buildTransparencyRulesSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // --- WIDGET THÀNH PHẦN CHI TIẾT ---

  Widget _buildVipMembershipCard() {
    final nextTarget = _getNextTierTarget(_membershipTier);
    final nextLabel = _getNextTierLabel(_membershipTier);
    final progressVal = (_loyaltyPoints / nextTarget).clamp(0.0, 1.0);
    final deductibleAmount = _loyaltyPoints * 10;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [primaryColor, primaryContainer, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, color: Color(0xFF370C14), size: 12),
                            const SizedBox(width: 2),
                            Text(
                              _formatTierTitle(_membershipTier),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF370C14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ví 3T Xu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_loyaltyPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Xu',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFDAD2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.price_change, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '≈ ${_formatCurrency(deductibleAmount)} khấu trừ trực tiếp',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Color(0xFFFFB2B7), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '250 Xu hết hạn 31/10',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFFFFB2B7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nextLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Text(
                '$_loyaltyPoints / $nextTarget Xu',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 6,
              backgroundColor: Colors.black.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _showToast('Chuyển tới kho quà đổi Xu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.redeem, size: 16),
                    label: Text(
                      'Đổi quà / Voucher',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextButton.icon(
                    onPressed: _showPointsHistoryModal,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    ),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'Lịch sử tích điểm',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.sell, color: primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _promoInputController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'NHẬP MÃ ƯU ĐÃI (VÍ DỤ: 3TTINHTUOM...)',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isVerifying ? null : _handleApplyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Áp dụng',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCoupon({
    required IconData icon,
    required String discountTag,
    required String discountValue,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String title,
    required String subBadge,
    required Color subBadgeBg,
    required Color subBadgeTextColor,
    required String desc,
    required String code,
    required String expiry,
    required String btnText,
    required bool isPrimaryBtn,
    required Color accentColor,
  }) {
    return Container(
      height: 125,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  discountTag,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: outlineColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  discountValue,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(1, double.infinity),
            painter: DashedLinePainter(color: const Color(0xFFE3BDBF)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: subBadgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subBadge,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: subBadgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              _showToast('Đã sao chép mã $code! Sẵn sàng áp dụng khi đặt giặt sấy.');
                            },
                            child: Row(
                              children: [
                                Text(
                                  code,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.content_copy, size: 12, color: outlineColor),
                              ],
                            ),
                          ),
                          Text(
                            'HSD: $expiry',
                            style: GoogleFonts.plusJakartaSans(fontSize: 9, color: outlineColor),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            _showToast('Đã sao chép mã $code! Sẵn sàng áp dụng khi đặt giặt sấy.');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPrimaryBtn ? primaryColor : surfaceHigh,
                            foregroundColor: isPrimaryBtn ? Colors.white : onSurface,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            btnText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemRewardsStore() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: surfaceLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFFD56A7), shape: BoxShape.circle),
                child: const Icon(Icons.stars, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đổi 3T Xu Nhận Quà Tinh Tươm',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    'Số dư của bạn: $_loyaltyPoints Xu',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRewardCard(
                  imageUrl: 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?q=80&w=400',
                  cost: '300 Xu',
                  title: 'Nước xả vải hữu cơ Pháp',
                  desc: 'Nâng cấp hương nước hoa cỏ thơm mát lưu hương 7 ngày.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRewardCard(
                  imageUrl: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?q=80&w=400',
                  cost: '500 Xu',
                  title: 'Voucher 20k Giặt Chăn Ga',
                  desc: 'Áp dụng giặt rèm cửa, topper và drap nệm phòng ngủ.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: TextButton.icon(
              onPressed: () => _showToast('Đang tải thêm danh sách quà tặng...'),
              style: TextButton.styleFrom(
                backgroundColor: surfaceHigh,
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              label: Text(
                'Xem thêm 12 phần quà đổi điểm khác',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.chevron_right, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard({
    required String imageUrl,
    required String cost,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, height: 90, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    cost,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            desc,
            style: GoogleFonts.plusJakartaSans(fontSize: 9, color: outlineColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () => _showToast('Xác nhận đổi $cost lấy quà!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceHigh,
                foregroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Đổi ngay',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignBanner() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?q=80&w=600'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [const Color(0xFF512128).withOpacity(0.85), Colors.transparent],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    'ĐẠI TIỆC THÁNG 10',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Áp dụng toàn quốc',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tuần Lễ Tinh Tươm 3T',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Tặng túi vải niêm phong kháng nước & kháng khuẩn cho đơn từ 100k.',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFFFFF0F0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransparencyRulesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: primaryColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Cam Kết Vải Sợi & Điều Khoản Minh Bạch',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRuleItem('Bảo hiểm 100% sợi vải:', 'Đền bù theo quy chuẩn 3T Care nếu xảy ra co rút, phai màu hoặc hư hại form dáng.'),
          const SizedBox(height: 6),
          _buildRuleItem('Chính sách gộp mã:', 'Cho phép áp dụng cùng lúc 01 Mã Freeship và 01 Mã giảm giá dịch vụ trên mỗi hóa đơn.'),
          const SizedBox(height: 6),
          _buildRuleItem('Tích lũy linh hoạt:', 'Mỗi 10.000đ thanh toán tích ngay 10 Xu 3T, xu có giá trị trong vòng 180 ngày.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cần hỗ trợ về mã voucher?', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: outlineColor)),
                        Text('Hotline: 1900 3388 (Miễn cước)', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: onSurface)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Gọi ngay', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String boldTitle, String normalText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: primaryColor, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
              children: [
                TextSpan(text: '$boldTitle ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF370C14))),
                TextSpan(text: normalText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// CLASS VẼ NÉT ĐỨT VÉ COUPON CHUẨN KHÔNG LỖI
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 4, dashSpace = 3, startY = 6;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    while (startY < size.height - 6) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
