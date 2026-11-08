import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_tracking_screen.dart'; // Import màn hình Chi tiết / Theo dõi tiến độ

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  // Màu sắc thiết kế theo Hệ thống Brand Tokens WashSmart 3T
  final Color primaryColor = const Color(0xFFB90538);
  final Color primaryContainer = const Color(0xFFDC2C4F);
  final Color primaryFixed = const Color(0xFFFFDADB);
  final Color secondaryColor = const Color(0xFFB4136D);
  final Color tertiaryColor = const Color(0xFF006577);
  final Color tertiaryFixed = const Color(0xFFACEDFF);
  final Color bgSurface = const Color(0xFFFFF8F7);
  final Color cardBg = Colors.white;
  final Color surfaceLow = const Color(0xFFFFF0F0);
  final Color surfaceContainer = const Color(0xFFFFE9EA);
  final Color surfaceHigh = const Color(0xFFFFE1E3);
  final Color surfaceVariant = const Color(0xFFFFD9DC);
  final Color onSurface = const Color(0xFF370C14);
  final Color onSurfaceVariant = const Color(0xFF5B4041);
  final Color outlineColor = const Color(0xFF8F6F71);

  // State Quản lý
  int _selectedFilterIndex =
      1; // 0: Tất cả, 1: Đang xử lý, 2: Đã hoàn thành, 3: Đã hủy
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _loadError;

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();

    return _orders.where((order) {
      final status = (order['status'] ?? '').toString();
      final id = (order['id'] ?? '').toString();
      final items = order['items'] is List
          ? order['items'] as List
          : <dynamic>[];

      final searchText = [
        id,
        status,
        order['pickupAddress'] ?? '',
        order['deliveryAddress'] ?? '',
        ...items.map((item) => item is Map ? item['serviceName'] ?? '' : ''),
      ].join(' ').toLowerCase();

      if (query.isNotEmpty && !searchText.contains(query)) {
        return false;
      }

      switch (_selectedFilterIndex) {
        case 1:
          return !_isCompleted(status) && !_isCancelled(status);
        case 2:
          return _isCompleted(status);
        case 3:
          return _isCancelled(status);
        default:
          return true;
      }
    }).toList();
  }

  bool _isCompleted(String status) => status.toLowerCase() == 'completed';

  bool _isCancelled(String status) => status.toLowerCase() == 'cancelled';

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final result = await ApiService.getMyOrders();

      if (!mounted) return;

      setState(() {
        _orders = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Hiệu ứng nhấp nháy chấm tròn trạng thái live
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadOrders();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Toast thông báo chuẩn từ code cũ
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
                  color: Colors.white,
                  fontSize: 13,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,

      // --- 1. HEADER APP BAR ---
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surfaceLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_laundry_service_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WASHSMART 3T',
                  style: GoogleFonts.plusJakartaSans(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Đơn Hàng',
                  style: GoogleFonts.plusJakartaSans(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    'ROSE CLUB',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: primaryColor,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // --- NỘI DUNG CHÍNH ---
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. KHUNG TÌM KIẾM & CHIPS LỌC TRẠNG THÁI
            _buildSearchAndFilterSection(),
            const SizedBox(height: 16),

            // 3. CARD ĐƠN HÀNG ĐANG XỬ LÝ (LIVE STATUS - #WS3T-8892)
            const SizedBox(height: 16),

            Text(
              'Đơn hàng của bạn',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              _buildEmptyOrError('Không tải được đơn hàng.', isError: true)
            else if (_filteredOrders.isEmpty)
              _buildEmptyOrError(
                _orders.isEmpty
                    ? 'Bạn chưa có đơn hàng nào.'
                    : 'Không có đơn hàng phù hợp với bộ lọc.',
              )
            else
              ..._filteredOrders.map(_buildOrderCard),

            const SizedBox(height: 16),

            // 6. BANNER TỔNG ĐÀI HỖ TRỢ & CSKH 24/7
            _buildSupportBanner(),
            const SizedBox(height: 30), // Đã thu gọn khoảng trống bên dưới
          ],
        ),
      ),
    );
  }

  // --- WIDGET TÌM KIẾM & BỘ LỌC ---
  Widget _buildSearchAndFilterSection() {
    final allCount = _orders.length;
    final activeCount = _orders
        .where(
          (o) =>
              !_isCompleted((o['status'] ?? '').toString()) &&
              !_isCancelled((o['status'] ?? '').toString()),
        )
        .length;
    final completedCount = _orders
        .where((o) => _isCompleted((o['status'] ?? '').toString()))
        .length;
    final cancelledCount = _orders
        .where((o) => _isCancelled((o['status'] ?? '').toString()))
        .length;

    final filters = [
      {'title': 'Tất cả ($allCount)', 'index': 0},
      {
        'title': 'Đang xử lý ($activeCount)',
        'index': 1,
        'icon': Icons.local_laundry_service,
      },
      {'title': 'Đã hoàn thành ($completedCount)', 'index': 2},
      {'title': 'Đã hủy ($cancelledCount)', 'index': 3},
    ];

    return Column(
      children: [
        // Thanh Tìm kiếm
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surfaceLow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã đơn (#WS3T...), tên dịch vụ...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: outlineColor.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Icon(Icons.tune, color: outlineColor, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Tabs lọc nằm ngang
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilterIndex == f['index'];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () =>
                      setState(() => _selectedFilterIndex = f['index'] as int),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        if (f['icon'] != null) ...[
                          Icon(
                            f['icon'] as IconData,
                            size: 14,
                            color: isSelected ? Colors.white : onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          f['title'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected ? Colors.white : onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- WIDGET ĐƠN HÀNG ĐANG XỬ LÝ (#WS3T-8892) ---
  Widget _buildActiveOrderCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dải màu viền trên
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryContainer,
                  const Color(0xFFFD56A7),
                  primaryColor,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Đơn hàng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#WS3T-8892',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showToast('Đã chép mã đơn #WS3T-8892'),
                          child: Icon(
                            Icons.content_copy,
                            size: 15,
                            color: outlineColor,
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
                        color: surfaceHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          FadeTransition(
                            opacity: _pulseController,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đang xử lý • 70%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Sub Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: outlineColor),
                        const SizedBox(width: 4),
                        Text(
                          'Hôm nay, 10:24',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.person, size: 13, color: outlineColor),
                        const SizedBox(width: 4),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: outlineColor,
                            ),
                            children: [
                              const TextSpan(text: 'Khách hàng: '),
                              TextSpan(
                                text: 'Kiều Như',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
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
                const SizedBox(height: 12),

                // Ảnh & Chi tiết dịch vụ
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1545173168-9f1947eebb7f?q=80&w=300&auto=format&fit=crop',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 64,
                                height: 64,
                                color: surfaceContainer,
                                child: Icon(
                                  Icons.dry_cleaning,
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
                              'Giặt Sấy Tinh Tươm (5.0 kg)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ủi hơi nước chống nhăn + Hương hoa ban mai + Túi seal 3T',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: outlineColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: tertiaryColor,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Q.1',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: outlineColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

                // Thanh 5 Bước tiến trình Workflow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceLow.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStepLabel('1. Đã đặt', isCompleted: true),
                          _buildStepLabel('2. Tới lấy', isCompleted: true),
                          _buildStepLabel('3. Giặt sấy', isCurrent: true),
                          _buildStepLabel('4. Seal', isCompleted: false),
                          _buildStepLabel('5. Giao', isCompleted: false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 6,
                          color: surfaceVariant,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 70,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, secondaryColor],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 30,
                                child: Container(color: Colors.transparent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Shipper & Thời gian giao
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: tertiaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.two_wheeler,
                            size: 14,
                            color: tertiaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: onSurface,
                            ),
                            children: [
                              const TextSpan(text: 'Shipper: '),
                              TextSpan(
                                text: 'Văn Nam ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '(4.9⭐)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Giao 16:30 hôm nay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Giá tiền
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng thanh toán tạm tính',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: outlineColor,
                          ),
                        ),
                        Text(
                          '135.000 đ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '(Đã gồm phí gom giao\n& Tip shipper)',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: outlineColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // NÚT CHUYỂN SANG MÀN HÌNH THEO DÕI TIẾN ĐỘ
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_orders.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chưa có đơn hàng để theo dõi.'),
                          ),
                        );
                        return;
                      }

                      final order = _orders.first;
                      final rawId = order['id'] ?? order['Id'];

                      final orderId = rawId is int
                          ? rawId
                          : int.tryParse(rawId?.toString() ?? '');

                      if (orderId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không xác định được mã đơn hàng.'),
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderId: orderId),
                        ),
                      );
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Theo dõi tiến độ chi tiết',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showToast('Đang gọi điện cho Shipper Văn Nam...'),
                        icon: Icon(
                          Icons.phone_in_talk,
                          size: 16,
                          color: tertiaryColor,
                        ),
                        label: Text(
                          'Gọi Shipper 3T',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: surfaceContainer,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showToast('Đang tải hóa đơn điện tử...'),
                        icon: Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: secondaryColor,
                        ),
                        label: Text(
                          'Hóa đơn điện tử',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: surfaceContainer,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
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
    );
  }

  Widget _buildStepLabel(
    String label, {
    bool isCompleted = false,
    bool isCurrent = false,
  }) {
    if (isCurrent) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
        color: isCompleted ? primaryColor : outlineColor.withOpacity(0.7),
      ),
    );
  }

  // --- WIDGET TIÊU ĐỀ SECTION ---
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: primaryColor, size: 20),
            const SizedBox(width: 6),
            Text(
              'Lịch sử đơn hàng gần đây',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () => _showToast('Mở danh sách tất cả đơn hàng cũ'),
          child: Row(
            children: [
              Text(
                'Xem tất cả',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: primaryColor),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET DANH SÁCH ĐƠN HÀNG LỊCH SỬ ---
  Widget _buildHistoryOrdersList() {
    final orders = [
      {
        'id': 'WS3T-8120',
        'date': '12/05/2024',
        'title': 'Giặt hấp Vest & Đầm dạ hội (2 món)',
        'subtitle': 'Mã seal: #SEAL-3T-8120 (Đã mở)',
        'price': '185.000 đ',
        'payment': 'VietQR',
        'icon': Icons.dry_cleaning,
        'rated': true,
      },
      {
        'id': 'WS3T-7945',
        'date': '05/05/2024',
        'title': 'Spa giày & Sneaker chiếu UV (1 đôi)',
        'subtitle': 'Khử khuẩn UV đa tầng & Phục hồi đế',
        'price': '60.000 đ',
        'payment': 'Tiền mặt (COD)',
        'icon': Icons.roller_skating,
        'rated': false,
      },
      {
        'id': 'WS3T-7612',
        'date': '28/04/2024',
        'title': 'Giặt mền ga & Drap cotton (6.5 kg)',
        'subtitle': 'Sấy diệt khuẩn hương Lavender',
        'price': '160.000 đ',
        'payment': 'VietQR',
        'icon': Icons.bed,
        'rated': false,
      },
    ];

    return Column(
      children: orders.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
          child: Column(
            children: [
              // Header đơn hàng cũ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${item['id']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        ' • ${item['date']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: outlineColor,
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
                      color: surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 12, color: primaryColor),
                        const SizedBox(width: 3),
                        Text(
                          'Hoàn tất',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chi tiết món đồ
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: outlineColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['price'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              item['payment'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: outlineColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Nút Đặt lại / Xem đánh giá
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item['rated'] == true) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showToast('Đánh giá của bạn: 5 sao Tinh Tươm!'),
                      icon: Icon(Icons.star, size: 14, color: secondaryColor),
                      label: Text(
                        'Xem đánh giá 5⭐',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: surfaceContainer,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _showToast('Đã thêm dịch vụ vào đơn mới!'),
                    icon: const Icon(
                      Icons.replay,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Đặt lại đơn này',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyOrError(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.cloud_off_outlined : Icons.receipt_long_outlined,
            size: 36,
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: onSurfaceVariant,
            ),
          ),
          if (isError)
            TextButton(onPressed: _loadOrders, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Future<void> _openOrderDetails(Map<String, dynamic> order) async {
    final rawId = order['id'] ?? order['Id'];
    final orderId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    if (orderId == null || orderId <= 0) {
      _showToast('Không xác định được mã đơn hàng.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId)),
    );

    // Làm mới trạng thái và tổng tiền khi quay lại từ trang chi tiết.
    if (mounted) _loadOrders();
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id'];
    final status = (order['status'] ?? '').toString();
    final createdAt = DateTime.tryParse((order['createdAt'] ?? '').toString());

    final items = order['items'] is List ? order['items'] as List : <dynamic>[];

    final itemNames = items
        .whereType<Map>()
        .map((item) => (item['serviceName'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(', ');

    final total = order['totalAmount'];

    final totalText = total is num
        ? '${total.toStringAsFixed(0)} đ'
        : 'Chưa có thông tin';

    String statusText;
    Color statusColor;

    switch (status.toLowerCase()) {
      case 'pending':
        statusText = 'Chờ xác nhận';
        statusColor = tertiaryColor;
        break;
      case 'confirmed':
        statusText = 'Đã xác nhận';
        statusColor = tertiaryColor;
        break;
      case 'pickingup':
        statusText = 'Đang lấy đồ';
        statusColor = tertiaryColor;
        break;
      case 'received':
        statusText = 'Đã nhận đồ';
        statusColor = tertiaryColor;
        break;
      case 'washing':
        statusText = 'Đang giặt';
        statusColor = primaryColor;
        break;
      case 'ready':
        statusText = 'Đã giặt xong';
        statusColor = primaryColor;
        break;
      case 'delivering':
        statusText = 'Đang giao hàng';
        statusColor = tertiaryColor;
        break;
      case 'completed':
        statusText = 'Hoàn thành';
        statusColor = Colors.green.shade700;
        break;
      case 'cancelled':
        statusText = 'Đã hủy';
        statusColor = outlineColor;
        break;
      default:
        statusText = status.isEmpty ? 'Chưa có trạng thái' : status;
        statusColor = outlineColor;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openOrderDetails(order),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đơn hàng #$id',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  createdAt == null
                      ? 'Chưa có ngày tạo'
                      : 'Ngày tạo: ${createdAt.toLocal().day.toString().padLeft(2, '0')}/'
                            '${createdAt.toLocal().month.toString().padLeft(2, '0')}/'
                            '${createdAt.toLocal().year}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: outlineColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_laundry_service,
                      color: primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        itemNames.isEmpty
                            ? 'Chưa có thông tin dịch vụ'
                            : itemNames,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((order['pickupAddress'] ?? '').toString().isNotEmpty)
                  Text(
                    'Địa chỉ lấy đồ: ${order['pickupAddress']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng tiền',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: onSurfaceVariant,
                      ),
                    ),
                    Text(
                      totalText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BANNER TỔNG ĐÀI HỖ TRỢ ---
  Widget _buildSupportBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cam kết dịch vụ & Khiếu nại 3T',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cần hỗ trợ về đồ giặt hoặc khiếu nại bồi thường? Liên hệ Hotline 3T hoặc gửi yêu cầu giải quyết trong 24h.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: outlineColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _showToast('Đang gọi Tổng đài 1900 3388...'),
                      child: Row(
                        children: [
                          Icon(Icons.call, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            '1900 3388',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () =>
                          _showToast('Đang kết nối tới tư vấn viên CSKH...'),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 14,
                            color: tertiaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chat CSKH 24/7',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: tertiaryColor,
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
        ],
      ),
    );
  }
}
