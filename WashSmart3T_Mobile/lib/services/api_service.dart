import 'dart:convert';
import 'auth_service.dart';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5085/api';

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Đăng nhập thất bại');
  }

  static Future<Map<String, dynamic>> sendRegistrationOtp({
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/send-registration-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'purpose': 'Register',
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gửi OTP thất bại');
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String otpCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'password': password,
        'otpCode': otpCode,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Đăng ký thất bại');
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/Auth/me'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập hết hạn.');
    }

    if (response.statusCode != 200) {
      throw Exception('Không tải được thông tin tài khoản.');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getMyOrders() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/Orders/my-orders'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Không tải được danh sách đơn hàng.');
    }

    final data = jsonDecode(response.body) as List;

    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getServices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/Services'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Không tải được danh sách dịch vụ.');
    }

    final data = jsonDecode(response.body) as List;

    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/Orders/$orderId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Không tải được chi tiết đơn (${response.statusCode}).');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> getOrderHistory(int orderId) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/Orders/$orderId/history'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Không tải được lịch sử đơn (${response.statusCode}).');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  /// Lấy danh sách đơn hàng dành cho Admin/Staff.
  /// Endpoint đã được xác nhận qua Swagger.
  static Future<List<Map<String, dynamic>>> getManagementOrders() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/Orders/management'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được đơn quản lý (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as List;

    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Phân công shipper cho đơn hàng.
  static Future<Map<String, dynamic>> assignShipper({
    required int orderId,
    required int shipperId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/Orders/$orderId/assign-shipper'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'shipperId': shipperId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map
            ? (data['message'] ?? 'Phân công shipper thất bại').toString()
            : 'Phân công shipper thất bại',
      );
    }

    return Map<String, dynamic>.from(data as Map);
  }

  /// Tạo đơn hàng mới từ ứng dụng khách hàng.
  /// Quantity = 0 nghĩa là khách chưa cân/đếm; shipper sẽ nhập số liệu thực tế.
  static Future<Map<String, dynamic>> createOrder({
    required String pickupAddress,
    required String deliveryAddress,
    required String contactPhone,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập để đặt đơn.');
    }
    if (items.isEmpty) {
      throw Exception('Vui lòng chọn ít nhất một dịch vụ.');
    }

    final payload = <String, dynamic>{
      'pickupAddress': pickupAddress.trim(),
      'deliveryAddress': deliveryAddress.trim(),
      'contactPhone': contactPhone.trim(),
      'note': note?.trim(),
      'items': items
          .map(
            (item) => <String, dynamic>{
              'serviceId': item['serviceId'],
              // Không tự đoán khối lượng/số lượng. Shipper cập nhật sau khi nhận đồ.
              'quantity': item['quantity'] ?? 0,
            },
          )
          .toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/Orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['title'] ?? 'Đặt đơn thất bại')
                .toString()
          : 'Đặt đơn thất bại (${response.statusCode}).';
      throw Exception(message);
    }

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'result': decoded};
  }

  /// Cập nhật trạng thái đơn hàng.
  static Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
    String? note,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/Orders/$orderId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map
            ? (data['message'] ?? 'Cập nhật trạng thái thất bại').toString()
            : 'Cập nhật trạng thái thất bại',
      );
    }

    return Map<String, dynamic>.from(data as Map);
  }

  /// Gửi khiếu nại bảo hiểm 3T Care lên Backend API
  static Future<Map<String, dynamic>> createComplaint({
    int? orderId,
    required String incidentType,
    required String itemDescription,
    String? severity,
    String? photoUrl,
    String? customerNote,
    double? requestedRefund,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final payload = <String, dynamic>{
      if (orderId != null && orderId > 0) 'orderId': orderId,
      'incidentType': incidentType,
      'itemDescription': itemDescription,
      'severity': severity ?? 'Medium',
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (customerNote != null && customerNote.isNotEmpty) 'customerNote': customerNote,
      if (requestedRefund != null && requestedRefund > 0) 'requestedRefund': requestedRefund,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/Complaints'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map
            ? (data['message'] ?? 'Gửi khiếu nại thất bại').toString()
            : 'Gửi khiếu nại thất bại',
      );
    }

    return Map<String, dynamic>.from(data as Map);
  }

  /// Lấy thông tin mã VietQR chuẩn EMVCo khóa theo mã đơn hàng
  static Future<Map<String, dynamic>> getVietQr(int orderId) async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('$baseUrl/Payments/vietqr/$orderId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Không tải được mã VietQR cho đơn #$orderId');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  /// Xác nhận giao hàng kèm ảnh minh chứng thực tế
  static Future<Map<String, dynamic>> uploadDeliveryProof({
    required int orderId,
    required String proofPhotoUrl,
    String? note,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/Orders/$orderId/delivery-proof'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'proofPhotoUrl': proofPhotoUrl,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map
            ? (data['message'] ?? 'Xác nhận giao hàng thất bại').toString()
            : 'Xác nhận giao hàng thất bại',
      );
    }

    return Map<String, dynamic>.from(data as Map);
  }
}
