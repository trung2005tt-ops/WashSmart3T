// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Lưu trữ phiên đăng nhập theo từng tab trình duyệt (sessionStorage) trên Web.
class TabSessionStorage {
  static String? getItem(String key) => html.window.sessionStorage[key];

  static void setItem(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  static void removeItem(String key) {
    html.window.sessionStorage.remove(key);
  }
}
