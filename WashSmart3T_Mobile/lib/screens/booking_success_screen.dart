import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_tracking_screen.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String orderCode;
  final int? orderId;
  final String pickupTime;
  final String deliveryTime;
  final String pickupAddress;
  final String deliveryAddress;
  final String contactPhone;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> selectedCareOptions;
  final double estimatedWeight;
  final int washPrice;
  final int shippingFee;
  final int expressFee;
  final int addonFee;
  final int voucherDiscount;
  final String selectedVoucherCode;
  final bool isCoinUsed;
  final int coinDiscount;
  final int finalPrice;
  final String paymentMethod;
  final String? customerName;

  const BookingSuccessScreen({
    super.key,
    this.orderCode = 'WS3T-8892',
    this.orderId,
    this.pickupTime = '14:00 - 16:00 Hôm nay',
    this.deliveryTime = '10:00 – 12:00 Ngày mai (Chuẩn 24h)',
    this.pickupAddress = 'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Q.1',
    this.deliveryAddress = '',
    this.contactPhone = '',
    this.items = const [],
    this.selectedCareOptions = const [],
    this.estimatedWeight = 3.0,
    this.washPrice = 0,
    this.shippingFee = 30000,
    this.expressFee = 0,
    this.addonFee = 0,
    this.voucherDiscount = 0,
    this.selectedVoucherCode = '',
    this.isCoinUsed = false,
    this.coinDiscount = 0,
    this.finalPrice = 0,
    this.paymentMethod = 'Thanh toán khi Shipper cân đồ (Tiền mặt / Quét VietQR)',
    this.customerName,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  // --- BRAND COLOR TOKENS WASHSMART 3T ---
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color secondaryColor = Color(0xFFB4136D);
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

  bool _isCopied = false;

  int get calculatedWashPrice {
    if (widget.washPrice > 0) return widget.washPrice;
    int sum = 0;
    for (final item in widget.items) {
      final num unitPrice = (item['unitPrice'] as num?) ?? 0;
      final num qty = (item['quantity'] as num?) ?? (item['isByItem'] == true ? 1 : widget.estimatedWeight);
      sum += (unitPrice * qty).round();
    }
    return sum > 0 ? sum : (widget.estimatedWeight * 15000).round();
  }

  int get calculatedFinalPrice {
    if (widget.finalPrice > 0) return widget.finalPrice;
    int total = calculatedWashPrice + widget.shippingFee + widget.expressFee + widget.addonFee - widget.voucherDiscount - (widget.isCoinUsed ? widget.coinDiscount : 0);
    return total < 0 ? 0 : total;
  }

  String _formatCurrency(num amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

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
            (widget.customerName != null && widget.customerName!.isNotEmpty)
                ? 'Cảm ơn ${widget.customerName}! Shipper 3T đã nhận lịch hẹn và chuẩn bị tới nhận đồ tại nhà bạn.'
                : 'Cảm ơn bạn! Shipper 3T đã nhận lịch hẹn và chuẩn bị tới nhận đồ tại nhà bạn.',
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
                      widget.pickupTime,
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

          // Dynamic Services List (Danh sách dịch vụ đã chọn từ Bước 1)
          _buildSelectedServicesList(),
          const SizedBox(height: 10),

          // Selected Care Options (Tiện ích chăm sóc đã chọn)
          if (widget.selectedCareOptions.isNotEmpty) ...[
            _buildSelectedCareOptions(),
            const SizedBox(height: 10),
          ],

          // Details List
          _buildDetailRow(
            icon: Icons.location_on,
            iconColor: primaryColor,
            label: 'Địa chỉ lấy đồ',
            value: widget.pickupAddress.isNotEmpty
                ? widget.pickupAddress
                : 'Địa chỉ của khách hàng',
          ),
          if (widget.deliveryAddress.isNotEmpty && widget.deliveryAddress != widget.pickupAddress) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.local_shipping,
              iconColor: secondaryColor,
              label: 'Địa chỉ giao trả khác',
              value: widget.deliveryAddress,
            ),
          ],
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.schedule,
            iconColor: tertiaryColor,
            label: 'Dự kiến giao đồ sạch',
            value: widget.deliveryTime,
            subtext: 'Cam kết giao đúng hẹn tinh tươm',
            subtextColor: tertiaryColor,
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.account_balance_wallet,
            iconColor: onSurfaceVariant,
            label: 'Phương thức thanh toán',
            value: widget.paymentMethod,
            subtext: 'Linh hoạt Tiền mặt hoặc Quét VietQR',
          ),
          const SizedBox(height: 14),

          // Pricing Breakdown Box (Bảng giá tiền tạm tính)
          _buildPricingBreakdownBox(),
        ],
      ),
    );
  }

  Widget _buildSelectedServicesList() {
    final items = widget.items;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaceContainer),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_laundry_service, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dịch vụ giặt sấy tiêu chuẩn 3T',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.estimatedWeight.toStringAsFixed(1)} kg (ước tính) • Cân điện tử khi nhận đồ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_formatCurrency(calculatedWashPrice)} đ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map((it) {
        final name = it['name']?.toString() ?? 'Dịch vụ giặt';
        final isByItem = it['isByItem'] == true;
        final unit = it['unit']?.toString() ?? (isByItem ? 'Cái' : 'kg');
        final num unitPrice = (it['unitPrice'] as num?) ?? 0;
        final num qty = (it['quantity'] as num?) ?? (isByItem ? 1 : widget.estimatedWeight);
        final num lineTotal = (it['totalPrice'] as num?) ?? (unitPrice * qty).round();
        final desc = it['description']?.toString() ??
            (isByItem ? 'Kiểm đếm theo số lượng món thực tế' : 'Giặt nước nóng, sấy khử khuẩn 70°C');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: surfaceContainer),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isByItem ? const Color(0xFFFFE4EC) : surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isByItem ? Icons.dry_cleaning : Icons.local_laundry_service,
                  color: isByItem ? secondaryColor : primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${_formatCurrency(lineTotal)} đ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isByItem
                          ? '${qty.toInt()} $unit × ${_formatCurrency(unitPrice)} đ'
                          : '${qty.toStringAsFixed(1)} $unit (ước tính) × ${_formatCurrency(unitPrice)} đ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedCareOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tiện ích chăm sóc đã chọn:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.selectedCareOptions.map((opt) {
            final name = opt['name']?.toString() ?? 'Tiện ích';
            final price = (opt['price'] as num?)?.toInt() ?? 0;
            final badge = price > 0 ? '+${_formatCurrency(price)}đ' : 'Miễn phí';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 12, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    '$name ($badge)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPricingBreakdownBox() {
    final hasItems = widget.items.isNotEmpty;
    final String labelSummary = hasItems
        ? '${widget.items.length} món/dịch vụ'
        : '${widget.estimatedWeight.toStringAsFixed(1)} kg';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceContainer),
      ),
      child: Column(
        children: [
          _buildPriceLine(
            'Tạm tính dịch vụ ($labelSummary):',
            '${_formatCurrency(calculatedWashPrice)} đ',
          ),
          const SizedBox(height: 4),
          _buildPriceLine(
            'Phí vận chuyển 2 chiều:',
            '${_formatCurrency(widget.shippingFee)} đ',
          ),
          if (widget.expressFee > 0) ...[
            const SizedBox(height: 4),
            _buildPriceLine(
              'Phí hỏa tốc 4h:',
              '+${_formatCurrency(widget.expressFee)} đ',
            ),
          ],
          if (widget.addonFee > 0) ...[
            const SizedBox(height: 4),
            _buildPriceLine(
              'Tiện ích chăm sóc:',
              '+${_formatCurrency(widget.addonFee)} đ',
            ),
          ],
          if (widget.voucherDiscount > 0) ...[
            const SizedBox(height: 4),
            _buildPriceLine(
              'Mã giảm giá (${widget.selectedVoucherCode.isNotEmpty ? widget.selectedVoucherCode : 'Ưu đãi 3T'})',
              '-${_formatCurrency(widget.voucherDiscount)} đ',
              valueColor: primaryColor,
              isVoucher: true,
            ),
          ],
          if (widget.isCoinUsed && widget.coinDiscount > 0) ...[
            const SizedBox(height: 4),
            _buildPriceLine(
              'WashPoints xu:',
              '-${_formatCurrency(widget.coinDiscount)} đ',
              valueColor: Colors.amber[800],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng giá tiền tạm tính:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      '(Chốt sau khi Shipper cân đo)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: outlineColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_formatCurrency(calculatedFinalPrice)} đ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ],
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
