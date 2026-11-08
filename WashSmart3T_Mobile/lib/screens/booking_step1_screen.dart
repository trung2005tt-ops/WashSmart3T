import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'booking_step2_screen.dart'; // 🚀 Import chuyển sang Bước 2

class BookingStep1Screen extends StatefulWidget {
  const BookingStep1Screen({super.key});

  @override
  State<BookingStep1Screen> createState() => _BookingStep1ScreenState();
}

class _BookingStep1ScreenState extends State<BookingStep1Screen> {
  // Brand Color Tokens WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color primaryFixed = Color(0xFFFFDADB);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color secondaryFixed = Color(0xFFFFD9E4);
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

  // Khách chọn dịch vụ và nhóm đồ; số lượng thực tế do shipper ghi nhận.
  final List<Map<String, dynamic>> availableServices = [];
  final Set<int> selectedServiceIds = {};
  final Set<String> selectedGarmentTypes = {};
  bool isLoadingServices = false;
  String? serviceLoadError;

  // Dịch vụ bổ sung
  bool isIronChecked = true;
  bool isFragranceChecked = true;
  bool isSealChecked = true;

  final TextEditingController _notesController = TextEditingController(
    text:
        'Vải mỏng cần giặt nhiệt dịu 55°C, bấm mã seal niêm phong trước mặt khi nhận đồ...',
  );

  @override
  void initState() {
    super.initState();
    _loadAvailableServices();
  }

  Future<void> _loadAvailableServices() async {
    setState(() {
      isLoadingServices = true;
      serviceLoadError = null;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5085/api/Services'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('API trả về mã ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception('Dữ liệu dịch vụ không hợp lệ');
      final services = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        availableServices
          ..clear()
          ..addAll(services);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        serviceLoadError =
            'Không tải được danh sách dịch vụ. Kiểm tra Backend/API rồi thử tải lại.';
      });
    } finally {
      if (mounted)
        setState(() {
          isLoadingServices = false;
        });
    }
  }

  List<Map<String, dynamic>> _buildOrderItems() {
    return availableServices
        .where(
          (service) =>
              selectedServiceIds.contains((service['id'] as num?)?.toInt()),
        )
        .map(
          (service) => <String, dynamic>{
            'serviceId': (service['id'] as num).toInt(),
            'quantity': 0,
          },
        )
        .toList();
  }

  String _buildBookingNote() {
    final parts = <String>[];
    if (selectedGarmentTypes.isNotEmpty) {
      parts.add('Loại đồ: ${selectedGarmentTypes.join(', ')}');
    }
    if (isIronChecked) parts.add('Dịch vụ bổ sung: ủi hơi nước');
    if (isFragranceChecked) parts.add('Dịch vụ bổ sung: hương thơm');
    if (isSealChecked) parts.add('Dịch vụ bổ sung: túi niêm phong');
    if (_notesController.text.trim().isNotEmpty)
      parts.add(_notesController.text.trim());
    return parts.join(' | ');
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
    _notesController.dispose();
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
          'Đặt Dịch Vụ (Bước 1/3)',
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
            padding: const EdgeInsets.only(bottom: 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PROGRESS STEPPER 3T
                _buildProgressStepper(),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. BANNER TIÊU CHUẨN 3T
                      _buildBanner3T(),
                      const SizedBox(height: 16),

                      // 3. GÓI DỊCH VỤ GIẶT ỦI CHÍNH
                      _buildServicePackageSection(),
                      const SizedBox(height: 16),
                      _buildAvailableServicesSection(),
                      const SizedBox(height: 16),

                      // 4. ƯỚC TÍNH KHỐI LƯỢNG (WEIGHT STEPPER)
                      _buildWeightEstimationSection(),
                      const SizedBox(height: 16),


                      // 6. CHĂM SÓC NÂNG CAO & ĐÓNG GÓI
                      _buildAddonsSection(),
                      const SizedBox(height: 16),

                      // 7. GHI CHÚ CHO TIỆM
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 8. FOOTER STICKY BOTTOM BAR ---
          _buildBottomActionBar(context),
        ],
      ),
    );
  }

  // --- WIDGET 1: PROGRESS STEPPER 3T ---
  Widget _buildProgressStepper() {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'QUY TRÌNH ĐẶT 3T',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Bước 1 trên 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1. Dịch vụ & Đồ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: surfaceHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2. Lịch & Địa chỉ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: surfaceHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3. Xác nhận',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  // --- WIDGET 2: BANNER TIÊU CHUẨN 3T ---
  Widget _buildBanner3T() {
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: Color(0xFF3E0022),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tiêu chuẩn WashSmart 3T',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3E0022),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Giặt Riêng 1 Máy / Khách',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Khử khuẩn UV 99.9%, sấy thơm tự nhiên & gấp nếp tươm tất chuẩn tủ đồ cao cấp.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuB40T_eeTL8ZWeMgTM5cDBWPWC_w8J2kTj5QMKs3-gAxrupHisWQPvfYUA4dpir38BqEgggwmT9swjyXU8j7Vcr9R62seh0lsIexutDFGKunAfSZffl2fuKvf9aXlaalMSdmLXA_Aa-ceCym0XTtHZi7uZCLsQ_c99SyW0epHqI_bIbSVDFU4_uT7qTZvQ8KO_P4O4kWs_j14NqWrz9lzCZfFl6BRIjHtfNknUm1EasS9Useu-bYyCnZA',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 80,
                height: 80,
                color: surfaceContainer,
                child: const Icon(
                  Icons.local_laundry_service,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 3: GÓI DỊCH VỤ GIẶT ỦI CHÍNH ---
  Widget _buildServicePackageSection() {
    return Column(
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
                  'Gói Dịch Vụ Giặt Ủi',
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
                color: primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Phổ biến nhất',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dry_cleaning,
                      color: primaryColor,
                      size: 28,
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
                              'Giặt Sấy Tinh Tươm',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle,
                              color: primaryColor,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Giặt sạch sâu, sấy dịu chống co rút & gấp xếp ngay ngắn theo chuẩn khách sạn.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: onSurfaceVariant,
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
                    Text(
                      'Đơn giá tham khảo:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: onSurfaceVariant,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Theo bảng giá',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          ' thực tế',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.shield, size: 16, color: secondaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Bảo hiểm hư hại vải lên tới 3.000.000 đ/đơn hàng',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Khách không nhập cân nặng; shipper cân thực tế khi nhận đồ.
  Widget _buildWeightEstimationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.scale, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cân đo khi nhận đồ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn không cần ước lượng cân nặng hoặc số lượng. Shipper sẽ cân/đếm thực tế, thông báo cho bạn kiểm tra và xác nhận trước khi hệ thống chốt giá.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khách chọn nhóm đồ, không nhập số lượng thực tế.
  Widget _buildGarmentsListSection() {
    final categories = <Map<String, dynamic>>[
      {
        'icon': Icons.dry_cleaning,
        'title': 'Áo sơ mi & áo thun',
        'sub': 'Phân loại theo chất liệu',
      },
      {
        'icon': Icons.straighten,
        'title': 'Quần tây & quần jean',
        'sub': 'Giặt và xử lý theo chất vải',
      },
      {
        'icon': Icons.style,
        'title': 'Đầm & váy',
        'sub': 'Ưu tiên chế độ giặt phù hợp',
      },
      {
        'icon': Icons.layers,
        'title': 'Khăn tắm & đồ cotton',
        'sub': 'Giặt sạch, khử mùi',
      },
      {
        'icon': Icons.checkroom,
        'title': 'Đồ khác',
        'sub': 'Trao đổi với shipper khi nhận đồ',
      },
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom, color: primaryColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Loại đồ cần giặt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn các nhóm đồ có trong túi. Shipper sẽ kiểm đếm số lượng thực tế khi nhận.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...categories.map((item) {
            final title = item['title'] as String;
            final selected = selectedGarmentTypes.contains(title);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: primaryColor,
              value: selected,
              onChanged: (value) => setState(() {
                if (value == true) {
                  selectedGarmentTypes.add(title);
                } else {
                  selectedGarmentTypes.remove(title);
                }
              }),
              title: Row(
                children: [
                  Icon(item['icon'] as IconData, color: primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  item['sub'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: onSurfaceVariant,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvailableServicesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_laundry_service,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chọn dịch vụ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Danh sách được tải từ hệ thống. Giá giặt sẽ chốt sau khi shipper cân/đếm.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoadingServices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          if (serviceLoadError != null) ...[
            Text(
              serviceLoadError!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: primaryColor,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadAvailableServices,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại'),
              ),
            ),
          ],
          if (!isLoadingServices &&
              serviceLoadError == null &&
              availableServices.isEmpty)
            Text(
              'Hiện chưa có dịch vụ khả dụng.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: onSurfaceVariant,
              ),
            ),
          ...availableServices.map((service) {
            final id = (service['id'] as num?)?.toInt();
            if (id == null) return const SizedBox.shrink();
            final name = service['name']?.toString() ?? 'Dịch vụ $id';
            final description = service['description']?.toString() ?? '';
            final selected = selectedServiceIds.contains(id);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: primaryColor,
              value: selected,
              onChanged: (value) => setState(() {
                if (value == true) {
                  selectedServiceIds.add(id);
                } else {
                  selectedServiceIds.remove(id);
                }
              }),
              title: Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '✓ Giặt riêng 1 máy • Sấy diệt khuẩn 99.9% • Gấp nếp tinh tươm',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
              secondary: const Icon(
                Icons.local_laundry_service,
                color: primaryColor,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGarmentStepperRow({
    required IconData icon,
    required String title,
    required String sub,
    required int count,
    required VoidCallback onMin,
    required VoidCallback onAdd,
  }) {
    return Container(
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
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Column(
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
                  Text(
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: onMin,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 16, color: onSurface),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET 6: CHĂM SÓC NÂNG CAO & ĐÓNG GÓI ---
  Widget _buildAddonsSection() {
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
              const Icon(Icons.auto_awesome, color: primaryColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Chăm Sóc Nâng Cao & Đóng Gói',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildAddonCheckboxRow(
            title: 'Ủi hơi nước chống nhăn form',
            desc: 'Ủi đứng áp suất nhiệt, giữ phom áo sơ mi & quần âu',
            priceText: '+20.000 đ',
            isPricePrimary: true,
            value: isIronChecked,
            onChanged: (val) => setState(() => isIronChecked = val ?? false),
          ),
          const SizedBox(height: 8),

          _buildAddonCheckboxRow(
            title: 'Hương Hoa Ban Mai 3T',
            badgeText: '72 Giờ',
            desc: 'Chiết xuất tinh dầu thảo mộc dịu nhẹ, an toàn da nhạy cảm',
            priceText: 'Miễn phí (0 đ)',
            value: isFragranceChecked,
            onChanged: (val) =>
                setState(() => isFragranceChecked = val ?? false),
          ),
          const SizedBox(height: 8),

          _buildAddonCheckboxRow(
            title: 'Túi vải niêm phong chống nước',
            badgeText: '#SEAL-3T',
            badgeBgColor: tertiaryColor,
            desc: 'Khóa seal an toàn chống ẩm bụi, mở seal tại nhà khách',
            priceText: 'Miễn phí (0 đ)',
            value: isSealChecked,
            onChanged: (val) => setState(() => isSealChecked = val ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonCheckboxRow({
    required String title,
    String? badgeText,
    Color badgeBgColor = secondaryColor,
    required String desc,
    required String priceText,
    bool isPricePrimary = false,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            priceText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPricePrimary ? primaryColor : secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 7: GHI CHÚ CHO TIỆM ---
  Widget _buildNotesSection() {
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
              const Icon(Icons.edit_note, color: primaryColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Ghi Chú Cho Chuyên Viên Giặt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _notesController,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: onSurface),
            decoration: InputDecoration(
              hintText:
                  'Ví dụ: Vải mỏng cần giặt nhiệt dịu 55°C, bấm mã seal niêm phong trước mặt khi nhận đồ...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineVariant,
              ),
              filled: true,
              fillColor: surfaceLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nhắc hẹn đặc biệt về cổ áo, vết ố hoặc chất liệu',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: onSurfaceVariant,
                ),
              ),
              Text(
                '${_notesController.text.length}/200',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET 8: STICKY BOTTOM ACTION BAR (TÍCH HỢP SẴN CHUYỂN BƯỚC 2) ---
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Giá sẽ chốt sau khi cân:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.help_outline,
                            size: 14,
                            color: onSurfaceVariant,
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Chưa chốt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(theo khối lượng thực tế)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chờ kiểm đếm',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 🚀 Lệnh chuyển bước 2
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedServiceIds.isEmpty) {
                      _showToast('Vui lòng chọn ít nhất một dịch vụ.');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookingStep2Screen(items: _buildOrderItems()),
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
                      Text(
                        'Tiếp tục: Chọn lịch hẹn (Bước 2/3)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
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
