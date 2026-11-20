import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'booking_step3_screen.dart'; // 🚀 Giữ nguyên luồng chuyển sang Bước 3

class BookingStep2Screen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String pickupAddress;
  final String contactPhone;
  final String initialNote;
  final int addonFee;

  const BookingStep2Screen({
    super.key,
    this.items = const [],
    this.pickupAddress =
        'Căn hộ Heritage Manor, Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    this.contactPhone = '0908123456',
    this.initialNote = '',
    this.addonFee = 0,
  });

  @override
  State<BookingStep2Screen> createState() => _BookingStep2ScreenState();
}

class _BookingStep2ScreenState extends State<BookingStep2Screen> {
  // Brand Color Tokens WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color primaryFixed = Color(0xFFFFDADB);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color secondaryFixed = Color(0xFFFFD9E4);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color tertiaryFixed = Color(0xFFACEDFF);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceContainer = Color(0xFFFFE9EA);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color surfaceVariant = Color(0xFFFFD9DC);
  static const Color onSurface = Color(0xFF370C14);
  static const Color onSurfaceVariant = Color(0xFF5B4041);

  // --- STATE QUẢN LÝ ---
  int shippingFee = 30000; // Phí vận chuyển 2 chiều
  int selectedDateIndex = 0; // 0: hôm nay, 1: ngày mai, 2: ngày kia
  int selectedTimeSlot = 0; // Sẽ được tự động tính toán trong initState
  bool isSameDeliveryAddress = true; // Giao trả về cùng địa chỉ lấy

  late final TextEditingController _pickupNoteController;
  String userPhone = '0908123456';
  String userName = 'Kiều Như';

  // 🚀 Logic kiểm tra khung giờ hết hạn theo thời gian thực (Lead Time Buffer)
  bool _isSlotExpired(int slotIndex, int dateIndex) {
    if (dateIndex > 0) return false;
    final now = DateTime.now();
    // Ca 0: Hỏa tốc trong 30-45 phút. Đóng sau 20:00 tối
    if (slotIndex == 0) {
      return now.hour >= 20;
    }
    // Ca 1: 08:00 – 10:00. Đóng lúc 09:30
    if (slotIndex == 1) {
      return now.hour > 9 || (now.hour == 9 && now.minute >= 30);
    }
    // Ca 2: 10:00 – 12:00. Đóng lúc 11:30
    if (slotIndex == 2) {
      return now.hour > 11 || (now.hour == 11 && now.minute >= 30);
    }
    // Ca 3: 14:00 – 16:00. Đóng lúc 15:30
    if (slotIndex == 3) {
      return now.hour > 15 || (now.hour == 15 && now.minute >= 30);
    }
    // Ca 4: 17:00 – 19:00. Đóng lúc 18:30
    if (slotIndex == 4) {
      return now.hour > 18 || (now.hour == 18 && now.minute >= 30);
    }
    // Ca 5: 19:30 – 21:00. Đóng lúc 20:30
    if (slotIndex == 5) {
      return now.hour > 20 || (now.hour == 20 && now.minute >= 30);
    }
    return false;
  }

  bool _areAllSlotsExpiredToday() {
    for (int i = 0; i < 6; i++) {
      if (!_isSlotExpired(i, 0)) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Tự động kiểm tra thời gian thực để chọn ngày và ca hợp lệ
    if (_areAllSlotsExpiredToday()) {
      selectedDateIndex = 1; // Tự động sang Ngày mai nếu hôm nay đã hết ca (sau 20:30)
      selectedTimeSlot = 1; // 08:00 - 10:00 sáng mai
    } else {
      selectedDateIndex = 0;
      selectedTimeSlot = 0;
      for (int i = 0; i < 6; i++) {
        if (!_isSlotExpired(i, 0)) {
          selectedTimeSlot = i;
          break;
        }
      }
    }

    final defaultNote = 'Bấm chuông căn 302 lầu 3 hoặc gửi lễ tân sảnh A';
    _pickupNoteController = TextEditingController(
      text: [
        widget.initialNote.trim(),
        defaultNote,
      ].where((note) => note.isNotEmpty).join(' | '),
    );
    userPhone = widget.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (userPhone.isEmpty) userPhone = '0908123456';
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
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
              if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
                userPhone = data['phone'].toString().replaceAll(RegExp(r'[^0-9+]'), '');
              }
              if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
                userName = data['fullName'].toString();
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  // Giá giặt chưa xác định cho đến khi shipper cân/đếm thực tế.
  int get expressFee => (selectedTimeSlot == 0) ? 25000 : 0;
  int get transportTotal => shippingFee + expressFee;

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
                  fontSize: 13,
                  color: Colors.white,
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

  @override
  void dispose() {
    _pickupNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,

      // --- 1. HEADER APP BAR ---
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: onSurface, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Đặt Dịch Vụ Bước 2',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
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

      // --- NỘI DUNG CHÍNH ---
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
                // 1. STEPPER PROGRESS TRACKER
                _buildStepperProgressTracker(),
                const SizedBox(height: 12),

                // 2. STEP 1 QUICK SUMMARY CARD
                _buildStep1SummaryCard(),
                const SizedBox(height: 16),

                // 3. PICKUP ADDRESS SECTION
                _buildPickupAddressSection(),
                const SizedBox(height: 16),

                // 4. PICKUP SCHEDULE SECTION
                _buildPickupScheduleSection(),
                const SizedBox(height: 16),

                // 5. DELIVERY METHOD & EXPECTED RETURN TIME
                _buildDeliveryMethodSection(),
                const SizedBox(height: 16),

                // 6. SHIPPING FEE TRANSPARENCY
                _buildShippingFeeSection(),
              ],
            ),
          ),

          // --- 7. STICKY BOTTOM CHECKOUT ACTION BAR ---
          _buildBottomActionBar(context),
        ],
      ),
    );
  }

  // --- WIDGET 1: STEPPER PROGRESS TRACKER ---
  Widget _buildStepperProgressTracker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BƯỚC 2 TRÊN 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                'Lịch hẹn & Địa chỉ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Step 1 Completed
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gói giặt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider Line 1
              Expanded(
                child: Container(
                  height: 3,
                  color: primaryColor,
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),

              // Step 2 Active
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryFixed, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          '2',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lịch & Vị trí',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider Line 2
              Expanded(
                child: Container(
                  height: 3,
                  color: surfaceVariant,
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),

              // Step 3 Inactive
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '3',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Xác nhận',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET 2: STEP 1 QUICK SUMMARY CARD ---
  Widget _buildStep1SummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: secondaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_laundry_service,
                  size: 20,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Gói Giặt Sấy Tinh Tươm',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryFixed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Chờ cân/đếm thực tế',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3E0022),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Giá giặt sẽ được xác nhận khi shipper nhận đồ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
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
                'Chưa chốt giá',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                'Chờ shipper xác nhận',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: tertiaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET 3: PICKUP ADDRESS SECTION ---
  Widget _buildPickupAddressSection() {
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
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pin_drop,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Địa chỉ Shipper tới lấy đồ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showToast('Chức năng Đổi địa chỉ sắp ra mắt!'),
                child: Row(
                  children: [
                    Text(
                      'Đổi địa chỉ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Address Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          ' • $userPhone',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'MẶC ĐỊNH',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Text(
                  'Căn hộ Heritage Manor, Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Quận 1, TP. Hồ Chí Minh',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: tertiaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Địa chỉ đã xác thực vệ tinh 3T Express',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: tertiaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Shipper Note Input
          Text(
            'Ghi chú vị trí lấy đồ cho Shipper:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pickupNoteController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: onSurface,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _showToast('Đang thu âm ghi chú giọng nói...'),
                  icon: const Icon(
                    Icons.mic,
                    size: 18,
                    color: onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 4: PICKUP SCHEDULE SECTION ---
  Widget _buildPickupScheduleSection() {
    final today = DateTime.now();
    final dates = List<DateTime>.generate(
      3,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
    const weekdays = <String>[
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    String dateLabel(DateTime date, int index) {
      final day =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      if (index == 0) {
        return _areAllSlotsExpiredToday() ? 'Hôm nay ($day) • Hết ca' : 'Hôm nay ($day)';
      }
      if (index == 1) return 'Ngày mai ($day)';
      return '${weekdays[date.weekday - 1]} ($day)';
    }

    final dateOptions = List<String>.generate(
      dates.length,
      (index) => dateLabel(dates[index], index),
    );

    final timeSlots = [
      {
        'title': 'Lấy gấp hỏa tốc (trong 30–45 phút)',
        'timeRange': 'Gấp trong 30–45 phút',
        'period': 'Hỏa tốc',
        'sub': 'Shipper điều phối ngay • Giao sau 3.5 – 4 giờ (bán kính ≤ 5km)',
        'badge': 'Hỏa tốc 4h',
        'badgeBg': const Color(0xFFFFDAD6),
        'badgeText': const Color(0xFF93000A),
        'price': '+25.000 đ',
        'isPricePrimary': true,
        'extraFee': 25000,
      },
      {
        'title': '08:00 – 10:00',
        'timeRange': '08:00 – 10:00',
        'period': 'Sáng',
        'sub': 'Khung giờ buổi sáng • Shipper ca sớm',
        'badge': 'Buổi sáng',
        'badgeBg': secondaryFixed,
        'badgeText': const Color(0xFF3E0022),
        'price': 'Miễn phí',
        'isPricePrimary': false,
        'extraFee': 0,
      },
      {
        'title': '10:00 – 12:00',
        'timeRange': '10:00 – 12:00',
        'period': 'Trưa',
        'sub': 'Khung giờ trưa • Tiếp nhận trước ca giặt trưa',
        'badge': 'Buổi trưa',
        'badgeBg': surfaceContainer,
        'badgeText': onSurfaceVariant,
        'price': 'Miễn phí',
        'isPricePrimary': false,
        'extraFee': 0,
      },
      {
        'title': '14:00 – 16:00',
        'timeRange': '14:00 – 16:00',
        'period': 'Chiều',
        'sub': 'Shipper khu vực Bến Nghé đang sẵn sàng',
        'badge': 'Tối ưu nhất',
        'badgeBg': tertiaryFixed,
        'badgeText': const Color(0xFF001F26),
        'price': 'Miễn phí',
        'isPricePrimary': false,
        'extraFee': 0,
      },
      {
        'title': '17:00 – 19:00',
        'timeRange': '17:00 – 19:00',
        'period': 'Chiều tối',
        'sub': 'Khung giờ tan tầm • Shipper lấy sau giờ làm',
        'badge': 'Tan tầm',
        'badgeBg': surfaceVariant,
        'badgeText': onSurface,
        'price': 'Miễn phí',
        'isPricePrimary': false,
        'extraFee': 0,
      },
      {
        'title': '19:30 – 21:00',
        'timeRange': '19:30 – 21:00',
        'period': 'Tối',
        'sub': 'Khung giờ tối • Thích hợp khi về nhà trễ',
        'badge': 'Ca tối',
        'badgeBg': surfaceContainer,
        'badgeText': onSurfaceVariant,
        'price': 'Miễn phí',
        'isPricePrimary': false,
        'extraFee': 0,
      },
    ];

    String getSlotTitle(int index) {
      if (index == 0) return timeSlots[0]['title'] as String;
      final base = timeSlots[index]['title'] as String;
      final period = timeSlots[index]['period'] as String;
      if (selectedDateIndex == 0) {
        return '$base ($period nay)';
      } else if (selectedDateIndex == 1) {
        return '$base ($period mai)';
      } else {
        return '$base ($period)';
      }
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
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: secondaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event, size: 18, color: secondaryColor),
              ),
              const SizedBox(width: 8),
              Text(
                'Thời gian Shipper tới lấy',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date selector pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(dateOptions.length, (index) {
                final isSelected = selectedDateIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedDateIndex = index;
                        // Nếu ca hiện tại bị hết hạn ở ngày mới, chuyển sang ca mở đầu tiên
                        if (_isSlotExpired(selectedTimeSlot, selectedDateIndex)) {
                          for (int i = 0; i < timeSlots.length; i++) {
                            if (!_isSlotExpired(i, selectedDateIndex)) {
                              selectedTimeSlot = i;
                              break;
                            }
                          }
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          if (index == 0) ...[
                            Icon(
                              Icons.today,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            dateOptions[index],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Banner thông báo nếu hôm nay đã kết thúc ca làm việc
          if (selectedDateIndex == 0 && _areAllSlotsExpiredToday())
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEEBA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF856404), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hôm nay xưởng 3T đã hết ca làm việc (sau 20:30). Vui lòng chuyển sang tab Ngày mai để đặt lịch sớm nhất!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF856404),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Time slot list
          Column(
            children: List.generate(timeSlots.length, (index) {
              final slot = timeSlots[index];
              final isSelected = selectedTimeSlot == index;
              final isSlotDisabled = _isSlotExpired(index, selectedDateIndex);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: isSlotDisabled
                      ? () => _showToast('Ca giặt này đã hết hạn nhận đồ. Vui lòng chọn ca tiếp theo hoặc ngày mai.')
                      : () => setState(() => selectedTimeSlot = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSlotDisabled
                          ? Colors.grey.shade100
                          : isSelected
                          ? primaryFixed.withOpacity(0.4)
                          : surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSlotDisabled
                            ? Colors.transparent
                            : isSelected
                            ? primaryColor
                            : Colors.transparent,
                        width: isSelected ? 1.5 : 0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: selectedTimeSlot,
                              activeColor: primaryColor,
                              onChanged: isSlotDisabled
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() => selectedTimeSlot = val);
                                      }
                                    },
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      getSlotTitle(index),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSlotDisabled
                                            ? Colors.grey.shade400
                                            : onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (isSlotDisabled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Đã hết ca',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    else if (slot['badge'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: slot['badgeBg'] as Color,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          slot['badge'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: slot['badgeText'] as Color,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  slot['sub'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: isSlotDisabled
                                        ? Colors.grey.shade400
                                        : onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          isSlotDisabled
                              ? 'Đã đóng'
                              : (slot['price'] as String),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSlotDisabled
                                ? Colors.grey.shade400
                                : (slot['isPricePrimary'] == true)
                                ? primaryColor
                                : tertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Safety Guarantee Notice Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurface,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: 'An tâm tuyệt đối: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text:
                              'Shipper 3T trang bị cân điện tử mini chính xác & túi vải niêm phong mã Seal chống nước trước mặt bạn khi nhận đồ.',
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
    );
  }

  // --- WIDGET 5: DELIVERY METHOD & EXPECTED RETURN TIME ---
  Widget _buildDeliveryMethodSection() {
    final today = DateTime.now();
    final dates = List<DateTime>.generate(
      3,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
    final pickupDate = dates[selectedDateIndex];

    // Kiểm tra xem đơn hàng có đồ cần chăm sóc chuyên sâu (Vest, dạ hội, giày, rèm...) không
    final bool hasSpecialItems = widget.items.any((item) {
      final name = (item['serviceName'] ?? item['name'] ?? '').toString().toLowerCase();
      return name.contains('vest') ||
          name.contains('comple') ||
          name.contains('dạ hội') ||
          name.contains('áo dài') ||
          name.contains('giày') ||
          name.contains('sneaker') ||
          name.contains('rèm') ||
          name.contains('màn');
    });

    const slotRanges = [
      'Gấp sau 3.5 – 4 giờ',
      '08:00 – 10:00',
      '10:00 – 12:00',
      '14:00 – 16:00',
      '17:00 – 19:00',
      '19:30 – 21:00',
    ];
    final currentSlotRange = slotRanges[selectedTimeSlot.clamp(0, slotRanges.length - 1)];

    String returnTitle;
    String returnSub;

    if (selectedTimeSlot == 0) {
      final dateStr = selectedDateIndex == 0
          ? 'Hôm nay'
          : selectedDateIndex == 1
              ? 'Ngày mai'
              : '${pickupDate.day}/${pickupDate.month}';
      returnTitle = 'Giao hỏa tốc sau 3.5 – 4 giờ ($dateStr)';
      returnSub = 'Xưởng ưu tiên xử lý cấp tốc • Bán kính giao ≤ 5km';
    } else if (hasSpecialItems) {
      final returnDate = pickupDate.add(const Duration(days: 2));
      final returnDateStr = '${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}';
      returnTitle = '$currentSlotRange Ngày $returnDateStr (Quy trình 48h)';
      returnSub = 'Đơn có trang phục cao cấp (Vest/Dạ hội/Giày/Rèm) cần hấp sấy dưỡng chất 48h';
    } else {
      final returnDate = pickupDate.add(const Duration(days: 1));
      final returnDateStr = '${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}';
      returnTitle = '$currentSlotRange Ngày $returnDateStr (Chuẩn 24h)';
      returnSub = 'Chuẩn quy trình 24h: Giặt sạch • Sấy diệt khuẩn • Ủi nếp tinh tươm';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: tertiaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping,
                  size: 18,
                  color: tertiaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Giao trả đồ sạch thơm',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Return estimation card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: secondaryFixed.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer,
                    size: 22,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        returnTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        returnSub,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Checkbox: Same delivery address
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSameDeliveryAddress,
                  activeColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) =>
                      setState(() => isSameDeliveryAddress = val ?? true),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Giao trả về cùng địa chỉ lấy đồ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET 6: SHIPPING FEE TRANSPARENCY ---
  Widget _buildShippingFeeSection() {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: tertiaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.two_wheeler,
                  size: 20,
                  color: tertiaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phí vận chuyển 2 chiều',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lấy & Giao trả tận nơi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '30.000 đ',
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

  // --- WIDGET 7: STICKY BOTTOM CHECKOUT ACTION BAR (GIỮ NGUYÊN LUỒNG BƯỚC 3) ---
  Widget _buildBottomActionBar(BuildContext context) {
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
                    'Phí vận chuyển${expressFee > 0 ? ' (đã gồm phí gấp)' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: onSurfaceVariant,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${transportTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'đ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Tiền giặt chốt sau khi cân',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // 🚀 NÚT BẤM BƯỚC 3: GIỮ NGUYÊN LUỒNG BẤM QUA BookingStep3Screen
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_isSlotExpired(selectedTimeSlot, selectedDateIndex)) {
                      _showToast(
                        'Khung giờ này đã hết ca nhận đồ. Vui lòng chọn khung giờ khác hoặc ngày mai.',
                      );
                      return;
                    }

                    if (!isSameDeliveryAddress) {
                      _showToast(
                        'Chức năng nhập địa chỉ giao trả khác sẽ được bổ sung. Hiện hãy chọn giao trả cùng địa chỉ lấy đồ.',
                      );
                      return;
                    }

                    final current = DateTime.now();
                    final pickupDate = DateTime(
                      current.year,
                      current.month,
                      current.day + selectedDateIndex,
                    );
                    final formattedDate =
                        '${pickupDate.day.toString().padLeft(2, '0')}/${pickupDate.month.toString().padLeft(2, '0')}';
                    const weekdays = <String>[
                      'Thứ Hai',
                      'Thứ Ba',
                      'Thứ Tư',
                      'Thứ Năm',
                      'Thứ Sáu',
                      'Thứ Bảy',
                      'Chủ nhật',
                    ];
                    final pickupDateLabel = selectedDateIndex == 0
                        ? 'Hôm nay ($formattedDate)'
                        : selectedDateIndex == 1
                        ? 'Ngày mai ($formattedDate)'
                        : '${weekdays[pickupDate.weekday - 1]} ($formattedDate)';

                    const slotRanges = [
                      'Gấp trong 30–45 phút',
                      '08:00 – 10:00',
                      '10:00 – 12:00',
                      '14:00 – 16:00',
                      '17:00 – 19:00',
                      '19:30 – 21:00',
                    ];
                    final currentSlotRange = slotRanges[selectedTimeSlot.clamp(0, slotRanges.length - 1)];
                    final pickupTimeFull = selectedTimeSlot == 0
                        ? 'Gấp trong 30–45 phút ($pickupDateLabel)'
                        : '$currentSlotRange ($pickupDateLabel)';

                    // Kiểm tra xem đơn hàng có đồ cần chăm sóc chuyên sâu không
                    final bool hasSpecialItems = widget.items.any((item) {
                      final name = (item['serviceName'] ?? item['name'] ?? '').toString().toLowerCase();
                      return name.contains('vest') ||
                          name.contains('comple') ||
                          name.contains('dạ hội') ||
                          name.contains('áo dài') ||
                          name.contains('giày') ||
                          name.contains('sneaker') ||
                          name.contains('rèm') ||
                          name.contains('màn');
                    });

                    // Tính deliveryTime dự kiến chuẩn xác
                    String deliveryTimeFull;
                    if (selectedTimeSlot == 0) {
                      deliveryTimeFull = 'Giao sau 3.5 – 4 giờ ($pickupDateLabel)';
                    } else if (hasSpecialItems) {
                      final returnDate = pickupDate.add(const Duration(days: 2));
                      final rDateStr = '${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}';
                      deliveryTimeFull = '$currentSlotRange Ngày $rDateStr (Chuẩn 48h)';
                    } else {
                      final returnDate = pickupDate.add(const Duration(days: 1));
                      final rDateStr = '${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}';
                      deliveryTimeFull = '$currentSlotRange Ngày $rDateStr (Chuẩn 24h)';
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingStep3Screen(
                          pickupAddress: widget.pickupAddress,
                          deliveryAddress: widget.pickupAddress,
                          contactPhone: userPhone,
                          note: [
                            _pickupNoteController.text.trim(),
                            'Lịch lấy đồ: $pickupTimeFull',
                            'Dự kiến giao trả: $deliveryTimeFull',
                          ].where((value) => value.trim().isNotEmpty).join(' | '),
                          items: widget.items,
                          pickupTime: pickupTimeFull,
                          deliveryTime: deliveryTimeFull,
                          expressFee: expressFee,
                          addonFee: widget.addonFee,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tiếp tục: Bước 3/3',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
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
