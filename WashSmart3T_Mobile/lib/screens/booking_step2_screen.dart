import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'booking_step3_screen.dart'; // 🚀 Giữ nguyên luồng chuyển sang Bước 3

class BookingStep2Screen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String pickupAddress;
  final String contactPhone;
  final String initialNote;

  const BookingStep2Screen({
    super.key,
    this.items = const [],
    this.pickupAddress =
        'Căn hộ Heritage Manor, Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    this.contactPhone = '0908 123 456',
    this.initialNote = '',
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
  static const Color outlineVariant = Color(0xFFE3BDBF);

  // --- STATE QUẢN LÝ ---
  int shippingFee = 30000; // Phí vận chuyển 2 chiều
  int selectedDateIndex = 0; // 0: hôm nay, 1: ngày mai, 2: ngày kia
  int selectedTimeSlot = DateTime.now().hour < 14
      ? 1
      : DateTime.now().hour < 17
      ? 2
      : DateTime.now().hour < 19
      ? 3
      : 0; // Tự chọn khung giờ chưa qua
  bool isSameDeliveryAddress = true; // Giao trả về cùng địa chỉ lấy

  late final TextEditingController _pickupNoteController;

  @override
  void initState() {
    super.initState();
    final defaultNote = 'Bấm chuông căn 302 lầu 3 hoặc gửi lễ tân sảnh A';
    _pickupNoteController = TextEditingController(
      text: [
        widget.initialNote.trim(),
        defaultNote,
      ].where((note) => note.isNotEmpty).join(' | '),
    );
  }

  // Giá giặt chưa xác định cho đến khi shipper cân/đếm thực tế.
  int get expressFee => (selectedTimeSlot == 0) ? 15000 : 0;
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
                          'Kiều Như',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
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
      if (index == 0) return 'Hôm nay ($day)';
      if (index == 1) return 'Ngày mai ($day)';
      return '${weekdays[date.weekday - 1]} ($day)';
    }

    final dateOptions = List<String>.generate(
      dates.length,
      (index) => dateLabel(dates[index], index),
    );

    final timeSlots = [
      {
        'title': 'Gấp trong 30–45 phút',
        'sub': 'Shipper có mặt ngay tức thì',
        'badge': 'Siêu tốc',
        'badgeBg': const Color(0xFFFFDAD6),
        'badgeText': const Color(0xFF93000A),
        'price': '+15.000 đ',
        'isPricePrimary': true,
      },
      {
        'title': '14:00 – 16:00',
        'sub': 'Shipper khu vực Bến Nghé đang sẵn sàng',
        'badge': 'Tối ưu nhất',
        'badgeBg': tertiaryFixed,
        'badgeText': const Color(0xFF001F26),
        'price': 'Miễn phí',
        'isPricePrimary': false,
      },
      {
        'title': '17:00 – 19:00',
        'sub': 'Lấy đồ sau giờ tan tầm',
        'price': 'Miễn phí',
        'isPricePrimary': false,
      },
      {
        'title': '19:30 – 21:00',
        'sub': 'Thích hợp khi về nhà trễ',
        'price': 'Miễn phí',
        'isPricePrimary': false,
      },
    ];

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
                    onTap: () => setState(() => selectedDateIndex = index),
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

          // Time slot list
          Column(
            children: List.generate(timeSlots.length, (index) {
              final slot = timeSlots[index];
              final isSelected = selectedTimeSlot == index;
              final now = DateTime.now();
              final isPastTodaySlot =
                  selectedDateIndex == 0 &&
                  ((index == 1 && now.hour >= 16) ||
                      (index == 2 && now.hour >= 19) ||
                      (index == 3 &&
                          (now.hour > 21 ||
                              (now.hour == 21 && now.minute > 0))));

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: isPastTodaySlot
                      ? null
                      : () => setState(() => selectedTimeSlot = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPastTodaySlot
                          ? Colors.grey.shade100
                          : isSelected
                          ? primaryFixed.withOpacity(0.4)
                          : surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.transparent,
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
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => selectedTimeSlot = val);
                              },
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${slot['title']}${selectedDateIndex == 0
                                          ? (index == 0
                                                ? ' (trong 30–45 phút)'
                                                : index == 1
                                                ? ' (chiều nay)'
                                                : index == 2
                                                ? ' (tối nay)'
                                                : ' (tối muộn)')
                                          : selectedDateIndex == 1
                                          ? ' (ngày mai)'
                                          : ' (${dateOptions[selectedDateIndex]})'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: onSurface,
                                      ),
                                    ),
                                    if (slot['badge'] != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: slot['badgeBg'] as Color,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  slot['sub'] as String,
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
                          slot['price'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (slot['isPricePrimary'] == true)
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
                    color: secondaryFixed.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer,
                    size: 22,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '10:00 – 12:00 Ngày mai (25/10)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chuẩn quy trình 24h giặt sấy & ủi tinh tươm',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tertiaryColor,
                      ),
                    ),
                  ],
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
                    final current = DateTime.now();
                    final selectedSlotExpired =
                        selectedDateIndex == 0 &&
                        ((selectedTimeSlot == 1 && current.hour >= 16) ||
                            (selectedTimeSlot == 2 && current.hour >= 19) ||
                            (selectedTimeSlot == 3 &&
                                (current.hour > 21 ||
                                    (current.hour == 21 &&
                                        current.minute > 0))));
                    if (selectedSlotExpired) {
                      _showToast(
                        'Khung giờ này đã qua. Vui lòng chọn khung giờ khác.',
                      );
                      return;
                    }
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
                    const pickupTimeTitles = <String>[
                      'Gấp trong 30–45 phút',
                      '14:00 – 16:00',
                      '17:00 – 19:00',
                      '19:30 – 21:00',
                    ];
                    final pickupTimeTitle =
                        pickupTimeTitles[selectedTimeSlot.clamp(
                          0,
                          pickupTimeTitles.length - 1,
                        )];
                    if (!isSameDeliveryAddress) {
                      _showToast(
                        'Chức năng nhập địa chỉ giao trả khác sẽ được bổ sung. Hiện hãy chọn giao trả cùng địa chỉ lấy đồ.',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingStep3Screen(
                          pickupAddress: widget.pickupAddress,
                          deliveryAddress: widget.pickupAddress,
                          contactPhone: widget.contactPhone,
                          note: [
                            _pickupNoteController.text.trim(),
                            'Lịch lấy đồ dự kiến: $pickupDateLabel, $pickupTimeTitle',
                          ].where((value) => value.trim().isNotEmpty).join(' | '),
                          items: widget.items,
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
