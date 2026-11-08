import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'booking_success_screen.dart';

class BookingStep3Screen extends StatefulWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final String contactPhone;
  final String? note;
  final List<Map<String, dynamic>> items;

  const BookingStep3Screen({
    super.key,
    this.pickupAddress = '',
    this.deliveryAddress = '',
    this.contactPhone = '',
    this.note,
    this.items = const [],
  });

  @override
  State<BookingStep3Screen> createState() => _BookingStep3ScreenState();
}

class _BookingStep3ScreenState extends State<BookingStep3Screen> {
  // Brand Color Tokens WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color primaryFixed = Color(0xFFFFDADB);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceContainer = Color(0xFFFFE9EA);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color surfaceVariant = Color(0xFFFFD9DC);
  static const Color onSurface = Color(0xFF370C14);
  static const Color onSurfaceVariant = Color(0xFF5B4041);
  static const Color outlineVariant = Color(0xFFE3BDBF);

  // --- STATE TÍNH TIỀN & ĐẶT ĐƠN ---
  bool isCoinUsed = false;
  String paymentMethod = 'pickup_weigh';
  bool isSubmitting = false;

  // Giá giặt chưa xác định: shipper sẽ cân/đếm và xác nhận khi nhận đồ.
  final int washPrice = 0;
  final int shippingFee = 30000;
  final int coinDiscount = 5000;

  // State Voucher đang chọn
  String selectedVoucherCode = '';
  int voucherDiscount = 0;
  String selectedVoucherTitle = 'Chưa áp dụng mã giảm giá';

  // Danh sách các voucher khả dụng
  final List<Map<String, dynamic>> availableVouchers = [
    {
      'code': '3TCHAOBAN',
      'title': 'Giảm 20.000 đ đơn đầu tiên',
      'discount': 20000,
      'minOrder': 0,
      'desc': 'Áp dụng cho khách hàng mới của WashSmart 3T',
    },
    {
      'code': 'WASH3T30K',
      'title': 'Giảm 30.000 đ đơn từ 100k',
      'discount': 30000,
      'minOrder': 100000,
      'desc': 'Ưu đãi giặt sấy nguyên mẻ tinh tươm',
    },
    {
      'code': 'FREESHIP3T',
      'title': 'Miễn phí vận chuyển 2 chiều',
      'discount': 30000,
      'minOrder': 80000,
      'desc': 'Trừ trực tiếp 30.000 đ phí ship',
    },
  ];

  int get finalPrice {
    // Chỉ hiển thị phí vận chuyển tạm tính; tiền giặt chờ xác nhận khối lượng thực tế.
    int total = shippingFee;
    return total < 0 ? 0 : total;
  }

  // 🚀 Hàm hiển thị Bottom Sheet chọn Voucher
  void _showVoucherBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                        color: outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chọn Mã Giảm Giá 3T',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Ô nhập mã thủ công
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Nhập mã ưu đãi...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Mã đã được áp dụng thành công!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Áp dụng',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Mã ưu đãi dành cho bạn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Danh sách Voucher
                  Column(
                    children: availableVouchers.map((voucher) {
                      bool isSelected = selectedVoucherCode == voucher['code'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedVoucherCode = voucher['code'];
                            voucherDiscount = voucher['discount'];
                            selectedVoucherTitle = voucher['title'];
                          });
                          Navigator.pop(modalContext);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? surfaceLow : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : outlineVariant.withOpacity(0.5),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.loyalty,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      voucher['code'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      voucher['title'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: onSurface,
                                      ),
                                    ),
                                    Text(
                                      voucher['desc'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Radio<String>(
                                value: voucher['code'],
                                groupValue: selectedVoucherCode,
                                activeColor: primaryColor,
                                onChanged: (val) {
                                  setState(() {
                                    selectedVoucherCode = voucher['code'];
                                    voucherDiscount = voucher['discount'];
                                    selectedVoucherTitle = voucher['title'];
                                  });
                                  Navigator.pop(modalContext);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleConfirmBooking() async {
    // Không báo thành công giả lập khi chưa có đủ dữ liệu để tạo đơn thật.
    if (widget.pickupAddress.trim().isEmpty ||
        widget.deliveryAddress.trim().isEmpty ||
        widget.contactPhone.trim().isEmpty ||
        widget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa đủ thông tin tạo đơn. Cần truyền địa chỉ, số điện thoại và dịch vụ đã chọn từ bước trước.',
          ),
        ),
      );
      return;
    }

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập trước khi đặt lịch.')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/Orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'pickupAddress': widget.pickupAddress.trim(),
          'deliveryAddress': widget.deliveryAddress.trim(),
          'contactPhone': widget.contactPhone.trim(),
          'note': widget.note,
          'items': widget.items,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Không thể tạo đơn hàng (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {
          // Giữ thông báo mặc định nếu API không trả JSON.
        }
        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['orderId'] == null) {
        throw Exception(
          'API tạo đơn thành công nhưng không trả về mã đơn hàng.',
        );
      }
      final orderId = (decoded['orderId'] as num).toInt();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            orderId: orderId,
            orderCode: 'WS3T-${orderId.toString().padLeft(4, '0')}',
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đặt đơn thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.95),
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
        title: Text(
          '3. Xác Nhận Đơn & Tạm Tính (Bước 3/3)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 130,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepperHeader(),
                const SizedBox(height: 12),
                _buildGuaranteeBanner(),
                const SizedBox(height: 16),
                _buildSelectedServiceCard(),
                const SizedBox(height: 16),
                _buildScheduleAndAddressCard(),
                const SizedBox(height: 16),
                _buildPromotionsCard(),
                const SizedBox(height: 16),
                _buildPriceBreakdownCard(),
                const SizedBox(height: 12),
                _buildImportantNoticeBox(),
                const SizedBox(height: 16),
                _buildPaymentMethodSection(),
              ],
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                'Gói giặt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              height: 2,
              color: secondaryColor,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                'Lịch & Địa chỉ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              height: 2,
              color: primaryColor,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Tạm tính',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cam kết Tinh Tươm 3T',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  'Cân đúng chuẩn • Giặt riêng từng mẻ • Thơm ngát sợi vải',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, size: 22, color: outlineVariant),
        ],
      ),
    );
  }

  Widget _buildSelectedServiceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_laundry_service,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dịch vụ đã chọn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '5.0 kg • 12 món',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAFYvhLJ9jbLqd_6SVUWX2xC8BTqUDBmxDY9DM8KLO6wuQE2JpTdvkMBiQKc4sI-bXlyDkgUCQKh0z4vnlnRy_PjvRt6uQq6OXnjCYrvQ_OVo_oU_DrbUp4H80RC3pkEwl5s5VK8ZopV_vWlBU6DCFQ4QBGrLR_p4lehxbDOPPjU8TuuiaPcC3sskA1xEKtLXiN0BDMbptpAXMLubTWXXk73BeSe1l9oH-JSP6wmpgLt6j7vgEeMV0Qvw',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            '115.000 đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giặt nước nóng, sấy khử khuẩn 70°C',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _buildSmallTag(
                            Icons.iron,
                            'Ủi hơi nước',
                            primaryColor,
                          ),
                          _buildSmallTag(
                            Icons.wb_sunny,
                            'Hương ban mai',
                            tertiaryColor,
                          ),
                          _buildSmallTag(
                            Icons.lock,
                            'Túi niêm phong 3T',
                            secondaryColor,
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

  Widget _buildSmallTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleAndAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.two_wheeler, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Lịch Shipper & Địa chỉ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Giao tận cửa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tertiaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryFixed,
                  child: Text(
                    'KN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Kiều Như',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            ' • 0908 123 456',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Q.1, TP.HCM',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.call_received,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SHIPPER LẤY ĐỒ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '14:00 - 16:00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        'Hôm nay (24/10)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.call_made,
                            size: 14,
                            color: tertiaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GIAO TRẢ SẠCH THƠM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: tertiaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '10:00 - 12:00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        'Ngày mai (25/10)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: onSurfaceVariant,
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
    );
  }

  // --- WIDGET 5: ƯU ĐÃI & KHUYẾN MÃI (ĐÃ SỬA NÚT "ĐỔI MÃ" ĐỂ MỞ MODAL) ---
  Widget _buildPromotionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.redeem, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Ưu đãi & Khuyến mãi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'Ví xu: '),
                    TextSpan(
                      text: '12.500',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.loyalty,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedVoucherCode,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Tiết kiệm ${_formatCurrency(voucherDiscount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          selectedVoucherTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // 🚀 Bấm nút Đổi mã để mở Modal chọn Voucher
                TextButton(
                  onPressed: _showVoucherBottomSheet,
                  style: TextButton.styleFrom(
                    backgroundColor: surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Đổi mã',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: tertiaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.toll,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dùng 5.000 3T Xu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          'Trừ trực tiếp 5.000 đ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: tertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isCoinUsed,
                  activeColor: primaryColor,
                  onChanged: (val) => setState(() => isCoinUsed = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tạm tính minh bạch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPriceRow('Tiền giặt sấy', 'Chờ shipper cân/đếm'),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'Phí vận chuyển 2 chiều (Lấy & Giao)',
                  _formatCurrency(shippingFee),
                ),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'Mã giảm giá',
                  'Áp dụng sau khi chốt giá',
                  textColor: onSurfaceVariant,
                  icon: Icons.sell,
                ),
                if (isCoinUsed) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Đổi 3T Xu tích lũy',
                    '-${_formatCurrency(coinDiscount)}',
                    textColor: tertiaryColor,
                    icon: Icons.toll,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phí hiện biết (chưa phải tổng cuối)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      'Tổng tiền cập nhật sau khi shipper xác nhận đồ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Chưa chốt',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

  Widget _buildPriceRow(
    String label,
    String value, {
    Color? textColor,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor ?? onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: textColor ?? onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor ?? onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildImportantNoticeBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: onSurfaceVariant,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Lưu ý quan trọng: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Đây là số tiền tạm tính dựa trên số kg bạn ước lượng. Khi tới lấy đồ, Shipper 3T sẽ mang theo cân điện tử kiểm tra chính xác công khai trước mặt bạn và xuất hóa đơn chuẩn xác nhất.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, color: primaryColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Phương thức thanh toán',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPaymentOptionTile(
            value: 'pickup_weigh',
            icon: Icons.scale,
            iconColor: primaryColor,
            title: 'Thanh toán khi Shipper tới cân đồ',
            sub:
                'Thanh toán tiền mặt hoặc quét VietQR ngay sau khi Shipper kiểm tra số kg thực tế tại cửa',
          ),
          const SizedBox(height: 8),
          _buildPaymentOptionTile(
            value: 'delivery_done',
            icon: Icons.inventory_2,
            iconColor: secondaryColor,
            title: 'Thanh toán khi nhận lại đồ sạch',
            sub:
                'Thanh toán tiền mặt hoặc quét VietQR sau khi kiểm tra đồ giặt sấy thơm tho nguyên seal',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String sub,
  }) {
    final bool isSelected = paymentMethod == value;

    return InkWell(
      onTap: () => setState(() => paymentMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: isSelected ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: paymentMethod,
              activeColor: primaryColor,
              onChanged: (val) {
                if (val != null) setState(() => paymentMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: cardBg.withOpacity(0.98),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(top: BorderSide(color: surfaceContainer)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tạm tính thanh toán',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Chưa chốt',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(sau khi shipper cân/đếm)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _handleConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Xác nhận đặt lịch',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
