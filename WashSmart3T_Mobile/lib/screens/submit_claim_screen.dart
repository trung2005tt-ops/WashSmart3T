import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
  static const Color secondaryColor = Color(0xFFB4136D);
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

  // 📸 Ảnh bằng chứng tải lên từ di động / camera (Bắt đầu rỗng, không dùng ảnh mẫu giả lập)
  final List<Map<String, dynamic>> _proofPhotoItems = [];
  bool _isUploadingPhoto = false;

  List<String> get _proofPhotos => _proofPhotoItems
      .map((e) => (e['url'] ?? '').toString())
      .where((u) => u.isNotEmpty)
      .toList();

  // ⏱️ Giới hạn 60 phút sau khi giao hàng thành công
  bool _isClaimExpired = false;
  int _remainingMinutes = 60;
  String? _expiredMessage;

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

          // ⏱️ Kiểm tra thời hạn 60 phút sau khi giao hàng thành công
          final completionRaw = (order['updatedAt'] ?? order['paidAt'] ?? order['createdAt'])?.toString();
          if (completionRaw != null && completionRaw.isNotEmpty) {
            String cleanDate = completionRaw;
            if (!cleanDate.endsWith('Z') && !cleanDate.contains('+')) {
              cleanDate += 'Z';
            }
            final completionTime = DateTime.tryParse(cleanDate);
            if (completionTime != null) {
              final diff = DateTime.now().toUtc().difference(completionTime.toUtc());
              final mins = diff.inMinutes;
              if (mins > 60) {
                _isClaimExpired = true;
                _expiredMessage = 'Đơn hàng đã giao thành công được $mins phút. Thời hạn tiếp nhận khiếu nại trực tuyến tối đa là 60 phút kể từ lúc nhận đồ (để đối soát seal niêm phong). Quý khách vui lòng liên hệ Hotline 1900 3T3T (0818.605.505) để được hỗ trợ đặc cách.';
              } else {
                _isClaimExpired = false;
                _remainingMinutes = 60 - mins;
              }
            }
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

  Future<String?> _uploadSinglePhoto(Uint8List bytes, String fileName) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('http://localhost:5085/api/Uploads'));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      var safeName = fileName.isNotEmpty ? fileName : 'claim_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (!safeName.contains('.')) {
        safeName += '.jpg';
      }
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
      debugPrint('Lỗi tải ảnh khiếu nại: $e');
      return null;
    }
  }

  Future<void> _pickAndUploadPhoto({required ImageSource source}) async {
    if (_proofPhotoItems.length >= 5) {
      _showToast('Bạn chỉ có thể tải lên tối đa 5 hình ảnh bằng chứng.');
      return;
    }
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      final tempItem = <String, dynamic>{
        'bytes': bytes,
        'url': '',
        'name': xfile.name,
        'isUploading': true,
      };

      setState(() {
        _proofPhotoItems.add(tempItem);
        _isUploadingPhoto = true;
      });
      _showToast('Đang tải ảnh chụp thực tế lên máy chủ...');

      final uploadedUrl = await _uploadSinglePhoto(bytes, xfile.name);

      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          tempItem['url'] = uploadedUrl;
          tempItem['isUploading'] = false;
        } else {
          _proofPhotoItems.remove(tempItem);
        }
      });

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        _showToast('Tải ảnh bằng chứng #${_proofPhotoItems.length} thành công!');
      } else {
        _showToast('Không tải được ảnh lên máy chủ. Vui lòng thử lại!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showToast('Lỗi chọn ảnh: $e');
      }
    }
  }

  void _showPickPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thêm ảnh bằng chứng sự cố',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chụp rõ tem seal niêm phong hoặc vết bẩn/hỏng vải trên trang phục',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: primaryColor),
                ),
                title: Text(
                  'Chụp ảnh bằng Camera',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Mở máy ảnh chụp trực tiếp sản phẩm',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF0284C7)),
                ),
                title: Text(
                  'Chọn ảnh từ Thiết bị / Thư viện',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Chọn hình ảnh đã chụp sẵn trong máy',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmitClaim() async {
    if (_isClaimExpired) {
      _showToast(_expiredMessage ?? 'Đã hết thời hạn 60 phút khiếu nại kể từ lúc giao hàng thành công.');
      return;
    }

    final selectedItems = _itemSelections.where((x) => x['isSelected'] == true).toList();
    if (selectedItems.isEmpty) {
      _showToast('Vui lòng chọn ít nhất 1 món đồ bị sự cố!');
      return;
    }

    if (_proofPhotos.isEmpty) {
      _showToast('Vui lòng chụp hoặc tải lên ít nhất 1 ảnh bằng chứng để đối soát!');
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
        photoUrl: _proofPhotos.join(','),
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
                  const SizedBox(height: 12),
                  _buildTimeLimitBanner(),
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
              onPressed: (_isSubmitting || _isClaimExpired) ? null : _handleSubmitClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClaimExpired ? Colors.grey.shade400 : primaryColor,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: _isClaimExpired ? 0 : 4,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(_isClaimExpired ? Icons.timer_off_outlined : Icons.shield, color: Colors.white, size: 20),
              label: Text(
                _isClaimExpired ? 'Đã quá hạn khiếu nại (60 phút)' : 'Gửi khiếu nại & Yêu cầu xử lý',
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

  // --- 0. TIME LIMIT BANNER ---
  Widget _buildTimeLimitBanner() {
    if (_isClaimExpired) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timer_off_outlined, color: Colors.red, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ĐÃ HẾT HẠN KHIẾU NẠI TRỰC TUYẾN (60 PHÚT)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _expiredMessage ??
                        'Đơn hàng đã hoàn tất vượt quá 60 phút. Quy chuẩn đối soát niêm phong chỉ áp dụng trong vòng 60 phút sau khi shipper bàn giao. Quý khách vui lòng liên hệ Hotline 1900 3T3T (0818.605.505) để được hỗ trợ đặc cách.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.red.shade800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF059669), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF065F46)),
                children: [
                  const TextSpan(text: 'Thời hạn tiếp nhận khiếu nại 3T Care: '),
                  TextSpan(
                    text: 'Còn $_remainingMinutes phút ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                  const TextSpan(text: '(Chỉ áp dụng trong vòng 60 phút sau khi shipper giao hàng hoàn tất).'),
                ],
              ),
            ),
          ),
        ],
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
                    'Khách hàng: $_customerName${_customerPhone.isNotEmpty ? ' ($_customerPhone)' : ''}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: outlineColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Shipper: $_shipperName • $_drumInfo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: outlineColor),
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
        ..._itemSelections.map((item) {
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
              '${_proofPhotoItems.length} / 5 hình',
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
              ...List.generate(_proofPhotoItems.length, (idx) {
                final item = _proofPhotoItems[idx];
                final Uint8List? bytes = item['bytes'] as Uint8List?;
                final String url = (item['url'] ?? '').toString();
                final bool isUploading = item['isUploading'] == true;
                final fullUrl = url.startsWith('http')
                    ? url
                    : 'http://localhost:5085${url.startsWith('/') ? url : '/$url'}';

                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: bytes != null
                            ? Image.memory(
                                bytes,
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                fullUrl,
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: 85,
                                    height: 85,
                                    color: surfaceLow,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  width: 85,
                                  height: 85,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                      ),
                      if (isUploading)
                        Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ảnh ${idx + 1}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _proofPhotoItems.removeAt(idx)),
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
              if (_isUploadingPhoto)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      color: surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đang tải...',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_proofPhotoItems.length < 5 && !_isUploadingPhoto)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: InkWell(
                    onTap: _showPickPhotoSourceSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
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
