import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'booking_step1_screen.dart';
import 'orders_list_screen.dart';
import 'order_tracking_screen.dart';
import 'promotions_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _services = [];

  bool _isLoadingHomeData = true;
  String? _profileError;
  String? _ordersError;
  String? _servicesError;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final user = await ApiService.getMe();
      if (mounted) {
        setState(() => _currentUser = user);
      }
    } catch (e) {
      _profileError = e.toString();
    }

    try {
      final orders = await ApiService.getMyOrders();
      if (mounted) {
        setState(() => _orders = orders);
      }
    } catch (e) {
      _ordersError = e.toString();
    }

    try {
      final services = await ApiService.getServices();
      if (mounted) {
        setState(() => _services = services);
      }
    } catch (e) {
      _servicesError = e.toString();
    }

    if (mounted) {
      setState(() => _isLoadingHomeData = false);
    }
  }

  void _onNavigateToOrders() {
    setState(() => _selectedIndex = 1);
  }

  // Bảng màu chuẩn theo hệ thống thiết kế WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color surfaceContainer = Color(0xFFFFE9EA);
  static const Color surfaceContainerLow = Color(0xFFFFF0F0);
  static const Color textColor = Color(0xFF370C14);
  static const Color textVariantColor = Color(0xFF5B4041);

  void _onNavigateToPromotions() {
    setState(() {
      _selectedIndex = 2; // Chuyển sang tab Ưu đãi
    });
  }

  // Hàm chuyển sang tab Tài khoản
  void _onNavigateToProfile() {
    setState(() {
      _selectedIndex = 3; // Chuyển sang tab Tài khoản
    });
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách các màn hình tương ứng với các tab dưới Bottom Bar
    final List<Widget> screens = [
      HomeScreenContent(
        onNavigateToPromotions: _onNavigateToPromotions,
        onNavigateToProfile: _onNavigateToProfile,
        onNavigateToOrders: _onNavigateToOrders,
        user: _currentUser,
        orders: _orders,
        services: _services,
        isLoading: _isLoadingHomeData,
        profileError: _profileError,
        ordersError: _ordersError,
        servicesError: _servicesError,
      ),
      // Nội dung Trang chủ (index 0)
      const OrdersListScreen(), // Màn hình Đơn hàng (index 1)
      const PromotionsScreen(), // Màn hình Ưu đãi (index 2)
      const ProfileScreen(), // Màn hình Tài khoản (index 3)
    ];

    return Scaffold(
      backgroundColor: bgSurface,

      // 1. HEADER CỐ ĐỊNH TRÊN CÙNG
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.95),
        elevation: 0.5,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        titleSpacing: 16,
        title: Row(
          children: [
            // Logo thương hiệu 3T
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_laundry_service,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WashSmart 3T',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  _selectedIndex == 0
                      ? 'Trang Chủ'
                      : (_selectedIndex == 1
                            ? 'Đơn Hàng'
                            : (_selectedIndex == 2 ? 'Ưu Đãi' : 'Tài Khoản')),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textVariantColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Thẻ Rose Club
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: secondaryColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  '3T Rose Club',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chuông thông báo trạng thái đơn hàng
          _buildNotificationBell(),
          const SizedBox(width: 8),
          // Avatar người dùng trên App Bar - Bấm vào chuyển sang Tab Tài khoản
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
              },
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),

      // 2. NỘI DUNG THAY ĐỔI THEO TAB CHỌN
      body: IndexedStack(index: _selectedIndex, children: screens),

      // 3. THANH ĐIỀU HƯỚNG BOTTOM BAR CÓ NÚT "ĐẶT LỊCH" NỔI Ở GIỮA
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingStep1Screen()),
          );
        },
        backgroundColor: primaryColor,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.local_laundry_service, 'Trang chủ'),
              _buildNavItem(1, Icons.receipt_long_outlined, 'Đơn hàng'),
              const SizedBox(width: 48), // Chừa khoảng trống cho nút + ở giữa
              _buildNavItem(2, Icons.loyalty_outlined, 'Ưu đãi'),
              _buildNavItem(3, Icons.account_circle_outlined, 'Tài khoản'),
            ],
          ),
        ),
      ),
    );
  }

  // Chuông thông báo trạng thái đơn hàng trên AppBar
  Widget _buildNotificationBell() {
    final activeCount = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      return s != 'completed' && s != 'cancelled';
    }).length;

    return GestureDetector(
      onTap: () => _showNotificationsSheet(context),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              activeCount > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: activeCount > 0 ? primaryColor : textColor,
              size: 19,
            ),
            if (activeCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Center(
                    child: Text(
                      activeCount > 9 ? '9+' : '$activeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1,
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

  // Bảng thông báo trạng thái đơn hàng
  void _showNotificationsSheet(BuildContext context) {
    int filterIndex = 0; // 0: Tất cả, 1: Đang xử lý, 2: Hoàn thành

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final activeOrders = _orders.where((o) {
              final s = (o['status'] ?? '').toString().toLowerCase();
              return s != 'completed' && s != 'cancelled';
            }).toList();

            final completedOrders = _orders.where((o) {
              final s = (o['status'] ?? '').toString().toLowerCase();
              return s == 'completed';
            }).toList();

            List<Map<String, dynamic>> displayedOrders;
            if (filterIndex == 1) {
              displayedOrders = activeOrders;
            } else if (filterIndex == 2) {
              displayedOrders = completedOrders;
            } else {
              displayedOrders = _orders;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thanh kéo handle
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

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thông Báo Đơn Hàng',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                activeOrders.isNotEmpty
                                    ? '${activeOrders.length} đơn giặt đang xử lý theo thời gian thực'
                                    : 'Cập nhật tiến trình giặt sấy từ 3T Express',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: textVariantColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 20, color: textVariantColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildSheetFilterChip(
                          label: 'Tất cả (${_orders.length})',
                          isSelected: filterIndex == 0,
                          onTap: () => setSheetState(() => filterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildSheetFilterChip(
                          label: 'Đang xử lý (${activeOrders.length})',
                          isSelected: filterIndex == 1,
                          badgeColor: primaryColor,
                          onTap: () => setSheetState(() => filterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _buildSheetFilterChip(
                          label: 'Đã giao (${completedOrders.length})',
                          isSelected: filterIndex == 2,
                          onTap: () => setSheetState(() => filterIndex = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0E5E5)),

                  // Danh sách thông báo
                  Flexible(
                    child: displayedOrders.isEmpty
                        ? _buildNotificationEmptyState(filterIndex)
                        : RefreshIndicator(
                            color: primaryColor,
                            onRefresh: () async {
                              await _loadHomeData();
                              setSheetState(() {});
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: displayedOrders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (itemCtx, index) {
                                final order = displayedOrders[index];
                                return _buildNotificationCard(ctx, order);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext sheetContext, Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase();
    final orderId = order['id'] is int
        ? order['id'] as int
        : (int.tryParse(order['id']?.toString() ?? '') ?? 0);
    final orderCode = order['orderCode'] ?? '#WS3T-$orderId';

    // Status details
    String statusTitle;
    String statusDesc;
    IconData statusIcon;
    Color statusColor;
    Color statusBg;

    switch (status) {
      case 'pickingup':
        statusTitle = 'Shipper đang tới lấy đồ';
        final shipper = order['shipperName'] ?? 'Shipper 3T';
        statusDesc = 'Tài xế $shipper đang di chuyển tới địa chỉ của bạn để nhận đồ.';
        statusIcon = Icons.two_wheeler_rounded;
        statusColor = const Color(0xFF006577);
        statusBg = const Color(0xFFE0F7FA);
        break;
      case 'received':
        statusTitle = 'Đã nhận đồ vào xưởng 3T';
        final seal = order['sealCode'] ?? '';
        statusDesc = seal.toString().isNotEmpty
            ? 'Đồ đã được cân thực tế và niêm phong an toàn với mã seal $seal.'
            : 'Đồ giặt đã được đưa về xưởng giặt 3T Express an toàn.';
        statusIcon = Icons.inventory_2_rounded;
        statusColor = const Color(0xFF5B308C);
        statusBg = const Color(0xFFF3E8FD);
        break;
      case 'washing':
        statusTitle = 'Đang giặt sấy kháng khuẩn';
        final drum = order['drumInfo'] ?? 'Lồng giặt thông minh Turbo';
        statusDesc = 'Đồ giặt của bạn đang được xử lý bằng công nghệ $drum.';
        statusIcon = Icons.local_laundry_service_rounded;
        statusColor = primaryColor;
        statusBg = const Color(0xFFFFEBEE);
        break;
      case 'ready':
        statusTitle = 'Đã giặt xong & Đóng gói niêm phong';
        statusDesc = 'Đồ sạch thơm ngát đã hoàn thành kiểm định và đóng túi nguyên seal.';
        statusIcon = Icons.verified_rounded;
        statusColor = const Color(0xFFB4136D);
        statusBg = const Color(0xFFFCE4EC);
        break;
      case 'delivering':
        statusTitle = 'Shipper đang giao hàng trả bạn';
        final shipper = order['shipperName'] ?? 'Shipper 3T';
        statusDesc = 'Tài xế $shipper đang mang đồ sạch gấp gọn tới tận cửa.';
        statusIcon = Icons.delivery_dining_rounded;
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'completed':
        statusTitle = 'Đơn hàng giao thành công';
        statusDesc = 'Cảm ơn bạn đã tin chọn WashSmart 3T. Chúc bạn có trang phục sạch thơm!';
        statusIcon = Icons.task_alt_rounded;
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFDCFCE7);
        break;
      case 'cancelled':
        statusTitle = 'Đơn hàng đã hủy';
        statusDesc = 'Đơn hàng $orderCode đã được hủy theo yêu cầu.';
        statusIcon = Icons.cancel_outlined;
        statusColor = const Color(0xFF6B7280);
        statusBg = const Color(0xFFF3F4F6);
        break;
      case 'confirmed':
      default:
        statusTitle = 'Đã xác nhận đơn hàng';
        statusDesc = 'Hệ thống đã tiếp nhận đơn. Điều phối viên đang chỉ định Shipper tới lấy.';
        statusIcon = Icons.check_circle_outline_rounded;
        statusColor = const Color(0xFF006577);
        statusBg = const Color(0xFFE0F7FA);
        break;
    }

    // Items summary
    final items = order['items'] is List ? order['items'] as List : <dynamic>[];
    final itemsSummary = items
        .whereType<Map>()
        .map((it) => '${it['serviceName'] ?? ''}${it['quantity'] != null ? ' (${it['quantity']} ${it['unit'] ?? ''})' : ''}')
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    // Date
    String timeStr = '';
    final createdRaw = (order['createdAt'] ?? '').toString();
    if (createdRaw.isNotEmpty) {
      final dt = DateTime.tryParse(createdRaw.endsWith('Z') || createdRaw.contains('+') ? createdRaw : '${createdRaw}Z')?.toLocal();
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} · ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    return InkWell(
      onTap: () {
        Navigator.pop(sheetContext);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'pickingup' || status == 'washing' || status == 'delivering'
                ? statusColor.withValues(alpha: 0.3)
                : const Color(0xFFF3E0E2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status Icon + Title + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
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
                              statusTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              orderCode,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusDesc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textVariantColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (itemsSummary.isNotEmpty || timeStr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (itemsSummary.isNotEmpty) ...[
                      const Icon(Icons.dry_cleaning_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          itemsSummary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Row action "Theo dõi đơn hàng >"
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Xem lộ trình & chi tiết',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationEmptyState(int filterIndex) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              filterIndex == 1
                  ? 'Không có đơn nào đang xử lý'
                  : (filterIndex == 2
                      ? 'Chưa có đơn hàng hoàn thành'
                      : 'Chưa có thông báo đơn hàng'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Khi bạn đặt đơn giặt, mọi cập nhật trạng thái đơn (Shipper lấy đồ, Giặt sấy, Đóng gói, Giao hàng) sẽ được thông báo trực tiếp tại đây.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: textVariantColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingStep1Screen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Đặt lịch giặt ngay',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Item Tab Bottom Navigation
  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryColor : textVariantColor,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? primaryColor : textVariantColor,
            ),
          ),
        ],
      ),
    );
  }
}

// TÁCH PHẦN NỘI DUNG CUỘN CỦA TRANG CHỦ RA THÀNH WIDGET RIÊNG
class HomeScreenContent extends StatelessWidget {
  final VoidCallback onNavigateToPromotions;
  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToOrders;

  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> services;

  final bool isLoading;
  final String? profileError;
  final String? ordersError;
  final String? servicesError;

  const HomeScreenContent({
    super.key,
    required this.onNavigateToPromotions,
    required this.onNavigateToProfile,
    required this.onNavigateToOrders,
    required this.user,
    required this.orders,
    required this.services,
    required this.isLoading,
    required this.profileError,
    required this.ordersError,
    required this.servicesError,
  });

  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color surfaceContainer = Color(0xFFFFE9EA);
  static const Color surfaceContainerLow = Color(0xFFFFF0F0);
  static const Color textColor = Color(0xFF370C14);
  static const Color textVariantColor = Color(0xFF5B4041);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 16),
          _buildPromoBanner(),
          const SizedBox(height: 20),
          _buildActiveOrderTracker(),
          const SizedBox(height: 20),
          _buildQuickActionButton(context),
          const SizedBox(height: 20),
          _buildServicesGrid(context),
          const SizedBox(height: 16),
          _buildCarePromisesRow(),
          const SizedBox(height: 80), // Khoảng trống cho Bottom Bar
        ],
      ),
    );
  }

  // Khối 1: Thông tin chào mừng (Bấm Avatar KN chuyển sang Trang cá nhân)

  Widget _buildWelcomeSection() {
    final fullName = (user?['fullName'] ?? '').toString().trim();
    final displayName = fullName.isEmpty
        ? (profileError != null ? 'Chưa tải được tài khoản' : 'bạn')
        : fullName;

    final initials = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Row(
      children: [
        GestureDetector(
          onTap: onNavigateToProfile,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: surfaceContainer,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, $displayName!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?['phone']?.toString() ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: textVariantColor,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNavigateToProfile,
          tooltip: 'Tài khoản',
          icon: const Icon(
            Icons.account_circle_outlined,
            color: primaryColor,
            size: 28,
          ),
        ),
      ],
    );
  }

  // Khối 2: Banner Ưu đãi (Cập nhật hình ảnh banner mới)

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WASHSMART 3T',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chăm sóc quần áo của bạn',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn dịch vụ phù hợp với nhu cầu giặt ủi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Khối 3: Theo dõi Đơn hàng đang xử lý

  Widget _buildActiveOrderTracker() {
    final activeOrders = orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      return status != 'completed' && status != 'cancelled';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đơn hàng đang xử lý',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: onNavigateToOrders,
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (ordersError != null)
          _buildHomeMessage(
            'Không tải được đơn hàng. Vui lòng thử lại.',
            onRetry: () {
              // Tải lại được bổ sung ở bước xử lý lỗi bên dưới.
            },
          )
        else if (activeOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn chưa có đơn hàng đang xử lý.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: textVariantColor,
                  ),
                ),
                TextButton(
                  onPressed: onNavigateToOrders,
                  child: const Text('Xem lịch sử đơn hàng'),
                ),
              ],
            ),
          )
        else
          ...activeOrders.take(1).map((order) {
            final id = order['id'];
            final status = (order['status'] ?? '').toString();
            final statusText = _orderStatusText(status);
            final items = order['items'] is List
                ? order['items'] as List
                : <dynamic>[];

            final itemSummary = items
                .map((item) {
                  if (item is! Map) return '';
                  final name = (item['serviceName'] ?? '').toString();
                  final quantity = item['quantity'] ?? '';
                  final unit = (item['unit'] ?? '').toString();
                  return '$name ($quantity $unit)';
                })
                .where((text) => text.isNotEmpty)
                .join(', ');

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn hàng #$id',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itemSummary.isEmpty ? 'Chi tiết đơn hàng' : itemSummary,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textVariantColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_laundry_service,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onNavigateToOrders,
                      child: const Text('Xem đơn hàng'),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _orderStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'pickingup':
        return 'Đang lấy đồ';
      case 'received':
        return 'Đã nhận đồ';
      case 'washing':
        return 'Đang giặt';
      case 'ready':
        return 'Đã giặt xong';
      case 'delivering':
        return 'Đang giao hàng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status.isEmpty ? 'Chưa có trạng thái' : status;
    }
  }

  Widget _buildHomeMessage(String message, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: textVariantColor,
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  // Khối 4: Nút Đặt Giặt Ngay
  Widget _buildQuickActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingStep1Screen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          elevation: 6,
          shadowColor: primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.electric_moped,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đặt giặt ngay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Shipper gom tận nhà sau 30 phút',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: primaryColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Khối 5: Lưới Dịch vụ giặt ủi (Cập nhật 4 hình ảnh minh họa thực tế)

  Widget _buildServicesGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dịch vụ giặt ủi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),

        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (servicesError != null)
          _buildHomeMessage('Không tải được danh sách dịch vụ.')
        else if (services.isEmpty)
          _buildHomeMessage('Hiện chưa có dịch vụ nào được cung cấp.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final service = services[index];
              final name = (service['name'] ?? '').toString();
              final description = (service['description'] ?? '').toString();

              final priceInfo = service['price'] is Map
                  ? Map<String, dynamic>.from(service['price'] as Map)
                  : <String, dynamic>{};

              final priceValue = priceInfo['price'];
              final unit = (priceInfo['unit'] ?? '').toString();

              final priceText = priceValue is num
                  ? '${priceValue.toStringAsFixed(0)} đ'
                  : 'Chưa có giá';

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingStep1Screen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.local_laundry_service,
                        size: 30,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Dịch vụ' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: textVariantColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unit.isEmpty ? priceText : '$priceText / $unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Khối 6: Cam kết chất lượng
  Widget _buildCarePromisesRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPromiseItem(Icons.eco, 'Nước giặt hữu cơ'),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE3BDBF),
              shape: BoxShape.circle,
            ),
          ),
          _buildPromiseItem(Icons.verified_user, 'Bảo hiểm vải sợi'),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE3BDBF),
              shape: BoxShape.circle,
            ),
          ),
          _buildPromiseItem(Icons.timer, 'Giao hẹn chuẩn giờ'),
        ],
      ),
    );
  }

  Widget _buildPromiseItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
