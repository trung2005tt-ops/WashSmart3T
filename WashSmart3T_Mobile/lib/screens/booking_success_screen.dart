import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_tracking_screen.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String orderCode;
  final int? orderId;

  const BookingSuccessScreen({
    super.key,
    this.orderCode = 'WS3T-8892',
    this.orderId,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  // --- BRAND COLOR TOKENS WASHSMART 3T ---
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color primaryFixed = Color(0xFFFFDADB);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color secondaryContainer = Color(0xFFFD56A7);
  static const Color secondaryFixed = Color(0xFFFFD9E4);
  static const Color onSecondaryFixed = Color(0xFF3E0022);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color tertiaryContainer = Color(0xFF008096);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceContainer = Color(0xFFFFE9EA);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color surfaceVariant = Color(0xFFFFD9DC);
  static const Color onSurface = Color(0xFF370C14);
  static const Color onSurfaceVariant = Color(0xFF5B4041);
  static const Color outlineColor = Color(0xFF8F6F71);
  static const Color outlineVariant = Color(0xFFE3BDBF);

  bool _isCopied = false;

  void _copyOrderCode() {
    Clipboard.setData(ClipboardData(text: widget.orderCode));
    setState(() => _isCopied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã sao chép mã đơn hàng #${widget.orderCode}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,

      // --- 1. HEADER APP BAR ---
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.85),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Image.network(
              'https://lh3.googleusercontent.com/aida/AEtjO1WWHqP8zmaM6FoIWgRFnkPSHxNJXdi1iw3pRzf0faw1YizBq5Xtgm78Scsr1L67QVplMW-qgVGruAIdpoPUsJAvSwbSX8ANCPt8eQ4CHUMSuAfIbrSnyLYTR4XbYmVWa8xjenDlfd45EM79hyK-kq6BQ530Htav7pCtPiZULHkeJg2B_5mI68R2gctoqdTKboEslYfggMFAKix5H0PHZAZICjSN6LUNn3i3Xt9fkqbHj5LaNeqOvFZFvY_k',
              height: 28,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_laundry_service, color: primaryColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '3. Xác Nhận Đơn & Tạm Tính (Bước 3/3)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),

      // --- NỘI DUNG CHÍNH ---
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // 2. SUCCESS CELEBRATION BANNER
            _buildSuccessCelebrationBanner(),
            const SizedBox(height: 20),

            // 3. ORDER TICKET HEADER
            _buildOrderTicketHeader(),
            const SizedBox(height: 16),

            // 4. DETAILED BOOKING SUMMARY
            _buildDetailedBookingSummary(),
            const SizedBox(height: 16),

            // 5. 3T CARE PROMISE & SCALE ASSURANCE
            _build3TCarePromiseCard(),
            const SizedBox(height: 24),

            // 6. INTERACTIVE ACTION BUTTONS
            _buildInteractiveActionButtons(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- WIDGET 2: SUCCESS CELEBRATION BANNER ---
  Widget _buildSuccessCelebrationBanner() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Aura Halo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40B90538),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 48,
              ),
            ),
            // Floating sparkles
            Positioned(
              top: 0,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: primaryColor,
                  size: 16,
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Icon(
                  Icons.bubble_chart,
                  color: tertiaryContainer,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: secondaryFixed.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_laundry_service,
                size: 14,
                color: onSecondaryFixed,
              ),
              const SizedBox(width: 4),
              Text(
                'Đã Xác Nhận Đơn Hàng',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: onSecondaryFixed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'Đặt Lịch Thành Công!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Cảm ơn Kiều Như! Shipper 3T đã nhận lịch hẹn và chuẩn bị tới nhận đồ tại nhà bạn.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET 3: ORDER TICKET HEADER ---
  Widget _buildOrderTicketHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MÃ ĐƠN HÀNG',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: outlineColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '#${widget.orderCode}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _copyOrderCode,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isCopied ? primaryColor : surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.content_copy,
                                size: 12,
                                color: _isCopied
                                    ? Colors.white
                                    : onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isCopied ? 'Đã chép!' : 'Sao chép',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isCopied
                                      ? Colors.white
                                      : onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: primaryColor,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pickup Window Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.moped, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHIPPER TỚI NHẬN ĐỒ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      '14:00 - 16:00 Hôm nay (24/10)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 4: DETAILED BOOKING SUMMARY ---
  Widget _buildDetailedBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Chi Tiết Tóm Tắt',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Bước 3/3 Hoàn Tất',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Garment Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuA10AHGmdpjrLr6Sr_yrMV_LNlSyc2571EASoD7azknvssxjC_kBi9TgyxkmjpFqCttJcIO4Bx8QomW086ot5G7i-tpT8c6uVbswch5jQJLxYildcOiLmkfHvcXsv_ca1PBemGGYacWmi9iO3rv_eFIu2yCMypHj2T9W4DMIaAIn2A2PE0vSEALxDoPDcd7r-rZT0HYwfHh-lvlHEMvw362f19qDXVK8_UaPqLsIynirmEHgjSbW19NJw',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: surfaceContainer,
                      child: const Icon(
                        Icons.dry_cleaning,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gói Giặt Sấy Tinh Tươm',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        '5.0 kg • Khoảng 12 món đồ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          _buildPerkTag(Icons.iron, 'Ủi hơi nước'),
                          _buildPerkTag(Icons.spa, 'Hương Ban Mai'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Details List
          _buildDetailRow(
            icon: Icons.location_on,
            iconColor: primaryColor,
            label: 'Địa chỉ lấy & giao trả',
            value: 'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Q.1',
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.schedule,
            iconColor: tertiaryColor,
            label: 'Dự kiến giao đồ sạch',
            value: '10:00 – 12:00 Ngày mai (25/10)',
            subtext: 'Cam kết giao đúng hẹn trong 24h',
            subtextColor: tertiaryColor,
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.account_balance_wallet,
            iconColor: onSurfaceVariant,
            label: 'Phương thức thanh toán',
            value: 'Thanh toán khi Shipper cân đồ',
            subtext: 'Linh hoạt Tiền mặt hoặc Quét VietQR',
          ),
          const SizedBox(height: 14),

          // Pricing Breakdown Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPriceLine('Tạm tính dịch vụ (5.0 kg):', '120.000 đ'),
                const SizedBox(height: 4),
                _buildPriceLine('Ủi hơi nước & Khử khuẩn:', '25.000 đ'),
                const SizedBox(height: 4),
                _buildPriceLine(
                  'Voucher (3TCHAOBAN)',
                  '-20.000 đ',
                  valueColor: primaryColor,
                  isVoucher: true,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceHigh.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng tạm tính:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '125.000 đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            '(Chốt theo khối lượng thực tế)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtext,
    Color? subtextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: outlineColor,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              if (subtext != null)
                Text(
                  subtext,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: subtextColor ?? onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(
    String label,
    String value, {
    Color? valueColor,
    bool isVoucher = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isVoucher) ...[
              const Icon(Icons.sell, size: 12, color: primaryColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isVoucher ? primaryColor : onSurfaceVariant,
                fontWeight: isVoucher ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: valueColor ?? onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // --- WIDGET 5: 3T CARE PROMISE & SCALE ASSURANCE ---
  Widget _build3TCarePromiseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.scale, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quy Trình 3T Minh Bạch & Chu Đáo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: onSurfaceVariant,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Shipper 3T sẽ mang theo '),
                      TextSpan(
                        text: 'cân điện tử kiểm tra chính xác công khai ',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const TextSpan(
                        text: 'ngay trước mặt bạn và niêm phong túi bằng ',
                      ),
                      TextSpan(
                        text: 'Khóa Seal chống nước ',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const TextSpan(text: 'độc quyền.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 6: INTERACTIVE ACTION BUTTONS ---
  Widget _buildInteractiveActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary CTA Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (widget.orderId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Không có mã đơn hàng để theo dõi. Vui lòng mở đơn từ Danh sách đơn hàng.',
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(orderId: widget.orderId!),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.explore, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Theo dõi tiến độ đơn hàng #${widget.orderCode}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Grid 2 Secondary Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceContainer,
                    foregroundColor: onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.home, size: 18),
                  label: Text(
                    'Về Trang chủ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceContainer,
                    foregroundColor: onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.format_list_bulleted, size: 18),
                  label: Text(
                    'Danh sách đơn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
