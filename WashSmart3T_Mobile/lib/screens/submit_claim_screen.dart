import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class SubmitClaimScreen extends StatefulWidget {
  final String orderCode;
  final int? orderId;
  final double orderWeight;
  final List<Map<String, dynamic>>? items;

  const SubmitClaimScreen({
    super.key,
    this.orderCode = 'WS3T-8892',
    this.orderId,
    this.orderWeight = 2.5,
    this.items,
  });

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  // Bảng màu thiết kế chuẩn WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color primaryContainer = Color(0xFFDC2C4F);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);

  // States quản lý dữ liệu đơn hàng thực tế
  bool _isLoadingOrder = false;
  String _orderCode = 'WS3T-8892';
  String _customerName = 'Khách hàng 3T';
  String _customerPhone = '';
  String _sealCode = 'WS-SEAL-8892';
  String _drumInfo = 'Lồng giặt sấy thông minh LG Turbo #02';
  String _shipperName = 'Lê Minh Hoàng (0922222222)';
  double _orderWeight = 2.5;
  double _orderTotalAmount = 0;

  // Danh sách các món đồ thực tế của đơn hàng
  List<Map<String, dynamic>> _itemSelections = [];

  int _selectedCategoryIndex = 2; // 0: Lem màu, 1: Rách, 2: Vết bẩn chưa sạch, 3: Thất lạc, 4: Đồ ẩm
  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.palette_outlined, 'label': 'Lem màu / Phai màu'},
    {'icon': Icons.texture, 'label': 'Rách / Bung chỉ / Co rút'},
    {'icon': Icons.cleaning_services, 'label': 'Vết bẩn chưa sạch hoàn toàn'},
    {'icon': Icons.search_off, 'label': 'Thất lạc phụ kiện, nút áo'},
    {'icon': Icons.air, 'label': 'Đồ còn ẩm / Mùi lạ'},
  ];

  final List<String> _proofPhotos = [
    'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=200&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?q=80&w=200&auto=format&fit=crop',
  ];

  late TextEditingController _descController;
  late TextEditingController _refundAmountController;
  int _selectedSolution = 1; // 1: Giặt lại miễn phí, 2: Hoàn tiền, 3: Bồi thường sản phẩm, 4: Tặng Voucher / Xu
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderCode = widget.orderCode;
    _orderWeight = widget.orderWeight;
    _descController = TextEditingController(
      text: 'Món đồ có sự cố sau khi nhận từ shipper, nhờ xưởng kiểm tra hỗ trợ xử lý thỏa đáng.',
    );
    _refundAmountController = TextEditingController(text: '150000');
    _loadOrderData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _refundAmountController.dispose();
    super.dispose();
  }

  String _formatCurrency(dynamic amount) {
    final num val = amount is num ? amount : (num.tryParse(amount?.toString() ?? '0') ?? 0);
    return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  Future<void> _loadOrderData() async {
    // 1. Nếu có items truyền từ màn trước
    if (widget.items != null && widget.items!.isNotEmpty) {
      _itemSelections = widget.items!.map((it) {
        final sName = (it['serviceName'] ?? it['name'] ?? 'Dịch vụ giặt sấy').toString();
        final qty = it['quantity'] ?? 1;
        final unit = (it['unit'] ?? 'món').toString();
        final price = it['unitPrice'] ?? it['price'] ?? 0;
        return {
          'title': '$qty $unit $sName',
          'subtitle': 'Đơn giá: ${_formatCurrency(price)} / $unit',
          'tag': sName,
          'isSelected': true,
        };
      }).toList();
    }

    // 2. Nếu có orderId, tải trực tiếp dữ liệu đơn hàng thật từ Backend
    if (widget.orderId != null && widget.orderId! > 0) {
      setState(() => _isLoadingOrder = true);
      try {
        final order = await ApiService.getOrderDetail(widget.orderId!);
        if (!mounted) return;

        setState(() {
          _orderCode = 'WS3T-${widget.orderId.toString().padLeft(4, '0')}';
          _customerName = (order['customerName'] ?? '').toString();
          if (_customerName.isEmpty) _customerName = 'Khách hàng 3T';
          _customerPhone = (order['customerPhone'] ?? order['contactPhone'] ?? '').toString();
          _sealCode = (order['sealCode'] ?? 'WS-SEAL-${widget.orderId.toString().padLeft(4, '0')}').toString();
          _drumInfo = (order['drumInfo'] ?? 'Lồng giặt sấy thông minh LG Turbo #02').toString();
          _shipperName = (order['shipperName'] ?? 'Shipper giao nhận WashSmart 3T').toString();

          if (order['weightKg'] is num) {
            _orderWeight = (order['weightKg'] as num).toDouble();
          }
          if (order['totalAmount'] is num) {
            _orderTotalAmount = (order['totalAmount'] as num).toDouble();
          }

          if (_itemSelections.isEmpty) {
            final rawItems = order['items'];
            if (rawItems is List && rawItems.isNotEmpty) {
              _itemSelections = rawItems.map((raw) {
                final it = Map<String, dynamic>.from(raw as Map);
                final sName = (it['serviceName'] ?? it['name'] ?? 'Dịch vụ giặt').toString();
                final qty = it['quantity'] ?? 1;
                final unit = (it['unit'] ?? 'món').toString();
                final price = it['unitPrice'] ?? it['price'] ?? 0;
                return {
                  'title': '$qty $unit $sName',
                  'subtitle': 'Đơn giá: ${_formatCurrency(price)} / $unit',
                  'tag': sName,
                  'isSelected': true,
                };
              }).toList();
            }
          }
          _isLoadingOrder = false;
        });
      } catch (e) {
        if (mounted) setState(() => _isLoadingOrder = false);
      }
    }

    // Fallback nếu không có item nào
    if (_itemSelections.isEmpty) {
      setState(() {
        _itemSelections = [
          {
            'title': 'Dịch vụ giặt sấy theo đơn #$_orderCode',
            'subtitle': 'Khối lượng: ${_orderWeight.toStringAsFixed(1)} kg',
            'tag': 'Tiêu chuẩn',
            'isSelected': true,
          }
        ];
      });
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF4CD7F6), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF512128),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSubmitClaim() async {
    final selectedItems = _itemSelections.where((x) => x['isSelected'] == true).toList();
    if (selectedItems.isEmpty) {
      _showToast('Vui lòng chọn ít nhất 1 món đồ bị sự cố!');
      return;
    }

    final categoryLabel = _categories[_selectedCategoryIndex]['label'] as String? ?? 'Sự cố đồ giặt';
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      _showToast('Vui lòng nhập mô tả chi tiết sự cố đồ giặt!');
      return;
    }

    final selectedNames = selectedItems.map((e) => e['title']).join('; ');
    final fullItemDesc = '$selectedNames. $desc';

    double refundAmount = 0;
    String solutionText = 'Giặt & phục hồi miễn phí';
    if (_selectedSolution == 2) {
      solutionText = 'Hoàn tiền dịch vụ giặt';
      refundAmount = _orderTotalAmount > 0 ? _orderTotalAmount : 115000;
    } else if (_selectedSolution == 3) {
      solutionText = 'Bồi thường giá trị sản phẩm';
      refundAmount = double.tryParse(_refundAmountController.text.replaceAll('.', '').trim()) ?? 50000;
    } else if (_selectedSolution == 4) {
      solutionText = 'Tặng Voucher đền bù / Cộng 3T Xu vào ví';
      refundAmount = 50000;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await ApiService.createComplaint(
        orderId: widget.orderId,
        incidentType: categoryLabel,
        itemDescription: fullItemDesc,
        severity: _selectedCategoryIndex == 1 ? 'High' : 'Medium',
        photoUrl: _proofPhotos.isNotEmpty ? _proofPhotos.first : null,
        customerNote: 'Phương án mong muốn: $solutionText. Ghi chú khách: $desc',
        requestedRefund: refundAmount,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        final ticket = res['complaint'];
        final ticketCode = ticket is Map ? (ticket['ticketCode'] ?? ticket['ticket_code'] ?? 'KN-WS3T') : 'KN-WS3T';
        _showToast('Đã tiếp nhận hồ sơ #$ticketCode thành công! Chuyên viên bảo hiểm 3T Care sẽ phản hồi trong 15 phút.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showToast('Lỗi gửi khiếu nại: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface.withOpacity(0.85),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: onSurface, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gửi Khiếu Nại & Bồi Thường',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              'Đơn hàng #$_orderCode',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: outlineColor, size: 22),
            onPressed: () => _showToast('Đang kết nối tới bộ phận Bảo hiểm 3T Care...'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: _isLoadingOrder
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInsuranceHeaderCard(),
                  const SizedBox(height: 16),
                  _buildItemSelectionSection(),
                  const SizedBox(height: 20),
                  _buildCategoryChipsSection(),
                  const SizedBox(height: 20),
                  _buildEvidenceMediaSection(),
                  const SizedBox(height: 20),
                  _buildProblemDescriptionSection(),
                  const SizedBox(height: 20),
                  _buildSolutionOptionsSection(),
                  const SizedBox(height: 16),
                  _buildUrgentSupportBox(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgSurface.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmitClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 4,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.shield, color: Colors.white, size: 20),
              label: Text(
                'Gửi khiếu nại & Yêu cầu xử lý',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 0. INSURANCE HEADER CARD ---
  Widget _buildInsuranceHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: primaryColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'BẢO HIỂM 3T CARE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Thời gian: Hôm nay',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn hàng #$_orderCode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    'Khách hàng: $_customerName',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$_sealCode',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                      children: [
                        TextSpan(
                          text: 'Cam kết bảo hiểm: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const TextSpan(
                          text: 'Đền bù lên đến 100% giá trị trang phục hoặc giặt sấy lại miễn phí trong 24h.',
                        ),
                      ],
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

  // --- 1. ITEM SELECTION SECTION ---
  Widget _buildItemSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '1. Chọn món đồ bị sự cố',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            Text(
              'Chọn ít nhất 1 món',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._itemSelections.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isSelected = item['isSelected'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  item['isSelected'] = !isSelected;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? cardBg : surfaceLow.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: surfaceLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item['tag'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- 2. CATEGORY CHIPS SECTION ---
  Widget _buildCategoryChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '2. Phân loại sự cố',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            Text(
              'Chọn loại lỗi',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_categories.length, (index) {
            final cat = _categories[index];
            final bool isSelected = _selectedCategoryIndex == index;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : onSurface,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? primaryColor : Colors.transparent),
              ),
              showCheckmark: false,
              onSelected: (bool selected) {
                if (selected) setState(() => _selectedCategoryIndex = index);
              },
            );
          }),
        ),
      ],
    );
  }

  // --- 3. EVIDENCE MEDIA SECTION ---
  Widget _buildEvidenceMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '3. Hình ảnh / Video bằng chứng',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '${_proofPhotos.length} / 5 hình',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Chụp rõ nét vết bẩn kèm tem seal niêm phong để đối soát minh bạch với xưởng giặt.',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(_proofPhotos.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _proofPhotos[idx],
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ảnh ${idx + 1}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _proofPhotos.removeAt(idx)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFFBA1A1A),
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_proofPhotos.length < 5)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: InkWell(
                    onTap: () {
                      final dummyPhotos = [
                        'https://images.unsplash.com/photo-1545127398-14699f92334b?q=80&w=200&auto=format&fit=crop',
                        'https://images.unsplash.com/photo-1567113463300-102570d935b4?q=80&w=200&auto=format&fit=crop',
                        'https://images.unsplash.com/photo-1574634534894-89d7576c8259?q=80&w=200&auto=format&fit=crop',
                      ];
                      final nextPhoto = dummyPhotos[_proofPhotos.length % dummyPhotos.length];
                      setState(() => _proofPhotos.add(nextPhoto));
                      _showToast('Đã thêm ảnh bằng chứng #${_proofPhotos.length}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: surfaceLow, shape: BoxShape.circle),
                            child: const Icon(Icons.photo_camera_outlined, color: primaryColor, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+ Thêm ảnh',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
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
      ],
    );
  }

  // --- 4. PROBLEM DESCRIPTION SECTION ---
  Widget _buildProblemDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '4. Mô tả chi tiết vấn đề',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '${_descController.text.length}/300 ký tự',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              TextField(
                controller: _descController,
                maxLength: 300,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: onSurface),
                decoration: InputDecoration(
                  hintText: 'Vui lòng mô tả cụ thể vị trí vết bẩn, dấu hiệu hư tổn...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (text) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 5. SOLUTION OPTIONS SECTION ---
  Widget _buildSolutionOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 16,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '5. Phương án giải quyết mong muốn',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Option 1: Giặt lại
        _buildSolutionRadioCard(
          value: 1,
          title: 'Giặt & tẩy hấp phục hồi miễn phí',
          badge: 'Khuyên dùng',
          subtitle: 'Giao nhận tận nơi lại ngay trong vòng 24h. Được xử lý bởi chuyên viên bậc cao 3T.',
        ),
        const SizedBox(height: 8),

        // Option 2: Hoàn tiền dịch vụ
        _buildSolutionRadioCard(
          value: 2,
          title: 'Hoàn tiền cước dịch vụ giặt',
          subtitle: 'Hoàn lại 100% tiền dịch vụ về tài khoản ngân hàng hoặc ví điểm thưởng.',
        ),
        const SizedBox(height: 8),

        // Option 3: Bồi thường sản phẩm
        _buildSolutionRadioCard(
          value: 3,
          title: 'Yêu cầu bồi thường giá trị sản phẩm',
          subtitle: 'Áp dụng theo cam kết bảo hiểm chất lượng 3T Care khi đồ bị hỏng sợi, co rút.',
        ),
        if (_selectedSolution == 3) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(
                  'Số tiền mong muốn:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _refundAmountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      suffixText: 'VNĐ',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Option 4: Tặng Voucher / Xu đền bù
        _buildSolutionRadioCard(
          value: 4,
          title: 'Tặng Voucher đền bù / Cộng 3T Xu vào ví',
          subtitle: 'Nhận ngay Voucher 100.000đ hoặc 10.000 Xu để sử dụng cho các lần giặt tới.',
        ),
      ],
    );
  }

  Widget _buildSolutionRadioCard({
    required int value,
    required String title,
    String? badge,
    required String subtitle,
  }) {
    final bool isSelected = _selectedSolution == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSolution = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? cardBg : surfaceLow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<int>(
              value: value,
              groupValue: _selectedSolution,
              activeColor: primaryColor,
              onChanged: (val) {
                if (val != null) setState(() => _selectedSolution = val);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD9E4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- URGENT SUPPORT BOX ---
  Widget _buildUrgentSupportBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD1D8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hotline Bảo Hiểm 3T Care: 1900 6868',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                Text(
                  'Hỗ trợ thẩm định và đối soát IoT trực tiếp 24/7',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
