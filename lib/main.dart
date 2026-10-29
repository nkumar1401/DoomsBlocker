import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_setup_screen.dart';
import 'services/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to dark
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const DoomsBlockerApp());
}

class DoomsBlockerApp extends StatelessWidget {
  const DoomsBlockerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoomsBlocker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFFEF4444),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEF4444),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
        ),
        fontFamily: 'Roboto',
      ),
      home: const AppGatewayScreen(),
    );
  }
}

class AppGatewayScreen extends StatefulWidget {
  const AppGatewayScreen({Key? key}) : super(key: key);

  @override
  State<AppGatewayScreen> createState() => _AppGatewayScreenState();
}

class _AppGatewayScreenState extends State<AppGatewayScreen> {
  bool _isLoading = true;
  bool _needsSetup = true;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final isPinSet = await NativeBridge.isPinSet();
    final perms = await NativeBridge.checkPermissions();
    final allPerms = (perms['accessibility'] ?? false) &&
                     (perms['overlay'] ?? false) &&
                     (perms['usageStats'] ?? false);

    if (mounted) {
      setState(() {
        _needsSetup = !isPinSet || !allPerms;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
        ),
      );
    }

    if (_needsSetup) {
      return const OnboardingSetupScreen();
    }

    return const DashboardScreen();
  }
}

