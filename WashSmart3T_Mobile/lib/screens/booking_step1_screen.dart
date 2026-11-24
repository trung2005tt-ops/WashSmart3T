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
  double estimatedWeightKg = 3.0; // Khối lượng ước tính mặc định 3.0 kg
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
    var ids = selectedServiceIds.toList();
    if (ids.isEmpty && availableServices.isNotEmpty) {
      final defaultSvc = availableServices.firstWhere(
        (s) => s['id'] == 7,
        orElse: () => availableServices.first,
      );
      final defaultId = (defaultSvc['id'] as num?)?.toInt() ?? 7;
      ids = [defaultId];
    }

    return ids.map((id) {
      final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
      final name = svc['name']?.toString() ?? 'Dịch vụ $id';
      final isByItem = svc.isNotEmpty ? _isServiceByItem(svc) : false;
      final unit = svc.isNotEmpty ? _getServiceUnit(svc) : (isByItem ? 'cái' : 'kg');
      final price = svc.isNotEmpty ? _getServicePrice(svc) : 0;
      final qty = isByItem ? (selectedItemQuantities[id] ?? 1).toDouble() : estimatedWeightKg;
      final lineTotal = (price * qty).round();

      return <String, dynamic>{
        'serviceId': id,
        'name': name,
        'description': svc['description']?.toString() ?? '',
        'unit': unit,
        'unitPrice': price,
        'isByItem': isByItem,
        'quantity': qty,
        'totalPrice': lineTotal,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getSelectedCareOptions() {
    return selectedCareOptionIds.map((id) {
      final opt = availableCareOptions.firstWhere((c) => c['id'] == id, orElse: () => {});
      return <String, dynamic>{
        'id': id,
        'name': opt['name']?.toString() ?? 'Tiện ích $id',
        'price': (opt['price'] as num? ?? 0).toInt(),
        'badgeText': opt['badgeText']?.toString() ?? '',
        'icon': opt['icon']?.toString() ?? 'verified',
      };
    }).toList();
  }

  int _calculateEstimatedWashPrice() {
    int total = 0;
    for (final id in selectedServiceIds) {
      final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
      if (svc.isNotEmpty) {
        final price = _getServicePrice(svc);
        final isByItem = _isServiceByItem(svc);
        if (isByItem) {
          final qty = selectedItemQuantities[id] ?? 1;
          total += price * qty;
        } else {
          total += (price * estimatedWeightKg).round();
        }
      }
    }
    return total;
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

  // --- WIDGET 3: GÓI DỊCH VỤ GIẶT ỦI ĐANG CHỌN (ĐỒNG BỘ ĐỘNG THEO DỊCH VỤ ĐÃ CHỌN) ---
  Widget _buildServicePackageSection() {
    final mainSvcId = selectedComboboxServiceId ?? (selectedServiceIds.isNotEmpty ? selectedServiceIds.first : 7);
    final mainSvc = availableServices.firstWhere(
      (s) => s['id'] == mainSvcId,
      orElse: () => availableServices.isNotEmpty ? availableServices.first : {},
    );
    final name = mainSvc['name']?.toString() ?? 'Giặt sấy tiêu chuẩn 3T';
    final desc = mainSvc['description']?.toString() ??
        'Giặt sạch sâu, sấy dịu chống co rút & gấp xếp ngay ngắn theo chuẩn khách sạn.';
    final unit = mainSvc.isNotEmpty ? _getServiceUnit(mainSvc) : 'kg';
    final price = mainSvc.isNotEmpty ? _getServicePrice(mainSvc) : 15000;
    final isByItem = mainSvc.isNotEmpty ? _isServiceByItem(mainSvc) : false;

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
                'Dịch vụ chính',
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
                    child: Icon(
                      isByItem ? Icons.dry_cleaning : Icons.local_laundry_service,
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
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                          desc,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                      'Đơn giá dịch vụ:',
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
                          _formatCurrency(price),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          ' đ/$unit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
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

  // Khách hàng chọn khối lượng (kg) hoặc số lượng (bộ/cái/đôi) ước tính tùy theo dịch vụ đã chọn
  Widget _buildWeightEstimationSection() {
    final kgServices = selectedServiceIds.map((id) {
      return availableServices.firstWhere((s) => s['id'] == id, orElse: () => <String, dynamic>{});
    }).where((svc) => svc.isNotEmpty && !_isServiceByItem(svc)).toList();

    final itemServices = selectedServiceIds.map((id) {
      return availableServices.firstWhere((s) => s['id'] == id, orElse: () => <String, dynamic>{});
    }).where((svc) => svc.isNotEmpty && _isServiceByItem(svc)).toList();

    final children = <Widget>[];

    // NẾU CÓ DỊCH VỤ THEO KG (Giặt sấy tiêu chuẩn, Giặt thường, Giặt nhanh, Giặt rèm cửa...)
    if (kgServices.isNotEmpty) {
      children.add(_buildKgEstimationCard(kgServices));
    }

    // NẾU CÓ DỊCH VỤ THEO MÓN (Bộ, Cái, Đôi: Comple/Áo vest, Giày sneaker, Đầm dạ hội, Chăn mền...)
    if (itemServices.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 14));
      }
      for (final svc in itemServices) {
        children.add(_buildItemQuantityEstimationCard(svc));
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // Khối Lượng Ước Tính cho các dịch vụ tính theo KG
  Widget _buildKgEstimationCard(List<Map<String, dynamic>> kgServices) {
    int estimatedKgAmount = 0;
    int totalRatePerKg = 0;
    bool isCurtain = false;

    for (final svc in kgServices) {
      final price = _getServicePrice(svc);
      totalRatePerKg += price;
      estimatedKgAmount += (price * estimatedWeightKg).round();
      final name = (svc['name'] ?? '').toString().toLowerCase();
      if (name.contains('rèm') || name.contains('màn')) {
        isCurtain = true;
      }
    }

    final presetList = isCurtain
        ? [3.0, 5.0, 8.0, 10.0, 15.0]
        : [2.0, 3.0, 5.0, 7.0, 10.0];

    final title = kgServices.length == 1
        ? 'Khối Lượng Ước Tính (Theo kg)'
        : 'Khối Lượng Ước Tính (${kgServices.length} dịch vụ giặt theo kg)';

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
                  const Icon(Icons.scale, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
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
                  '${estimatedWeightKg.toStringAsFixed(1)} kg',
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
            isCurtain
                ? 'Chọn khối lượng rèm cửa ước chừng. Shipper 3T trang bị cân điện tử mini IoT để cân chốt chính xác khi nhận đồ.'
                : 'Chọn khối lượng ước chừng để tạm tính chi phí. Shipper 3T sẽ cân chốt thực tế khi nhận đồ.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // BỘ ĐẾM SỐ KG LỚN [-] X.X kg [+]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    if (estimatedWeightKg > 1.0) {
                      setState(() {
                        estimatedWeightKg = (estimatedWeightKg - 0.5);
                        if (estimatedWeightKg < 1.0) estimatedWeightKg = 1.0;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: outlineVariant),
                    ),
                    child: Icon(
                      Icons.remove,
                      color: estimatedWeightKg > 1.0 ? primaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          estimatedWeightKg.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'kg',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (estimatedKgAmount > 0)
                      Text(
                        kgServices.length == 1
                            ? 'Tạm tính: ~${_formatCurrency(estimatedKgAmount)} đ (${_formatCurrency(totalRatePerKg)} đ/kg)'
                            : 'Tạm tính: ~${_formatCurrency(estimatedKgAmount)} đ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tertiaryColor,
                        ),
                      ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    if (estimatedWeightKg < 30.0) {
                      setState(() {
                        estimatedWeightKg = (estimatedWeightKg + 0.5);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // CÁC NÚT CHỌN NHANH: 2kg, 3kg, 5kg, 7kg, 10kg
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presetList.map((presetKg) {
                final isSelected = (estimatedWeightKg - presetKg).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('${presetKg.toInt()} kg'),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : onSurface,
                    ),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    backgroundColor: surfaceLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? primaryColor : outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          estimatedWeightKg = presetKg;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // LỜI NHẮC CÂN ĐO MINH BẠCH
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 16, color: tertiaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shipper 3T trang bị cân điện tử mini IoT, cân chốt minh bạch trước mặt bạn khi nhận đồ.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                      height: 1.3,
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

  // Số Lượng Ước Tính cho dịch vụ tính theo Món (Bộ, Cái, Đôi)
  Widget _buildItemQuantityEstimationCard(Map<String, dynamic> svc) {
    final id = (svc['id'] as num).toInt();
    final name = svc['name']?.toString() ?? 'Dịch vụ $id';
    final unit = _getServiceUnit(svc);
    final price = _getServicePrice(svc);
    final qty = selectedItemQuantities[id] ?? 1;
    final nameLower = name.toLowerCase();

    IconData itemIcon = Icons.checkroom;
    if (unit.toLowerCase().contains('bộ') || nameLower.contains('vest') || nameLower.contains('comple')) {
      itemIcon = Icons.dry_cleaning;
    } else if (unit.toLowerCase().contains('đôi') || nameLower.contains('giày') || nameLower.contains('sneaker')) {
      itemIcon = Icons.style;
    } else if (nameLower.contains('mền') || nameLower.contains('drap') || nameLower.contains('chăn')) {
      itemIcon = Icons.bed;
    }

    final totalLinePrice = price * qty;
    final presetCounts = [1, 2, 3, 4, 5];

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
                  Icon(itemIcon, color: secondaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Số Lượng Ước Tính (Theo $unit)',
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
                  color: const Color(0xFFFFEEF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$qty $unit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn số lượng $unit cho gói "$name" để tạm tính chi phí. Shipper 3T sẽ kiểm đếm xác nhận cùng bạn khi nhận đồ.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // BỘ ĐẾM SỐ LƯỢNG MÓN [-] X cái/bộ/đôi [+]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: secondaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    if (qty > 1) {
                      setState(() {
                        selectedItemQuantities[id] = qty - 1;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: outlineVariant),
                    ),
                    child: Icon(
                      Icons.remove,
                      color: qty > 1 ? secondaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$qty',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tạm tính: ~${_formatCurrency(totalLinePrice)} đ (${_formatCurrency(price)} đ/$unit)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    if (qty < 50) {
                      setState(() {
                        selectedItemQuantities[id] = qty + 1;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: secondaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // CÁC NÚT CHỌN NHANH: 1, 2, 3, 4, 5
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presetCounts.map((presetVal) {
                final isSelected = qty == presetVal;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('$presetVal $unit'),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : onSurface,
                    ),
                    selected: isSelected,
                    selectedColor: secondaryColor,
                    backgroundColor: surfaceLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? secondaryColor : outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedItemQuantities[id] = presetVal;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // LỜI NHẮC KIỂM ĐẾM MINH BẠCH
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 16, color: secondaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unit.toLowerCase().contains('đôi') || nameLower.contains('giày')
                        ? 'Shipper 3T kiểm tra tình trạng giày, chụp ảnh đối soát và bấm seal niêm phong minh bạch trước mặt bạn.'
                        : 'Shipper 3T kiểm đếm số lượng chi tiết, đối soát và bấm seal niêm phong minh bạch trước mặt bạn khi nhận đồ.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: onSurfaceVariant,
                      height: 1.3,
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
                        selectedServiceIds.clear();
                        selectedServiceIds.add(newId);
                        if (!selectedItemQuantities.containsKey(newId)) {
                          selectedItemQuantities[newId] = 1;
                        }
                        final svc = availableServices.firstWhere((s) => s['id'] == newId, orElse: () => {});
                        final name = (svc['name'] ?? '').toString().toLowerCase();
                        if (name.contains('rèm') || name.contains('màn')) {
                          if (estimatedWeightKg < 5.0) estimatedWeightKg = 5.0;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dịch vụ đã chọn trong đơn (${selectedServiceIds.length}):',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: onSurfaceVariant,
                  ),
                ),
                if (availableServices.length > selectedServiceIds.length)
                  InkWell(
                    onTap: () => _showAddServiceBottomSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            '+ Thêm dịch vụ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                              child: Padding(
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

  String _getBottomEstimationSummaryText() {
    final hasKg = selectedServiceIds.any((id) {
      final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
      return svc.isNotEmpty && !_isServiceByItem(svc);
    });
    final itemSvcs = selectedServiceIds.where((id) {
      final svc = availableServices.firstWhere((s) => s['id'] == id, orElse: () => {});
      return svc.isNotEmpty && _isServiceByItem(svc);
    }).toList();

    if (hasKg && itemSvcs.isNotEmpty) {
      int totalItems = 0;
      for (final id in itemSvcs) {
        totalItems += selectedItemQuantities[id] ?? 1;
      }
      return '(tạm tính: ${estimatedWeightKg.toStringAsFixed(1)} kg + $totalItems món)';
    } else if (hasKg) {
      return '(tạm tính theo ${estimatedWeightKg.toStringAsFixed(1)} kg)';
    } else if (itemSvcs.isNotEmpty) {
      if (itemSvcs.length == 1) {
        final svc = availableServices.firstWhere((s) => s['id'] == itemSvcs.first, orElse: () => {});
        final unit = _getServiceUnit(svc);
        final qty = selectedItemQuantities[itemSvcs.first] ?? 1;
        return '(tạm tính theo $qty $unit)';
      } else {
        int totalItems = 0;
        for (final id in itemSvcs) {
          totalItems += selectedItemQuantities[id] ?? 1;
        }
        return '(tạm tính theo $totalItems món)';
      }
    }
    return '(tạm tính)';
  }

  void _showAddServiceBottomSheet(BuildContext context) {
    final unselectedServices = availableServices.where((svc) {
      final id = (svc['id'] as num).toInt();
      return !selectedServiceIds.contains(id);
    }).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: cardBg,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Thêm dịch vụ kết hợp vào đơn hàng',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn thêm dịch vụ bạn muốn gom giặt chung trong chuyến lấy đồ này.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (unselectedServices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Bạn đã thêm tất cả các dịch vụ hiện có.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: unselectedServices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final svc = unselectedServices[i];
                        final id = (svc['id'] as num).toInt();
                        final name = svc['name']?.toString() ?? 'Dịch vụ $id';
                        final unit = _getServiceUnit(svc);
                        final price = _getServicePrice(svc);
                        final isByItem = _isServiceByItem(svc);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: surfaceLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isByItem ? Icons.checkroom : Icons.local_laundry_service,
                              color: isByItem ? secondaryColor : primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatCurrency(price)} đ/$unit • ${isByItem ? 'Theo $unit' : 'Theo kg'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: isByItem ? secondaryColor : tertiaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.add_circle, color: primaryColor),
                          onTap: () {
                            setState(() {
                              selectedServiceIds.add(id);
                              if (!selectedItemQuantities.containsKey(id)) {
                                selectedItemQuantities[id] = 1;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
                            'Tạm tính tạm thời:',
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
                            '~${_formatCurrency(_calculateEstimatedWashPrice() + _calculateAddonFee())} đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getBottomEstimationSummaryText(),
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
                          'Ước tính',
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
                              selectedCareOptions: _getSelectedCareOptions(),
                              estimatedWeight: estimatedWeightKg,
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
