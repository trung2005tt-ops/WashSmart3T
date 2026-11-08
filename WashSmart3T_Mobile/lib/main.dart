import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/shipper_screen.dart';
import 'screens/splash_screen.dart';
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
      title: 'Smart Wash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9F1239)),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

/// Restores the logged-in user's screen on app startup/browser refresh.
/// AuthService uses SharedPreferences, which persists across Flutter Web reloads.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Widget> _destination = _restoreSession();

  Future<Widget> _restoreSession() async {
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
        // A legacy token without a readable role should not lock the app.
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
