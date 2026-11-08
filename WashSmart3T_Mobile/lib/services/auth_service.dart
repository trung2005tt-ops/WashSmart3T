import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String tokenKey = 'jwt_token';
  static const String roleKey = 'user_role';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<void> saveSession({
    required String token,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(roleKey, role.trim().toLowerCase());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString(roleKey);
    if (savedRole != null && savedRole.trim().isNotEmpty) {
      return savedRole.trim().toLowerCase();
    }

    // Backward compatibility: recover role from an existing JWT session.
    final token = prefs.getString(tokenKey);
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
    } catch (_) {
      // If the token cannot be decoded, let the auth gate ask the user to log in.
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(roleKey);
  }
}
