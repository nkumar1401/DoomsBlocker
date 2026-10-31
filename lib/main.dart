import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_setup_screen.dart';
import 'services/native_bridge.dart';
import 'services/notification_update_service.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationUpdateService.instance.initialize();
  await AuthService().init();
  await SubscriptionService().init();

  // Set system UI overlay style to clean bright silver-white
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
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
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        primaryColor: const Color(0xFF06B6D4),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF3B82F6),
          surface: Colors.white,
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
        backgroundColor: Color(0xFFF8FAFC),
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
