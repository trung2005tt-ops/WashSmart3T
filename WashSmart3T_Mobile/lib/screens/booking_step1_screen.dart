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

  // Khách chọn dịch vụ bằng combobox; có giá theo kg và theo cái; đồ theo cái là số nguyên
  final List<Map<String, dynamic>> availableServices = [];
  int? selectedComboboxServiceId;
  final Set<int> selectedServiceIds = {};
  final Map<int, int> selectedItemQuantities = {}; // Số lượng nguyên cho đồ theo cái
  final Set<String> selectedGarmentTypes = {};
  bool isLoadingServices = false;
  String? serviceLoadError;

  // Gói Chăm Sóc Nâng Cao & Đóng Gói (Đồng bộ từ Backend API, KHÔNG tự động tích sẵn)
  final List<Map<String, dynamic>> availableCareOptions = [];
  final Set<int> selectedCareOptionIds = {}; // Mặc định rỗng, người dùng chủ động chọn
  bool isLoadingCareOptions = false;
  String? careOptionsLoadError;

  final TextEditingController _notesController = TextEditingController(
    text:
        'Vải mỏng cần giặt nhiệt dịu 55°C, bấm mã seal niêm phong trước mặt khi nhận đồ...',
  );

  @override
  void initState() {
    super.initState();
    _loadAvailableServices();
    _loadCareOptions();
  }

  String _formatCurrency(num value) {
    final s = value.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  bool _isServiceByItem(Map<String, dynamic> svc) {
    final unit = (svc['price']?['unit'] ?? svc['unit'] ?? 'kg').toString().toLowerCase().trim();
    return !unit.contains('kg') && !unit.contains('ký');
  }

  String _getServiceUnit(Map<String, dynamic> svc) {
    return (svc['price']?['unit'] ?? svc['unit'] ?? 'kg').toString();
  }

  int _getServicePrice(Map<String, dynamic> svc) {
    final p = svc['price']?['price'] ?? svc['pricePerUnit'] ?? svc['unitPrice'] ?? 0;
    return (p as num).toInt();
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

        // Mặc định chọn dịch vụ đầu tiên hoặc dịch vụ ID 7 (Giặt sấy tiêu chuẩn)
        if (selectedServiceIds.isEmpty && availableServices.isNotEmpty) {
          final defaultSvc = availableServices.firstWhere(
            (s) => s['id'] == 7,
            orElse: () => availableServices.first,
          );
          final defaultId = (defaultSvc['id'] as num?)?.toInt();
          if (defaultId != null) {
            selectedComboboxServiceId = defaultId;
            selectedServiceIds.add(defaultId);
            if (_isServiceByItem(defaultSvc)) {
              selectedItemQuantities[defaultId] = 1;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        serviceLoadError =
            'Không tải được danh sách dịch vụ. Kiểm tra Backend/API rồi thử tải lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingServices = false;
        });
      }
    }
  }

  Future<void> _loadCareOptions() async {
    setState(() {
      isLoadingCareOptions = true;
      careOptionsLoadError = null;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5085/api/CareOptions'),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          if (!mounted) return;
          setState(() {
            availableCareOptions
              ..clear()
              ..addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
            // KHÔNG tự động tích sẵn: selectedCareOptionIds giữ rỗng
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        careOptionsLoadError = 'Không tải được gói chăm sóc từ máy chủ.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingCareOptions = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildOrderItems() {
    var items = selectedServiceIds.map((id) {
      final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
      final isByItem = svc.isNotEmpty ? _isServiceByItem(svc) : false;
      final qty = isByItem ? (selectedItemQuantities[id] ?? 1) : 0;
      return <String, dynamic>{
        'serviceId': id,
        'quantity': qty,
      };
    }).toList();

    if (items.isEmpty && availableServices.isNotEmpty) {
      final defaultSvc = availableServices.firstWhere(
        (s) => s['id'] == 7,
        orElse: () => availableServices.first,
      );
      final defaultId = (defaultSvc['id'] as num?)?.toInt() ?? 7;
      final isByItem = _isServiceByItem(defaultSvc);
      items.add({
        'serviceId': defaultId,
        'quantity': isByItem ? 1 : 0,
      });
    }
    return items;
  }

  int _calculateAddonFee() {
    int sum = 0;
    for (final id in selectedCareOptionIds) {
      final opt = availableCareOptions.firstWhere((c) => c['id'] == id, orElse: () => {});
      if (opt.isNotEmpty) {
        sum += (opt['price'] as num? ?? 0).toInt();
      }
    }
    return sum;
  }

  String _buildBookingNote() {
    final parts = <String>[];
    if (selectedGarmentTypes.isNotEmpty) {
      parts.add('Loại đồ: ${selectedGarmentTypes.join(', ')}');
    }
    for (final id in selectedCareOptionIds) {
      final opt = availableCareOptions.firstWhere((c) => c['id'] == id, orElse: () => {});
      if (opt.isNotEmpty) {
        final name = opt['name'] ?? 'Tiện ích';
        final price = (opt['price'] as num? ?? 0).toInt();
        parts.add('Tiện ích: $name (${price > 0 ? '+${_formatCurrency(price)}đ' : 'Miễn phí'})');
      }
    }
    if (_notesController.text.trim().isNotEmpty) {
      parts.add(_notesController.text.trim());
    }
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
              const Icon(
                Icons.local_laundry_service,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chọn Dịch Vụ Giặt Ủi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              if (selectedServiceIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Đã chọn ${selectedServiceIds.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn dịch vụ bằng combobox bên dưới. Giá hiển thị rõ ràng theo kg hoặc theo cái.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          if (isLoadingServices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (serviceLoadError != null) ...[
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
          ]
          else if (availableServices.isNotEmpty) ...[
            // COMBOBOX DROPDOWN CHỌN DỊCH VỤ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: outlineVariant.withOpacity(0.5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: availableServices.any((s) => s['id'] == selectedComboboxServiceId)
                      ? selectedComboboxServiceId
                      : availableServices.first['id'],
                  icon: const Icon(Icons.arrow_drop_down, color: primaryColor, size: 24),
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: onSurface),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  onChanged: (int? newId) {
                    if (newId != null) {
                      setState(() {
                        selectedComboboxServiceId = newId;
                        selectedServiceIds.add(newId);
                        if (!selectedItemQuantities.containsKey(newId)) {
                          selectedItemQuantities[newId] = 1;
                        }
                      });
                    }
                  },
                  items: availableServices.map((svc) {
                    final id = (svc['id'] as num).toInt();
                    final name = svc['name']?.toString() ?? 'Dịch vụ $id';
                    final unit = _getServiceUnit(svc);
                    final price = _getServicePrice(svc);
                    final isByItem = _isServiceByItem(svc);

                    return DropdownMenuItem<int>(
                      value: id,
                      child: Row(
                        children: [
                          Icon(
                            isByItem ? Icons.checkroom : Icons.local_laundry_service,
                            size: 18,
                            color: isByItem ? secondaryColor : primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isByItem ? const Color(0xFFFFF0F5) : const Color(0xFFE8F7F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isByItem ? secondaryColor.withOpacity(0.3) : tertiaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isByItem ? 'Theo $unit' : 'Theo kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isByItem ? secondaryColor : tertiaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatCurrency(price)} đ/$unit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // DANH SÁCH DỊCH VỤ ĐÃ CHỌN
            Text(
              'Dịch vụ đã chọn trong đơn:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),

            ...selectedServiceIds.map((id) {
              final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
              if (svc.isEmpty) return const SizedBox.shrink();
              final name = svc['name']?.toString() ?? 'Dịch vụ $id';
              final unit = _getServiceUnit(svc);
              final price = _getServicePrice(svc);
              final isByItem = _isServiceByItem(svc);
              final qty = selectedItemQuantities[id] ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isByItem ? secondaryColor.withOpacity(0.25) : primaryColor.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isByItem ? Icons.dry_cleaning : Icons.local_laundry_service,
                        color: isByItem ? secondaryColor : primaryColor,
                        size: 20,
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
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedServiceIds.length > 1)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedServiceIds.remove(id);
                                      if (selectedComboboxServiceId == id && selectedServiceIds.isNotEmpty) {
                                        selectedComboboxServiceId = selectedServiceIds.first;
                                      }
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isByItem ? const Color(0xFFFFE4EC) : const Color(0xFFE0F4F7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isByItem ? 'Theo $unit (Số lượng nguyên)' : 'Theo kg',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isByItem ? secondaryColor : tertiaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_formatCurrency(price)} đ/$unit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          if (!isByItem) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Khối lượng: Shipper cân bằng cân điện tử IoT khi nhận đồ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isByItem) ...[
                      const SizedBox(width: 10),
                      // BỘ ĐẾM SỐ NGUYÊN (1, 2, 3...) BẮT BUỘC SỐ NGUYÊN
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: outlineVariant.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (qty > 1) {
                                  setState(() {
                                    selectedItemQuantities[id] = qty - 1;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: qty > 1 ? onSurface : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 26),
                              alignment: Alignment.center,
                              child: Text(
                                '$qty',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedItemQuantities[id] = qty + 1;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: const Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.add, size: 16, color: primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chăm Sóc Nâng Cao & Đóng Gói',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              if (selectedCareOptionIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${_formatCurrency(_calculateAddonFee())} đ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tùy chọn tiện ích đi kèm (không bắt buộc). Giá được đồng bộ trực tiếp từ cửa hàng.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          if (isLoadingCareOptions)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (availableCareOptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Hiện tại không có gói chăm sóc nâng cao nào khả dụng.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: onSurfaceVariant,
                ),
              ),
            )
          else
            ...availableCareOptions.map((opt) {
              final id = (opt['id'] as num).toInt();
              final name = opt['name']?.toString() ?? 'Tiện ích $id';
              final desc = opt['description']?.toString() ?? '';
              final price = (opt['price'] as num? ?? 0).toInt();
              final badge = opt['badgeText']?.toString();
              final isChecked = selectedCareOptionIds.contains(id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildAddonCheckboxRow(
                  title: name,
                  desc: desc,
                  badgeText: badge,
                  badgeBgColor: badge != null && badge.contains('#SEAL') ? tertiaryColor : secondaryColor,
                  priceText: price == 0 ? 'Miễn phí (0 đ)' : '+${_formatCurrency(price)} đ',
                  isPricePrimary: price > 0,
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedCareOptionIds.add(id);
                      } else {
                        selectedCareOptionIds.remove(id);
                      }
                    });
                  },
                ),
              );
            }),
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
                            'Giá sẽ chốt sau khi cân/đếm:',
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
                            selectedCareOptionIds.isNotEmpty
                                ? '+${_formatCurrency(_calculateAddonFee())}đ'
                                : 'Theo thực tế',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedCareOptionIds.isNotEmpty
                                ? '(tiện ích + giặt thực tế)'
                                : '(chờ shipper kiểm đếm)',
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
                    if (selectedServiceIds.isEmpty && availableServices.isNotEmpty) {
                      final defaultSvc = availableServices.firstWhere(
                        (s) => s['id'] == 7,
                        orElse: () => availableServices.first,
                      );
                      final defaultId = (defaultSvc['id'] as num?)?.toInt();
                      if (defaultId != null) selectedServiceIds.add(defaultId);
                    }
                    final orderItems = _buildOrderItems();
                    if (orderItems.isEmpty) {
                      _showToast('Vui lòng chọn ít nhất một dịch vụ.');
                      return;
                    }
                    final int addonFee = _calculateAddonFee();
                    final String step1Note = _buildBookingNote();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookingStep2Screen(
                              items: orderItems,
                              addonFee: addonFee,
                              initialNote: step1Note,
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
