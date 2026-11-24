import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'booking_step3_screen.dart'; // 🚀 Giữ nguyên luồng chuyển sang Bước 3

class BookingStep2Screen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> selectedCareOptions;
  final double estimatedWeight;
  final String pickupAddress;
  final String contactPhone;
  final String customerName;
  final String initialNote;
  final int addonFee;

  const BookingStep2Screen({
    super.key,
    this.items = const [],
    this.selectedCareOptions = const [],
    this.estimatedWeight = 3.0,
    this.pickupAddress = '',
    this.contactPhone = '',
    this.customerName = '',
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
  bool isDifferentDeliveryAddress = false; // Mặc định không tích: giao trả về cùng địa chỉ lấy đồ

  late final TextEditingController _pickupNoteController;
  late final TextEditingController _deliveryAddressController;
  late final TextEditingController _deliveryReceiverNameController;
  late final TextEditingController _deliveryReceiverPhoneController;
  late final TextEditingController _deliveryNoteController;

  String userPhone = '';
  String userName = '';
  late String currentPickupAddress;

  String _formatCurrency(num amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // 🚀 Logic tính khoảng cách từ Hub Xưởng WashSmart 3T (140 Lê Trọng Tấn)
  double calculateDistanceToStore(String address) {
    if (address.isEmpty) return 0.1;
    final q = address.toLowerCase().trim();
    if (q.contains('140 lê trọng tấn') || q.contains('tại xưởng') || q.contains('tại cửa hàng')) {
      return 0.1;
    }

    double targetLat = 10.8070;
    double targetLng = 106.6287;
    bool matched = false;

    if (q.contains('lê trọng tấn') || q.contains('tây thạnh') || q.contains('sơn kỳ') || q.contains('chế lan viên')) {
      targetLat = 10.8090; targetLng = 106.6300; matched = true;
    } else if (q.contains('celadon') || q.contains('aeon') || q.contains('bờ bao tân thắng')) {
      targetLat = 10.8020; targetLng = 106.6180; matched = true;
    } else if (q.contains('tân kỳ tân quý') || q.contains('bình long') || q.contains('trường chinh')) {
      targetLat = 10.7980; targetLng = 106.6210; matched = true;
    } else if (q.contains('lũy bán bích') || q.contains('thoại ngọc hầu') || q.contains('hòa bình') || q.contains('tân phú')) {
      targetLat = 10.7830; targetLng = 106.6360; matched = true;
    } else if (q.contains('cộng hòa') || q.contains('hoàng hoa thám') || q.contains('nguyễn sỹ sách') || q.contains('bàu cát') || q.contains('tân bình')) {
      targetLat = 10.8015; targetLng = 106.6530; matched = true;
    } else if (q.contains('quang trung') || q.contains('phan huy ích') || q.contains('thống nhất') || q.contains('gò vấp')) {
      targetLat = 10.8350; targetLng = 106.6620; matched = true;
    } else if (q.contains('an sương') || q.contains('nguyễn văn quá') || q.contains('tân thới nhất') || q.contains('quận 12') || q.contains('q12') || q.contains('q.12')) {
      targetLat = 10.8450; targetLng = 106.6200; matched = true;
    } else if (q.contains('lý thường kiệt') || q.contains('tô hiến thành') || q.contains('thành thái') || q.contains('quận 10') || q.contains('q10') || q.contains('q.10')) {
      targetLat = 10.7720; targetLng = 106.6570; matched = true;
    } else if (q.contains('đầm sen') || q.contains('lãnh binh thăng') || q.contains('quận 11') || q.contains('q11') || q.contains('q.11')) {
      targetLat = 10.7680; targetLng = 106.6450; matched = true;
    } else if (q.contains('bình tân') || q.contains('tên lửa') || q.contains('bình hưng hòa')) {
      targetLat = 10.7700; targetLng = 106.6080; matched = true;
    } else if (q.contains('cách mạng tháng 8') || q.contains('cmt8') || q.contains('quận 3') || q.contains('q3') || q.contains('q.3')) {
      targetLat = 10.7790; targetLng = 106.6780; matched = true;
    } else if (q.contains('phú nhuận') || q.contains('phan xích long')) {
      targetLat = 10.7980; targetLng = 106.6800; matched = true;
    } else if (q.contains('chợ lớn') || q.contains('bình tây') || q.contains('hậu giang') || q.contains('quận 6') || q.contains('q6') || q.contains('q.6')) {
      targetLat = 10.7510; targetLng = 106.6380; matched = true;
    } else if (q.contains('bến thành') || q.contains('lê lợi') || q.contains('nguyễn huệ') || q.contains('quận 1') || q.contains('q1') || q.contains('q.1')) {
      targetLat = 10.7725; targetLng = 106.6980; matched = true;
    }
    // CÁC KHU VỰC VƯỢT QUÁ BÁN KÍNH 10KM:
    else if (q.contains('landmark') || q.contains('bình thạnh') || q.contains('thảo điền') || q.contains('quận 2') || q.contains('q2')) {
      targetLat = 10.8030; targetLng = 106.7250; matched = true;
    } else if (q.contains('nguyễn thị thập') || q.contains('phú mỹ hưng') || q.contains('sunrise') || q.contains('tân quy') || q.contains('quận 7') || q.contains('q7') || q.contains('q.7')) {
      targetLat = 10.7380; targetLng = 106.7130; matched = true;
    } else if (q.contains('quận 8') || q.contains('q8') || q.contains('q.8') || q.contains('quận 4') || q.contains('q4') || q.contains('q.4')) {
      targetLat = 10.7450; targetLng = 106.6850; matched = true;
    } else if (q.contains('nhà bè') || q.contains('cần giờ')) {
      targetLat = 10.6800; targetLng = 106.7300; matched = true;
    } else if (q.contains('thủ đức') || q.contains('quận 9') || q.contains('q9') || q.contains('q.9') || q.contains('suối tiên') || q.contains('làng đại học')) {
      targetLat = 10.8510; targetLng = 106.7720; matched = true;
    } else if (q.contains('bình chánh') || q.contains('củ chi') || q.contains('hóc môn')) {
      targetLat = 10.8800; targetLng = 106.5500; matched = true;
    } else if (q.contains('bình dương') || q.contains('đồng nai') || q.contains('long an') || q.contains('biên hòa')) {
      targetLat = 10.9500; targetLng = 106.7000; matched = true;
    }

    if (!matched) {
      return 2.5;
    }

    const double R = 6371.0;
    final double dLat = (targetLat - 10.8070) * math.pi / 180.0;
    final double dLon = (targetLng - 106.6287) * math.pi / 180.0;
    final double a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
        math.cos(10.8070 * math.pi / 180.0) * math.cos(targetLat * math.pi / 180.0) *
        math.sin(dLon / 2.0) * math.sin(dLon / 2.0);
    final double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    final double roadDist = (R * c * 1.35 * 10).round() / 10;
    return math.max(0.5, roadDist);
  }

  // 🚀 Logic tính thời gian thực di chuyển xe máy shipper (vận tốc nội đô ~22km/h)
  int calculateTravelTimeMinutes(double distanceKm) {
    if (distanceKm <= 0.2) return 2;
    final minutes = ((distanceKm / 22.0) * 60).round() + 2;
    return math.max(3, minutes);
  }

  String formatTravelTime(double distanceKm) {
    final mins = calculateTravelTimeMinutes(distanceKm);
    if (mins < 60) {
      return '~$mins phút di chuyển';
    } else {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '~$h giờ $m phút di chuyển' : '~$h giờ di chuyển';
    }
  }

  void _showOutOfRadiusDialog(BuildContext ctx, String address, double dist) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ngoài Bán Kính 10km',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WashSmart 3T hiện CHỈ CHẤP NHẬN GIAO NHẬN trong bán kính tối đa 10km từ Xưởng Trung Tâm (140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú).',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: onSurface),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Địa chỉ bạn chọn:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Khoảng cách: ~$dist km • ~${calculateTravelTimeMinutes(dist)} phút (Vượt quá 10km)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vui lòng chọn địa chỉ khác trong phạm vi 10km (Tân Phú, Tân Bình, Q.12, Gò Vấp, Q.10, Q.11, Q.3, Q.1...) để shipper phục vụ bạn tốt nhất.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(
              'Đóng',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dCtx);
              _showChangePickupAddressDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Đổi địa chỉ ngay',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 Logic kiểm tra khung giờ hết hạn theo thời gian thực (Lead Time Buffer)
  bool _isSlotExpired(int slotIndex, int dateIndex) {
    if (dateIndex > 0) {
      // Ca lấy gấp hỏa tốc (slotIndex == 0) chỉ áp dụng trong ngày hôm nay, không áp dụng cho ngày khác
      return slotIndex == 0;
    }
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

    _pickupNoteController = TextEditingController();

    userName = widget.customerName.trim();
    userPhone = widget.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    currentPickupAddress = widget.pickupAddress.trim();

    _deliveryAddressController = TextEditingController();
    _deliveryReceiverNameController = TextEditingController(text: userName);
    _deliveryReceiverPhoneController = TextEditingController(text: userPhone);
    _deliveryNoteController = TextEditingController();

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // 1. Tải nhanh từ bộ nhớ SharedPreferences nếu có
      final cachedName = await AuthService.getFullName();
      final cachedPhone = await AuthService.getPhone();
      final cachedAddr = await AuthService.getAddress();
      if (mounted) {
        setState(() {
          if (userName.isEmpty && cachedName != null && cachedName.isNotEmpty) {
            userName = cachedName;
            _deliveryReceiverNameController.text = userName;
          }
          if (userPhone.isEmpty && cachedPhone != null && cachedPhone.isNotEmpty) {
            userPhone = cachedPhone;
            _deliveryReceiverPhoneController.text = userPhone;
          }
          if (currentPickupAddress.isEmpty && cachedAddr != null && cachedAddr.isNotEmpty) {
            currentPickupAddress = cachedAddr;
          }
        });
      }

      // 2. Đồng bộ tươi từ API /Auth/me của người dùng đang đăng nhập
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
                _deliveryReceiverPhoneController.text = userPhone;
              }
              if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
                userName = data['fullName'].toString();
                _deliveryReceiverNameController.text = userName;
              }
              if (data['address'] != null && data['address'].toString().trim().isNotEmpty) {
                currentPickupAddress = data['address'].toString().trim();
              } else if (currentPickupAddress.isEmpty) {
                currentPickupAddress = '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. Hồ Chí Minh';
              }
            });
            await AuthService.saveUserProfile(
              fullName: data['fullName']?.toString(),
              phone: data['phone']?.toString(),
              address: data['address']?.toString(),
              email: data['email']?.toString(),
              userId: (data['id'] as num?)?.toInt(),
            );
          }
        }
      } else if (currentPickupAddress.isEmpty && mounted) {
        setState(() {
          currentPickupAddress = '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. Hồ Chí Minh';
        });
      }
    } catch (_) {
      if (currentPickupAddress.isEmpty && mounted) {
        setState(() {
          currentPickupAddress = '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. Hồ Chí Minh';
        });
      }
    }
  }

  // Giá giặt chưa xác định cho đến khi shipper cân/đếm thực tế. Phí hỏa tốc chỉ áp dụng nếu đặt lấy gấp hôm nay.
  int get expressFee => (selectedDateIndex == 0 && selectedTimeSlot == 0) ? 25000 : 0;
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
    _deliveryAddressController.dispose();
    _deliveryReceiverNameController.dispose();
    _deliveryReceiverPhoneController.dispose();
    _deliveryNoteController.dispose();
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

  // --- WIDGET 2: STEP 1 QUICK SUMMARY CARD (ĐỒNG BỘ ĐỘNG THEO DỮ LIỆU BƯỚC 1) ---
  Widget _buildStep1SummaryCard() {
    final firstItemName = widget.items.isNotEmpty
        ? (widget.items.first['name']?.toString() ?? 'Giặt sấy 3T')
        : 'Giặt sấy tiêu chuẩn 3T';
    final extraCount = widget.items.length > 1 ? ' +${widget.items.length - 1} dịch vụ' : '';
    final displayName = '$firstItemName$extraCount';

    final totalPieces = widget.items
        .where((it) => it['isByItem'] == true)
        .fold<int>(0, (prev, it) => prev + ((it['quantity'] as num?)?.toInt() ?? 0));
    final hasKg = widget.items.any((it) => it['isByItem'] != true);

    String quantityBadge = '';
    if (hasKg && widget.estimatedWeight > 0) {
      quantityBadge = '${widget.estimatedWeight.toStringAsFixed(1)} kg';
    }
    if (totalPieces > 0) {
      quantityBadge = quantityBadge.isNotEmpty
          ? '$quantityBadge • $totalPieces món'
          : '$totalPieces món';
    }
    if (quantityBadge.isEmpty) {
      quantityBadge = 'Đã chọn';
    }

    final int estimatedWashTotal = widget.items.fold<int>(
      0,
      (prev, it) => prev + ((it['totalPrice'] as num?)?.toInt() ?? 0),
    );

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
          Expanded(
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              quantityBadge,
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
                        widget.selectedCareOptions.isNotEmpty
                            ? '+${widget.selectedCareOptions.length} tiện ích nâng cao đã chọn'
                            : 'Shipper sẽ cân chốt thực tế khi nhận đồ',
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
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                estimatedWashTotal > 0 ? '~${_formatCurrency(estimatedWashTotal)} đ' : 'Chờ cân đồ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                'Tạm tính giặt',
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

  void _showChangePickupAddressDialog() {
    final addrController = TextEditingController(text: currentPickupAddress);
    final quickSuggestions = [
      '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM',
      'Aeon Mall Tân Phú, 30 Bờ Bao Tân Thắng, P. Sơn Kỳ, Q. Tân Phú',
      '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
      'Chợ Bến Thành, Đường Lê Lợi, Phường Bến Thành, Quận 1, TP.HCM',
      'Nguyễn Thị Thập, P. Tân Quy, Quận 7, TP.HCM (Thử nghiệm ngoài 10km)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentInput = addrController.text.trim();
          final liveDist = calculateDistanceToStore(currentInput);
          final liveTime = calculateTravelTimeMinutes(liveDist);
          final isLiveWithin10Km = liveDist <= 10.0;

          return Container(
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
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đổi địa chỉ lấy đồ',
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
                const SizedBox(height: 10),
                TextField(
                  controller: addrController,
                  maxLines: 2,
                  minLines: 1,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Nhập số nhà, tên đường, phường/xã...',
                    filled: true,
                    fillColor: surfaceLow,
                    prefixIcon: const Icon(Icons.pin_drop, color: primaryColor, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gợi ý nhanh khu vực TP.HCM:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickSuggestions.map((suggestion) {
                    final sDist = calculateDistanceToStore(suggestion);
                    final sTime = calculateTravelTimeMinutes(sDist);
                    final isOver = sDist > 10.0;
                    final isSelected = addrController.text.trim() == suggestion;

                    return InkWell(
                      onTap: () {
                        addrController.text = suggestion;
                        setSheetState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isOver ? const Color(0xFFFEE2E2) : primaryColor)
                              : surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOver
                                ? const Color(0xFFEF4444)
                                : (isSelected ? primaryColor : primaryColor.withOpacity(0.2)),
                          ),
                        ),
                        child: Text(
                          '${suggestion.split(',').take(2).join(',')} (~$sDist km • ~$sTime p)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: isSelected
                                ? (isOver ? const Color(0xFF991B1B) : Colors.white)
                                : (isOver ? const Color(0xFFB91C1C) : primaryColor),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 🚀 BẢNG THÔNG SỐ TÍNH TOÁN KM & THỜI GIAN THỰC DI CHUYỂN
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLiveWithin10Km ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLiveWithin10Km ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.two_wheeler,
                                size: 16,
                                color: isLiveWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Khoảng cách: ~$liveDist km',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isLiveWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: isLiveWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '~$liveTime phút di chuyển',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isLiveWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isLiveWithin10Km ? Icons.check_circle : Icons.error,
                            size: 14,
                            color: isLiveWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isLiveWithin10Km
                                  ? 'Trong bán kính giao nhận (≤ 10km từ Hub Xưởng 140 Lê Trọng Tấn, Tân Phú)'
                                  : 'VƯỢT QUÁ BÁN KÍNH 10KM (~$liveDist km • ~$liveTime phút) - Vui lòng chọn địa chỉ khác!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isLiveWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      final newAddr = addrController.text.trim();
                      if (newAddr.isEmpty) {
                        _showToast('Vui lòng nhập địa chỉ lấy đồ');
                        return;
                      }
                      if (!isLiveWithin10Km) {
                        _showOutOfRadiusDialog(context, newAddr, liveDist);
                        return;
                      }
                      setState(() {
                        currentPickupAddress = newAddr;
                      });
                      Navigator.pop(ctx);
                      _showToast('Đã đổi địa chỉ: ~$liveDist km • ~$liveTime phút di chuyển');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLiveWithin10Km ? primaryColor : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    child: Text(
                      isLiveWithin10Km
                          ? 'Xác nhận địa chỉ này (~$liveDist km)'
                          : 'Địa chỉ vượt quá 10km (Chưa hỗ trợ)',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET 3: PICKUP ADDRESS SECTION ---
  Widget _buildPickupAddressSection() {
    final pickupDist = calculateDistanceToStore(currentPickupAddress);
    final pickupTime = calculateTravelTimeMinutes(pickupDist);
    final isPickupWithin10Km = pickupDist <= 10.0;

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
                onTap: _showChangePickupAddressDialog,
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
                          userName.isNotEmpty ? userName : 'Khách hàng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        if (userPhone.isNotEmpty)
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
                  currentPickupAddress,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // 🚀 THÔNG SỐ TÍNH TOÁN KM & THỜI GIAN THỰC DI CHUYỂN
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPickupWithin10Km ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPickupWithin10Km ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.two_wheeler,
                                size: 15,
                                color: isPickupWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Khoảng cách: ~$pickupDist km',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isPickupWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: isPickupWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '~$pickupTime phút di chuyển',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isPickupWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            isPickupWithin10Km ? Icons.verified : Icons.warning_amber_rounded,
                            size: 13,
                            color: isPickupWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isPickupWithin10Km
                                  ? 'Bán kính hợp lệ ≤ 10km từ Hub Xưởng 140 Lê Trọng Tấn, Q. Tân Phú'
                                  : 'VƯỢT QUÁ BÁN KÍNH 10KM (~$pickupDist km) - Vui lòng bấm Đổi địa chỉ!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isPickupWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
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
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Bấm chuông căn 302 lầu 3, gửi lễ tân sảnh A...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
        'price': '55.000 đ',
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
        'price': '30.000 đ',
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
        'price': '30.000 đ',
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
        'price': '30.000 đ',
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
        'price': '30.000 đ',
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
        'price': '30.000 đ',
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
                        // Nếu chuyển sang ngày khác (index > 0) và đang chọn slot lấy gấp (0), tự động chuyển sang ca 1 (08:00 - 10:00)
                        if (index > 0 && selectedTimeSlot == 0) {
                          selectedTimeSlot = 1;
                        }
                        // Nếu ca hiện tại bị hết hạn ở ngày mới, chuyển sang ca mở đầu tiên
                        if (_isSlotExpired(selectedTimeSlot, selectedDateIndex)) {
                          final startIdx = selectedDateIndex == 0 ? 0 : 1;
                          for (int i = startIdx; i < timeSlots.length; i++) {
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

          // Time slot list (Chỉ hiển thị option Lấy gấp hỏa tốc ở ngày Hôm nay; các ngày khác không hiện option lấy gấp)
          Column(
            children: [
              for (int index = (selectedDateIndex == 0 ? 0 : 1); index < timeSlots.length; index++)
                Builder(builder: (context) {
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
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSlotDisabled
                                    ? Colors.grey.shade400
                                    : (isSelected
                                        ? primaryColor
                                        : (slot['isPricePrimary'] == true)
                                            ? primaryColor
                                            : onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
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

          // Checkbox: Nhận đồ tại địa chỉ khác
          InkWell(
            onTap: () {
              setState(() {
                isDifferentDeliveryAddress = !isDifferentDeliveryAddress;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isDifferentDeliveryAddress,
                      activeColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          isDifferentDeliveryAddress = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giao trả đồ tới địa chỉ khác',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          isDifferentDeliveryAddress
                              ? 'Tùy chọn: Nhận đồ tại cơ quan, nhà người thân...'
                              : 'Chỉ nhận đồ tại địa chỉ lấy đồ mặc định (${currentPickupAddress.split(',').first})',
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
          ),

          // Form nhập địa chỉ khác khi khách hàng tích chọn
          if (isDifferentDeliveryAddress) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryFixed, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pin_drop, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Địa chỉ giao trả đồ sạch khác:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Ô nhập địa chỉ chi tiết
                  TextField(
                    controller: _deliveryAddressController,
                    onChanged: (val) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Nhập số nhà, tên đường, tòa nhà, phường, quận...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: surfaceVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  if (_deliveryAddressController.text.trim().isNotEmpty) ...[
                    Builder(builder: (ctx) {
                      final delivAddr = _deliveryAddressController.text.trim();
                      final delivDist = calculateDistanceToStore(delivAddr);
                      final delivTime = calculateTravelTimeMinutes(delivDist);
                      final isDelivWithin10Km = delivDist <= 10.0;

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDelivWithin10Km ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDelivWithin10Km ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.two_wheeler,
                                      size: 15,
                                      color: isDelivWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Khoảng cách: ~$delivDist km',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDelivWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: isDelivWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '~$delivTime phút di chuyển',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDelivWithin10Km ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isDelivWithin10Km ? Icons.verified : Icons.warning_amber_rounded,
                                  size: 13,
                                  color: isDelivWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isDelivWithin10Km
                                        ? 'Bán kính hợp lệ ≤ 10km từ Hub 140 Lê Trọng Tấn'
                                        : 'VƯỢT QUÁ BÁN KÍNH 10KM (~$delivDist km) - Vui lòng nhập địa chỉ ≤ 10km!',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDelivWithin10Km ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),

                  // 2 cột: Tên & SĐT người nhận tại địa chỉ này
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Người nhận đồ:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _deliveryReceiverNameController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: onSurface),
                              decoration: InputDecoration(
                                hintText: 'Tên người nhận',
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: surfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Số điện thoại:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _deliveryReceiverPhoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: onSurface),
                              decoration: InputDecoration(
                                hintText: 'SĐT người nhận',
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: surfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Ghi chú thêm cho shipper khi giao đồ
                  TextField(
                    controller: _deliveryNoteController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Ghi chú giao đồ (Gửi lễ tân, bảo vệ, gọi trước 15p...)',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: surfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET 6: STICKY BOTTOM CHECKOUT ACTION BAR (GIỮ NGUYÊN LUỒNG BƯỚC 3) ---
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
                        transportTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'),
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
                    final checkAddress = isDifferentDeliveryAddress &&
                            _deliveryAddressController.text.trim().isNotEmpty
                        ? _deliveryAddressController.text.trim()
                        : currentPickupAddress;
                    final dist = calculateDistanceToStore(checkAddress);
                    if (dist > 10.0) {
                      _showOutOfRadiusDialog(context, checkAddress, dist);
                      return;
                    }

                    if (_isSlotExpired(selectedTimeSlot, selectedDateIndex)) {
                      _showToast(
                        'Khung giờ này đã hết ca nhận đồ. Vui lòng chọn khung giờ khác hoặc ngày mai.',
                      );
                      return;
                    }

                    if (isDifferentDeliveryAddress &&
                        _deliveryAddressController.text.trim().isEmpty) {
                      _showToast(
                        'Vui lòng nhập địa chỉ giao trả đồ sạch hoặc bỏ tích chọn.',
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

                    final finalDeliveryAddress = isDifferentDeliveryAddress
                        ? _deliveryAddressController.text.trim()
                        : currentPickupAddress;
                    final receiverPhone = isDifferentDeliveryAddress &&
                            _deliveryReceiverPhoneController.text.trim().isNotEmpty
                        ? _deliveryReceiverPhoneController.text.trim()
                        : userPhone;
                    final receiverName = isDifferentDeliveryAddress &&
                            _deliveryReceiverNameController.text.trim().isNotEmpty
                        ? _deliveryReceiverNameController.text.trim()
                        : userName;
                    final deliveryNote = isDifferentDeliveryAddress &&
                            _deliveryNoteController.text.trim().isNotEmpty
                        ? 'Ghi chú giao: ${_deliveryNoteController.text.trim()}'
                        : '';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingStep3Screen(
                          pickupAddress: currentPickupAddress,
                          deliveryAddress: finalDeliveryAddress,
                          customerName: receiverName,
                          contactPhone: receiverPhone,
                          note: [
                            if (widget.initialNote.trim().isNotEmpty)
                              widget.initialNote.trim(),
                            if (_pickupNoteController.text.trim().isNotEmpty)
                              _pickupNoteController.text.trim(),
                            if (deliveryNote.trim().isNotEmpty)
                              deliveryNote.trim(),
                            if (isDifferentDeliveryAddress)
                              'Giao tới địa chỉ khác: $finalDeliveryAddress (Người nhận: $receiverName - $receiverPhone)',
                            'Lịch lấy đồ: $pickupTimeFull',
                            'Dự kiến giao trả: $deliveryTimeFull',
                          ].where((value) => value.trim().isNotEmpty).join(' | '),
                          items: widget.items,
                          selectedCareOptions: widget.selectedCareOptions,
                          estimatedWeight: widget.estimatedWeight,
                          pickupTime: pickupTimeFull,
                          deliveryTime: deliveryTimeFull,
                          expressFee: expressFee,
                          addonFee: widget.addonFee,
                          distanceKm: dist,
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
