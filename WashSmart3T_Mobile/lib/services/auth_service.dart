import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage_stub.dart'
    if (dart.library.html) 'session_storage_web.dart';

class AuthService {
  static const String tokenKey = 'jwt_token_secure';
  static const String legacyTokenKey = 'jwt_token';
  static const String roleKey = 'user_role';
  static const String fullNameKey = 'user_fullname';
  static const String phoneKey = 'user_phone';
  static const String addressKey = 'user_address';
  static const String emailKey = 'user_email';
  static const String userIdKey = 'user_id';

  static Future<void> _setString(String key, String value) async {
    if (kIsWeb) {
      TabSessionStorage.setItem(key, value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> _getString(String key) async {
    if (kIsWeb) {
      return TabSessionStorage.getItem(key);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> _setInt(String key, int value) async {
    if (kIsWeb) {
      TabSessionStorage.setItem(key, value.toString());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  static Future<int?> _getInt(String key) async {
    if (kIsWeb) {
      final raw = TabSessionStorage.getItem(key);
      return raw == null ? null : int.tryParse(raw);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  static Future<void> _remove(String key) async {
    if (kIsWeb) {
      TabSessionStorage.removeItem(key);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

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
    await _setString(tokenKey, _obfuscate(token));
    await _remove(legacyTokenKey);
  }

  static Future<void> saveSession({
    required String token,
    required String role,
    String? fullName,
    String? phone,
    String? address,
    String? email,
    int? userId,
  }) async {
    await _setString(tokenKey, _obfuscate(token));
    await _remove(legacyTokenKey);
    await _setString(roleKey, role.trim().toLowerCase());
    if (fullName != null && fullName.isNotEmpty) {
      await _setString(fullNameKey, fullName.trim());
    }
    if (phone != null && phone.isNotEmpty) {
      await _setString(phoneKey, phone.trim());
    }
    if (address != null && address.isNotEmpty) {
      await _setString(addressKey, address.trim());
    }
    if (email != null && email.isNotEmpty) {
      await _setString(emailKey, email.trim());
    }
    if (userId != null) {
      await _setInt(userIdKey, userId);
    }
  }

  static Future<void> saveUserProfile({
    String? fullName,
    String? phone,
    String? address,
    String? email,
    int? userId,
  }) async {
    if (fullName != null && fullName.isNotEmpty) {
      await _setString(fullNameKey, fullName.trim());
    }
    if (phone != null && phone.isNotEmpty) {
      await _setString(phoneKey, phone.trim());
    }
    if (address != null && address.isNotEmpty) {
      await _setString(addressKey, address.trim());
    }
    if (email != null && email.isNotEmpty) {
      await _setString(emailKey, email.trim());
    }
    if (userId != null) {
      await _setInt(userIdKey, userId);
    }
  }

  static Future<String?> getFullName() => _getString(fullNameKey);

  static Future<String?> getPhone() => _getString(phoneKey);

  static Future<String?> getAddress() => _getString(addressKey);

  static Future<String?> getEmail() => _getString(emailKey);

  static Future<int?> getUserId() => _getInt(userIdKey);

  static Future<String?> getToken() async {
    final enc = await _getString(tokenKey);
    if (enc != null && enc.isNotEmpty) {
      return _deobfuscate(enc);
    }
    // Hỗ trợ phiên cũ trước khi mã hóa
    final legacy = await _getString(legacyTokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      // Nâng cấp lên dạng mã hóa
      await _setString(tokenKey, _obfuscate(legacy));
      await _remove(legacyTokenKey);
      return legacy;
    }
    return null;
  }

  static Future<String?> getRole() async {
    final savedRole = await _getString(roleKey);
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
          await _setString(roleKey, role);
          return role;
        }
        if (value is List && value.isNotEmpty) {
          final role = value.first.toString().trim().toLowerCase();
          if (role.isNotEmpty) {
            await _setString(roleKey, role);
            return role;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    await _remove(tokenKey);
    await _remove(legacyTokenKey);
    await _remove(roleKey);
    await _remove(fullNameKey);
    await _remove(phoneKey);
    await _remove(addressKey);
    await _remove(emailKey);
    await _remove(userIdKey);
  }
}
