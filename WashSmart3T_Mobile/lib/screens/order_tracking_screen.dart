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

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Thời gian không hợp lệ';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderSummary(order, status),
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
          const SizedBox(height: 16),
          _buildSectionTitle('Lịch sử trạng thái'),
          const SizedBox(height: 10),
          _buildHistoryCard(),
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

  Widget _buildInsuranceSupportCard(Map<String, dynamic> order) {
    final id = order['id'] ?? order['Id'] ?? widget.orderId;
    final orderCode = 'WS3T-${id.toString().padLeft(4, '0')}';
    final sealCode = (order['sealCode'] ?? 'WS-SEAL-${id.toString().padLeft(4, '0')}').toString();
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
          const SizedBox(height: 12),
          if (isPaidOrCompleted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubmitClaimScreen(
                        orderId: (id is num) ? (id as num).toInt() : int.tryParse(id.toString()) ?? widget.orderId,
                        orderCode: orderCode,
                        orderWeight: weightKg,
                        items: items,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.report_problem_outlined, size: 16, color: primary),
                label: Text(
                  'Gửi Khiếu Nại Đơn Hàng Này',
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
                          : 'Khiếu nại & bồi thường chỉ khả dụng sau khi đơn hàng được giao và thanh toán thành công.',
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
          final quantity = item['quantity'] ?? item['Quantity'] ?? '';
          final unit = (item['unit'] ?? item['Unit'] ?? '').toString();
          final unitPrice = item['unitPrice'] ?? item['UnitPrice'];
          final totalPrice = item['totalPrice'] ?? item['TotalPrice'];

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
                        'Khối lượng/số lượng: $quantity ${unit.isEmpty ? '' : unit}',
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
