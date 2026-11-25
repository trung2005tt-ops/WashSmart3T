import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialIdentifier;

  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isResetting = false;
  bool _otpSent = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _maskedEmail;
  String? _statusMessage;
  int _resendSeconds = 0;
  Timer? _timer;

  static const Color primaryColor = Color(0xFFA6002E);
  static const Color surfaceBg = Color(0xFFFFF8F7);
  static const Color inputBg = Color(0xFFFDEEEE);

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
      _identifierController.text = widget.initialIdentifier!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnack('Vui lòng nhập Email hoặc Số điện thoại tài khoản.', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await ApiService.sendForgotPasswordOtp(identifier: identifier);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _maskedEmail = res['maskedEmail']?.toString();
        _statusMessage = res['message']?.toString();
      });
      _startCooldown(60);
      _showSnack(res['message']?.toString() ?? 'Mã OTP đã được gửi về email của bạn!');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _resetPassword() async {
    final identifier = _identifierController.text.trim();
    final otpCode = _otpController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otpCode.length != 6) {
      _showSnack('Vui lòng nhập đầy đủ mã OTP 6 chữ số từ Email.', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('Mật khẩu mới phải có ít nhất 6 ký tự.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('Xác nhận mật khẩu mới chưa khớp.', isError: true);
      return;
    }

    setState(() => _isResetting = true);
    try {
      final res = await ApiService.resetPassword(
        identifier: identifier,
        otpCode: otpCode,
        newPassword: newPass,
      );
      if (!mounted) return;
      _showSnack(res['message']?.toString() ?? 'Đặt lại mật khẩu thành công!');
      Navigator.pop(context, identifier);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        backgroundColor: isError ? const Color(0xFFB3261E) : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quên mật khẩu',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B1718),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF3DADA)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khôi phục mật khẩu',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2B1718),
                              ),
                            ),
                            Text(
                              'Hệ thống sẽ gửi mã OTP 6 số về Email đã đăng ký của bạn.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF6E5556),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Bước 1: Nhập Email hoặc Số điện thoại
                  Text(
                    'Email hoặc Số điện thoại tài khoản',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2B1718),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _identifierController,
                    enabled: !_otpSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Nhập SĐT (VD: 0818...) hoặc Email',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black38),
                      prefixIcon: const Icon(Icons.alternate_email, color: primaryColor, size: 20),
                      filled: true,
                      fillColor: _otpSent ? const Color(0xFFF5F5F5) : inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (!_otpSent)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSendingOtp ? null : _sendOtp,
                        icon: _isSendingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.mark_email_read_outlined, size: 20),
                        label: Text(
                          _isSendingOtp ? 'Đang gửi mã OTP...' : 'Gửi mã OTP về Email',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),

                  if (_otpSent) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_unread_rounded, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusMessage ??
                                  'Mã OTP đã được gửi tới email ${_maskedEmail ?? ''}. Vui lòng kiểm tra hộp thư đến hoặc mục Spam.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF065F46),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã xác thực OTP (6 số)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2B1718),
                          ),
                        ),
                        TextButton(
                          onPressed: (_resendSeconds > 0 || _isSendingOtp) ? null : _sendOtp,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                          child: Text(
                            _resendSeconds > 0 ? 'Gửi lại sau ${_resendSeconds}s' : 'Gửi lại mã OTP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _resendSeconds > 0 ? Colors.grey : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • • • •',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, letterSpacing: 6, color: Colors.black26),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Mật khẩu mới',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B1718),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Ít nhất 6 ký tự',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black38),
                        prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.black45),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Xác nhận mật khẩu mới',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B1718),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Nhập lại mật khẩu mới',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black38),
                        prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.black45),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isResetting ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: _isResetting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Xác nhận đặt lại mật khẩu',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
