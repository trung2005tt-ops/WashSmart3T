import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String tokenKey = 'jwt_token_secure';
  static const String legacyTokenKey = 'jwt_token';
  static const String roleKey = 'user_role';

  // Khóa xor chống trích xuất plaintext từ bộ nhớ SharedPreferences
  static const int _obfKey = 0x5A;

  static String _obfuscate(String plain) {
    final bytes = utf8.encode(plain);
    final masked = bytes.map((b) => b ^ _obfKey).toList();
    return base64Url.encode(masked);
  }

  static String _deobfuscate(String encoded) {
    try {
      final bytes = base64Url.decode(encoded);
      final unmasked = bytes.map((b) => b ^ _obfKey).toList();
      return utf8.decode(unmasked);
    } catch (_) {
      return encoded;
    }
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, _obfuscate(token));
    await prefs.remove(legacyTokenKey);
  }

  static Future<void> saveSession({
    required String token,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, _obfuscate(token));
    await prefs.remove(legacyTokenKey);
    await prefs.setString(roleKey, role.trim().toLowerCase());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final enc = prefs.getString(tokenKey);
    if (enc != null && enc.isNotEmpty) {
      return _deobfuscate(enc);
    }
    // Hỗ trợ phiên cũ trước khi mã hóa
    final legacy = prefs.getString(legacyTokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      // Nâng cấp lên dạng mã hóa
      await prefs.setString(tokenKey, _obfuscate(legacy));
      await prefs.remove(legacyTokenKey);
      return legacy;
    }
    return null;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString(roleKey);
    if (savedRole != null && savedRole.trim().isNotEmpty) {
      return savedRole.trim().toLowerCase();
    }

    // Phục hồi role từ token nếu thiếu
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return null;

      const roleKeys = <String>[
        'role',
        'roles',
        'userRole',
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
      ];
      for (final key in roleKeys) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          final role = value.trim().toLowerCase();
          await prefs.setString(roleKey, role);
          return role;
        }
        if (value is List && value.isNotEmpty) {
          final role = value.first.toString().trim().toLowerCase();
          if (role.isNotEmpty) {
            await prefs.setString(roleKey, role);
            return role;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(legacyTokenKey);
    await prefs.remove(roleKey);
  }
}
