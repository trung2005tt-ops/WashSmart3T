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
    String createdRaw = (order['createdAt'] ?? '').toString().trim();
    if (createdRaw.isNotEmpty && !createdRaw.endsWith('Z') && !createdRaw.contains('+')) {
      createdRaw += 'Z';
    }
    final createdAt = DateTime.tryParse(createdRaw);

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

    final hasProof = (order['pickupProofPhotoUrl'] != null && order['pickupProofPhotoUrl'].toString().trim().isNotEmpty) ||
        (order['deliveryProofPhotoUrl'] != null && order['deliveryProofPhotoUrl'].toString().trim().isNotEmpty);

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
                      : 'Tạo lúc: ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')} ngày ${createdAt.toLocal().day.toString().padLeft(2, '0')}/${createdAt.toLocal().month.toString().padLeft(2, '0')}/${createdAt.toLocal().year}',
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
                if (hasProof || status.toLowerCase() == 'completed' || (order['paymentStatus'] ?? '').toString().toLowerCase() == 'paid') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      if (hasProof)
                        TextButton.icon(
                          onPressed: () => _showProofPhotosSheet(order),
                          icon: const Icon(Icons.photo_library, size: 14, color: Color(0xFF0284C7)),
                          label: Text(
                            'Xem ảnh minh chứng',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (status.toLowerCase() == 'completed' || (order['paymentStatus'] ?? '').toString().toLowerCase() == 'paid')
                        TextButton.icon(
                          onPressed: () => _showInvoiceDetailsSheet(order),
                          icon: const Icon(Icons.receipt_long, size: 14, color: Color(0xFF059669)),
                          label: Text(
                            'Xem hóa đơn điện tử',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
                if (status.toLowerCase() == 'pending' &&
                    (order['shipperId'] == null || order['shipperId'] == 0) &&
                    (order['shipperName'] == null || order['shipperName'].toString().trim().isEmpty)) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openOrderDetails(order),
                        icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                        label: Text(
                          'Hủy đơn hàng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200),
                          backgroundColor: const Color(0xFFFFF0F0),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MODAL XEM ẢNH XÁC NHẬN GIAO NHẬN (CHO KHÁCH HÀNG) ---
  void _showProofPhotosSheet(Map<String, dynamic> order) {
    final id = order['id'] ?? order['Id'] ?? 0;
    String formatFullUrl(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
      final normalized = trimmed.replaceAll(r'\', '/');
      final clean = normalized.startsWith('/') ? normalized : '/$normalized';
      return 'http://localhost:5085$clean';
    }

    final pickupUrls = (order['pickupProofPhotoUrl'] ?? '')
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final deliveryUrls = (order['deliveryProofPhotoUrl'] ?? '')
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ảnh Minh Chứng • #WS3T-${id.toString().padLeft(4, '0')}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          'Ảnh chụp niêm phong túi giặt & biên chứng giao đồ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
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
            Expanded(
              child: ListView(
                children: [
                  if (pickupUrls.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.lock_clock, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          '1. Ảnh Lấy Đồ & Niêm Phong Seal 3T (${pickupUrls.length})',
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
                            onTap: () => _openZoomImage(ctx, imgUrl),
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
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                    );
                                  },
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
                            onTap: () => _openZoomImage(ctx, imgUrl),
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
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                    );
                                  },
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
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openZoomImage(BuildContext context, String imageUrl) {
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
                      child: const Text('Không tải được ảnh.'),
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
  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey.shade400),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isHighlight || isDiscount ? FontWeight.bold : FontWeight.w600,
                color: isDiscount
                    ? Colors.red.shade600
                    : isHighlight
                        ? primaryColor
                        : onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetailsSheet(Map<String, dynamic> order) {
    final id = order['id'] ?? order['Id'] ?? 0;
    final orderCode = 'WS3T-${id.toString().padLeft(4, '0')}';
    final invoiceCode = 'HD-WS3T-${id.toString().padLeft(4, '0')}';
    final sealCode = (order['sealCode'] ?? 'WS-SEAL-${id.toString().padLeft(4, '0')}').toString();

    final customerName = (order['customerName'] ?? 'Quý khách').toString();
    final customerPhone = (order['customerPhone'] ?? order['contactPhone'] ?? 'Chưa có SĐT').toString();
    final pickupAddress = (order['pickupAddress'] ?? 'Tại cửa hàng').toString();
    final deliveryAddress = (order['deliveryAddress'] ?? order['pickupAddress'] ?? 'Tại cửa hàng').toString();
    final shipperName = (order['shipperName'] ?? 'Đang điều phối').toString();
    final shipperPhone = (order['shipperPhone'] ?? '').toString();

    final items = order['items'] is List
        ? (order['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final shippingFee = ((order['shippingFee'] ?? order['ShippingFee'] ?? 0) as num).toDouble();
    final addonFee = ((order['addonFee'] ?? order['AddonFee'] ?? 0) as num).toDouble();
    final discountAmount = ((order['discountAmount'] ?? order['DiscountAmount'] ?? 0) as num).toDouble();
    final totalAmount = ((order['totalAmount'] ?? order['TotalAmount'] ?? 0) as num).toDouble();

    final paymentMethod = (order['paymentMethod'] ?? order['PaymentMethod'] ?? 'Chuyển khoản').toString();
    String paidDate = 'Đã hoàn tất';
    if (order['paidAt'] != null) {
      final d = DateTime.tryParse(order['paidAt'].toString());
      if (d != null) {
        paidDate = '${d.toLocal().hour.toString().padLeft(2, '0')}:${d.toLocal().minute.toString().padLeft(2, '0')} ${d.toLocal().day.toString().padLeft(2, '0')}/${d.toLocal().month.toString().padLeft(2, '0')}/${d.toLocal().year}';
      }
    }

    final note = (order['note'] ?? '').toString();
    final utilities = <String>[];
    for (final part in note.split('|')) {
      final t = part.trim();
      if (t.toLowerCase().startsWith('tiện ích:')) {
        utilities.add(t.substring('tiện ích:'.length).trim());
      }
    }

    String formatMoney(num val) => '${val.toStringAsFixed(0)} đ';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFF059669), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hóa Đơn Điện Tử Bán Lẻ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_laundry_service, color: primaryColor, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'WASHSMART 3T',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'HỆ THỐNG GIẶT SẤY & CHĂM SÓC TRANG PHỤC THÔNG MINH',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '140 Lê Trọng Tấn, P. Tây Thạnh, TP.HCM • Hotline: 1900 3T3T',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: outlineColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDashedLine(),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HÓA ĐƠN DỊCH VỤ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Số HĐ: $invoiceCode',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                                Text(
                                  'Mã đơn: $orderCode',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: outlineColor,
                                  ),
                                ),
                                Text(
                                  'Thời gian: $paidDate',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: outlineColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF059669), width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFECFDF5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                                const SizedBox(height: 2),
                                Text(
                                  'ĐÃ THANH TOÁN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF059669),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'PAID',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDashedLine(),
                      const SizedBox(height: 14),
                      Text(
                        'THÔNG TIN KHÁCH HÀNG & GIAO NHẬN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Khách hàng:', customerName),
                      _buildReceiptRow('Số điện thoại:', customerPhone),
                      _buildReceiptRow('Địa chỉ nhận:', pickupAddress),
                      _buildReceiptRow('Địa chỉ giao:', deliveryAddress),
                      _buildReceiptRow('Mã Seal niêm phong:', sealCode, isHighlight: true),
                      if (shipperName.isNotEmpty && shipperName != 'Đang điều phối')
                        _buildReceiptRow('Shipper thực hiện:', '$shipperName ${shipperPhone.isNotEmpty ? "($shipperPhone)" : ""}'),
                      const SizedBox(height: 14),
                      _buildDashedLine(),
                      const SizedBox(height: 14),
                      Text(
                        'BẢNG KÊ DỊCH VỤ CHI TIẾT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Dịch vụ',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'SL',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Đơn giá',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Thành tiền',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (items.isNotEmpty)
                        ...items.map((item) {
                          final name = (item['serviceName'] ?? 'Dịch vụ giặt').toString();
                          final q = (item['quantity'] ?? 1);
                          final unit = (item['unit'] ?? '').toString();
                          final unitPrice = (item['unitPrice'] ?? 0) as num;
                          final totalPrice = (item['totalPrice'] ?? (unitPrice * (q as num))) as num;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    name,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '$q ${unit.isNotEmpty ? unit : ""}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(unitPrice),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(totalPrice),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Giặt sấy theo gói tiêu chuẩn 3T', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                        ),

                      if (utilities.isNotEmpty || addonFee > 0 || shippingFee > 0 || discountAmount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tiện ích & Phụ phí đi kèm:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: outlineColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              for (final u in utilities)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check, size: 12, color: Color(0xFF059669)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          u,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: onSurface),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (addonFee > 0 && utilities.isEmpty)
                                _buildReceiptRow('Phụ phí tiện ích:', '+${formatMoney(addonFee)}'),
                              if (shippingFee > 0)
                                _buildReceiptRow('Phí giao nhận 2 chiều:', '+${formatMoney(shippingFee)}'),
                              if (discountAmount > 0)
                                _buildReceiptRow('Khuyến mãi / Giảm giá:', '-${formatMoney(discountAmount)}', isDiscount: true),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      _buildDashedLine(),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TỔNG THANH TOÁN:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            formatMoney(totalAmount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Phương thức thanh toán:',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                          ),
                          Text(
                            paymentMethod,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tích lũy WashPoints:',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                          ),
                          Text(
                            '+11 điểm (Đã cộng ví 3T)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đơn hàng được bảo hiểm bồi thường 100% trang phục bởi gói 3T Care.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Cảm ơn Quý khách đã tin chọn WashSmart 3T! Hẹn gặp lại Quý khách.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: outlineColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showProofPhotosSheet(order);
                      },
                      icon: const Icon(Icons.photo_library, size: 16, color: Color(0xFF0284C7)),
                      label: Text(
                        'Xem ảnh minh chứng',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        backgroundColor: const Color(0xFFF0F9FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã lưu hóa đơn điện tử $invoiceCode thành công!'),
                            backgroundColor: const Color(0xFF059669),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16, color: Colors.white),
                      label: Text(
                        'Tải hóa đơn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
