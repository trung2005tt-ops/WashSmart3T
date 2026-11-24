import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../utils/url_helper.dart';
import '../widgets/route_map_embed.dart';

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
  double codAmount;
  bool isPaidOnline;
  final String timeWindow;
  final String customerNote;
  final String? proofPhotoUrl;
  final String? pickupProofPhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.pickupProofPhotoUrl,
    this.createdAt,
    this.updatedAt,
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
  int? _currentShipperId;
  Timer? _orderPollingTimer;
  int _selectedFilterIndex = 0; // 0: Cần lấy, 1: Cần giao, 2: Đã hoàn tất
  int _completedTimeFilter = 0; // 0: Đã đi hôm nay, 1: Tất cả lịch sử
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  // Shipper Stats
  int _todayCompletedCount = 0;

  bool _isSameDay(DateTime? d1, DateTime d2) {
    if (d1 == null) return false;
    final local = d1.toLocal();
    return local.year == d2.year && local.month == d2.month && local.day == d2.day;
  }

  // Danh sách các đơn đã hoàn tất trong ngày hôm nay
  List<ShipperOrderModel> get todayCompletedOrders {
    final now = DateTime.now();
    return _orders.where((o) {
      if (o.status != ShipperOrderStatus.completed) return false;
      return _isSameDay(o.updatedAt, now) || _isSameDay(o.createdAt, now);
    }).toList();
  }

  // Tổng tiền COD đã thu trong ngày hôm nay
  double get todayCodCollected {
    return todayCompletedOrders.fold(
      0.0,
      (sum, o) => sum + (o.isPaidOnline ? 0.0 : o.codAmount),
    );
  }

  // Danh sách các đơn đang cần đi (tuyến ghép hôm nay)
  List<ShipperOrderModel> get activePendingOrders {
    final list = _orders
        .where(
          (o) =>
              o.status != ShipperOrderStatus.completed &&
              o.status != ShipperOrderStatus.cancelled,
        )
        .toList();
    list.sort((a, b) {
      int score(ShipperOrderModel m) {
        if (m.status == ShipperOrderStatus.pickingUp) return 0;
        if (m.type == OrderType.pickup &&
            m.status == ShipperOrderStatus.available) {
          return 1;
        }
        if (m.status == ShipperOrderStatus.delivering) return 2;
        if (m.type == OrderType.delivery &&
            m.status == ShipperOrderStatus.available) {
          return 3;
        }
        return 4;
      }

      return score(a).compareTo(score(b));
    });
    return list;
  }

  // Thống kê ca chạy & Đối soát tiền mặt cuối ca
  Map<String, dynamic>? _currentShiftData;

  // Cấu hình tài khoản ngân hàng nhận tiền đồng bộ từ StoreConfig
  String _storeBankBin = '970422';
  String _storeBankName = 'MBBank (Ngân hàng Quân Đội)';
  String _storeBankAccountNo = '0818606505';
  String _storeBankAccountHolder = 'TRAN DIEP MINH TRUNG';

  Future<void> _loadStoreBankConfig() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/StoreConfig'));
      if (res.statusCode == 200) {
        final cfg = jsonDecode(res.body);
        if (cfg is Map<String, dynamic> && mounted) {
          setState(() {
            final bin = cfg['bankBin']?.toString().trim() ?? '';
            final name = cfg['bankName']?.toString().trim() ?? '';
            final acc = cfg['bankAccountNo']?.toString().trim() ?? '';
            final holder = cfg['bankAccountHolder']?.toString().trim() ?? '';
            if (bin.isNotEmpty) _storeBankBin = bin;
            if (name.isNotEmpty) _storeBankName = name;
            if (acc.isNotEmpty) _storeBankAccountNo = acc;
            if (holder.isNotEmpty) _storeBankAccountHolder = holder.toUpperCase();
          });
        }
      }
    } catch (_) {}
  }

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

      if (res.statusCode == 401) {
        await AuthService.logout();
        if (mounted) {
          setState(() {
            _loadError = 'Phiên làm việc đã hết hạn (HTTP 401). Vui lòng đăng nhập lại.';
            _isLoading = false;
          });
          _showSessionExpiredDialog();
        }
        return;
      }

      if (res.statusCode != 200) {
        if (mounted) {
          setState(() {
            _loadError = 'Lỗi tải đơn hàng (HTTP ${res.statusCode})';
            _isLoading = false;
          });
        }
        return;
      }

      // Lấy tên tài khoản hiện tại từ API hồ sơ; không dùng tên mẫu hard-code.
      await _loadShipperProfile(token);
      await _loadCurrentShiftSummary();
      await _loadStoreBankConfig();

      final previousActiveIds = _orders
          .where(
            (o) =>
                o.status != ShipperOrderStatus.completed &&
                o.status != ShipperOrderStatus.cancelled,
          )
          .map((o) => o.orderId)
          .whereType<int>()
          .toSet();

      final List<dynamic> raw = jsonDecode(res.body);
      final List<ShipperOrderModel> parsed = [];
      final List<String> newlyCancelledCodes = [];

      for (final o in raw) {
        final apiStatus = (o['status'] as String? ?? '').trim();
        final shipperStatus = ShipperOrderModel.statusFromApi(apiStatus);
        final backendId = o['id'] as int? ?? 0;
        final displayCode = 'WS3T-${backendId.toString().padLeft(4, '0')}';

        // 🚀 ĐƠN ĐÃ HỦY: Biến mất hoàn toàn, tuyệt đối không để dính trên app shipper
        if (apiStatus.toLowerCase() == 'cancelled' ||
            shipperStatus == ShipperOrderStatus.cancelled) {
          if (previousActiveIds.contains(backendId)) {
            newlyCancelledCodes.add(displayCode);
          }
          continue;
        }

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
        String createdRaw = (o['createdAt'] ?? '').toString().trim();
        if (createdRaw.isNotEmpty && !createdRaw.endsWith('Z') && !createdRaw.contains('+')) {
          createdRaw += 'Z';
        }
        final createdAt = (DateTime.tryParse(createdRaw) ?? DateTime.now()).toLocal();
        String? updatedRaw = o['updatedAt']?.toString().trim();
        if (updatedRaw != null && updatedRaw.isNotEmpty && !updatedRaw.endsWith('Z') && !updatedRaw.contains('+')) {
          updatedRaw += 'Z';
        }
        final updatedAt = updatedRaw != null ? DateTime.tryParse(updatedRaw)?.toLocal() : null;
        final timeStr =
            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} ngày ${createdAt.day}/${createdAt.month}';

        final paymentStatus = (o['paymentStatus'] as String? ?? '').trim().toLowerCase();
        final isPaid = paymentStatus == 'paid';
        final codToCollect = isPaid ? 0.0 : totalAmount;

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
            codAmount: codToCollect,
            isPaidOnline: isPaid,
            timeWindow: timeStr,
            customerNote: o['note'] as String? ?? '',
            proofPhotoUrl: o['deliveryProofPhotoUrl'] as String?,
            pickupProofPhotoUrl: o['pickupProofPhotoUrl'] as String?,
            createdAt: createdAt,
            updatedAt: updatedAt,
            items: items,
          ),
        );
      }

      // Phát hiện những đơn trước đây shipper đang theo dõi nhưng nay biến mất khỏi API (do backend loại bỏ vì đã hủy)
      final newActiveIds = parsed.map((o) => o.orderId).whereType<int>().toSet();
      final disappearedIds = previousActiveIds.difference(newActiveIds);
      for (final dId in disappearedIds) {
        final code = 'WS3T-${dId.toString().padLeft(4, '0')}';
        if (!newlyCancelledCodes.contains(code)) {
          newlyCancelledCodes.add(code);
        }
      }

      // Thông báo rõ ràng cho shipper khi có đơn bị hủy
      if (newlyCancelledCodes.isNotEmpty && _orders.isNotEmpty) {
        _showToast(
          'Đơn ${newlyCancelledCodes.join(', ')} đã bị hủy! Đã tự động gỡ khỏi màn hình làm việc.',
          isSuccess: false,
        );
      }

      setState(() {
        _orders = parsed;
        _todayCompletedCount = todayCompletedOrders.length;
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
          final idVal = body['id'] ?? body['Id'] ?? body['userId'] ?? body['UserId'];
          if (idVal != null) {
            _currentShipperId = int.tryParse(idVal.toString());
          }
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
          final idVal = claims['nameid'] ?? claims['sub'] ?? claims['userId'] ?? claims['UserId'];
          if (idVal != null) {
            _currentShipperId = int.tryParse(idVal.toString());
          }
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

  /// Tải thông tin đối soát sổ ca và các khoản tiền cần bàn giao từ API
  Future<void> _loadCurrentShiftSummary() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse('$_baseUrl/ShiftHandover/current-shift'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentShiftData = data;
          });
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
      if (res.statusCode == 401) {
        _showToast('Phiên làm việc đã hết hạn. Đang chuyển về màn hình đăng nhập...', isSuccess: false);
        await AuthService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return false;
      }
      if (res.statusCode == 401) {
        _showToast('Phiên làm việc đã hết hạn. Đang chuyển về màn hình đăng nhập...', isSuccess: false);
        await AuthService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return false;
      }
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

  Future<void> _syncPresenceToBackend(bool isOnline) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('$_baseUrl/Orders/shipper-presence'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'isOnline': isOnline,
          'latitude': 10.8031, // Cửa hàng WashSmart 3T (140 Lê Trọng Tấn)
          'longitude': 106.6268,
        }),
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Tải đơn hàng thật từ API khi mở màn hình
    _loadOrdersFromApi();
    _syncPresenceToBackend(true);

    // 🚀 Polling kiểm tra đơn hàng mới định kỳ mỗi 10 giây (Item 10)
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _isOnline) {
        _checkNewOrdersSilently();
        _syncPresenceToBackend(true);
      }
    });
  }

  Future<void> _checkNewOrdersSilently() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;
      final res = await http.get(
        Uri.parse('$_baseUrl/Orders/shipper-orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body);

        // Kiểm tra xem có đơn nào bị hủy hoặc số đơn đang làm thay đổi không
        final currentActiveIds = raw
            .where(
              (o) =>
                  (o['status'] ?? '').toString().toLowerCase() != 'cancelled' &&
                  (o['status'] ?? '').toString().toLowerCase() != 'completed',
            )
            .map((o) => (o['id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        final localActiveIds = _orders
            .where(
              (o) =>
                  o.status != ShipperOrderStatus.completed &&
                  o.status != ShipperOrderStatus.cancelled,
            )
            .map((o) => o.orderId)
            .whereType<int>()
            .toSet();

        // Nếu có đơn bị hủy/biến mất hoặc thay đổi, tự động reload ngay để đơn biến mất tức thì
        if (!currentActiveIds.containsAll(localActiveIds) ||
            currentActiveIds.length != localActiveIds.length) {
          if (mounted) {
            _loadOrdersFromApi();
          }
          return;
        }

        final currentPickupWaiting = raw
            .where((o) => o['status'] == 'Confirmed')
            .length;
        final localPickupWaiting = _orders
            .where(
              (o) =>
                  o.type == OrderType.pickup &&
                  o.status == ShipperOrderStatus.available,
            )
            .length;
        if (currentPickupWaiting > localPickupWaiting) {
          if (mounted) {
            _loadOrdersFromApi();
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _orderPollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ShipperOrderModel> get filteredOrders {
    return _orders.where((order) {
      // 🚀 ĐƠN ĐÃ HỦY: Biến mất hoàn toàn, tuyệt đối không để dính trên màn hình của shipper
      if (order.status == ShipperOrderStatus.cancelled) {
        return false;
      }

      // Filter by tab (0: Cần lấy, 1: Cần giao, 2: Đã hoàn tất)
      if (_selectedFilterIndex == 0) {
        if (order.type != OrderType.pickup ||
            order.status == ShipperOrderStatus.completed) {
          return false;
        }
      }
      if (_selectedFilterIndex == 1) {
        if (order.type != OrderType.delivery ||
            order.status == ShipperOrderStatus.completed) {
          return false;
        }
      }
      if (_selectedFilterIndex == 2) {
        if (order.status != ShipperOrderStatus.completed) {
          return false;
        }
        if (_completedTimeFilter == 0) {
          final now = DateTime.now();
          final isToday = _isSameDay(order.updatedAt, now) || _isSameDay(order.createdAt, now);
          if (!isToday) return false;
        }
      }

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
                  'Lộ Trình Giao Nhận',
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
                _syncPresenceToBackend(_isOnline);
                _showToast(
                  _isOnline
                      ? 'Bạn đã BẬT chế độ trực tuyến'
                      : 'Bạn đã TẮT chế độ trực tuyến (Tạm nghỉ)',
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
            const SizedBox(height: 14),

            // 🌟 Tuyến đường di chuyển hôm nay
            _buildRouteShortcutCard(pickupCount, deliveryCount),
            const SizedBox(height: 4),

            // 3. Search Bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // 4. Custom Filter Chips
            _buildFilterTabs(pickupCount, deliveryCount),

            // 🌟 Tổng kết chuyến đi hôm nay (khi xem tab Đã hoàn tất)
            if (_selectedFilterIndex == 2) ...[
              const SizedBox(height: 12),
              _buildCompletedTodaySummaryHeader(),
            ],
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDADB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
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
                    const SizedBox(width: 8),
                    if (_loadError!.contains('401') ||
                        _loadError!.contains('hết hạn') ||
                        _loadError!.contains('chưa đăng nhập') ||
                        _loadError!.contains('kết thúc'))
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await AuthService.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.login, color: Colors.white, size: 16),
                        label: Text(
                          'Đăng nhập lại ngay',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
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

    // Báo cho backend biết shipper đã offline
    await _syncPresenceToBackend(false);
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

  /// Hiển thị thông báo phiên làm việc đã hết hạn và chuyển hướng đăng nhập
  void _showSessionExpiredDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_outlined, color: Colors.orange, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Phiên đăng nhập hết hạn',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Phiên làm việc của bạn đã hết hạn bảo mật (HTTP 401). Vui lòng đăng nhập lại để tiếp tục nhận và cập nhật trạng thái đơn hàng.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: outlineColor, height: 1.4),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.login, color: Colors.white, size: 18),
            label: Text(
              'Đăng nhập lại ngay',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
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
                      'Tuyến đường giao nhận',
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
            onPressed: _showShiftHandoverDialog,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.point_of_sale_rounded, color: Colors.white),
                if (((_currentShiftData?['cashAmount'] as num?)?.toDouble() ?? 0) > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Sổ ca & Bàn giao tiền mặt',
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
    final cashAmount = (_currentShiftData?['cashAmount'] as num?)?.toDouble() ?? todayCodCollected;
    final onlineAmount = (_currentShiftData?['onlineAmount'] as num?)?.toDouble() ?? 0.0;
    final totalShiftOrders = (_currentShiftData?['totalOrders'] as num?)?.toInt() ?? _todayCompletedCount;
    final hasPending = _currentShiftData?['hasPendingHandover'] == true;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _showShiftHandoverDialog,
            borderRadius: BorderRadius.circular(16),
            child: _buildStatCard(
              title: 'Tiền mặt COD',
              value: _formatVnd(cashAmount),
              subtitle: hasPending ? 'Chờ duyệt' : 'Cần nộp lại',
              icon: Icons.payments_rounded,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFDC2626),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: _showShiftHandoverDialog,
            borderRadius: BorderRadius.circular(16),
            child: _buildStatCard(
              title: 'Chuyển khoản',
              value: _formatVnd(onlineAmount),
              subtitle: 'Đã vào tiệm',
              icon: Icons.qr_code_2_rounded,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: _showShiftHandoverDialog,
            borderRadius: BorderRadius.circular(16),
            child: _buildStatCard(
              title: 'Đã xong',
              value: '$totalShiftOrders đơn',
              subtitle: 'Trong ca',
              icon: Icons.task_alt_rounded,
              iconBg: const Color(0xFFD1FAE5),
              iconColor: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildRouteShortcutCard(int pickupCount, int deliveryCount) {
    final activeOrders = _orders
        .where(
          (o) =>
              o.status != ShipperOrderStatus.completed &&
              o.status != ShipperOrderStatus.cancelled,
        )
        .toList();
    final totalStops = activeOrders.length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006577), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006577).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTodayRouteModal(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: Colors.white,
                    size: 24,
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
                            'Tuyến đường hôm nay',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalStops trạm',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalStops > 0
                            ? '$pickupCount điểm lấy • $deliveryCount điểm giao • Bấm xem lộ trình'
                            : 'Đã hoàn tất mọi chuyến đi hôm nay!',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        size: 14,
                        color: Color(0xFF006577),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Xem tuyến',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006577),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedTodaySummaryHeader() {
    final allCompleted = _orders
        .where((o) => o.status == ShipperOrderStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng kết chuyến đi trong ngày',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      'Xem lại các đơn đã đi & đối chiếu tiền thu COD hôm nay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã đi hôm nay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: outlineColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${todayCompletedOrders.length} đơn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COD đã thu',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: outlineColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatVnd(todayCodCollected),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chuyển khoản',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: outlineColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatVnd(
                          (_currentShiftData?['onlineAmount'] as num?)?.toDouble() ?? 0.0,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  'Đã đi hôm nay (${todayCompletedOrders.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _completedTimeFilter == 0
                        ? Colors.white
                        : const Color(0xFF065F46),
                  ),
                ),
                selected: _completedTimeFilter == 0,
                selectedColor: const Color(0xFF059669),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (val) {
                  if (val) setState(() => _completedTimeFilter = 0);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Tất cả lịch sử ($allCompleted)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _completedTimeFilter == 1 ? Colors.white : onSurface,
                  ),
                ),
                selected: _completedTimeFilter == 1,
                selectedColor: outlineColor,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (val) {
                  if (val) setState(() => _completedTimeFilter = 1);
                },
              ),
            ],
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
                      if (activePendingOrders.length >= 2) ...[
                        Builder(
                          builder: (context) {
                            final stationIdx = activePendingOrders.indexWhere((p) => p.id == order.id);
                            if (stationIdx == -1) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF006577).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Trạm ${stationIdx + 1}/${activePendingOrders.length}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006577),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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
                                ? Icons.check_circle
                                : Icons.payments,
                            size: 16,
                            color: order.isPaidOnline
                                ? successColor
                                : primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.isPaidOnline
                                ? 'Đã thanh toán (0 đ COD)'
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
                      // Nút thanh toán cho đơn cần giao chưa trả tiền (Ẩn hoàn toàn khi đã thu để tránh chuyển khoản nhiều lần)
                      if (order.type == OrderType.delivery &&
                          !order.isPaidOnline &&
                          order.codAmount > 0)
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
                          Icon(
                            order.type == OrderType.pickup
                                ? Icons.moped
                                : Icons.schedule,
                            size: 14,
                            color: order.type == OrderType.pickup
                                ? primaryColor
                                : tertiaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.type == OrderType.pickup
                                ? 'Lấy: ${order.timeWindow}'
                                : 'Giao sạch: ${order.timeWindow}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: onSurface,
                              fontWeight: FontWeight.w600,
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
                      if (order.status == ShipperOrderStatus.completed &&
                          ((order.proofPhotoUrl != null && order.proofPhotoUrl!.isNotEmpty) ||
                           (order.pickupProofPhotoUrl != null && order.pickupProofPhotoUrl!.isNotEmpty))) ...[
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          onPressed: () => _showProofPhotoViewerDialog(order),
                          icon: const Icon(Icons.photo_library_outlined, color: secondaryColor),
                          style: IconButton.styleFrom(
                            backgroundColor: secondaryColor.withValues(alpha: 0.1),
                          ),
                          tooltip: 'Xem ảnh minh chứng',
                        ),
                      ],
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

                    if ((order.pickupProofPhotoUrl != null && order.pickupProofPhotoUrl!.isNotEmpty) ||
                        (order.proofPhotoUrl != null && order.proofPhotoUrl!.isNotEmpty)) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showProofPhotoViewerDialog(order);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.photo_library, color: Color(0xFF1D4ED8), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Xem ảnh minh chứng giao nhận',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                    Text(
                                      'Ảnh túi niêm phong seal 3T & Ảnh giao hàng',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1D4ED8)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
      case ShipperOrderStatus.cancelled:
        return const Color(0xFF6B7280); // Xám cho đơn đã hủy
      default:
        return primaryColor;
    }
  }

  String _getActionButtonText(ShipperOrderModel order) {
    if (order.status == ShipperOrderStatus.cancelled) {
      return 'Đơn đã hủy';
    }
    if (order.status == ShipperOrderStatus.completed) {
      return 'Đã hoàn tất';
    }

    if (order.type == OrderType.pickup) {
      switch (order.status) {
        case ShipperOrderStatus.available:
          return 'Bắt đầu đi lấy đồ';
        case ShipperOrderStatus.pickingUp:
          return 'Cân đồ';
        case ShipperOrderStatus.inStore:
          return 'Đã về tiệm giặt';
        default:
          return 'Cập nhật tiến độ';
      }
    } else {
      switch (order.status) {
        case ShipperOrderStatus.available:
          return 'Bắt đầu giao hàng';
        case ShipperOrderStatus.delivering:
          return (order.isPaidOnline || order.codAmount <= 0)
              ? 'Xác nhận đã giao hàng'
              : 'Xác nhận đã giao & Thu tiền';
        default:
          return 'Cập nhật tiến độ';
      }
    }
  }

  Future<void> _handleOrderMainAction(ShipperOrderModel order) async {
    if (order.orderId == null || order.orderId! <= 0) {
      _showToast('Đơn hàng chưa có mã từ máy chủ.', isSuccess: false);
      return;
    }

    if (order.status == ShipperOrderStatus.cancelled) {
      _showToast(
        'Đơn hàng này đã bị hủy, không thể thao tác tiếp.',
        isSuccess: false,
      );
      return;
    }
    if (order.status == ShipperOrderStatus.completed) {
      _showToast('Đơn hàng này đã hoàn tất thành công.', isSuccess: true);
      return;
    }
    if (order.type == OrderType.pickup &&
        order.status == ShipperOrderStatus.available) {
      // Đơn đã được Web Quản lý phân công -> chuyển thẳng sang Đang đi lấy
      await _updateOrderStatus(order, ShipperOrderStatus.pickingUp);
    } else if (order.type == OrderType.pickup &&
        order.status == ShipperOrderStatus.pickingUp) {
      _showPickupWeighingDialog(order);
    } else if (order.type == OrderType.delivery &&
        order.status == ShipperOrderStatus.available) {
      // Đơn đã được Web Quản lý phân công -> chuyển thẳng sang Đang giao hàng
      await _updateOrderStatus(order, ShipperOrderStatus.delivering);
    } else if (order.type == OrderType.delivery &&
        order.status == ShipperOrderStatus.delivering) {
      _showProofPhotoDialog(order, isPickup: false);
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

  Future<String?> _uploadSinglePhoto(Uint8List bytes, String fileName) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/Uploads'));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final safeName = fileName.isNotEmpty ? fileName : 'pickup_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: safeName,
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['url'] != null) {
          return body['url'].toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Lỗi tải ảnh minh chứng: $e');
      return null;
    }
  }

  Future<bool> _savePickupDetails(
    ShipperOrderModel order,
    List<Map<String, dynamic>> measuredItems,
    String note, {
    String? pickupProofPhotoUrl,
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
      final payload = <String, dynamic>{
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
      };
      if (pickupProofPhotoUrl != null && pickupProofPhotoUrl.isNotEmpty) {
        payload['pickupProofPhotoUrl'] = pickupProofPhotoUrl;
      }
      final res = await http.put(
        Uri.parse('$_baseUrl/Orders/${order.orderId}/pickup-details'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode == 401) {
        _showToast('Phiên làm việc đã hết hạn. Đang chuyển về màn hình đăng nhập...', isSuccess: false);
        await AuthService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return false;
      }
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

  bool _isUnitByItem(dynamic unit) {
    final u = unit?.toString().toLowerCase().trim() ?? '';
    return !u.contains('kg') && !u.contains('ký') && !u.contains('kí');
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
      final unitStr = (item['unit'] ?? catalogItem?['unit'] ?? 'KG').toString();
      final isByItem = _isUnitByItem(unitStr);
      final rawQty = item['kg'] ?? item['quantity'] ?? '';
      String initialText = '';
      if (rawQty != null && rawQty.toString().isNotEmpty) {
        final parsed = double.tryParse(rawQty.toString().replaceAll(',', '.'));
        if (parsed != null) {
          initialText = isByItem
              ? parsed.round().toString()
              : (parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString());
        } else {
          initialText = rawQty.toString();
        }
      }
      rows.add({
        'serviceId': serviceId,
        'name':
            (item['service'] ??
                    item['type'] ??
                    catalogItem?['name'] ??
                    'Dịch vụ')
                .toString(),
        'unit': unitStr,
        'unitPrice':
            ((item['unitPrice'] ??
                        item['UnitPrice'] ??
                        catalogItem?['unitPrice'] ??
                        0)
                    as num)
                .toDouble(),
        'minimumPrice': item['minimumPrice'] ?? catalogItem?['minimumPrice'],
        'isOriginal': true,
        'controller': TextEditingController(text: initialText),
      });
    }

    final noteController = TextEditingController();
    var customerConfirmed = false;
    var submitting = false;
    final picker = ImagePicker();
    final pickupPhotos = <Map<String, dynamic>>[];

    Future<void> pickPhoto(ImageSource source, StateSetter setSheetState) async {
      try {
        final xfile = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (xfile == null) return;
        final bytes = await xfile.readAsBytes();
        setSheetState(() {
          pickupPhotos.add({
            'bytes': bytes,
            'name': xfile.name,
            'url': null,
          });
        });
      } catch (e) {
        _showToast('Không thể chọn ảnh: $e', isSuccess: false);
      }
    }
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
                                          final isByItem = _isUnitByItem(row['unit']);
                                          final q = isByItem
                                              ? (int.tryParse(controller.text.trim())?.toDouble() ?? 0)
                                              : (double.tryParse(
                                                    controller.text
                                                        .trim()
                                                        .replaceAll(',', '.'),
                                                  ) ??
                                                  0);
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
                            Builder(
                              builder: (context) {
                                final isByItem = _isUnitByItem(row['unit']);
                                if (isByItem) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: controller,
                                          onChanged: (_) => setSheetState(() {}),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          decoration: InputDecoration(
                                            labelText:
                                                'Số lượng thực tế (Số nguyên ${row['unit']})',
                                            suffixText: row['unit'].toString(),
                                            prefixIcon: const Icon(
                                              Icons.checkroom,
                                              color: Color(0xFFC6003D),
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFF5BBC8),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 18),
                                              color: const Color(0xFFC6003D),
                                              onPressed: submitting
                                                  ? null
                                                  : () {
                                                      final cur = int.tryParse(
                                                            controller.text.trim(),
                                                          ) ??
                                                          1;
                                                      if (cur > 1) {
                                                        controller.text =
                                                            (cur - 1).toString();
                                                        setSheetState(() {});
                                                      }
                                                    },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 18),
                                              color: const Color(0xFFC6003D),
                                              onPressed: submitting
                                                  ? null
                                                  : () {
                                                      final cur = int.tryParse(
                                                            controller.text.trim(),
                                                          ) ??
                                                          0;
                                                      controller.text =
                                                          (cur + 1).toString();
                                                      setSheetState(() {});
                                                    },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return TextField(
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
                                );
                              },
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
                                    final isByItem = _isUnitByItem(service['unit']);
                                    setSheetState(() {
                                      rows.add({
                                        'serviceId': service['serviceId'],
                                        'name': service['name'],
                                        'unit': service['unit'],
                                        'unitPrice': service['unitPrice'] ?? 0,
                                        'minimumPrice': service['minimumPrice'],
                                        'isOriginal': false,
                                        'controller': TextEditingController(
                                          text: isByItem ? '1' : '',
                                        ),
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

                    // KHỐI ẢNH CHỤP ĐỒ & NIÊM PHONG HIỆN TRƯỜNG (BẢO VỆ TÀI SẢN KHÁCH HÀNG)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shield_outlined, color: primaryColor, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Ảnh chụp đồ & Niêm phong hiện trường',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '*(Bắt buộc)',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Bảo vệ tài sản khách hàng • Bắt buộc chụp tình trạng đồ & tem seal',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: outlineColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: submitting
                                      ? null
                                      : () => pickPhoto(ImageSource.camera, setSheetState),
                                  icon: const Icon(Icons.camera_alt, size: 16, color: primaryColor),
                                  label: Text(
                                    'Chụp ảnh',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: primaryColor),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: submitting
                                      ? null
                                      : () => pickPhoto(ImageSource.gallery, setSheetState),
                                  icon: const Icon(Icons.photo_library, size: 16, color: tertiaryColor),
                                  label: Text(
                                    'Thư viện ảnh',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tertiaryColor,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: tertiaryColor),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pickupPhotos.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: pickupPhotos.length,
                                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                                itemBuilder: (ctx, idx) {
                                  final photo = pickupPhotos[idx];
                                  final bytes = photo['bytes'] as Uint8List;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          bytes,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: submitting
                                              ? null
                                              : () {
                                                  setSheetState(() {
                                                    pickupPhotos.removeAt(idx);
                                                  });
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5), style: BorderStyle.solid),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Chưa có ảnh (Bắt buộc). Vui lòng chụp ảnh túi đồ & tem seal trước khi xác nhận lấy hàng.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
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
                                  final isByItem = _isUnitByItem(row['unit']);
                                  final textVal = controller.text.trim();
                                  if (isByItem) {
                                    final intQty = int.tryParse(textVal);
                                    if (intQty == null ||
                                        intQty <= 0 ||
                                        textVal.contains('.') ||
                                        textVal.contains(',')) {
                                      _showToast(
                                        'Số lượng "${row['name']}" phải là số nguyên lớn hơn 0 (không được là số thập phân).',
                                        isSuccess: false,
                                      );
                                      return;
                                    }
                                    measured.add({
                                      'serviceId': row['serviceId'],
                                      'quantity': intQty.toDouble(),
                                    });
                                  } else {
                                    final quantity = double.tryParse(
                                      textVal.replaceAll(',', '.'),
                                    );
                                    if (quantity == null || quantity <= 0) {
                                      _showToast(
                                        'Vui lòng nhập khối lượng "${row['name']}" lớn hơn 0 kg.',
                                        isSuccess: false,
                                      );
                                      return;
                                    }
                                    measured.add({
                                      'serviceId': row['serviceId'],
                                      'quantity': quantity,
                                    });
                                  }
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
                                if (pickupPhotos.isEmpty) {
                                  _showToast(
                                    'Bắt buộc phải chụp hoặc tải ít nhất 1 ảnh đồ & niêm phong trước khi xác nhận lấy hàng.',
                                    isSuccess: false,
                                  );
                                  return;
                                }
                                if (!customerConfirmed) {
                                  _showToast(
                                    'Vui lòng xác nhận đã đối chiếu với khách hàng.',
                                    isSuccess: false,
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);

                                // Upload ảnh minh chứng hiện trường nếu có
                                final uploadedUrls = <String>[];
                                for (final photo in pickupPhotos) {
                                  if (photo['url'] != null && (photo['url'] as String).isNotEmpty) {
                                    uploadedUrls.add(photo['url'] as String);
                                  } else if (photo['bytes'] != null) {
                                    final bytes = photo['bytes'] as Uint8List;
                                    final name = (photo['name'] as String?) ?? 'pickup.jpg';
                                    final uploadedUrl = await _uploadSinglePhoto(bytes, name);
                                    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                                      photo['url'] = uploadedUrl;
                                      uploadedUrls.add(uploadedUrl);
                                    }
                                  }
                                }
                                final proofUrlStr = uploadedUrls.isNotEmpty ? uploadedUrls.join(',') : null;

                                final saved = await _savePickupDetails(
                                  order,
                                  groupedMeasured,
                                  noteController.text.trim(),
                                  pickupProofPhotoUrl: proofUrlStr,
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
  Future<void> _showPaymentDialog(ShipperOrderModel order) async {
    if (order.isPaidOnline || order.codAmount <= 0) {
      _showToast(
        'Đơn hàng #${order.id} đã hoàn tất thanh toán. Mã QR đã đóng để tránh chuyển khoản lặp lại.',
        isSuccess: true,
      );
      return;
    }

    await _loadStoreBankConfig();
    if (!mounted) return;

    PaymentMethod? selected;
    bool isConfirming = false;
    bool isPaidSuccess = false;

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
            // Khi đã xác nhận thu tiền: MÃ QR BIẾN MẤT HOÀN TOÀN để tránh chuyển khoản lặp lại
            if (isPaidSuccess) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: outlineColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.check_circle, size: 52, color: Color(0xFF059669)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ĐÃ THU TIỀN THÀNH CÔNG!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        'Mã QR thanh toán đã được đóng và vô hiệu hóa để tránh chuyển khoản nhiều lần.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Đóng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

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
                    // ===== Hiển thị mã QR thanh toán chuẩn quét được 100% =====
                    () {
                      final amountVal = order.codAmount > 0 ? order.codAmount : 50000.0;
                      final cleanOrderTag = (order.id.isNotEmpty ? order.id : 'WS3T-${order.orderId ?? 0}').replaceAll('#', '');
                      final emvCoData = VietQrHelper.generateEmvCo(
                        bankBin: _storeBankBin,
                        accountNo: _storeBankAccountNo,
                        accountHolder: _storeBankAccountHolder,
                        amount: amountVal,
                        orderCode: cleanOrderTag,
                      );
                      // MoMo nhận tiền trực tiếp qua universal link hoặc EMVCo NAPAS 247
                      final momoData = 'https://nhantien.momo.vn/$_storeBankAccountNo/${amountVal.round()}';
                      final qrData = selected == PaymentMethod.momo ? momoData : emvCoData;

                      return Container(
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
                                      ? 'Ví MoMo (Chuyển tiền MoMo)'
                                      : 'Chuyển khoản VietQR NAPAS 247',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Khung vẽ mã QR chuẩn canvas trực tiếp - Không phụ thuộc mạng/CORS
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: outlineColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 210.0,
                                    gapless: true,
                                    backgroundColor: Colors.white,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (selected == PaymentMethod.momo
                                              ? const Color(0xFFA50064)
                                              : primaryColor)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      selected == PaymentMethod.momo
                                          ? 'Quét qua App MoMo hoặc Camera điện thoại'
                                          : 'Quét bằng bất kỳ App Ngân hàng nào (NAPAS 247)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: selected == PaymentMethod.momo
                                            ? const Color(0xFFA50064)
                                            : primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: outlineColor.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'STK / Ví MoMo:',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: outlineColor,
                                        ),
                                      ),
                                      Text(
                                        _storeBankAccountNo,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Chủ thụ hưởng:',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: outlineColor,
                                        ),
                                      ),
                                      Text(
                                        _storeBankAccountHolder,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Ngân hàng / Ví:',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: outlineColor,
                                        ),
                                      ),
                                      Text(
                                        selected == PaymentMethod.momo ? 'Ví điện tử MoMo' : _storeBankName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tertiaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Số tiền:',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: outlineColor,
                                        ),
                                      ),
                                      Text(
                                        '${order.codAmount.toStringAsFixed(0)} đ',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _storeBankAccountNo));
                                _showToast('Đã sao chép $_storeBankAccountNo vào bộ nhớ tạm');
                              },
                              icon: const Icon(Icons.copy, size: 14),
                              label: Text(
                                selected == PaymentMethod.momo
                                    ? 'Sao chép SĐT MoMo: $_storeBankAccountNo'
                                    : 'Sao chép STK: $_storeBankAccountNo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
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
                            onPressed: isConfirming
                                ? null
                                : () async {
                                    setSheetState(() => isConfirming = true);
                                    try {
                                      final token = await AuthService.getToken();
                                      final backendOrderId = order.orderId ??
                                          int.tryParse(order.id.replaceAll(RegExp(r'\D'), '')) ??
                                          0;
                                      if (backendOrderId > 0 && token != null && token.isNotEmpty) {
                                        await http.post(
                                          Uri.parse('$_baseUrl/Payments/order/$backendOrderId/confirm'),
                                          headers: {
                                            'Content-Type': 'application/json',
                                            'Authorization': 'Bearer $token',
                                          },
                                          body: jsonEncode({
                                            'method': selected == PaymentMethod.momo ? 'MoMo' : 'BankTransfer',
                                            'note': 'Shipper xác nhận khách chuyển khoản ${selected == PaymentMethod.momo ? "MoMo" : "VietQR"}'
                                          }),
                                        );
                                      }

                                      // Khóa cứng đơn hàng: Đã thanh toán, không còn COD
                                      order.isPaidOnline = true;
                                      order.codAmount = 0.0;

                                      if (mounted) {
                                        setState(() {});
                                        _loadCurrentShiftSummary();
                                      }

                                      setSheetState(() {
                                        isConfirming = false;
                                        isPaidSuccess = true;
                                      });

                                      _showToast('Đã xác nhận thu tiền thành công! Mã QR đã đóng.');
                                    } catch (e) {
                                      order.isPaidOnline = true;
                                      order.codAmount = 0.0;
                                      if (mounted) {
                                        setState(() {});
                                      }
                                      setSheetState(() {
                                        isConfirming = false;
                                        isPaidSuccess = true;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: isConfirming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
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

  String _buildMultiStopGoogleMapsUrl(List<ShipperOrderModel> orders) {
    const hub = '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. HCM';
    if (orders.isEmpty) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(hub)}';
    }
    final origin = Uri.encodeComponent(hub);
    final destination = Uri.encodeComponent(hub);
    final waypoints = orders.map((o) {
      final addr = o.type == OrderType.pickup ? o.pickupAddress : o.deliveryAddress;
      return Uri.encodeComponent(addr);
    }).join('|');
    return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints';
  }

  String _buildSingleStopGoogleMapsUrl(String address) {
    return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}';
  }

  void _showNavigationModal(ShipperOrderModel order) {
    final targetAddress = order.type == OrderType.pickup
        ? order.pickupAddress
        : order.deliveryAddress;
    final orderParam = order.orderId ?? int.tryParse(order.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
                      'Bản đồ dẫn đường (${order.distanceKm} km)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mở tab bản đồ riêng',
                      icon: const Icon(Icons.open_in_new, color: primaryColor, size: 20),
                      onPressed: () {
                        launchWebOrAppUrl('http://localhost:5500/shipper_route_map.html?orderIds=$orderParam');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Interactive Leaflet Map View like Web Dispatch
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RouteMapEmbed(
                url: 'http://localhost:5500/shipper_route_map.html?orderIds=$orderParam',
                height: 240,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Điểm đến (${order.type == OrderType.pickup ? 'Lấy đồ' : 'Giao đồ'}):',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        'Khách: ${order.customerName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetAddress,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  launchWebOrAppUrl(_buildSingleStopGoogleMapsUrl(targetAddress));
                },
                icon: const Icon(Icons.near_me, color: Colors.white),
                label: Text(
                  'Mở Google Maps chỉ đường trực tiếp',
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
            if (activePendingOrders.length >= 2) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showTodayRouteModal();
                  },
                  icon: const Icon(
                    Icons.alt_route_rounded,
                    color: tertiaryColor,
                    size: 18,
                  ),
                  label: Text(
                    'Xem tuyến đường ghép cả ${activePendingOrders.length} đơn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: tertiaryColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: tertiaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTodayRouteModal() {
    final pendingOrders = activePendingOrders;
    final doneOrders = todayCompletedOrders;
    final shipperQuery = _currentShipperId != null ? '?shipperId=$_currentShipperId' : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DefaultTabController(
        length: 2,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.94,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tertiaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: tertiaryColor,
                        size: 22,
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
                                'Bản Đồ Tuyến Đường Shipper',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Live OSRM',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Định tuyến tối ưu TSP • Cửa hàng 140 Lê Trọng Tấn',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mở bản đồ toàn màn hình',
                      icon: const Icon(Icons.open_in_new, color: primaryColor, size: 20),
                      onPressed: () {
                        launchWebOrAppUrl('http://localhost:5500/shipper_route_map.html$shipperQuery');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),

              // Tab Selector
              TabBar(
                labelColor: primaryColor,
                unselectedLabelColor: outlineColor,
                indicatorColor: primaryColor,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: 'Tuyến cần đi (${pendingOrders.length})'),
                  Tab(text: 'Đã đi hôm nay (${doneOrders.length})'),
                ],
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPendingRouteTab(sheetCtx, pendingOrders),
                    _buildCompletedRouteTab(sheetCtx, doneOrders),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRouteTab(
    BuildContext ctx,
    List<ShipperOrderModel> pendingOrders,
  ) {
    final shipperQuery = _currentShipperId != null ? '?shipperId=$_currentShipperId' : '';
    final embedQuery = _currentShipperId != null ? '?shipperId=$_currentShipperId&embed=1' : '?embed=1';
    final pickupCount = pendingOrders.where((o) => o.type == OrderType.pickup).length;
    final deliveryCount = pendingOrders.where((o) => o.type == OrderType.delivery).length;
    double totalEstKm = 0;
    for (var o in pendingOrders) {
      totalEstKm += o.distanceKm > 0 ? o.distanceKm : 1.5;
    }
    final displayKm = (totalEstKm * 1.15).toStringAsFixed(1);
    final estMinutes = (double.parse(displayKm) * 3.5).ceil();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==========================================
              // 1. LIVE INTERACTIVE LEAFLET MAP VIEW
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      RouteMapEmbed(
                        url: 'http://localhost:5500/shipper_route_map.html$embedQuery',
                        height: 300,
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () {
                            launchWebOrAppUrl('http://localhost:5500/shipper_route_map.html$shipperQuery');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fullscreen, size: 16, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Mở toàn cảnh',
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // 2. HUD LỘ TRÌNH THÔNG MINH
              // ==========================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Chỉ số hành trình hôm nay',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tối ưu TSP 2-Opt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Tổng cự ly',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: outlineColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$displayKm km',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Thời gian',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: outlineColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$estMinutes phút',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Phân loại trạm',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: outlineColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${pickupCount}P • ${deliveryCount}D',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: tertiaryColor,
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
              ),
              const SizedBox(height: 14),

              if (pendingOrders.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã hoàn thành mọi chuyến đi hôm nay!',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                            Text(
                              'Bản đồ trên đang hiển thị vị trí Trụ sở 140 Lê Trọng Tấn sẵn sàng nhận nhiệm vụ mới.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ==========================================
              // 3. DANH SÁCH CÁC TRẠM DỪNG TUẦN TỰ
              // ==========================================
              // Trạm xuất phát: Cửa hàng WashSmart 3T
              _buildRouteStationCard(
                stationNumber: 0,
                isStartOrEnd: true,
                title: 'Xuất phát: Cửa hàng WashSmart 3T (Hub Tân Phú)',
                address: '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. HCM',
                tag: 'ĐIỂM XUẤT PHÁT',
                tagColor: const Color(0xFF0284C7),
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 12),

              // Các trạm gom / giao của khách hàng
              ...List.generate(pendingOrders.length, (idx) {
                final o = pendingOrders[idx];
                final isPickup = o.type == OrderType.pickup;
                final targetAddress = isPickup
                    ? o.pickupAddress
                    : o.deliveryAddress;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRouteStationCard(
                    stationNumber: idx + 1,
                    isStartOrEnd: false,
                    title: '#${o.id} • ${o.customerName}',
                    subtitle: 'SĐT: ${o.customerPhone}',
                    address: targetAddress,
                    tag: isPickup ? 'LẤY ĐỒ TẬN NƠI' : 'GIAO ĐỒ SẠCH',
                    tagColor: isPickup ? tertiaryColor : primaryColor,
                    infoBadge: isPickup
                        ? '${o.weightKg} kg'
                        : (o.isPaidOnline
                              ? 'Đã TT online'
                              : 'COD: ${o.codAmount.toStringAsFixed(0)} đ'),
                    icon: isPickup
                        ? Icons.arrow_circle_up_rounded
                        : Icons.local_shipping_rounded,
                    onCall: () => _simulateCallCustomer(o),
                    onNavigate: () {
                      launchWebOrAppUrl(_buildSingleStopGoogleMapsUrl(targetAddress));
                    },
                  ),
                );
              }),

              // Trạm kết thúc: Quay về cửa hàng
              _buildRouteStationCard(
                stationNumber: pendingOrders.length + 1,
                isStartOrEnd: true,
                title: 'Kết thúc: Quay về Cửa hàng WashSmart 3T',
                address:
                    '140 Lê Trọng Tấn • Bàn giao đồ đã gom & nhận mẻ giặt sạch mới',
                tag: 'KẾT THÚC TUYẾN',
                tagColor: const Color(0xFF059669),
                icon: Icons.home_work_rounded,
              ),
            ],
          ),
        ),

        // Nút mở Google Maps toàn tuyến
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final mapsUrl = _buildMultiStopGoogleMapsUrl(pendingOrders);
                launchWebOrAppUrl(mapsUrl);
              },
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: Text(
                'Mở Google Maps dẫn đường toàn tuyến (${pendingOrders.length} trạm)',
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
        ),
      ],
    );
  }

  Widget _buildCompletedRouteTab(
    BuildContext ctx,
    List<ShipperOrderModel> doneOrders,
  ) {
    if (doneOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off,
                size: 54,
                color: outlineColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có đơn hoàn tất hôm nay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Các đơn giao/lấy hoàn thành trong ngày hôm nay sẽ hiển thị tại đây.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: outlineColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: doneOrders.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final o = doneOrders[idx];
        final isPickup = o.type == OrderType.pickup;
        final completedTime = o.updatedAt != null
            ? '${o.updatedAt!.hour.toString().padLeft(2, '0')}:${o.updatedAt!.minute.toString().padLeft(2, '0')}'
            : o.timeWindow;

        final hasProof =
            (o.proofPhotoUrl != null && o.proofPhotoUrl!.isNotEmpty) ||
            (o.pickupProofPhotoUrl != null && o.pickupProofPhotoUrl!.isNotEmpty);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'XONG LÚC $completedTime',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${o.id}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    o.isPaidOnline
                        ? 'Đã TT Online'
                        : 'COD: ${o.codAmount.toStringAsFixed(0)} đ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: o.isPaidOnline ? successColor : primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Khách: ${o.customerName} (${o.customerPhone})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPickup ? o.pickupAddress : o.deliveryAddress,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: outlineColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasProof)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showProofPhotoViewerDialog(o);
                      },
                      icon: const Icon(
                        Icons.photo_library,
                        size: 14,
                        color: secondaryColor,
                      ),
                      label: Text(
                        'Xem ảnh minh chứng',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showNavigationModal(o);
                    },
                    icon: const Icon(Icons.map, size: 14, color: tertiaryColor),
                    label: Text(
                      'Xem vị trí',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tertiaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteStationCard({
    required int stationNumber,
    required bool isStartOrEnd,
    required String title,
    String? subtitle,
    required String address,
    required String tag,
    required Color tagColor,
    String? infoBadge,
    required IconData icon,
    VoidCallback? onCall,
    VoidCallback? onNavigate,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isStartOrEnd ? surfaceLow : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStartOrEnd
              ? tagColor.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: tagColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  isStartOrEnd ? (stationNumber == 0 ? 'S' : 'E') : '$stationNumber',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                  ),
                ),
              ),
              if (infoBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    infoBadge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 14, color: primaryColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (!isStartOrEnd) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCall != null)
                  IconButton.filledTonal(
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 16, color: primaryColor),
                    style: IconButton.styleFrom(backgroundColor: surfaceLow),
                    tooltip: 'Gọi điện',
                  ),
                if (onNavigate != null) ...[
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.near_me, size: 14),
                    label: Text(
                      'Chỉ đường',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tertiaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _submitDeliveryProof({
    required ShipperOrderModel order,
    String? photoUrl,
    String? note,
    bool confirmPaymentCollected = true,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        _showToast('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.', isSuccess: false);
        return false;
      }
      final backendOrderId = order.orderId ?? int.tryParse(order.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (backendOrderId <= 0) return false;

      final res = await http.post(
        Uri.parse('$_baseUrl/Orders/$backendOrderId/delivery-proof'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'photoUrl': photoUrl ?? '',
          'proofPhotoUrl': photoUrl ?? '',
          'note': note ?? 'Shipper đã giao hàng và thu tiền COD thành công.',
          'confirmPaymentCollected': confirmPaymentCollected,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        return true;
      }

      if (res.statusCode == 401) {
        _showToast('Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.', isSuccess: false);
        await AuthService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return false;
      }

      debugPrint('delivery-proof HTTP ${res.statusCode}: ${res.body}');
      return await _pushStatusToApi(backendOrderId, 'Completed', note: note);
    } catch (e) {
      debugPrint('Lỗi nộp minh chứng giao hàng: $e');
      final backendOrderId = order.orderId ?? int.tryParse(order.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (backendOrderId > 0) {
        return await _pushStatusToApi(backendOrderId, 'Completed', note: note);
      }
      return false;
    }
  }

  // ============================================================
  // 🔍 MODAL XEM LẠI ẢNH MINH CHỨNG (PROOF PHOTO VIEWER)
  // Cho phép Shipper xem lại ảnh túi niêm phong khi lấy đồ và ảnh giao hàng thành công
  // ============================================================
  void _showProofPhotoViewerDialog(ShipperOrderModel order) {
    String formatFullUrl(String raw) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      final clean = raw.startsWith('/') ? raw : '/$raw';
      return 'http://localhost:5085$clean';
    }

    final pickupUrls = (order.pickupProofPhotoUrl ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final deliveryUrls = (order.proofPhotoUrl ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final hasAny = pickupUrls.isNotEmpty || deliveryUrls.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ảnh Minh Chứng • #${order.id}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          'Khách: ${order.customerName} • ${order.customerPhone}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!hasAny)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: outlineColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 48, color: outlineColor),
                    const SizedBox(height: 12),
                    Text(
                      'Đơn hàng chưa có ảnh minh chứng được lưu.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: outlineColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ảnh sẽ xuất hiện sau khi shipper nộp ảnh lấy đồ hoặc giao hàng.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: outlineColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    // Mục 1: Ảnh lấy đồ & niêm phong Seal 3T
                    if (pickupUrls.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.lock_clock, size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Text(
                            '1. Ảnh Lấy Đồ & Bấm Seal 3T Tại Nhà Khách (${pickupUrls.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pickupUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final imgUrl = formatFullUrl(pickupUrls[i]);
                            return GestureDetector(
                              onTap: () => _openFullScreenImage(ctx, imgUrl, 'Ảnh Lấy Đồ #${order.id}'),
                              child: Container(
                                width: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Mục 2: Ảnh giao hàng thành công
                    if (deliveryUrls.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(
                            '2. Ảnh Giao Hàng Thành Công (${deliveryUrls.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: deliveryUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final imgUrl = formatFullUrl(deliveryUrls[i]);
                            return GestureDetector(
                              onTap: () => _openFullScreenImage(ctx, imgUrl, 'Ảnh Giao Hàng #${order.id}'),
                              child: Container(
                                width: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Đóng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Xem ảnh phóng to toàn màn hình
  void _openFullScreenImage(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.5,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: const Text('Không tải được ảnh từ máy chủ.'),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
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
    Uint8List? proofPhotoBytes;
    String? proofPhotoName;
    String? uploadedPhotoUrl;
    bool isSubmitting = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> pickPhoto(ImageSource source) async {
            try {
              final xfile = await picker.pickImage(
                source: source,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 85,
              );
              if (xfile == null) return;
              final bytes = await xfile.readAsBytes();
              setSheetState(() {
                proofPhotoBytes = bytes;
                proofPhotoName = xfile.name;
                uploadedPhotoUrl = null;
              });
            } catch (e) {
              _showToast('Không thể chọn ảnh: $e', isSuccess: false);
            }
          }

          void choosePhotoSource() {
            showModalBottomSheet(
              context: sheetContext,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chọn nguồn ảnh minh chứng',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.camera_alt, color: primaryColor),
                      ),
                      title: Text(
                        'Chụp ảnh từ Camera',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Mở máy ảnh chụp trực tiếp',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        pickPhoto(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF3F4F6),
                        child: Icon(Icons.photo_library, color: tertiaryColor),
                      ),
                      title: Text(
                        'Chọn từ Thư viện ảnh',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Tải ảnh có sẵn từ máy',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        pickPhoto(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                              ? 'Chụp ảnh túi đồ niêm phong *(Bắt buộc)'
                              : 'Chụp ảnh giao hàng thành công *(Bắt buộc)',
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
                      onPressed: isSubmitting ? null : () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vùng hiển thị hoặc chụp ảnh minh chứng
                if (proofPhotoBytes != null)
                  GestureDetector(
                    onTap: isSubmitting ? null : choosePhotoSource,
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor, width: 2),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              proofPhotoBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          proofPhotoBytes = null;
                                          proofPhotoName = null;
                                          uploadedPhotoUrl = null;
                                        });
                                      },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đã tải ảnh • Nhấn để chụp/chọn ảnh khác',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: isSubmitting ? null : choosePhotoSource,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                          width: 1.5,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (isPickup) {
                              Navigator.pop(sheetContext);
                              _showPickupWeighingDialog(order);
                              return;
                            }

                            if (proofPhotoBytes == null && (uploadedPhotoUrl == null || uploadedPhotoUrl!.isEmpty)) {
                              _showToast(
                                'Bắt buộc phải chụp hoặc tải ảnh minh chứng giao hàng trước khi xác nhận.',
                                isSuccess: false,
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              // Tải ảnh lên server nếu đã chọn ảnh
                              if (proofPhotoBytes != null && (uploadedPhotoUrl == null || uploadedPhotoUrl!.isEmpty)) {
                                final url = await _uploadSinglePhoto(
                                  proofPhotoBytes!,
                                  proofPhotoName ?? 'delivery_${order.id}.jpg',
                                );
                                if (url != null && url.isNotEmpty) {
                                  uploadedPhotoUrl = url;
                                }
                              }

                              // Nộp minh chứng giao hàng lên backend
                              final backendOrderId = order.orderId ?? int.tryParse(order.id.replaceAll(RegExp(r'\D'), ''));
                              if (backendOrderId != null && backendOrderId > 0) {
                                final submitOk = await _submitDeliveryProof(
                                  order: order,
                                  photoUrl: uploadedPhotoUrl,
                                  confirmPaymentCollected: true,
                                );
                                if (!submitOk) {
                                  setSheetState(() => isSubmitting = false);
                                  return;
                                }
                              } else {
                                final ok = await _updateOrderStatus(
                                  order,
                                  ShipperOrderStatus.completed,
                                );
                                if (!ok) {
                                  setSheetState(() => isSubmitting = false);
                                  return;
                                }
                              }

                              if (mounted) {
                                setState(() {
                                  order.status = ShipperOrderStatus.completed;
                                  _todayCompletedCount += 1;
                                });
                                _showToast('Đã hoàn tất giao đơn #${order.id} và thu tiền thành công!');
                                await _loadOrdersFromApi();
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (e) {
                              _showToast('Lỗi khi hoàn tất đơn: $e', isSuccess: false);
                              setSheetState(() => isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      disabledBackgroundColor: successColor.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Đang tải ảnh & hoàn tất...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            isPickup
                                ? 'Xác nhận đã nhận đồ & Niêm phong'
                                : ((order.isPaidOnline || order.codAmount <= 0)
                                    ? 'Xác nhận đã giao hàng'
                                    : 'Xác nhận đã giao & Thu tiền'),
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
          );
        },
      ),
    );
  }

  void _showShiftHandoverDialog() async {
    await _loadCurrentShiftSummary();
    if (!mounted) return;

    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final data = _currentShiftData;
          final cashAmount = (data?['cashAmount'] as num?)?.toDouble() ?? todayCodCollected;
          final onlineAmount = (data?['onlineAmount'] as num?)?.toDouble() ?? 0.0;
          final totalOrders = (data?['totalOrders'] as num?)?.toInt() ?? _todayCompletedCount;
          final cashCount = (data?['cashOrdersCount'] as num?)?.toInt() ?? 0;
          final onlineCount = (data?['onlineOrdersCount'] as num?)?.toInt() ?? 0;
          final hasPending = data?['hasPendingHandover'] == true;
          final pendingInfo = data?['pendingHandover'] as Map<String, dynamic>?;
          final orders = (data?['orders'] as List<dynamic>?) ?? [];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sổ Ca & Bàn Giao Tiền Mặt 3T',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: onSurface,
                              ),
                            ),
                            Text(
                              'Đối soát dòng tiền ca chạy giữa Shipper & Quản lý',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: outlineColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close, size: 20, color: outlineColor),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.payments_rounded, color: Color(0xFFDC2626), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tiền mặt COD',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatVnd(cashAmount),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$cashCount đơn • Cần nộp lại',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(color: const Color(0xFF93C5FD)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Chuyển khoản',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatVnd(onlineAmount),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E40AF),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$onlineCount đơn • Đã vào tiệm',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Shipper thu tiền mặt COD từ khách có trách nhiệm nộp đầy đủ số tiền trên cho Quản lý / Thu ngân quầy khi kết thúc ca làm việc để chốt sổ đối soát.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chi tiết đơn trong ca ($totalOrders đơn)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            'Tổng thu: ${_formatVnd(cashAmount + onlineAmount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (orders.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Text(
                            'Ca làm việc hiện tại chưa có đơn hoàn thành.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: outlineColor,
                            ),
                          ),
                        )
                      else
                        ...orders.map((o) {
                          final isCash = o['isCash'] == true;
                          final amount = (o['totalAmount'] as num?)?.toDouble() ?? 0.0;
                          final code = o['orderCode'] ?? 'WS3T-${o['id']}';
                          final cust = o['customerName'] ?? 'Khách hàng';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isCash ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isCash ? Icons.payments_rounded : Icons.qr_code_2_rounded,
                                    size: 16,
                                    color: isCash ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$code • $cust',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      Text(
                                        isCash ? 'Khách trả Tiền mặt (COD)' : 'Khách quét Chuyển khoản (VietQR)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          color: isCash ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '+ ${_formatVnd(amount)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (actionCtx) {
                      if (hasPending) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đang chờ Quản lý duyệt nhận tiền ca',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                    Text(
                                      'Mã bàn giao: #SH-${pendingInfo?['id'] ?? '...'} • Số tiền nộp: ${_formatVnd((pendingInfo?['cashAmount'] as num?)?.toDouble() ?? cashAmount)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (totalOrders == 0) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Chưa có đơn hoàn thành để bàn giao',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: outlineColor,
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: noteController,
                            decoration: InputDecoration(
                              hintText: 'Ghi chú nộp tiền ca (không bắt buộc)...',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setSheetState(() => isSubmitting = true);
                                      try {
                                        final token = await AuthService.getToken();
                                        if (token == null) return;

                                        final res = await http.post(
                                          Uri.parse('$_baseUrl/ShiftHandover/submit'),
                                          headers: {
                                            'Content-Type': 'application/json',
                                            'Authorization': 'Bearer $token',
                                          },
                                          body: jsonEncode({'note': noteController.text.trim()}),
                                        );

                                        if (res.statusCode == 200) {
                                          await _loadCurrentShiftSummary();
                                          _showToast(
                                            'Gửi biên bản bàn giao thành công! Vui lòng nộp ${_formatVnd(cashAmount)} cho Quản lý.',
                                            isSuccess: true,
                                          );
                                          if (sheetCtx.mounted) {
                                            Navigator.pop(sheetCtx);
                                          }
                                        } else {
                                          final body = jsonDecode(res.body);
                                          _showToast(
                                            body['message'] ?? 'Gửi bàn giao thất bại!',
                                            isSuccess: false,
                                          );
                                        }
                                      } catch (err) {
                                        _showToast('Lỗi kết nối: $err', isSuccess: false);
                                      } finally {
                                        if (sheetCtx.mounted) {
                                          setSheetState(() => isSubmitting = false);
                                        }
                                      }
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_outline, color: Colors.white),
                              label: Text(
                                isSubmitting
                                    ? 'Đang gửi biên bản...'
                                    : 'Bàn Giao Tiền Ca Cho Quản Lý (${_formatVnd(cashAmount)})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== Phương thức thanh toán ====================
enum PaymentMethod { momo, bank }

// ==================== Tiện ích VietQR EMVCo chuẩn NAPAS 247 ====================
class VietQrHelper {
  static String formatTlv(String tag, String value) {
    if (value.isEmpty) return '';
    final bytes = utf8.encode(value);
    final lenStr = bytes.length.toString().padLeft(2, '0');
    return '$tag$lenStr$value';
  }

  static String calculateCrc16(String data) {
    final bytes = utf8.encode(data);
    int crc = 0xFFFF;
    const int polynomial = 0x1021;

    for (final b in bytes) {
      crc ^= (b << 8) & 0xFFFF;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Sinh chuỗi VietQR chuẩn EMVCo khóa cứng số tiền và mã đơn hàng
  static String generateEmvCo({
    required String bankBin,
    required String accountNo,
    required String accountHolder,
    required double amount,
    required String orderCode,
  }) {
    final cleanBin = bankBin.trim().isEmpty ? '970422' : bankBin.trim();
    final cleanAccount = accountNo.trim().isEmpty ? '0818606505' : accountNo.trim();
    final cleanHolder = accountHolder.trim().isEmpty ? 'TRAN DIEP MINH TRUNG' : accountHolder.trim().toUpperCase();
    final cleanOrderCode = orderCode.trim().isEmpty ? 'WS3T' : orderCode.trim();

    // 1. Tag 38: Thông tin người thụ hưởng NAPAS
    final subTag00 = formatTlv('00', cleanBin);
    final subTag01 = formatTlv('01', cleanAccount);
    final subNapasOrg = formatTlv('00', 'A000000727') + formatTlv('01', subTag00 + subTag01);
    final tag38 = formatTlv('38', subNapasOrg + formatTlv('02', 'QRIBFTTA'));

    // 2. Các tag tiêu chuẩn EMVCo
    final tag00 = formatTlv('00', '01'); // Payload Format Indicator
    final tag01 = formatTlv('01', '12'); // 12: Dynamic QR (có số tiền cố định)
    final tag53 = formatTlv('53', '704'); // VND
    final intAmount = amount.round().toString();
    final tag54 = formatTlv('54', intAmount); // Số tiền
    final tag58 = formatTlv('58', 'VN'); // Quốc gia
    final tag59 = formatTlv('59', cleanHolder); // Tên người thụ hưởng
    final tag60 = formatTlv('60', 'HO CHI MINH'); // Thành phố

    // 3. Tag 62: Mã đơn hàng khóa nội dung thanh toán #WS3T-XXXX
    final tag62Sub08 = formatTlv('08', cleanOrderCode);
    final tag62 = formatTlv('62', tag62Sub08);

    // 4. Ghép toàn bộ chuỗi trước khi tính CRC (bắt đầu bằng 6304)
    final rawPayload = '$tag00$tag01$tag38$tag53$tag54$tag58$tag59$tag60$tag62' '6304';
    final crc = calculateCrc16(rawPayload);
    return '$rawPayload$crc';
  }
}
