import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceRatingScreen extends StatefulWidget {
  const ServiceRatingScreen({super.key});

  @override
  State<ServiceRatingScreen> createState() => _ServiceRatingScreenState();
}

class _ServiceRatingScreenState extends State<ServiceRatingScreen> {
  // Bảng màu thiết kế chuẩn WashSmart 3T
  static const Color primaryColor = Color(0xFFB90538);
  static const Color secondaryColor = Color(0xFFB4136D);
  static const Color tertiaryColor = Color(0xFF006577);
  static const Color bgSurface = Color(0xFFFFF8F7);
  static const Color cardBg = Colors.white;
  static const Color surfaceLow = Color(0xFFFFF0F0);
  static const Color surfaceHigh = Color(0xFFFFE1E3);
  static const Color onSurface = Color(0xFF370C14);
  static const Color outlineColor = Color(0xFF8F6F71);
  static const Color starYellow = Color(0xFFF59E0B);

  // States tương tác
  int _rating = 5;
  final Set<int> _selectedAspects = {0, 1, 2}; // Khởi tạo chọn 3 chip đầu tiên
  final List<String> _aspects = [
    '✨ Quần áo thơm lâu, phẳng phiu',
    '⏱️ Giao nhận đúng giờ hẹn',
    '🏷️ Tem Seal niêm phong nguyên vẹn',
    '🧼 Sạch vết bẩn ở cổ áo',
    '🧺 Gấp nếp vuông vức',
  ];

  late TextEditingController _reviewController;
  final List<String> _uploadedPhotos = [
    'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?q=80&w=200&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?q=80&w=200&auto=format&fit=crop',
  ];

  bool _isAnonymous = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(
      text:
          'Áo sơ mi giặt ủi rất phẳng phiu và thơm mùi hoa cúc dịu nhẹ, vết ố cổ áo đã được xử lý sạch sẽ. Shipper Nam giao nhanh và rất lịch sự. Sẽ tiếp tục ủng hộ 3T ạ!',
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars, color: Color(0xFF4CD7F6), size: 18),
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

  void _handleSubmitReview() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showToast(
          'Cảm ơn bạn! +50 Xu 3T & Voucher 20.000đ đã được cộng vào ví.',
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  String _getRatingText() {
    switch (_rating) {
      case 5:
        return 'Tuyệt vời! Rất hài lòng 🥰';
      case 4:
        return 'Hài lòng 😁';
      case 3:
        return 'Bình thường 🙂';
      case 2:
        return 'Tạm ổn 😐';
      case 1:
        return 'Cần cải thiện 😞';
      default:
        return '';
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
              'Đánh Giá Dịch Vụ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              'Đơn hàng #WS3T-8892',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: outlineColor, size: 22),
            onPressed: () => _showToast(
              'Bạn có thể đánh giá trong vòng 7 ngày kể từ khi nhận đồ.',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: outlineColor, size: 22),
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
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
            // 1. CELEBRATION & ORDER INFO CARD
            _buildCelebrationCard(),
            const SizedBox(height: 12),

            // 2. OVERALL STAR RATING
            _buildStarRatingCard(),
            const SizedBox(height: 16),

            // 3. ASPECT CHIPS
            _buildAspectChipsSection(),
            const SizedBox(height: 16),

            // 4. REVIEW TEXT & PHOTO UPLOAD CARD
            _buildReviewTextAndPhotosCard(),
            const SizedBox(height: 16),

            // 5. ANONYMOUS TOGGLE CARD
            _buildAnonymousToggleCard(),
            const SizedBox(height: 20),

            // 6. BOTTOM ACTION BUTTON
            _buildSubmitButtonSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- 1. CELEBRATION CARD ---
  Widget _buildCelebrationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_laundry_service,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: tertiaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Đã giao thành công • 16:30',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: tertiaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bạn hài lòng với lần giặt này chứ?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      '01 Áo sơ mi cao cấp + Giặt sấy 4.8kg',
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
          const SizedBox(height: 10),

          // Reward Pill
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: surfaceLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.redeem,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: onSurface,
                      ),
                      children: [
                        const TextSpan(text: 'Đánh giá nhận ngay '),
                        TextSpan(
                          text: '+50 Xu 3T',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const TextSpan(text: ' & Voucher giảm '),
                        TextSpan(
                          text: '20.000đ',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
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

  // --- 2. OVERALL STAR RATING CARD ---
  Widget _buildStarRatingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Chất lượng dịch vụ tổng thể',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: outlineColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Group 5 Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    size: 38,
                    color: starYellow,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Tag kết quả đánh giá
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRatingText(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. ASPECT CHIPS SECTION ---
  Widget _buildAspectChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Điểm làm bạn ưng ý nhất?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_aspects.length, (index) {
            final isSelected = _selectedAspects.contains(index);
            return ChoiceChip(
              label: Text(_aspects[index]),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : outlineColor,
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
                setState(() {
                  if (selected) {
                    _selectedAspects.add(index);
                  } else {
                    _selectedAspects.remove(index);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  // --- 4. REVIEW TEXT & PHOTOS CARD ---
  Widget _buildReviewTextAndPhotosCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
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
              Text(
                'Nhận xét chi tiết',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              Text(
                '${_reviewController.text.length}/500',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: outlineColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Textarea
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 500,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Chia sẻ trải nghiệm sử dụng dịch vụ của bạn...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: outlineColor,
                ),
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (text) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),

          // Uploaded Photos List
          Text(
            'Hình ảnh thực tế từ bạn (${_uploadedPhotos.length}/5)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: outlineColor,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._uploadedPhotos.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _uploadedPhotos.remove(url));
                            },
                            child: const CircleAvatar(
                              radius: 9,
                              backgroundColor: Color(0x99000000),
                              child: Icon(
                                Icons.close,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Button Thêm ảnh
                InkWell(
                  onTap: () {
                    if (_uploadedPhotos.length < 5) {
                      setState(() {
                        _uploadedPhotos.add(
                          'https://images.unsplash.com/photo-1545173168-9f1947eebb7f?q=80&w=200&auto=format&fit=crop',
                        );
                      });
                    } else {
                      _showToast('Chỉ cho phép tải lên tối đa 5 hình ảnh.');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Thêm ảnh',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
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

  // --- 5. ANONYMOUS TOGGLE CARD ---
  Widget _buildAnonymousToggleCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đánh giá ẩn danh',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              Text(
                'Ẩn họ tên "Kiều Như" khi hiển thị trên cộng đồng',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: outlineColor,
                ),
              ),
            ],
          ),
          Switch(
            value: _isAnonymous,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _isAnonymous = val),
          ),
        ],
      ),
    );
  }

  // --- 6. SUBMIT BUTTON SECTION ---
  Widget _buildSubmitButtonSection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 4,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.stars, color: Colors.white, size: 22),
            label: Text(
              'Gửi Đánh Giá & Nhận Ưu Đãi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cảm ơn bạn đã đồng hành cùng WashSmart 3T!',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: outlineColor),
        ),
      ],
    );
  }
}
