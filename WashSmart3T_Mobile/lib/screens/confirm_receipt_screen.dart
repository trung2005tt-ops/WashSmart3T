import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'submit_claim_screen.dart'; // 🚀 Import màn hình Gửi Khiếu Nại
import 'service_rating_screen.dart'; // 🚀 Import màn hình Đánh Giá Dịch Vụ

class ConfirmReceiptScreen extends StatefulWidget {
  const ConfirmReceiptScreen({super.key});

  @override
  State<ConfirmReceiptScreen> createState() => _ConfirmReceiptScreenState();
}

class _ConfirmReceiptScreenState extends State<ConfirmReceiptScreen> {
  // Bảng màu thiết kế chuẩn Brand Tokens WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // States quản lý tương tác
  bool _item1Checked = true;
  bool _item2Checked = true;
  String _selectedFeedback = 'satisfied'; // 'satisfied' hoặc 'issue'

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
                  fontSize: 12,
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

  // 🚀 Chuyển hướng sang Màn hình Đánh giá dịch vụ (ServiceRatingScreen)
  void _handleFinishOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServiceRatingScreen()),
    );
  }

  // 🚀 Chuyển hướng sang Màn hình Gửi khiếu nại (SubmitClaimScreen)
  void _handleClaim() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubmitClaimScreen()),
    );
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
        title: Text(
          'Xác Nhận Đã Nhận Hàng',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.support_agent,
              color: primaryColor,
              size: 22,
            ),
            onPressed: () => _showToast('Hotline hỗ trợ khẩn cấp: 1900 3388'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER TRẠNG THÁI GIAO HÀNG HOÀN TẤT
            _buildDeliveryStatusBanner(),
            const SizedBox(height: 12),

            // 2. THẺ SHIPPER & ẢNH ĐỐI SOÁT SEAL
            _buildShipperAndProofSection(),
            const SizedBox(height: 16),

            // 3. DANH SÁCH MÓN ĐỒ CẦN KIỂM TRA
            _buildChecklistSection(),
            const SizedBox(height: 16),

            // 4. KHUNG ĐÁNH GIÁ NHANH (PHÂN NHÁNH TRẢI NGHIỆM)
            _buildQuickAssessmentSection(),
            const SizedBox(height: 16),

            // 5. NÚT HÀNH ĐỘNG DỰA THEO LỰA CHỌN
            _buildActionButtons(),
            const SizedBox(height: 20),

            // 6. CAM KẾT VÀ BẢO HIỂM FOOTER
            _buildGuaranteeFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- 1. DELIVERY STATUS BANNER ---
  Widget _buildDeliveryStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GIAO HÀNG HOÀN TẤT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '16:30 • Hôm nay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: outlineColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Shipper đã giao đồ tới bạn!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                Text(
                  'Đơn hàng #WS3T-8892 • Chị Kiều Như',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: outlineColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SHIPPER & PROOF OF DELIVERY CARD ---
  Widget _buildShipperAndProofSection() {
    return Column(
      children: [
        // Thông tin Shipper
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: surfaceLow,
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Nguyễn Văn Nam',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '3T Fleet',
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
                        'Biển số: 59P1-882.19 • Giao tận cửa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: outlineColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: surfaceHigh,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.phone_in_talk,
                    size: 18,
                    color: primaryColor,
                  ),
                  onPressed: () => _showToast(
                    'Đang gọi tài xế Nguyễn Văn Nam: 0901 234 567',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Ảnh chụp đối soát trước cửa & Mã Seal
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: cardBg,
            child: Column(
              children: [
                Stack(
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1545173168-9f1947eebb7f?q=80&w=800&auto=format&fit=crop',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified,
                                  color: Color(0xFF4CD7F6),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ảnh đối soát lúc 16:29',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#SEAL-3T-8892',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: surfaceLow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_open,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Khách tự tay tháo seal & kiểm đếm',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Chuẩn 3T An Tâm',
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
          ),
        ),
      ],
    );
  }

  // --- 3. CHECKLIST GARMENT BREAKDOWN ---
  Widget _buildChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kiểm tra món đồ đã nhận',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              '2 danh mục',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Item 1
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_laundry_service,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giặt sấy thơm tho (Hàng ngày)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            'Khối lượng: 5.0 kg • Hương hoa hồng Pháp',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _item1Checked,
                        activeColor: primaryColor,
                        onChanged: (val) =>
                            setState(() => _item1Checked = val!),
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
                        child: Text(
                          'Đủ số lượng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tertiaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16, color: surfaceLow),

              // Item 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.checkroom,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '03 Áo sơ mi ủi hơi nước',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            'Treo móc bọc màng PE chống bụi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _item2Checked,
                        activeColor: primaryColor,
                        onChanged: (val) =>
                            setState(() => _item2Checked = val!),
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
                        child: Text(
                          'Phẳng phiu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tertiaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. QUICK ASSESSMENT SECTION ---
  Widget _buildQuickAssessmentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'ĐÁNH GIÁ NHANH',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Bạn thấy quần áo nhận được thế nào?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Option 1: Hài lòng
          GestureDetector(
            onTap: () => setState(() => _selectedFeedback = 'satisfied'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFeedback == 'satisfied'
                      ? primaryColor
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'satisfied',
                    groupValue: _selectedFeedback,
                    activeColor: primaryColor,
                    onChanged: (val) =>
                        setState(() => _selectedFeedback = val!),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_very_satisfied,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đồ sạch thơm, đúng & đủ món',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          'Không có hư tổn, hài lòng tuyệt đối',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFeedback == 'satisfied')
                    const Icon(
                      Icons.check_circle,
                      color: primaryColor,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Option 2: Gặp sự cố
          GestureDetector(
            onTap: () => setState(() => _selectedFeedback = 'issue'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFeedback == 'issue'
                      ? errorColor
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'issue',
                    groupValue: _selectedFeedback,
                    activeColor: errorColor,
                    onChanged: (val) =>
                        setState(() => _selectedFeedback = val!),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.report_problem,
                      color: errorColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gặp sự cố với đồ giặt',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          'Lem màu, sờn rách, thiếu đồ hoặc ẩm mốc',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: outlineColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. ACTION BUTTONS BASED ON SELECTION ---
  Widget _buildActionButtons() {
    if (_selectedFeedback == 'satisfied') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              // 🚀 Chuyển sang Màn hình Đánh giá dịch vụ ServiceRatingScreen
              onPressed: _handleFinishOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.stars, color: Colors.white, size: 20),
              label: Text(
                'Đã nhận đủ & Đánh giá 5 sao',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedFeedback = 'issue'),
              style: TextButton.styleFrom(
                backgroundColor: surfaceLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.warning, color: primaryColor, size: 16),
              label: Text(
                'Đồ có vấn đề? Gửi khiếu nại bảo hiểm',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: errorContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: errorColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bảo hiểm trang phục WashSmart 3T',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: errorColor,
                        ),
                      ),
                      Text(
                        'Bồi thường lên tới 100% giá trị đồ nếu xảy ra co rút, lem màu hoặc thất lạc. Tiếp nhận phản hồi trong 30 phút.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: outlineColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              // 🚀 Chuyển sang Màn hình Gửi khiếu nại SubmitClaimScreen
              onPressed: _handleClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              icon: const Icon(
                Icons.notification_important,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Gửi khiếu nại & Yêu cầu bồi hoàn',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _selectedFeedback = 'satisfied'),
            child: Text(
              'Quay lại kiểm tra đồ lần nữa',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
            ),
          ),
        ],
      );
    }
  }

  // --- 6. GUARANTEE FOOTER ---
  Widget _buildGuaranteeFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 16, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                'CAM KẾT 3T: TẬN TÂM - TINH TƯƠM - TIỆN LỢI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Thời hạn tiếp nhận đối soát là 24h kể từ thời điểm mở seal niêm phong. Cần hỗ trợ khẩn cấp?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: outlineColor,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showToast('Đang gọi CSKH WashSmart 3T: 1900 3388'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.call, size: 14, color: primaryColor),
                const SizedBox(width: 4),
                Text(
                  'Hotline CSKH: 1900 3388 (24/7)',
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
    );
  }
}
