import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'booking_success_screen.dart';

class BookingStep3Screen extends StatefulWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final String customerName;
  final String contactPhone;
  final String? note;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> selectedCareOptions;
  final double estimatedWeight;
  final String pickupTime;
  final String deliveryTime;
  final int expressFee;
  final int addonFee;
  final double distanceKm;

  const BookingStep3Screen({
    super.key,
    this.pickupAddress = '',
    this.deliveryAddress = '',
    this.customerName = '',
    this.contactPhone = '',
    this.note,
    this.items = const [],
    this.selectedCareOptions = const [],
    this.estimatedWeight = 3.0,
    this.pickupTime = '14:00 – 16:00 Hôm nay',
    this.deliveryTime = '10:00 – 12:00 Ngày mai (Chuẩn 24h)',
    this.expressFee = 0,
    this.addonFee = 0,
    this.distanceKm = 2.5,
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
  static const Color outlineColor = Color(0xFF8F6F71);

  // --- STATE TÀI KHOẢN NGƯỜI ĐĂNG NHẬP ---
  String currentCustomerName = '';
  String currentContactPhone = '';

  @override
  void initState() {
    super.initState();
    currentCustomerName = widget.customerName.trim();
    currentContactPhone = widget.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      if (currentCustomerName.isEmpty) {
        final cached = await AuthService.getFullName();
        if (cached != null && cached.isNotEmpty && mounted) {
          setState(() => currentCustomerName = cached);
        }
      }
      if (currentContactPhone.isEmpty) {
        final cachedPhone = await AuthService.getPhone();
        if (cachedPhone != null && cachedPhone.isNotEmpty && mounted) {
          setState(() => currentContactPhone = cachedPhone);
        }
      }
      // Luôn kiểm tra từ API /Auth/me để có dữ liệu tài khoản đăng nhập tươi mới
      if (currentCustomerName.isEmpty || currentContactPhone.isEmpty) {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) {
          final res = await http.get(
            Uri.parse('${ApiService.baseUrl}/Auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (mounted && data is Map) {
              setState(() {
                if (currentCustomerName.isEmpty && data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
                  currentCustomerName = data['fullName'].toString();
                }
                if (currentContactPhone.isEmpty && data['phone'] != null && data['phone'].toString().isNotEmpty) {
                  currentContactPhone = data['phone'].toString().replaceAll(RegExp(r'[^0-9+]'), '');
                }
              });
            }
          }
        }
      }
      // Kiểm tra lịch sử đơn hàng để xác định khách hàng mới
      try {
        final orders = await ApiService.getMyOrders();
        if (mounted) {
          setState(() {
            _isNewCustomer = orders.isEmpty;
          });
        }
      } catch (_) {}
    } catch (_) {}
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'KH';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // --- STATE TÍNH TIỀN & ĐẶT ĐƠN ---
  bool isCoinUsed = false;
  bool isSubmitting = false;
  bool _isNewCustomer = true;

  // Tạm tính giá giặt theo khối lượng ước tính hoặc số lượng cái
  int get washPrice {
    int sum = 0;
    for (final item in widget.items) {
      final num unitPrice = (item['unitPrice'] as num?) ?? 0;
      final num qty = (item['quantity'] as num?) ?? (item['isByItem'] == true ? 1 : widget.estimatedWeight);
      sum += (unitPrice * qty).round();
    }
    return sum;
  }

  int get orderSubtotal => washPrice + widget.addonFee;

  int get travelTimeMinutes {
    if (widget.distanceKm <= 0.2) return 2;
    final minutes = ((widget.distanceKm / 22.0) * 60).round() + 2;
    return math.max(3, minutes);
  }

  final int shippingFee = 30000;
  final int coinDiscount = 5000;

  // State Voucher đang chọn
  String selectedVoucherCode = '';
  int voucherDiscount = 0;
  String selectedVoucherTitle = 'Chưa áp dụng mã giảm giá';

  // Danh sách các voucher khả dụng với đầy đủ điều kiện rõ ràng
  final List<Map<String, dynamic>> availableVouchers = [
    {
      'code': '3TCHAOBAN',
      'title': 'Giảm 20.000 đ đơn đầu tiên',
      'discount': 20000,
      'minOrder': 0,
      'desc': 'Áp dụng cho khách hàng mới của WashSmart 3T',
      'requiresNewUser': true,
    },
    {
      'code': 'WASH3T30K',
      'title': 'Giảm 30.000 đ đơn từ 100k',
      'discount': 30000,
      'minOrder': 100000,
      'desc': 'Ưu đãi giặt sấy nguyên mẻ tinh tươm (Đơn từ 100.000 đ)',
      'requiresNewUser': false,
    },
    {
      'code': 'FREESHIP3T',
      'title': 'Miễn phí vận chuyển 2 chiều',
      'discount': 30000,
      'minOrder': 0,
      'desc': 'Trừ trực tiếp 30.000 đ phí vận chuyển 2 chiều',
      'requiresNewUser': false,
    },
  ];

  bool isVoucherEligible(Map<String, dynamic> voucher) {
    final int minOrder = (voucher['minOrder'] as num?)?.toInt() ?? 0;
    final bool requiresNewUser = voucher['requiresNewUser'] == true;
    if (orderSubtotal < minOrder) return false;
    if (requiresNewUser && !_isNewCustomer) return false;
    return true;
  }

  String getVoucherIneligibleReason(Map<String, dynamic> voucher) {
    final int minOrder = (voucher['minOrder'] as num?)?.toInt() ?? 0;
    final bool requiresNewUser = voucher['requiresNewUser'] == true;
    if (orderSubtotal < minOrder) {
      final int diff = minOrder - orderSubtotal;
      return 'Đơn từ ${_formatCurrency(minOrder)} đ (Còn thiếu ${_formatCurrency(diff)} đ)';
    }
    if (requiresNewUser && !_isNewCustomer) {
      return 'Chỉ áp dụng cho đơn đầu tiên của khách hàng mới';
    }
    return '';
  }

  int get finalPrice {
    int total = washPrice + shippingFee + widget.expressFee + widget.addonFee - voucherDiscount - (isCoinUsed ? coinDiscount : 0);
    return total < 0 ? 0 : total;
  }

  // 🚀 Hàm hiển thị Bottom Sheet chọn Voucher
  void _showVoucherBottomSheet() {
    final TextEditingController manualInputController = TextEditingController();
    bool isVerifyingCode = false;

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
              child: SingleChildScrollView(
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
                            controller: manualInputController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Nhập mã ưu đãi (VD: WASH3T30K)...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: outlineColor,
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
                          onPressed: isVerifyingCode
                              ? null
                              : () async {
                                  final typed = manualInputController.text.trim().toUpperCase();
                                  if (typed.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vui lòng nhập mã ưu đãi.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  // 1. Kiểm tra trong danh sách cục bộ trước
                                  final localMatch = availableVouchers.firstWhere(
                                    (v) => (v['code'] as String).toUpperCase() == typed,
                                    orElse: () => {},
                                  );

                                  if (localMatch.isNotEmpty) {
                                    if (!isVoucherEligible(localMatch)) {
                                      final reason = getVoucherIneligibleReason(localMatch);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Không đủ điều kiện áp dụng mã $typed: $reason'),
                                          backgroundColor: const Color(0xFF93000A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      selectedVoucherCode = localMatch['code'];
                                      voucherDiscount = localMatch['discount'];
                                      selectedVoucherTitle = localMatch['title'];
                                    });
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã áp dụng mã $typed! Giảm ${_formatCurrency(localMatch['discount'])} đ'),
                                        backgroundColor: const Color(0xFF006878),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  // 2. Xác thực với Backend API
                                  setModalState(() => isVerifyingCode = true);
                                  try {
                                    final res = await ApiService.verifyPromotion(
                                      code: typed,
                                      orderAmount: orderSubtotal.toDouble(),
                                    );
                                    if (!mounted) return;
                                    if (res['valid'] == true) {
                                      final disc = (res['discountAmount'] as num?)?.toInt() ?? 0;
                                      final title = res['title']?.toString() ?? 'Mã $typed';
                                      setState(() {
                                        selectedVoucherCode = typed;
                                        voucherDiscount = disc;
                                        selectedVoucherTitle = title;
                                      });
                                      Navigator.pop(modalContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message']?.toString() ?? 'Áp dụng mã $typed thành công!'),
                                          backgroundColor: const Color(0xFF006878),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message']?.toString() ?? 'Mã ưu đãi không hợp lệ.'),
                                          backgroundColor: const Color(0xFF93000A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Mã không hợp lệ hoặc lỗi kết nối: $e'),
                                        backgroundColor: const Color(0xFF93000A),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } finally {
                                    setModalState(() => isVerifyingCode = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isVerifyingCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
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

                    // Tiêu đề & giá trị đơn hàng hiện tại
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã ưu đãi dành cho bạn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Đơn hiện tại: ${_formatCurrency(orderSubtotal)} đ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Danh sách Voucher
                    Column(
                      children: availableVouchers.map((voucher) {
                        final bool isSelected = selectedVoucherCode == voucher['code'];
                        final bool eligible = isVoucherEligible(voucher);
                        final String ineligibilityReason = eligible ? '' : getVoucherIneligibleReason(voucher);

                        return Opacity(
                          opacity: eligible ? 1.0 : 0.6,
                          child: InkWell(
                            onTap: () {
                              if (!eligible) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Color(0xFFFFDAD6), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Không đủ điều kiện: $ineligibilityReason',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF93000A),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                );
                                return;
                              }

                              if (isSelected) {
                                setState(() {
                                  selectedVoucherCode = '';
                                  voucherDiscount = 0;
                                  selectedVoucherTitle = 'Chưa áp dụng mã giảm giá';
                                });
                                Navigator.pop(modalContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Đã gỡ bỏ mã giảm giá'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                );
                              } else {
                                setState(() {
                                  selectedVoucherCode = voucher['code'];
                                  voucherDiscount = voucher['discount'];
                                  selectedVoucherTitle = voucher['title'];
                                });
                                Navigator.pop(modalContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã áp dụng mã ${voucher['code']} - Giảm ${_formatCurrency(voucher['discount'])} đ'),
                                    backgroundColor: const Color(0xFF006878),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? surfaceLow : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : (eligible ? outlineVariant.withOpacity(0.5) : const Color(0xFFFECACA)),
                                  width: isSelected ? 1.8 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: eligible ? primaryContainer : Colors.grey.shade400,
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
                                            Row(
                                              children: [
                                                Text(
                                                  voucher['code'],
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: eligible ? primaryColor : Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? primaryFixed
                                                        : (eligible ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isSelected
                                                        ? 'Đang chọn'
                                                        : (eligible ? 'Đủ điều kiện' : 'Chưa đủ điều kiện'),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected
                                                          ? primaryColor
                                                          : (eligible ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
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
                                      if (eligible)
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
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  if (!eligible) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 12, color: Color(0xFFB91C1C)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              ineligibilityReason,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF991B1B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (selectedVoucherCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedVoucherCode = '';
                              voucherDiscount = 0;
                              selectedVoucherTitle = 'Chưa áp dụng mã giảm giá';
                            });
                            Navigator.pop(modalContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã gỡ bỏ mã giảm giá.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFFB91C1C)),
                          label: Text(
                            'Không dùng mã giảm giá',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleConfirmBooking() async {
    final rawPhone = currentContactPhone.isNotEmpty
        ? currentContactPhone
        : widget.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleanPhone = rawPhone.isNotEmpty ? rawPhone : '';
    final safePickupAddress = widget.pickupAddress.trim().isNotEmpty
        ? widget.pickupAddress.trim()
        : '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. Hồ Chí Minh';
    final safeDeliveryAddress = widget.deliveryAddress.trim().isNotEmpty
        ? widget.deliveryAddress.trim()
        : safePickupAddress;
    final safeItems = (widget.items.isNotEmpty
            ? widget.items
            : [
                {'serviceId': 7, 'quantity': widget.estimatedWeight}
              ])
        .map((it) {
          final isByItem = it['isByItem'] == true;
          final num rawQty = (it['quantity'] as num?) ?? 0;
          final num finalQty = rawQty > 0
              ? (isByItem ? rawQty.round() : rawQty.toDouble())
              : (isByItem ? 1 : widget.estimatedWeight);
          return {
            'serviceId': (it['serviceId'] as num?)?.toInt() ?? 7,
            'quantity': finalQty,
          };
        })
        .toList();

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập trước khi đặt lịch.')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final fullNote = [
        widget.note?.trim(),
        'Thanh toán khi nhận đồ (Tiền mặt / VietQR)',
        if (selectedVoucherCode.isNotEmpty) 'Voucher: $selectedVoucherCode',
      ].where((s) => s != null && s.isNotEmpty).join(' | ');

      final totalDiscount = voucherDiscount + (isCoinUsed ? coinDiscount : 0);
      final totalShipping = 30000 + widget.expressFee;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/Orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'pickupAddress': safePickupAddress,
          'deliveryAddress': safeDeliveryAddress,
          'contactPhone': cleanPhone,
          'note': fullNote,
          'shippingFee': totalShipping,
          'addonFee': widget.addonFee,
          'discountAmount': totalDiscount,
          'paymentMethod': 'COD',
          'orderType': 'Delivery',
          'distanceKm': widget.distanceKm,
          'items': safeItems,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Không thể tạo đơn hàng (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
              message = decoded['message'].toString();
            } else if (decoded['errors'] is Map) {
              final errMap = decoded['errors'] as Map;
              final errorsList = <String>[];
              for (var err in errMap.values) {
                if (err is List) {
                  errorsList.addAll(err.map((e) => e.toString()));
                } else if (err != null) {
                  errorsList.add(err.toString());
                }
              }
              if (errorsList.isNotEmpty) {
                message = errorsList.join(' | ');
              } else if (decoded['title'] != null) {
                message = decoded['title'].toString();
              }
            } else if (decoded['title'] != null) {
              message = decoded['title'].toString();
            }
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
            pickupAddress: widget.pickupAddress,
            deliveryAddress: widget.deliveryAddress,
            contactPhone: widget.contactPhone,
            pickupTime: widget.pickupTime,
            deliveryTime: widget.deliveryTime,
            items: widget.items,
            selectedCareOptions: widget.selectedCareOptions,
            estimatedWeight: widget.estimatedWeight,
            washPrice: washPrice,
            shippingFee: shippingFee,
            expressFee: widget.expressFee,
            addonFee: widget.addonFee,
            voucherDiscount: voucherDiscount,
            selectedVoucherCode: selectedVoucherCode,
            isCoinUsed: isCoinUsed,
            coinDiscount: isCoinUsed ? coinDiscount : 0,
            finalPrice: finalPrice,
            paymentMethod: 'Tiền mặt / Quét VietQR khi nhận đồ',
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

  String _formatCurrency(num amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
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
    final totalPieces = widget.items
        .where((it) => it['isByItem'] == true)
        .fold<int>(0, (prev, it) => prev + ((it['quantity'] as num?)?.toInt() ?? 0));
    final hasKg = widget.items.any((it) => it['isByItem'] != true);
    String headerBadge = '';
    if (hasKg && widget.estimatedWeight > 0) {
      headerBadge = '${widget.estimatedWeight.toStringAsFixed(1)} kg';
    }
    if (totalPieces > 0) {
      headerBadge = headerBadge.isNotEmpty ? '$headerBadge • $totalPieces món' : '$totalPieces món';
    }
    if (headerBadge.isEmpty) {
      headerBadge = '${widget.items.length} dịch vụ';
    }

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
                  headerBadge,
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

          // Render động danh sách dịch vụ khách đã chọn từ Bước 1
          ...widget.items.map((it) {
            final name = it['name']?.toString() ?? 'Dịch vụ giặt';
            final isByItem = it['isByItem'] == true;
            final unit = it['unit']?.toString() ?? (isByItem ? 'cái' : 'kg');
            final num unitPrice = (it['unitPrice'] as num?) ?? 0;
            final num qty = (it['quantity'] as num?) ?? (isByItem ? 1 : widget.estimatedWeight);
            final num lineTotal = (it['totalPrice'] as num?) ?? (unitPrice * qty).round();
            final desc = it['description']?.toString() ??
                (isByItem ? 'Kiểm đếm theo số lượng món thực tế' : 'Giặt nước kháng khuẩn, sấy nhiệt dịu chống co rút');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(12),
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
          }),

          // Hiển thị động các gói chăm sóc nâng cao mà khách đã tick chọn
          if (widget.selectedCareOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Tiện ích chăm sóc đã chọn:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceVariant,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selectedCareOptions.map((opt) {
                final name = opt['name']?.toString() ?? 'Tiện ích';
                final price = (opt['price'] as num?)?.toInt() ?? 0;
                final badge = price > 0 ? '+${_formatCurrency(price)}đ' : 'Miễn phí';
                return _buildSmallTag(
                  Icons.verified,
                  '$name ($badge)',
                  primaryColor,
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildSmallTag(Icons.verified, 'Chuẩn giặt sấy 3T', primaryColor),
                _buildSmallTag(Icons.thermostat, 'Sấy nhiệt dịu chống co rút', tertiaryColor),
                _buildSmallTag(Icons.lock, 'Túi niêm phong 3T', secondaryColor),
              ],
            ),
          ],
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
                    _getInitials(currentCustomerName),
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
                            currentCustomerName.isNotEmpty ? currentCustomerName : 'Khách hàng',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          if (currentContactPhone.isNotEmpty || widget.contactPhone.isNotEmpty)
                            Text(
                              ' • ${currentContactPhone.isNotEmpty ? currentContactPhone : widget.contactPhone}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_upward, size: 12, color: primaryColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Lấy: ${widget.pickupAddress.isNotEmpty ? widget.pickupAddress : '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.deliveryAddress.isNotEmpty && widget.deliveryAddress != widget.pickupAddress) ...[
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_downward, size: 12, color: tertiaryColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Giao trả: ${widget.deliveryAddress}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tertiaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, size: 11, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Bán kính: ~${widget.distanceKm} km • ~$travelTimeMinutes phút di chuyển (Hợp lệ ≤ 10km từ 140 Lê Trọng Tấn)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
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
                        widget.pickupTime,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                        widget.deliveryTime,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selectedVoucherCode.isNotEmpty ? primaryContainer : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.loyalty,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectedVoucherCode.isNotEmpty) ...[
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
                                      'Tiết kiệm ${_formatCurrency(voucherDiscount)} đ',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else ...[
                              Text(
                                'Chưa áp dụng mã ưu đãi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                              Text(
                                'Nhấn để chọn mã giảm giá từ 3T',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedVoucherCode.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.cancel, size: 18, color: onSurfaceVariant),
                        tooltip: 'Gỡ bỏ mã',
                        onPressed: () {
                          setState(() {
                            selectedVoucherCode = '';
                            voucherDiscount = 0;
                            selectedVoucherTitle = 'Chưa áp dụng mã giảm giá';
                          });
                        },
                      ),
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
                        selectedVoucherCode.isNotEmpty ? 'Đổi mã' : 'Chọn mã',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
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
                _buildPriceRow(
                  'Tiền giặt sấy (tạm tính theo ước lượng)',
                  '${_formatCurrency(washPrice)} đ',
                  textColor: primaryColor,
                  icon: Icons.local_laundry_service,
                ),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'Phí vận chuyển 2 chiều',
                  '${_formatCurrency(shippingFee)} đ',
                  icon: Icons.two_wheeler,
                ),
                if (widget.addonFee > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Phụ phí tiện ích chăm sóc',
                    '+${_formatCurrency(widget.addonFee)} đ',
                    textColor: primaryColor,
                    icon: Icons.auto_awesome,
                  ),
                ],
                if (widget.expressFee > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Phụ phí giao gấp hỏa tốc (≤5km)',
                    '+${_formatCurrency(widget.expressFee)} đ',
                    textColor: primaryColor,
                    icon: Icons.bolt,
                  ),
                ],
                if (voucherDiscount > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Mã giảm giá ($selectedVoucherCode)',
                    '-${_formatCurrency(voucherDiscount)} đ',
                    textColor: primaryColor,
                    icon: Icons.sell,
                  ),
                ],
                if (isCoinUsed) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Đổi 3T Xu tích lũy',
                    '-${_formatCurrency(coinDiscount)} đ',
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
                      'Tổng tạm tính dự kiến',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      'Chốt chuẩn sau khi shipper cân đo thực tế',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_formatCurrency(finalPrice)} đ',
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
                        '${_formatCurrency(finalPrice)} đ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(dự kiến)',
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
