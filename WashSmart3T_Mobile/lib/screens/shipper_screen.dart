import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import '../services/auth_service.dart';

enum OrderType { pickup, delivery }

enum ShipperOrderStatus {
  available, // Đơn mới chưa ai nhận / Chờ shipper nhận
  pickingUp, // Shipper đang tới nhà khách lấy đồ
  inStore, // Đã về cửa hàng (đang giặt sấy)
  delivering, // Shipper đang giao đồ sạch tới nhà khách
  completed, // Đã hoàn thành
  cancelled, // Đơn sự cố / Hủy
}

class ShipperOrderModel {
  final int? orderId; // ID thực từ backend
  final String id; // Mã hiển thị: WS3T-XXXX
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final String deliveryAddress;
  final double distanceKm;
  final OrderType type;
  ShipperOrderStatus status;
  final String serviceDetails;
  final double weightKg;
  final double codAmount;
  final bool isPaidOnline;
  final String timeWindow;
  final String customerNote;
  final String? proofPhotoUrl;
  final List<Map<String, dynamic>> items;

  ShipperOrderModel({
    this.orderId,
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.distanceKm,
    required this.type,
    required this.status,
    required this.serviceDetails,
    required this.weightKg,
    required this.codAmount,
    required this.isPaidOnline,
    required this.timeWindow,
    required this.customerNote,
    this.proofPhotoUrl,
    this.items = const [],
  });

  /// Chuyển đổi status backend sang ShipperOrderStatus
  static ShipperOrderStatus statusFromApi(String s) {
    switch (s) {
      case 'Confirmed':
        return ShipperOrderStatus.available; // chờ shipper lấy hàng
      case 'PickingUp':
        return ShipperOrderStatus.pickingUp;
      case 'Received':
        return ShipperOrderStatus.inStore;
      case 'Ready':
        return ShipperOrderStatus.available; // sẵn sàng → shipper giao
      case 'Delivering':
        return ShipperOrderStatus.delivering;
      case 'Completed':
        return ShipperOrderStatus.completed;
      case 'Cancelled':
        return ShipperOrderStatus.cancelled;
      default:
        return ShipperOrderStatus.available;
    }
  }

  /// Chuyển ShipperOrderStatus về status string gửi lên API
  static String statusToApi(ShipperOrderStatus s) {
    switch (s) {
      case ShipperOrderStatus.pickingUp:
        return 'PickingUp';
      case ShipperOrderStatus.inStore:
        return 'Received';
      case ShipperOrderStatus.delivering:
        return 'Delivering';
      case ShipperOrderStatus.completed:
        return 'Completed';
      default:
        return '';
    }
  }
}

class ShipperScreen extends StatefulWidget {
  const ShipperScreen({super.key});

  @override
  State<ShipperScreen> createState() => _ShipperScreenState();
}

class _ShipperScreenState extends State<ShipperScreen>
    with SingleTickerProviderStateMixin {
  // Brand Color Tokens
  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  bool _isOnline = true;
  String _shipperName = 'Shipper';
  int _selectedFilterIndex = 0; // 0: Cần lấy, 1: Cần giao, 2: Đã hoàn tất
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  // Shipper Stats
  static const double _kpiPerOrder = 30000;
  static const double _baseSalary = 10000000;
  final double _violationFee = 50000;
  int _todayCompletedCount = 0;

  double get kpiEarnings => _todayCompletedCount * _kpiPerOrder;
  double get totalIncome => kpiEarnings + _baseSalary - _violationFee;

  // Dữ liệu đơn từ API (không còn mock)
  List<ShipperOrderModel> _orders = [];
  bool _isLoading = false;
  String? _loadError;

  static const String _baseUrl = 'http://localhost:5085/api';

  /// Lấy danh sách đơn từ API backend thật
  Future<void> _loadOrdersFromApi() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _loadError = 'Bạn chưa đăng nhập. Vui lòng đăng nhập lại.';
          _isLoading = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse('$_baseUrl/Orders/shipper-orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Lỗi tải đơn hàng (HTTP ${res.statusCode})';
          _isLoading = false;
        });
        return;
      }

      // Lấy tên tài khoản hiện tại từ API hồ sơ; không dùng tên mẫu hard-code.
      await _loadShipperProfile(token);

      final List<dynamic> raw = jsonDecode(res.body);
      final List<ShipperOrderModel> parsed = [];
      int completedCount = 0;

      for (final o in raw) {
        final apiStatus = o['status'] as String? ?? '';
        final shipperStatus = ShipperOrderModel.statusFromApi(apiStatus);

        // Xác định loại đơn: pickup (lấy đồ về tiệm) hay delivery (giao đồ đến khách)
        // Confirmed/PickingUp/Received => shipper lấy hàng từ khách về tiệm
        // Ready/Delivering => shipper giao đồ sạch đến khách
        final isDelivery = (apiStatus == 'Ready' || apiStatus == 'Delivering');
        final type = isDelivery ? OrderType.delivery : OrderType.pickup;

        final items = (o['items'] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((item) {
              return {
                'serviceId': item['serviceId'] ?? item['ServiceId'] ?? 0,
                'type': item['serviceName'] ?? 'Dịch vụ',
                'kg': (item['quantity'] ?? 0).toDouble(),
                'quantity': (item['quantity'] ?? 0).toDouble(),
                'unit': (item['unit'] ?? item['Unit'] ?? 'KG').toString(),
                'unitPrice': (item['unitPrice'] ?? item['UnitPrice'] ?? 0)
                    .toDouble(),
                'totalPrice': (item['totalPrice'] ?? item['TotalPrice'] ?? 0)
                    .toDouble(),
                'service': item['serviceName'] ?? '',
                'status': apiStatus,
              };
            })
            .toList();

        final serviceDetails = items
            .map((i) => '${i['type']} × ${i['kg']}')
            .join(' • ');
        final totalAmount = (o['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = o['createdAt'] != null
            ? DateTime.tryParse(o['createdAt'] as String) ?? DateTime.now()
            : DateTime.now();
        final timeStr =
            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} ngày ${createdAt.day}/${createdAt.month}';

        final backendId = o['id'] as int? ?? 0;
        final displayCode = 'WS3T-${backendId.toString().padLeft(4, '0')}';

        if (shipperStatus == ShipperOrderStatus.completed) completedCount++;

        parsed.add(
          ShipperOrderModel(
            orderId: backendId,
            id: displayCode,
            customerName: o['customerName'] as String? ?? 'Khách hàng',
            customerPhone:
                o['customerPhone'] as String? ??
                o['contactPhone'] as String? ??
                '',
            pickupAddress: o['pickupAddress'] as String? ?? '',
            deliveryAddress: o['deliveryAddress'] as String? ?? '',
            distanceKm: 0.0,
            type: type,
            status: shipperStatus,
            serviceDetails: serviceDetails.isNotEmpty
                ? serviceDetails
                : 'Dịch vụ giặt',
            weightKg: items
                .where((i) => i['unit'].toString().toUpperCase() == 'KG')
                .fold<double>(
                  0.0,
                  (sum, i) =>
                      sum + ((i['quantity'] as num?)?.toDouble() ?? 0.0),
                ),
            codAmount: totalAmount,
            isPaidOnline: false,
            timeWindow: timeStr,
            customerNote: o['note'] as String? ?? '',
            items: items,
          ),
        );
      }

      setState(() {
        _orders = parsed;
        _todayCompletedCount = completedCount;
        // Nếu không có đơn lấy nhưng có đơn giao, tự mở tab giao để đơn hiện ngay.
        final hasPickup = parsed.any(
          (o) =>
              o.type == OrderType.pickup &&
              o.status != ShipperOrderStatus.completed,
        );
        final hasDelivery = parsed.any(
          (o) =>
              o.type == OrderType.delivery &&
              o.status != ShipperOrderStatus.completed,
        );
        if (_selectedFilterIndex == 0 && !hasPickup && hasDelivery) {
          _selectedFilterIndex = 1;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Không kết nối được đến máy chủ: $e';
        _isLoading = false;
      });
    }
  }

  /// Lấy tên đúng của tài khoản Shipper đang đăng nhập.
  Future<void> _loadShipperProfile(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/Auth/me'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map) {
          final name =
              (body['fullName'] ??
                      body['FullName'] ??
                      body['name'] ??
                      body['Name'] ??
                      '')
                  .toString()
                  .trim();
          if (name.isNotEmpty && mounted) {
            setState(
              () => _shipperName = name.startsWith('Shipper ')
                  ? name
                  : 'Shipper $name',
            );
            return;
          }
        }
      }
    } catch (_) {
      // Nếu endpoint hồ sơ không khả dụng, thử đọc tên từ JWT bên dưới.
    }

    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final claims = jsonDecode(utf8.decode(base64Url.decode(normalized)));
        if (claims is Map) {
          final name =
              (claims['fullName'] ??
                      claims['FullName'] ??
                      claims['name'] ??
                      claims['unique_name'] ??
                      '')
                  .toString()
                  .trim();
          if (name.isNotEmpty && mounted) {
            setState(
              () => _shipperName = name.startsWith('Shipper ')
                  ? name
                  : 'Shipper $name',
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Gửi trạng thái lên backend; không đổi giao diện trước khi API xác nhận.
  Future<bool> _pushStatusToApi(
    int backendOrderId,
    String apiStatus, {
    String? note,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        _showToast(
          'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
          isSuccess: false,
        );
        return false;
      }
      final res = await http.put(
        Uri.parse('$_baseUrl/Orders/$backendOrderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': apiStatus,
          'note': note ?? 'Shipper cập nhật từ ứng dụng',
        }),
      );
      if (res.statusCode != 200) {
        String message = 'HTTP ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null)
            message = body['message'].toString();
        } catch (_) {}
        _showToast('Không thể cập nhật trạng thái: $message', isSuccess: false);
        return false;
      }
      return true;
    } catch (e) {
      _showToast('Không kết nối được API: $e', isSuccess: false);
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Tải đơn hàng thật từ API khi mở màn hình
    _loadOrdersFromApi();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ShipperOrderModel> get filteredOrders {
    return _orders.where((order) {
      // Filter by tab (0: Cần lấy, 1: Cần giao, 2: Đã hoàn tất)
      if (_selectedFilterIndex == 0) {
        if (order.type != OrderType.pickup ||
            order.status == ShipperOrderStatus.completed)
          return false;
      }
      if (_selectedFilterIndex == 1) {
        if (order.type != OrderType.delivery ||
            order.status == ShipperOrderStatus.completed)
          return false;
      }
      if (_selectedFilterIndex == 2 &&
          order.status != ShipperOrderStatus.completed)
        return false;

      // Filter by search text
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = order.id.toLowerCase().contains(q);
        final matchName = order.customerName.toLowerCase().contains(q);
        final matchPhone = order.customerPhone.contains(q);
        final matchAddr =
            order.pickupAddress.toLowerCase().contains(q) ||
            order.deliveryAddress.toLowerCase().contains(q);
        return matchId || matchName || matchPhone || matchAddr;
      }
      return true;
    }).toList();
  }

  void _showToast(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? tertiaryColor : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _updateOrderStatus(
    ShipperOrderModel order,
    ShipperOrderStatus newStatus,
  ) async {
    final apiStatus = ShipperOrderModel.statusToApi(newStatus);
    if (order.orderId != null && order.orderId! > 0 && apiStatus.isNotEmpty) {
      final ok = await _pushStatusToApi(order.orderId!, apiStatus);
      if (!ok) return false;
    }
    if (!mounted) return false;
    setState(() {
      final wasCompleted = order.status == ShipperOrderStatus.completed;
      order.status = newStatus;
      if (newStatus == ShipperOrderStatus.completed && !wasCompleted) {
        _todayCompletedCount += 1;
      }
    });
    final statusText = switch (newStatus) {
      ShipperOrderStatus.pickingUp => 'Đã nhận đơn lấy hàng #${order.id}',
      ShipperOrderStatus.inStore =>
        'Đã xác nhận mang hàng #${order.id} về tiệm',
      ShipperOrderStatus.delivering =>
        'Đã nhận đơn và bắt đầu giao #${order.id}',
      ShipperOrderStatus.completed =>
        'Đã hoàn tất đơn hàng #${order.id} thành công!',
      _ => 'Đã cập nhật đơn #${order.id}',
    };
    _showToast(statusText);
    await _loadOrdersFromApi();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    int pickupCount = _orders
        .where(
          (o) =>
              o.type == OrderType.pickup &&
              o.status != ShipperOrderStatus.completed &&
              o.status != ShipperOrderStatus.cancelled,
        )
        .length;
    int deliveryCount = _orders
        .where(
          (o) =>
              o.type == OrderType.delivery &&
              o.status != ShipperOrderStatus.completed &&
              o.status != ShipperOrderStatus.cancelled,
        )
        .length;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_laundry_service_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHIPPER 3T PRO',
                  style: GoogleFonts.plusJakartaSans(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Điều Phối Lấy & Giao',
                  style: GoogleFonts.plusJakartaSans(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle Online/Offline Status
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline
                  ? successColor.withValues(alpha: 0.15)
                  : outlineColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOnline ? successColor : outlineColor,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isOnline = !_isOnline;
                });
                _showToast(
                  _isOnline
                      ? 'Bạn đã BẬT chế độ sẵn sàng nhận đơn'
                      : 'Bạn đã TẮT chế độ nhận đơn (Tạm nghỉ)',
                  isSuccess: _isOnline,
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? successColor : outlineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Trực tuyến' : 'Tạm nghỉ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? successColor : outlineColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Shipper Header Info Card
            _buildShipperProfileCard(),
            const SizedBox(height: 16),

            // 2. Stats Dashboard Cards (Daily Performance & COD)
            _buildDashboardStats(),
            const SizedBox(height: 16),

            // 3. Search Bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // 4. Custom Filter Chips
            _buildFilterTabs(pickupCount, deliveryCount),
            const SizedBox(height: 16),

            // 5. Header Title & Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách đơn (${filteredOrders.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _loadOrdersFromApi();
                          _showToast('Đang làm mới danh sách đơn...');
                        },
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: primaryColor,
                  ),
                  label: Text(
                    'Làm mới',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 6. Orders List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (_loadError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDADB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loadError!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadOrdersFromApi,
                      child: Text(
                        'Thử lại',
                        style: GoogleFonts.plusJakartaSans(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (filteredOrders.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredOrders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildOrderCard(filteredOrders[index]);
                },
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  // 🚀 Đăng xuất: xóa token & về màn hình đăng nhập
  Future<void> _handleLogout(BuildContext context) async {
    // Xác nhận trước khi đăng xuất
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Đăng xuất?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản shipper không?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Hủy',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Xóa Token lưu dưới SharedPreferences
    await AuthService.logout();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đăng xuất tài khoản shipper!'),
        duration: Duration(seconds: 2),
      ),
    );

    // Về Trang đăng nhập và xóa toàn bộ Stack màn hình cũ
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildShipperProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB90538), Color(0xFF800326)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 34, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: successColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _shipperName,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.amber, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Tài khoản Shipper',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Điều phối lấy & giao',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showShipperWalletDialog,
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            tooltip: 'Ví Shipper',
          ),
          IconButton(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Thu nhập KPI',
            value: '${(kpiEarnings / 1000).toStringAsFixed(0)}k đ',
            icon: Icons.monetization_on,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'Lương cứng',
            value: '${(_baseSalary / 1000).toStringAsFixed(0)}k đ',
            icon: Icons.payments,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'Đã xong',
            value: '$_todayCompletedCount đơn',
            icon: Icons.task_alt,
            iconBg: const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: outlineColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Tìm theo mã đơn, tên khách, số điện thoại, đường...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: outlineColor.withValues(alpha: 0.7),
          ),
          prefixIcon: const Icon(Icons.search, color: outlineColor, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: outlineColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(int pickupCount, int deliveryCount) {
    final filterItems = [
      //{'label': 'Tất cả', 'count': _orders.length},
      {'label': 'Cần lấy ($pickupCount)', 'count': pickupCount},
      {'label': 'Cần giao ($deliveryCount)', 'count': deliveryCount},
      {'label': 'Đã hoàn tất', 'count': _todayCompletedCount},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filterItems.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filterItems[index]['label'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: cardBg,
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : const Color(0xFFFFD9DC),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilterIndex = index;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(ShipperOrderModel order) {
    bool isPickup = order.type == OrderType.pickup;
    Color statusBgColor;
    Color statusTextColor;
    String statusTitle;

    switch (order.status) {
      case ShipperOrderStatus.available:
        statusBgColor = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFD97706);
        statusTitle = isPickup ? 'CHỜ LẤY HÀNG' : 'SẴN SÀNG GIAO';
        break;
      case ShipperOrderStatus.pickingUp:
        statusBgColor = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0284C7);
        statusTitle = 'ĐANG ĐẾN LẤY HÀNG';
        break;
      case ShipperOrderStatus.delivering:
        statusBgColor = surfaceHigh;
        statusTextColor = primaryColor;
        statusTitle = 'ĐANG TRÊN ĐƯỜNG GIAO';
        break;
      case ShipperOrderStatus.completed:
        statusBgColor = const Color(0xFFD1FAE5);
        statusTextColor = const Color(0xFF059669);
        statusTitle = 'HOÀN THÀNH';
        break;
      default:
        statusBgColor = surfaceLow;
        statusTextColor = outlineColor;
        statusTitle = 'ĐANG XỬ LÝ';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              order.status == ShipperOrderStatus.pickingUp ||
                  order.status == ShipperOrderStatus.delivering
              ? primaryColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetailSheet(order),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isPickup
                    ? tertiaryColor.withValues(alpha: 0.08)
                    : primaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPickup ? tertiaryColor : primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPickup
                                  ? Icons.arrow_circle_up_rounded
                                  : Icons.local_shipping_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPickup
                                  ? 'LẤY HÀNG TẬN NƠI'
                                  : 'GIAO HÀNG TẬN TAY',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${order.id}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Name & Phone & Distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: outlineColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.customerPhone,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: outlineColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${order.distanceKm} km',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
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

                  // Pickup / Delivery Address Block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.trip_origin,
                              size: 16,
                              color: tertiaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPickup
                                        ? 'Điểm lấy hàng (Nhà khách):'
                                        : 'Điểm lấy (Cửa hàng):',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: outlineColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    order.pickupAddress,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.0),
                          child: Divider(height: 1, color: Color(0xFFFFD9DC)),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPickup
                                        ? 'Điểm đến (Cửa hàng):'
                                        : 'Điểm giao (Nhà khách):',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: outlineColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    order.deliveryAddress,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Service Details & Customer Notes
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: secondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.serviceDetails} (${order.weightKg} kg)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (order.customerNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: warningColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ghi chú: ${order.customerNote}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF92400E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Danh sách đồ gửi kèm (số lượng & dịch vụ)
                  if (order.items.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: secondaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.checklist_rounded,
                                size: 14,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ĐỒ GỬI KÈM (${order.items.length} loại - ${order.weightKg} kg)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...order.items
                              .take(3)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: secondaryColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${item['kg']} kg',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: secondaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item['type']} • ${item['service']} • ${item['status']}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          if (order.items.length > 3)
                            Text(
                              '+ ${order.items.length - 3} món khác...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: outlineColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // COD & Payment Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            order.isPaidOnline
                                ? Icons.verified_user
                                : Icons.payments,
                            size: 16,
                            color: order.isPaidOnline
                                ? successColor
                                : primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.isPaidOnline
                                ? 'Đã thanh toán Online'
                                : 'Thu hộ COD: ${order.codAmount.toStringAsFixed(0)} đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: order.isPaidOnline
                                  ? successColor
                                  : primaryColor,
                            ),
                          ),
                        ],
                      ),
                      // Nút thanh toán cho đơn cần giao chưa trả tiền
                      if (order.type == OrderType.delivery &&
                          !order.isPaidOnline)
                        GestureDetector(
                          onTap: () => _showPaymentDialog(order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Thanh toán',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: outlineColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.timeWindow,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: outlineColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons Bar (Quick Call, Maps, Action)
                  Row(
                    children: [
                      // Call button
                      IconButton.filledTonal(
                        onPressed: () => _simulateCallCustomer(order),
                        icon: const Icon(Icons.call, color: primaryColor),
                        style: IconButton.styleFrom(
                          backgroundColor: surfaceLow,
                        ),
                        tooltip: 'Gọi cho khách',
                      ),
                      // Navigation Maps button
                      IconButton.filledTonal(
                        onPressed: () => _showNavigationModal(order),
                        icon: const Icon(Icons.map, color: tertiaryColor),
                        style: IconButton.styleFrom(
                          backgroundColor: tertiaryColor.withValues(alpha: 0.1),
                        ),
                        tooltip: 'Mở chỉ đường',
                      ),
                      const SizedBox(width: 6),
                      // Main Action Button
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => _handleOrderMainAction(order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getActionButtonColor(order),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              _getActionButtonText(order),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    );
  }

  // Bottom sheet chi tiết đơn hàng: đồ gửi kèm (số lượng) & dịch vụ giặt
  void _showOrderDetailSheet(ShipperOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chi tiết đơn #${order.id}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin khách
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          order.customerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.customerPhone,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: outlineColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Địa chỉ
                    Text(
                      order.type == OrderType.pickup
                          ? 'Điểm lấy hàng:'
                          : 'Điểm giao hàng:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: outlineColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      order.type == OrderType.pickup
                          ? order.pickupAddress
                          : order.deliveryAddress,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bảng đồ gửi kèm
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          size: 18,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ĐỒ GỬI KÈM (${order.items.length} loại - ${order.weightKg} kg)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (order.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Chưa có thông tin đồ gửi kèm.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: outlineColor,
                          ),
                        ),
                      )
                    else ...[
                      // Header bảng
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryColor.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'LOẠI ĐỒ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'DỊCH VỤ GIẶT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'SL / ĐV',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'TRẠNG THÁI',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: secondaryColor.withValues(alpha: 0.2),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          children: List.generate(order.items.length, (i) {
                            final item = order.items[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? Colors.white
                                    : surfaceLow.withValues(alpha: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item['type'].toString(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: onSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '${item['service']}\nĐơn giá: ${_formatVnd((item['unitPrice'] as num?)?.toDouble() ?? 0)} / ${item['unit']}\nThành tiền: ${_formatVnd((item['totalPrice'] as num?)?.toDouble() ?? 0)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: outlineColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${item['quantity']} ${item['unit']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getItemStatusColor(
                                            item['status'].toString(),
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          item['status'].toString(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getItemStatusColor(
                                              item['status'].toString(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Tổng quan dịch vụ & khối lượng
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            Icons.local_laundry_service,
                            'Gói dịch vụ:',
                            order.serviceDetails,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.scale,
                            'Tổng khối lượng:',
                            '${order.weightKg} kg',
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.schedule,
                            'Thời gian:',
                            order.timeWindow,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            order.isPaidOnline
                                ? Icons.verified_user
                                : Icons.payments,
                            'Thanh toán:',
                            order.isPaidOnline
                                ? 'Đã thanh toán Online'
                                : 'COD: ${order.codAmount.toStringAsFixed(0)} đ',
                          ),
                          if (order.customerNote.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              Icons.chat_bubble_outline,
                              'Ghi chú:',
                              order.customerNote,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Nút hành động chính
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleOrderMainAction(order);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getActionButtonColor(order),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _getActionButtonText(order),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Màu badge trạng thái của từng loại đồ trong chi tiết đơn
  Color _getItemStatusColor(String status) {
    switch (status) {
      case 'Đã xác nhận':
        return const Color(0xFF0284C7);
      case 'Đang giặt':
        return const Color(0xFFD97706);
      case 'Đang sấy':
        return secondaryColor;
      case 'Đang ủi':
        return const Color(0xFF7C3AED);
      case 'Hoàn tất':
        return successColor;
      default:
        return outlineColor;
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: outlineColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: outlineColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox,
            size: 56,
            color: outlineColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Không tìm thấy đơn hàng phù hợp',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vui lòng thử đổi bộ lọc hoặc kéo xuống để làm mới.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: outlineColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC HELPERS & DIALOGS ---

  Color _getActionButtonColor(ShipperOrderModel order) {
    switch (order.status) {
      case ShipperOrderStatus.available:
        return primaryColor;
      case ShipperOrderStatus.pickingUp:
        return tertiaryColor;
      case ShipperOrderStatus.delivering:
        return successColor;
      case ShipperOrderStatus.completed:
        return outlineColor;
      default:
        return primaryColor;
    }
  }

  String _getActionButtonText(ShipperOrderModel order) {
    if (order.type == OrderType.pickup) {
      switch (order.status) {
        case ShipperOrderStatus.available:
          return 'Nhận đơn lấy hàng';
        case ShipperOrderStatus.pickingUp:
          return 'Đã lấy đồ từ khách';
        case ShipperOrderStatus.inStore:
          return 'Đã về tiệm giặt';
        case ShipperOrderStatus.completed:
          return 'Đã hoàn thành';
        default:
          return 'Cập nhật';
      }
    } else {
      switch (order.status) {
        case ShipperOrderStatus.available:
          return 'Nhận đơn giao hàng';
        case ShipperOrderStatus.delivering:
          return 'Xác nhận đã giao';
        case ShipperOrderStatus.completed:
          return 'Đã hoàn thành';
        default:
          return 'Cập nhật';
      }
    }
  }

  Future<void> _handleOrderMainAction(ShipperOrderModel order) async {
    if (order.orderId == null || order.orderId! <= 0) {
      _showToast('Đơn hàng chưa có mã từ máy chủ.', isSuccess: false);
      return;
    }
    if (order.type == OrderType.pickup &&
        order.status == ShipperOrderStatus.available) {
      // Chỉ đơn Confirmed mới nhận được cho công đoạn lấy đồ.
      final assigned = await _assignOrderToSelf(order.orderId!);
      if (!assigned) {
        _showToast(
          'Không thể nhận đơn. Kiểm tra trạng thái đơn hoặc nhiệm vụ đang làm.',
          isSuccess: false,
        );
        await _loadOrdersFromApi();
        return;
      }
      await _updateOrderStatus(order, ShipperOrderStatus.pickingUp);
    } else if (order.type == OrderType.pickup &&
        order.status == ShipperOrderStatus.pickingUp) {
      _showPickupWeighingDialog(order);
    } else if (order.type == OrderType.delivery &&
        order.status == ShipperOrderStatus.available) {
      // Chỉ đơn Ready mới nhận được cho công đoạn giao đồ.
      final assigned = await _assignOrderToSelf(order.orderId!);
      if (!assigned) {
        _showToast(
          'Không thể nhận đơn giao. Kiểm tra trạng thái đơn hoặc nhiệm vụ đang làm.',
          isSuccess: false,
        );
        await _loadOrdersFromApi();
        return;
      }
      await _updateOrderStatus(order, ShipperOrderStatus.delivering);
    } else if (order.type == OrderType.delivery &&
        order.status == ShipperOrderStatus.delivering) {
      _showProofPhotoDialog(order, isPickup: false);
    }
  }

  /// Shipper nhận đơn qua POST /api/Orders/{id}/assign.
  Future<bool> _assignOrderToSelf(int backendOrderId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return false;
      final res = await http.post(
        Uri.parse('$_baseUrl/Orders/$backendOrderId/assign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) return true;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          _showToast(body['message'].toString(), isSuccess: false);
        }
      } catch (_) {}
      return false;
    } catch (_) {
      return false;
    }
  }

  String _formatVnd(double value) {
    final whole = value.round();
    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
    }
    return '${buffer.toString()} đ';
  }

  Future<bool> _savePickupDetails(
    ShipperOrderModel order,
    List<Map<String, dynamic>> measuredItems,
    String note,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        _showToast(
          'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
          isSuccess: false,
        );
        return false;
      }
      final res = await http.put(
        Uri.parse('$_baseUrl/Orders/${order.orderId}/pickup-details'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customerConfirmed': true,
          'note': note,
          'items': measuredItems
              .map(
                (item) => {
                  'serviceId': item['serviceId'],
                  'quantity': item['quantity'],
                },
              )
              .toList(),
        }),
      );
      if (res.statusCode != 200) {
        var message = 'HTTP ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null)
            message = body['message'].toString();
        } catch (_) {}
        _showToast('Không lưu được cân nặng: $message', isSuccess: false);
        return false;
      }
      return true;
    } catch (e) {
      _showToast('Lỗi lưu cân nặng: $e', isSuccess: false);
      return false;
    }
  }

  /// Màn nhập cân nặng/số lượng thực tế. Shipper có thể thêm nhiều dịch vụ
  /// khách yêu cầu tại chỗ; danh sách được lấy từ GET /api/Services.
  Future<List<Map<String, dynamic>>> _loadPickupServiceCatalog() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/Services'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách dịch vụ (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final price =
              item['price'] ??
              item['Price'] ??
              item['currentPrice'] ??
              item['CurrentPrice'];
          final priceMap = price is Map
              ? Map<String, dynamic>.from(price)
              : <String, dynamic>{};
          final rawId = item['id'] ?? item['Id'];
          final serviceId = rawId is num
              ? rawId.toInt()
              : int.tryParse('$rawId') ?? 0;
          return <String, dynamic>{
            'serviceId': serviceId,
            'name': (item['name'] ?? item['Name'] ?? 'Dịch vụ').toString(),
            'unit': (priceMap['unit'] ?? priceMap['Unit'] ?? 'KG').toString(),
            'unitPrice': (priceMap['price'] ?? priceMap['Price'] ?? 0)
                .toDouble(),
            'minimumPrice':
                (priceMap['minimumPrice'] ?? priceMap['MinimumPrice']) is num
                ? ((priceMap['minimumPrice'] ?? priceMap['MinimumPrice'])
                          as num)
                      .toDouble()
                : null,
          };
        })
        .where((item) => (item['serviceId'] as int) > 0)
        .toList();
  }

  void _showPickupWeighingDialog(ShipperOrderModel order) async {
    List<Map<String, dynamic>> catalog;
    try {
      catalog = await _loadPickupServiceCatalog();
    } catch (e) {
      if (!mounted) return;
      _showToast(
        'Không tải được danh sách để thêm dịch vụ: $e',
        isSuccess: false,
      );
      // Vẫn cho phép cân các dịch vụ đã có trên đơn.
      catalog = [];
    }
    if (!mounted) return;

    final rows = <Map<String, dynamic>>[];
    for (final item in order.items) {
      final serviceId = (item['serviceId'] as num?)?.toInt() ?? 0;
      if (serviceId <= 0 || rows.any((r) => r['serviceId'] == serviceId))
        continue;
      final catalogItem = catalog.cast<Map<String, dynamic>?>().firstWhere(
        (s) => s?['serviceId'] == serviceId,
        orElse: () => null,
      );
      rows.add({
        'serviceId': serviceId,
        'name':
            (item['service'] ??
                    item['type'] ??
                    catalogItem?['name'] ??
                    'Dịch vụ')
                .toString(),
        'unit': (item['unit'] ?? catalogItem?['unit'] ?? 'KG').toString(),
        'unitPrice':
            ((item['unitPrice'] ??
                        item['UnitPrice'] ??
                        catalogItem?['unitPrice'] ??
                        0)
                    as num)
                .toDouble(),
        'minimumPrice': item['minimumPrice'] ?? catalogItem?['minimumPrice'],
        'isOriginal': true,
        'controller': TextEditingController(
          text: ((item['kg'] ?? item['quantity'] ?? '')).toString(),
        ),
      });
    }

    final noteController = TextEditingController();
    var customerConfirmed = false;
    var submitting = false;
    // Cho phép thêm nhiều dòng, kể cả cùng dịch vụ (ví dụ khách tách riêng
    // hai túi giặt thường). Khi gửi API, các dòng cùng ServiceId sẽ được cộng gộp.
    final initiallyAvailableServices = catalog;
    int? selectedNewServiceId = initiallyAvailableServices.isEmpty
        ? null
        : initiallyAvailableServices.first['serviceId'] as int;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final availableServices = catalog;
          if (selectedNewServiceId != null &&
              !availableServices.any(
                (s) => s['serviceId'] == selectedNewServiceId,
              )) {
            selectedNewServiceId = availableServices.isEmpty
                ? null
                : availableServices.first['serviceId'] as int;
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cân đồ & xác nhận với khách',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đơn ${order.id} • Nhập số lượng thực tế cho từng dịch vụ.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: outlineColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Đơn chưa có dịch vụ hợp lệ. Hãy thêm dịch vụ khách yêu cầu bên dưới.',
                        ),
                      ),
                    ...rows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final controller =
                          row['controller'] as TextEditingController;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F2),
                          border: Border.all(color: const Color(0xFFF5BBC8)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_laundry_service,
                                  color: Color(0xFFC6003D),
                                  size: 22,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. ${row['name']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Mã dịch vụ: ${row['serviceId']} • Đơn vị: ${row['unit']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: outlineColor,
                                        ),
                                      ),
                                      Text(
                                        'Đơn giá: ${_formatVnd((row['unitPrice'] as num?)?.toDouble() ?? 0)} / ${row['unit']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFFC6003D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final q =
                                              double.tryParse(
                                                controller.text
                                                    .trim()
                                                    .replaceAll(',', '.'),
                                              ) ??
                                              0;
                                          final price =
                                              (row['unitPrice'] as num?)
                                                  ?.toDouble() ??
                                              0;
                                          final minimum =
                                              (row['minimumPrice'] as num?)
                                                  ?.toDouble();
                                          final subtotal = q <= 0
                                              ? 0.0
                                              : (minimum != null &&
                                                        q * price < minimum
                                                    ? minimum
                                                    : q * price);
                                          return Text(
                                            'Tạm tính: ${_formatVnd(subtotal)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: outlineColor,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Xóa dịch vụ bổ sung',
                                  onPressed:
                                      submitting || row['isOriginal'] == true
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            rows.removeAt(index);
                                            controller.dispose();
                                          });
                                        },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              onChanged: (_) => setSheetState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Số lượng thực tế (${row['unit']})',
                                suffixText: row['unit'].toString(),
                                prefixIcon: const Icon(
                                  Icons.scale_outlined,
                                  color: Color(0xFFC6003D),
                                ),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (availableServices.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Thêm loại dịch vụ khách yêu cầu',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedNewServiceId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Chọn dịch vụ bổ sung',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                isDense: true,
                              ),
                              items: availableServices
                                  .map(
                                    (service) => DropdownMenuItem<int>(
                                      value: service['serviceId'] as int,
                                      child: Text(
                                        '${service['name']} • ${_formatVnd((service['unitPrice'] as num?)?.toDouble() ?? 0)}/${service['unit']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: submitting
                                  ? null
                                  : (value) => setSheetState(
                                      () => selectedNewServiceId = value,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Thêm dòng dịch vụ',
                            onPressed:
                                submitting || selectedNewServiceId == null
                                ? null
                                : () {
                                    final service = catalog.firstWhere(
                                      (s) =>
                                          s['serviceId'] ==
                                          selectedNewServiceId,
                                    );
                                    setSheetState(() {
                                      rows.add({
                                        'serviceId': service['serviceId'],
                                        'name': service['name'],
                                        'unit': service['unit'],
                                        'unitPrice': service['unitPrice'] ?? 0,
                                        'minimumPrice': service['minimumPrice'],
                                        'isOriginal': false,
                                        'controller': TextEditingController(),
                                      });
                                      final remaining = catalog.where(
                                        (s) => !rows.any(
                                          (r) =>
                                              r['serviceId'] == s['serviceId'],
                                        ),
                                      );
                                      selectedNewServiceId = remaining.isEmpty
                                          ? null
                                          : remaining.first['serviceId'] as int;
                                    });
                                  },
                            icon: const Icon(Icons.add),
                            style: IconButton.styleFrom(
                              backgroundColor: successColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Có thể thêm không giới hạn dòng, kể cả cùng dịch vụ. Giá/đơn vị lấy từ bảng giá hiện hành.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: outlineColor,
                        ),
                      ),
                    ] else if (catalog.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Đã thêm hết các dịch vụ hiện có trong danh mục.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: outlineColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: customerConfirmed,
                      onChanged: submitting
                          ? null
                          : (value) => setSheetState(
                              () => customerConfirmed = value ?? false,
                            ),
                      title: Text(
                        'Đã đối chiếu cân nặng/số lượng với khách hàng',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (rows.isEmpty) {
                                  _showToast(
                                    'Vui lòng thêm ít nhất một dịch vụ.',
                                    isSuccess: false,
                                  );
                                  return;
                                }
                                final measured = <Map<String, dynamic>>[];
                                for (final row in rows) {
                                  final controller =
                                      row['controller']
                                          as TextEditingController;
                                  final quantity = double.tryParse(
                                    controller.text.trim().replaceAll(',', '.'),
                                  );
                                  if (quantity == null || quantity <= 0) {
                                    _showToast(
                                      'Vui lòng nhập số lượng ${row['name']} lớn hơn 0.',
                                      isSuccess: false,
                                    );
                                    return;
                                  }
                                  measured.add({
                                    'serviceId': row['serviceId'],
                                    'quantity': quantity,
                                  });
                                }
                                final grouped = <int, double>{};
                                for (final item in measured) {
                                  final serviceId = (item['serviceId'] as num)
                                      .toInt();
                                  grouped[serviceId] =
                                      (grouped[serviceId] ?? 0) +
                                      (item['quantity'] as double);
                                }
                                final groupedMeasured = grouped.entries
                                    .map(
                                      (entry) => {
                                        'serviceId': entry.key,
                                        'quantity': entry.value,
                                      },
                                    )
                                    .toList();
                                if (!customerConfirmed) {
                                  _showToast(
                                    'Vui lòng xác nhận đã đối chiếu với khách hàng.',
                                    isSuccess: false,
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                final saved = await _savePickupDetails(
                                  order,
                                  groupedMeasured,
                                  noteController.text.trim(),
                                );
                                if (!saved) {
                                  if (sheetContext.mounted)
                                    setSheetState(() => submitting = false);
                                  return;
                                }
                                final moved = await _updateOrderStatus(
                                  order,
                                  ShipperOrderStatus.inStore,
                                );
                                if (moved && sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: successColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          submitting
                              ? 'Đang lưu...'
                              : 'Xác nhận cân đồ & đã lấy hàng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final row in rows) {
        (row['controller'] as TextEditingController).dispose();
      }
      noteController.dispose();
    });
  }

  // ==================== THANH TOÁN (MoMo / Chuyển khoản) ====================
  void _showPaymentDialog(ShipperOrderModel order) {
    PaymentMethod? selected;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: outlineColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Thanh toán đơn ${order.id}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Số tiền cần thu: ${order.codAmount.toStringAsFixed(0)} đ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (selected == null) ...[
                    // ===== Lựa chọn 1: Ví MoMo =====
                    _buildPaymentOptionTile(
                      title: 'Thanh toán bằng ví MoMo',
                      subtitle: 'Quét mã QR qua ứng dụng MoMo',
                      icon: Icons.account_balance_wallet,
                      iconBgColor: const Color(0xFFA50064),
                      onTap: () =>
                          setSheetState(() => selected = PaymentMethod.momo),
                    ),
                    const SizedBox(height: 12),
                    // ===== Lựa chọn 2: Chuyển khoản ngân hàng =====
                    _buildPaymentOptionTile(
                      title: 'Chuyển khoản ngân hàng',
                      subtitle: 'Quét mã QR VietQR / chuyển khoản',
                      icon: Icons.account_balance,
                      iconBgColor: const Color(0xFF006577),
                      onTap: () =>
                          setSheetState(() => selected = PaymentMethod.bank),
                    ),
                  ] else ...[
                    // ===== Hiển thị mã QR minh họa =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected == PaymentMethod.momo
                                    ? Icons.account_balance_wallet
                                    : Icons.account_balance,
                                size: 18,
                                color: selected == PaymentMethod.momo
                                    ? const Color(0xFFA50064)
                                    : tertiaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selected == PaymentMethod.momo
                                    ? 'Ví MoMo'
                                    : 'Chuyển khoản ngân hàng',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: outlineColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: CustomPaint(
                                painter: _IllustrativeQrPainter(
                                  seed: '${order.id}-${selected!.name}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Mã QR minh họa - Khách quét để thanh toán',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: outlineColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Số tiền: ${order.codAmount.toStringAsFixed(0)} đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Nút đổi phương thức & xác nhận
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setSheetState(() => selected = null),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Đổi phương thức',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showToast(
                                'Đã xác nhận thanh toán ${selected == PaymentMethod.momo ? "MoMo" : "chuyển khoản"} cho đơn ${order.id}',
                                isSuccess: true,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Xác nhận đã thu',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconBgColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: outlineColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: outlineColor),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateCallCustomer(ShipperOrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: primaryColor),
            const SizedBox(width: 10),
            Text(
              'Gọi cho khách hàng',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.customerName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.customerPhone,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Ghi chú: ${order.customerNote.isEmpty ? 'Không có' : order.customerNote}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: outlineColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Đóng',
              style: GoogleFonts.plusJakartaSans(color: outlineColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showToast('Đang kết nối cuộc gọi tới ${order.customerPhone}...');
            },
            icon: const Icon(Icons.call, color: Colors.white, size: 18),
            label: Text(
              'Gọi ngay',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationModal(ShipperOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: tertiaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Lộ trình di chuyển (${order.distanceKm} km)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Map Mock Canvas
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=600&auto=format&fit=crop',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Dự kiến 8 phút',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mô phỏng bản đồ dẫn đường GPS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Địa chỉ cần tới:',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: outlineColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.type == OrderType.pickup
                  ? order.pickupAddress
                  : order.deliveryAddress,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showToast('Đang mở ứng dụng Google Maps...');
                },
                icon: const Icon(Icons.near_me, color: Colors.white),
                label: Text(
                  'Mở Google Maps chỉ đường',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tertiaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProofPhotoDialog(
    ShipperOrderModel order, {
    required bool isPickup,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      isPickup
                          ? 'Chụp ảnh túi đồ niêm phong'
                          : 'Chụp ảnh giao hàng thành công',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 42,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn để chụp ảnh minh chứng',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    isPickup
                        ? '(Hình ảnh túi quần áo có dán mã seal 3T)'
                        : '(Hình ảnh khách nhận túi giặt sạch)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: outlineColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isPickup && !order.isPaidOnline && order.codAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số tiền COD cần thu mặt:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          Text(
                            '${order.codAmount.toStringAsFixed(0)} đ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_box_outlined,
                      color: Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final dialogContext = context;
                  if (isPickup) {
                    Navigator.pop(dialogContext);
                    _showPickupWeighingDialog(order);
                    return;
                  }
                  final ok = await _updateOrderStatus(
                    order,
                    ShipperOrderStatus.completed,
                  );
                  if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isPickup
                      ? 'Xác nhận đã nhận đồ & Niêm phong'
                      : 'Xác nhận đã giao & Thu tiền',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShipperWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: primaryColor),
            const SizedBox(width: 10),
            Text(
              'Ví Shipper 3T',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWalletRow(
              'Thu nhập KPI:',
              '${kpiEarnings.toStringAsFixed(0)} đ',
            ),
            const SizedBox(height: 8),
            _buildWalletRow(
              'Lương cứng:',
              '${_baseSalary.toStringAsFixed(0)} đ',
            ),
            const SizedBox(height: 8),
            _buildWalletRow('Số đơn đã xong:', '$_todayCompletedCount đơn'),
            const SizedBox(height: 8),
            _buildWalletRow(
              'Phí vi phạm:',
              '- ${_violationFee.toStringAsFixed(0)} đ',
            ),
            const Divider(height: 20),
            _buildWalletRow(
              'Tổng thu nhập:',
              '${totalIncome.toStringAsFixed(0)} đ',
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Đóng',
              style: GoogleFonts.plusJakartaSans(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: outlineColor),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}

// ==================== Phương thức thanh toán ====================
enum PaymentMethod { momo, bank }

/// Vẽ mã QR minh họa (deterministic từ seed, chỉ để demo - không quét được thật)
class _IllustrativeQrPainter extends CustomPainter {
  final String seed;
  _IllustrativeQrPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    const modules = 25; // grid 25x25
    final cell = size.width / modules;
    final paint = Paint()..color = const Color(0xFF370C14);

    // Deterministic pseudo-random từ seed
    int h = 0;
    for (final code in seed.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    bool rand() {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      return (h >> 16) % 2 == 0;
    }

    // Vẽ các module dữ liệu
    for (int y = 0; y < modules; y++) {
      for (int x = 0; x < modules; x++) {
        final inFinder =
            (x < 7 && y < 7) ||
            (x >= modules - 7 && y < 7) ||
            (x < 7 && y >= modules - 7);
        if (inFinder) continue;
        if (rand()) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }

    // Vẽ 3 finder patterns (3 hình vuông góc như QR thật)
    void drawFinder(int ox, int oy) {
      canvas.drawRect(
        Rect.fromLTWH(ox * cell, oy * cell, 7 * cell, 7 * cell),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH((ox + 1) * cell, (oy + 1) * cell, 5 * cell, 5 * cell),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH((ox + 2) * cell, (oy + 2) * cell, 3 * cell, 3 * cell),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(modules - 7, 0);
    drawFinder(0, modules - 7);

    // Logo trung tâm minh họa
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.07, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      size.width * 0.055,
      Paint()..color = const Color(0xFFB90538),
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrativeQrPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
