import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/booking_step1_screen.dart';
import 'screens/booking_step2_screen.dart';
import 'screens/booking_step3_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shipper_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/submit_claim_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartWashApp());
}

class SmartWashApp extends StatelessWidget {
  const SmartWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WashSmart 3T',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB90538)),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

/// Restores the logged-in user's screen on app startup/browser refresh.
/// Also supports ?screen= query parameter for opening multiple browser tabs (Shipper vs Khách).
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Widget> _destination = _restoreSession();

  Future<Widget> _restoreSession() async {
    final screenParam = Uri.base.queryParameters['screen']?.toLowerCase().trim();

    // 🚀 Hỗ trợ mở tab Shipper độc lập & tự đăng nhập shipper demo
    if (screenParam == 'shipper') {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        try {
          final res = await http.post(
            Uri.parse('http://localhost:5085/api/Auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': '0922222222', 'password': '123456'}),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            await AuthService.saveSession(token: data['token'], role: 'shipper');
          }
        } catch (_) {}
      }
      return const ShipperScreen();
    }

    if (screenParam == 'home' || screenParam == 'customer') return const HomeScreen();
    if (screenParam == 'step1') return const BookingStep1Screen();
    if (screenParam == 'step2') {
      return const BookingStep2Screen(
        items: [
          {'serviceId': 1, 'quantity': 2.0}
        ],
      );
    }
    if (screenParam == 'step3') {
      return const BookingStep3Screen(
        pickupAddress: 'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Quận 1',
        deliveryAddress: 'Căn 302, 128 Hai Bà Trưng, P. Bến Nghé, Quận 1',
        contactPhone: '0908 123 456',
        pickupTime: '08:00 – 10:00 (Sáng) • Hôm nay',
        deliveryTime: '10:00 – 12:00 Ngày mai (Chuẩn 24h)',
        expressFee: 0,
        items: [
          {'serviceId': 1, 'quantity': 2.0}
        ],
      );
    }
    if (screenParam == 'claim') {
      return const SubmitClaimScreen(
        orderCode: 'WS3T-0019',
        orderWeight: 2.5,
      );
    }

    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      return const SplashScreen();
    }

    final role = await AuthService.getRole();
    switch (role) {
      case 'shipper':
        return const ShipperScreen();
      case 'customer':
      case 'admin':
      case 'staff':
        return const HomeScreen();
      default:
        return const SplashScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const SplashScreen();
      },
    );
  }
}
