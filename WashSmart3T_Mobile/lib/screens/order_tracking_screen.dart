import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'submit_claim_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const Color primary = Color(0xFFB90538);
  static const Color background = Color(0xFFFFF8F7);
  static const Color textColor = Color(0xFF370C14);
  static const Color secondaryText = Color(0xFF5B4041);

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _history = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getOrderDetail(widget.orderId),
        ApiService.getOrderHistory(widget.orderId),
      ]);

      final order = results[0];
      final historyData = results[1];
      final dynamic raw = historyData['history'];
      final List<dynamic> rawHistory = raw is List ? raw : <dynamic>[];

      if (!mounted) return;

      setState(() {
        _order = order;
        _history = rawHistory
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) {
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
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status.isEmpty ? 'Chưa có trạng thái' : status;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Chưa có thông tin thời gian';
    }

    String str = value.toString().trim();
    if (!str.endsWith('Z') && !str.contains('+')) {
      str += 'Z';
    }

    final date = DateTime.tryParse(str);
    if (date == null) return 'Thời gian không hợp lệ';

    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatMoney(dynamic value) {
    if (value is! num) return 'Chưa có thông tin';
    return '${value.toStringAsFixed(0)} đ';
  }

  void _showCancelDialog() {
    String selectedReason = 'Đổi ý, không còn nhu cầu';
    final customReasonController = TextEditingController();
    final reasons = [
      'Đổi ý, không còn nhu cầu',
      'Muốn thay đổi thời gian hoặc địa chỉ lấy đồ',
      'Muốn chọn gói dịch vụ khác',
      'Lý do khác',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Xác nhận hủy đơn hàng',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn có chắc chắn muốn hủy đơn hàng này? Sau khi hủy, lịch hẹn lấy đồ sẽ bị hủy và không thể hoàn tác.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: secondaryText),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lý do hủy đơn:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...reasons.map((r) => RadioListTile<String>(
                          value: r,
                          groupValue: selectedReason,
                          activeColor: primary,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedReason = val);
                            }
                          },
                        )),
                    if (selectedReason == 'Lý do khác') ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: customReasonController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Nhập lý do cụ thể...',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFFF0F0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Đóng', style: GoogleFonts.plusJakartaSans(color: secondaryText, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final finalReason = selectedReason == 'Lý do khác' && customReasonController.text.trim().isNotEmpty
                        ? customReasonController.text.trim()
                        : selectedReason;
                    await _handleCancelOrder(finalReason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Xác nhận hủy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCancelOrder(String reason) async {
    setState(() => _loading = true);
    try {
      await ApiService.cancelOrder(widget.orderId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy đơn hàng thành công.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(
          'Theo dõi đơn hàng',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _order == null
          ? _buildMessage('Không tìm thấy thông tin đơn hàng.')
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: primary),
            const SizedBox(height: 12),
            Text(
              'Không tải được thông tin đơn hàng.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(color: secondaryText),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final status = (order['status'] ?? '').toString();
    final items = order['items'] is List ? order['items'] as List : <dynamic>[];
    final bool isCompleted = status.toLowerCase() == 'completed';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderSummary(order, status),
          const SizedBox(height: 16),
          _buildProofPhotosCard(order),
          const SizedBox(height: 16),
          _buildInsuranceSupportCard(order),
          const SizedBox(height: 16),
          _buildSectionTitle('Chi tiết dịch vụ'),
          const SizedBox(height: 10),
          _buildItemsCard(items),
          const SizedBox(height: 16),
          _buildSectionTitle('Thông tin nhận và giao đồ'),
          const SizedBox(height: 10),
          _buildAddressCard(order),
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Lịch sử trạng thái'),
            const SizedBox(height: 10),
            _buildHistoryCard(),
          ],
          const SizedBox(height: 16),
          _buildInvoiceCard(order),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Map<String, dynamic> order, String status) {
    final id = order['id'] ?? order['Id'] ?? widget.orderId;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đơn hàng #$id',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9EA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(status),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.calendar_today_outlined,
            'Ngày tạo',
            _formatDate(order['createdAt'] ?? order['CreatedAt']),
          ),
          if ((order['shippingFee'] ?? order['ShippingFee'] ?? 0) as num > 0) ...[
            const Divider(height: 18),
            _infoRow(
              Icons.local_shipping_outlined,
              'Phí vận chuyển',
              _formatMoney(order['shippingFee'] ?? order['ShippingFee']),
            ),
          ],
          if ((order['addonFee'] ?? order['AddonFee'] ?? 0) as num > 0) ...[
            const Divider(height: 18),
            _infoRow(
              Icons.auto_awesome_outlined,
              'Phụ phí tiện ích & ủi',
              _formatMoney(order['addonFee'] ?? order['AddonFee']),
            ),
          ],
          if ((order['discountAmount'] ?? order['DiscountAmount'] ?? 0) as num > 0) ...[
            const Divider(height: 18),
            _infoRow(
              Icons.discount_outlined,
              'Giảm giá ưu đãi',
              '-${_formatMoney(order['discountAmount'] ?? order['DiscountAmount'])}',
            ),
          ],
          const Divider(height: 18),
          _infoRow(
            Icons.credit_card_outlined,
            'Phương thức',
            (order['paymentMethod'] ?? order['PaymentMethod'] ?? 'COD').toString(),
          ),
          const Divider(height: 24),
          _infoRow(
            Icons.payments_outlined,
            'Tổng thanh toán',
            _formatMoney(order['totalAmount'] ?? order['TotalAmount']),
          ),
          if (status.toLowerCase() == 'pending' &&
              (order['shipperId'] == null || order['shipperId'] == 0) &&
              (order['shipperName'] == null || order['shipperName'].toString().trim().isEmpty)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showCancelDialog,
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                label: Text(
                  'Hủy Đơn Hàng Này',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  backgroundColor: const Color(0xFFFFF0F0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- HÀM CHUẨN HÓA ĐƯỜNG DẪN HÌNH ẢNH MINH CHỨNG ---
  String _formatFullUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final normalized = trimmed.replaceAll(r'\', '/');
    final clean = normalized.startsWith('/') ? normalized : '/$normalized';
    return 'http://localhost:5085$clean';
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
                color: secondaryText,
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
                        ? primary
                        : textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET THẺ HÓA ĐƠN ĐIỆN TỬ CHI TIẾT CHO KHÁCH HÀNG ---
  Widget _buildInvoiceCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (order['paymentStatus'] ?? '').toString().toLowerCase();
    final isPaid = paymentStatus == 'paid' || status == 'completed';
    if (!isPaid) return const SizedBox.shrink();

    final id = order['id'] ?? order['Id'] ?? widget.orderId;
    final orderCode = 'WS3T-${id.toString().padLeft(4, '0')}';
    final invoiceCode = 'HD-WS3T-${id.toString().padLeft(4, '0')}';
    final total = (order['totalAmount'] ?? order['TotalAmount'] ?? 0) as num;
    final totalFormatted = _formatMoney(total);
    final paymentMethod = (order['paymentMethod'] ?? order['PaymentMethod'] ?? 'Chuyển khoản').toString();
    final paidDate = order['paidAt'] != null
        ? _formatDate(order['paidAt'])
        : _formatDate(order['updatedAt'] ?? order['createdAt']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD1D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hóa Đơn Điện Tử 3T',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'E-INVOICE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Số HĐ: $invoiceCode • Đơn: $orderCode • $paidDate',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 13, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      'Đã thanh toán',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD1D8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số tiền đã thanh toán',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalFormatted,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Hình thức: $paymentMethod',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${(total / 10000).floor()} WashPoints tích lũy',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showInvoiceDetailsSheet(order),
              icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
              label: Text(
                'Xem Chi Tiết Hóa Đơn Điện Tử (E-Receipt)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODAL CHI TIẾT HÓA ĐƠN ĐIỆN TỬ CHÍNH THỨC ---
  void _showInvoiceDetailsSheet(Map<String, dynamic> order) {
    final id = order['id'] ?? order['Id'] ?? widget.orderId;
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
    final paidDate = order['paidAt'] != null
        ? _formatDate(order['paidAt'])
        : _formatDate(order['updatedAt'] ?? order['createdAt']);

    // Trích xuất tiện ích từ note
    final note = (order['note'] ?? '').toString();
    final utilities = <String>[];
    for (final part in note.split('|')) {
      final t = part.trim();
      if (t.toLowerCase().startsWith('tiện ích:')) {
        utilities.add(t.substring('tiện ích:'.length).trim());
      }
    }

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
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: primary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hóa Đơn Điện Tử Bán Lẻ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
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
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_laundry_service, color: primary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'WASHSMART 3T',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: primary,
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
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '140 Lê Trọng Tấn, P. Tây Thạnh, TP.HCM • Hotline: 1900 3T3T',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: secondaryText,
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
                                    color: primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Số HĐ: $invoiceCode',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Mã đơn: $orderCode',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: secondaryText,
                                  ),
                                ),
                                Text(
                                  'Thời gian: $paidDate',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: secondaryText,
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
                                    _formatMoney(unitPrice),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _formatMoney(totalPrice),
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
                                  color: secondaryText,
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
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (addonFee > 0 && utilities.isEmpty)
                                _buildReceiptRow('Phụ phí tiện ích:', '+${_formatMoney(addonFee)}'),
                              if (shippingFee > 0)
                                _buildReceiptRow('Phí giao nhận 2 chiều:', '+${_formatMoney(shippingFee)}'),
                              if (discountAmount > 0)
                                _buildReceiptRow('Khuyến mãi / Giảm giá:', '-${_formatMoney(discountAmount)}', isDiscount: true),
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
                              color: textColor,
                            ),
                          ),
                          Text(
                            _formatMoney(totalAmount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primary,
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: secondaryText),
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: secondaryText),
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
                            color: secondaryText,
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
                        final pickupProof = (order['pickupProofPhotoUrl'] ?? '').toString();
                        final deliveryProof = (order['deliveryProofPhotoUrl'] ?? '').toString();
                        final first = deliveryProof.isNotEmpty ? deliveryProof : pickupProof;
                        if (first.isNotEmpty) {
                          _openZoomProofImage(_formatFullUrl(first));
                        }
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
                            backgroundColor: primary,
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
                        backgroundColor: primary,
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

  // --- WIDGET KHỐI ẢNH MINH CHỨNG GIAO NHẬN CHO KHÁCH HÀNG ---
  Widget _buildProofPhotosCard(Map<String, dynamic> order) {
    String formatFullUrl(String raw) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      final clean = raw.startsWith('/') ? raw : '/$raw';
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

    if (pickupUrls.isEmpty && deliveryUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = pickupUrls.length + deliveryUrls.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh Xác Nhận Minh Chứng ($totalCount ảnh)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Hình ảnh đối soát niêm phong seal & nhận đồ sạch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 12, color: Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text(
                      'Đã chụp',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Ảnh lấy đồ
          if (pickupUrls.isNotEmpty) ...[
            Text(
              'Ảnh niêm phong mã Seal khi lấy đồ:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0369A1),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pickupUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final imgUrl = formatFullUrl(pickupUrls[idx]);
                  return GestureDetector(
                    onTap: () => _openZoomProofImage(imgUrl),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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

          // 2. Ảnh giao đồ
          if (deliveryUrls.isNotEmpty) ...[
            Text(
              'Ảnh giao hàng hoàn tất (Khách nhận túi giặt sạch):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: deliveryUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final imgUrl = formatFullUrl(deliveryUrls[idx]);
                  return GestureDetector(
                    onTap: () => _openZoomProofImage(imgUrl),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
          ],
        ],
      ),
    );
  }

  void _openZoomProofImage(String imageUrl) {
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

  Widget _buildInsuranceSupportCard(Map<String, dynamic> order) {
    final id = order['id'] ?? order['Id'] ?? widget.orderId;
    final orderCode = 'WS3T-${id.toString().padLeft(4, '0')}';
    final sealCode = (order['sealCode'] ?? 'WS-SEAL-${id.toString().padLeft(4, '0')}').toString();
    final pickupProofPhotoUrl = (order['pickupProofPhotoUrl'] ?? '').toString();
    final deliveryProofPhotoUrl = (order['deliveryProofPhotoUrl'] ?? '').toString();
    final allProofs = [pickupProofPhotoUrl, deliveryProofPhotoUrl]
        .where((s) => s.trim().isNotEmpty)
        .join(',');
    final proofList = allProofs
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final weightKg = (order['weightKg'] is num) ? (order['weightKg'] as num).toDouble() : 2.5;
    final items = order['items'] is List
        ? (order['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final status = (order['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (order['paymentStatus'] ?? '').toString().toLowerCase();
    // 🚀 Chỉ khi đơn hàng hoàn thành hoặc thanh toán thành công mới được gửi khiếu nại
    final bool isPaidOrCompleted = status == 'completed' || paymentStatus == 'paid';
    bool isClaimExpired = false;
    int remainingMinutes = 60;
    final completionRaw = (order['updatedAt'] ?? order['paidAt'] ?? order['createdAt'])?.toString();
    if (completionRaw != null && completionRaw.isNotEmpty) {
      String cleanDate = completionRaw;
      if (!cleanDate.endsWith('Z') && !cleanDate.contains('+')) {
        cleanDate += 'Z';
      }
      final completionTime = DateTime.tryParse(cleanDate);
      if (completionTime != null) {
        final diff = DateTime.now().toUtc().difference(completionTime.toUtc());
        if (diff.inMinutes > 60) {
          isClaimExpired = true;
        } else {
          remainingMinutes = 60 - diff.inMinutes;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD1D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảo Hiểm 3T Care & Bồi Thường',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Mã Seal: $sealCode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Cam kết hoàn tiền 100% hoặc bồi thường trang phục nếu xảy ra sự cố vải sợi, phai màu hoặc thất lạc.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: secondaryText,
            ),
          ),
          if (proofList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ảnh chụp đồ & Niêm phong đối soát (${proofList.length} ảnh):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: proofList.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final rawUrl = proofList[idx];
                  final fullUrl = _formatFullUrl(rawUrl);
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              fullUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const ColoredBox(
                                color: Colors.white,
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Không tải được ảnh.'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (order['complaint'] != null)
            _buildSubmittedComplaintCard(Map<String, dynamic>.from(order['complaint'] as Map))
          else if (isPaidOrCompleted && !isClaimExpired)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubmitClaimScreen(
                        orderId: (id is num) ? id.toInt() : int.tryParse(id.toString()) ?? widget.orderId,
                        orderCode: orderCode,
                        orderWeight: weightKg,
                        items: items,
                      ),
                    ),
                  );
                  if (res == true) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.report_problem_outlined, size: 16, color: primary),
                label: Text(
                  'Gửi Khiếu Nại Đơn Hàng Này (Còn $remainingMinutes phút)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          else if (isPaidOrCompleted && isClaimExpired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_off_outlined, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã hết thời hạn khiếu nại (Quá 60 phút sau khi giao hàng thành công). Vui lòng liên hệ Hotline 1900 3T3T để được hỗ trợ.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD1D8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'cancelled'
                          ? 'Đơn hàng đã hủy, không thể gửi khiếu nại dịch vụ.'
                          : 'Khiếu nại & bồi thường chỉ khả dụng sau khi đơn hàng được giao và thanh toán thành công (trong 60 phút).',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
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

  Widget _buildSubmittedComplaintCard(Map<String, dynamic> complaint) {
    final ticketCode = (complaint['ticketCode'] ?? 'KN-WS3T').toString();
    final status = (complaint['status'] ?? 'Pending').toString();
    final isDone = status.toLowerCase() == 'completed';
    final incidentType = (complaint['incidentType'] ?? 'Sự cố đồ giặt').toString();
    final itemDesc = (complaint['itemDescription'] ?? '').toString();
    final photoRaw = (complaint['photoUrl'] ?? complaint['PhotoUrl'] ?? '').toString();
    final claimPhotos = photoRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? const Color(0xFF10B981) : primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
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
                  Icon(
                    isDone ? Icons.check_circle : Icons.pending_actions,
                    color: isDone ? const Color(0xFF059669) : primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hồ sơ #$ticketCode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDone ? 'Đã giải quyết bồi thường' : 'Đang xử lý tiếp nhận',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDone ? const Color(0xFF047857) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$incidentType: $itemDesc',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (claimPhotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ảnh minh chứng hàng hỏng tải từ di động (${claimPhotos.length} ảnh):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 65,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: claimPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final fullUrl = _formatFullUrl(claimPhotos[idx]);
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              fullUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Colors.white,
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Không tải được ảnh.'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullUrl,
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 65,
                          height: 65,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    if (items.isEmpty) {
      return _card(const Text('Đơn hàng chưa có chi tiết dịch vụ.'));
    }

    return _card(
      Column(
        children: items.map((rawItem) {
          if (rawItem is! Map) {
            return const SizedBox.shrink();
          }

          final item = Map<String, dynamic>.from(rawItem);
          final name = (item['serviceName'] ?? '').toString();
          final rawQty = item['quantity'] ?? item['Quantity'] ?? '';
          final unit = (item['unit'] ?? item['Unit'] ?? '').toString();
          final unitPrice = item['unitPrice'] ?? item['UnitPrice'];
          final totalPrice = item['totalPrice'] ?? item['TotalPrice'];

          final isKg = unit.toLowerCase().contains('kg') || unit.toLowerCase().contains('ký') || unit.toLowerCase().contains('kí');
          final num? numQty = rawQty is num ? rawQty : num.tryParse(rawQty.toString());
          final String displayQty = numQty != null
              ? (isKg ? numQty.toStringAsFixed(1) : numQty.round().toString())
              : rawQty.toString();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_laundry_service_outlined,
                  color: primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Dịch vụ' : name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Khối lượng/số lượng: $displayQty ${unit.isEmpty ? '' : unit}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đơn giá: ${_formatMoney(unitPrice)} / ${unit.isEmpty ? 'đơn vị' : unit}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: secondaryText,
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
                      'Thành tiền',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatMoney(totalPrice),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> order) {
    final pickup = (order['pickupAddress'] ?? '').toString();
    final delivery = (order['deliveryAddress'] ?? '').toString();
    final phone = (order['contactPhone'] ?? '').toString();
    final note = (order['note'] ?? '').toString();

    return _card(
      Column(
        children: [
          _infoRow(
            Icons.shopping_bag_outlined,
            'Địa chỉ lấy đồ',
            pickup.isEmpty ? 'Chưa có thông tin' : pickup,
          ),
          const Divider(height: 24),
          _infoRow(
            Icons.local_shipping_outlined,
            'Địa chỉ giao đồ',
            delivery.isEmpty ? 'Chưa có thông tin' : delivery,
          ),
          if (phone.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.phone_outlined, 'Số liên hệ', phone),
          ],
          if (note.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.notes_outlined, 'Ghi chú', note),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return _card(
        Text(
          'Chưa có lịch sử cập nhật trạng thái cho đơn hàng này.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: secondaryText,
          ),
        ),
      );
    }

    return _card(
      Column(
        children: List.generate(_history.length, (index) {
          final entry = _history[index];
          final status = (entry['status'] ?? '').toString();
          final note = (entry['note'] ?? '').toString();
          final changedAt = entry['changedAt'];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.check_circle, color: primary, size: 20),
                  if (index != _history.length - 1)
                    Container(
                      width: 2,
                      height: 42,
                      color: const Color(0xFFFFD9DC),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(status),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(changedAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
