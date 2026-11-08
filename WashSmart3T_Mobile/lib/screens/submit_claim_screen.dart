import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubmitClaimScreen extends StatefulWidget {
  const SubmitClaimScreen({super.key});

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

  // States quản lý dữ liệu khiếu nại
  bool _item1Selected = true;
  bool _item2Selected = false;

  int _selectedCategoryIndex =
      2; // 0: Lem màu, 1: Rách, 2: Vết bẩn chưa sạch, 3: Thất lạc, 4: Đồ ẩm
  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.palette_outlined, 'label': 'Lem màu / Phai màu'},
    {'icon': Icons.texture, 'label': 'Rách / Bung chỉ / Co rút'},
    {'icon': Icons.cleaning_services, 'label': 'Vết bẩn chưa sạch hoàn toàn'},
    {'icon': Icons.search_off, 'label': 'Thất lạc phụ kiện, nút áo'},
    {'icon': Icons.air, 'label': 'Đồ còn ẩm / Mùi lạ'},
  ];

  bool _hasProofPhoto = true;
  late TextEditingController _descController;
  int _selectedSolution =
      1; // 1: Giặt & tẩy hấp, 2: Hoàn tiền, 3: Yêu cầu đền bù
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(
      text:
          'Cổ áo sơ mi vẫn còn vết ố sậm màu ở viền trong nẹp cổ và có nếp gấp bị nhăn.',
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleSubmitClaim() {
    if (!_item1Selected && !_item2Selected) {
      _showToast('Vui lòng chọn ít nhất 1 món đồ bị sự cố!');
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showToast(
          'Đã tiếp nhận khiếu nại #WS3T-8892. Chuyên viên bảo hiểm sẽ phản hồi trong 15 phút!',
        );
        Navigator.pop(context);
      }
    });
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
              'Đơn hàng #WS3T-8892',
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
            icon: const Icon(
              Icons.support_agent,
              color: outlineColor,
              size: 22,
            ),
            onPressed: () =>
                _showToast('Đang kết nối tới bộ phận Bảo hiểm 3T Care...'),
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
            // 0. BẢO HIỂM 3T CARE HEADER CARD
            _buildInsuranceHeaderCard(),
            const SizedBox(height: 16),

            // 1. CHỌN MÓN ĐỒ BỊ SỰ CỐ
            _buildItemSelectionSection(),
            const SizedBox(height: 20),

            // 2. PHÂN LOẠI SỰ CỐ
            _buildCategoryChipsSection(),
            const SizedBox(height: 20),

            // 3. HÌNH ẢNH / VIDEO BẰNG CHỨNG
            _buildEvidenceMediaSection(),
            const SizedBox(height: 20),

            // 4. MÔ TẢ CHI TIẾT VẤN ĐỀ
            _buildProblemDescriptionSection(),
            const SizedBox(height: 20),

            // 5. PHƯƠNG ÁN GIẢI QUYẾT MONG MUỐN
            _buildSolutionOptionsSection(),
            const SizedBox(height: 16),

            // HOTLINE HỖ TRỢ GẤP
            _buildUrgentSupportBox(),
            const SizedBox(height: 80), // Khoảng trống cho nút Fixed Bottom
          ],
        ),
      ),

      // FIXED BOTTOM CTA BUTTON
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      color: primaryColor,
                      size: 14,
                    ),
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
                '16:30 Hôm nay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: outlineColor,
                ),
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
                    'Đơn hàng #WS3T-8892',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    'Khách hàng: Chị Kiều Như',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: outlineColor,
                    ),
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
                  '#SEAL-3T-8892',
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: outlineColor,
                      ),
                      children: [
                        TextSpan(
                          text: 'Cam kết bảo hiểm: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const TextSpan(
                          text:
                              'Đền bù lên đến 100% giá trị trang phục hoặc giặt sấy lại miễn phí trong 24h.',
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Item 1
        _buildSelectableItemCard(
          title: '01 Áo sơ mi công sở cao cấp',
          subtitle: 'Vải lụa cát • Treo móc chống nhăn',
          tag: 'Ủi hơi nước',
          imageUrl:
              'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?q=80&w=200&auto=format&fit=crop',
          isSelected: _item1Selected,
          onTap: () => setState(() => _item1Selected = !_item1Selected),
        ),
        const SizedBox(height: 8),

        // Item 2
        _buildSelectableItemCard(
          title: 'Giặt sấy thông thường (5.0 kg)',
          subtitle: 'Quần áo thường ngày • Hương hoa hồng...',
          tag: 'Tiêu chuẩn',
          imageUrl:
              'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?q=80&w=200&auto=format&fit=crop',
          isSelected: _item2Selected,
          onTap: () => setState(() => _item2Selected = !_item2Selected),
        ),
      ],
    );
  }

  Widget _buildSelectableItemCard({
    required String title,
    required String subtitle,
    required String tag,
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
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
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
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
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: outlineColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: outlineColor,
              ),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.transparent,
                ),
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
              _hasProofPhoto ? '1 / 5 hình' : '0 / 5 hình',
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
          'Chụp rõ nét vết bẩn kèm tem seal niêm phong để hệ thống AI thẩm định tự động trong 15 phút.',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_hasProofPhoto) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=200&auto=format&fit=crop',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ảnh 1: Cổ áo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _hasProofPhoto = false),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(0xFFBA1A1A),
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],

            // Button Chụp ảnh
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasProofPhoto = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: surfaceLow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chụp ảnh',
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
            const SizedBox(width: 10),

            // Button Thêm video
            Expanded(
              child: InkWell(
                onTap: () =>
                    _showToast('Tính năng quay video bằng chứng đang được mở'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: outlineColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thêm video',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: outlineColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              TextField(
                controller: _descController,
                maxLength: 300,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: onSurface,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Vui lòng mô tả cụ thể vị trí vết bẩn, dấu hiệu hư tổn...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: outlineColor,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (text) => setState(() {}),
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        color: tertiaryColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gợi ý: Chỉ rõ vị trí trái/phải, loại vết bẩn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: tertiaryColor,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      _descController.clear();
                      setState(() {});
                    },
                    child: const Icon(
                      Icons.clear,
                      color: outlineColor,
                      size: 16,
                    ),
                  ),
                ],
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

        // Option 1
        _buildSolutionRadioCard(
          value: 1,
          title: 'Giặt & tẩy hấp phục hồi miễn phí',
          badge: 'Khuyên dùng',
          subtitle:
              'Giao nhận tận nơi lại ngay trong vòng 24h. Được xử lý bởi chuyên viên bậc cao 3T.',
        ),
        const SizedBox(height: 8),

        // Option 2
        _buildSolutionRadioCard(
          value: 2,
          title: 'Hoàn tiền dịch vụ giặt ủi',
          subtitle:
              'Cộng tiền ngay vào Ví WashSmart 3T hoặc chuyển khoản ngân hàng trong 2h.',
        ),
        const SizedBox(height: 8),

        // Option 3
        _buildSolutionRadioCard(
          value: 3,
          title: 'Yêu cầu đền bù thiệt hại bảo hiểm',
          subtitle:
              'Áp dụng nếu trang phục bị hỏng cấu trúc vải, mất phụ kiện không thể phục hồi.',
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? cardBg : surfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<int>(
              value: value,
              groupValue: _selectedSolution,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _selectedSolution = val!),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      if (badge != null) ...[
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
                            badge,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
    );
  }

  // --- URGENT SUPPORT BOX ---
  Widget _buildUrgentSupportBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_support_outlined,
                color: secondaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cần trợ giúp gấp 24/7?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    'Hotline ưu tiên tiếp nhận bảo hiểm',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: outlineColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () =>
                _showToast('Đang gọi Hotline ưu tiên Bảo hiểm: 1900 3388'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cardBg,
              foregroundColor: primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.call, size: 14),
            label: Text(
              '1900 3388',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
