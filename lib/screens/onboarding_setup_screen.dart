import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../widgets/pin_dialog.dart';
import 'dashboard_screen.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isPinSet = false;
  Map<String, bool> _permissions = {
    'accessibility': false,
    'overlay': false,
    'usageStats': false,
  };
  String _manufacturer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final isPin = await NativeBridge.isPinSet();
    final perms = await NativeBridge.checkPermissions();
    final mfg = await NativeBridge.getDeviceManufacturer();

    if (mounted) {
      setState(() {
        _isPinSet = isPin;
        _permissions = perms;
        _manufacturer = mfg.toLowerCase();
        _isLoading = false;
      });
    }
  }

  bool get _allPermissionsGranted =>
      (_permissions['accessibility'] ?? false) &&
      (_permissions['overlay'] ?? false) &&
      (_permissions['usageStats'] ?? false);

  bool get _isReady => _isPinSet && _allPermissionsGranted;

  bool get _isAggressiveOem =>
      _manufacturer.contains('xiaomi') ||
      _manufacturer.contains('redmi') ||
      _manufacturer.contains('poco') ||
      _manufacturer.contains('samsung') ||
      _manufacturer.contains('vivo') ||
      _manufacturer.contains('oppo') ||
      _manufacturer.contains('realme');

  Future<void> _handleSetPin() async {
    final pin = await PinDialog.showAndGetPin(
      context,
      title: 'Create Security PIN',
      description: 'Enter a 4-digit PIN for emergency unlocks and settings protection.',
      isCreatingPin: true,
    );

    if (pin != null && pin.length == 4) {
      await NativeBridge.setPin(pin);
      await _refreshStatus();
    }
  }

  void _proceedToDashboard() {
    if (!_isReady) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // App Icon & Header
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Welcome to DoomsBlocker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Complete initial setup to protect your screen time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // STEP 1: Security PIN Setup
                  _buildSectionHeader('STEP 1: CREATE EMERGENCY PIN'),
                  const SizedBox(height: 10),
                  _buildCard(
                    icon: _isPinSet ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    iconColor: _isPinSet ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    title: _isPinSet ? 'Security PIN Configured' : 'Set 4-Digit Security PIN',
                    subtitle: _isPinSet
                        ? 'Your emergency PIN is active and secure.'
                        : 'Required upfront so you can never get locked out.',
                    actionButton: TextButton(
                      onPressed: _handleSetPin,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        backgroundColor: _isPinSet
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFFF59E0B).withOpacity(0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _isPinSet ? 'CHANGE' : 'CREATE PIN',
                        style: TextStyle(
                          color: _isPinSet ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // STEP 2: Core Permissions
                  _buildSectionHeader('STEP 2: GRANT ESSENTIAL PERMISSIONS'),
                  const SizedBox(height: 10),

                  // 1. Accessibility Service
                  _buildCard(
                    icon: (_permissions['accessibility'] ?? false)
                        ? Icons.check_circle_rounded
                        : Icons.accessibility_new_rounded,
                    iconColor: (_permissions['accessibility'] ?? false)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF06B6D4),
                    title: 'Accessibility Service',
                    subtitle: 'Detects YouTube Shorts and blocks doomscrolling.',
                    actionButton: _buildPermissionButton(
                      isGranted: _permissions['accessibility'] ?? false,
                      onTap: () => NativeBridge.openAccessibilitySettings(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. Display Over Other Apps
                  _buildCard(
                    icon: (_permissions['overlay'] ?? false)
                        ? Icons.check_circle_rounded
                        : Icons.layers_rounded,
                    iconColor: (_permissions['overlay'] ?? false)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF06B6D4),
                    title: 'Display Over Other Apps',
                    subtitle: 'Allows showing the smooth 5-second countdown lock overlay.',
                    actionButton: _buildPermissionButton(
                      isGranted: _permissions['overlay'] ?? false,
                      onTap: () => NativeBridge.openOverlaySettings(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. Usage Stats
                  _buildCard(
                    icon: (_permissions['usageStats'] ?? false)
                        ? Icons.check_circle_rounded
                        : Icons.bar_chart_rounded,
                    iconColor: (_permissions['usageStats'] ?? false)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF06B6D4),
                    title: 'Usage Access',
                    subtitle: 'Measures screen time limits for games and social apps.',
                    actionButton: _buildPermissionButton(
                      isGranted: _permissions['usageStats'] ?? false,
                      onTap: () => NativeBridge.openUsageStatsSettings(),
                    ),
                  ),

                  // Optional OEM Background Setup
                  if (_isAggressiveOem) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('STEP 3 (OPTIONAL): OEM BACKGROUND SETUP'),
                    const SizedBox(height: 10),
                    _buildCard(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      title: 'Autostart & Battery Optimization',
                      subtitle: 'Allow autostart for 100% reliable lock screens on $_manufacturer.',
                      actionButton: TextButton(
                        onPressed: () => NativeBridge.openBatteryOptimizationSettings(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          backgroundColor: const Color(0xFF38BDF8).withOpacity(0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'OPEN',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Bottom CTA Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.95),
                border: const Border(
                  top: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isReady ? _proceedToDashboard : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReady ? const Color(0xFF06B6D4) : const Color(0xFF334155),
                    disabledBackgroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: _isReady ? 6 : 0,
                  ),
                  child: Text(
                    _isReady ? 'CONTINUE TO DASHBOARD' : 'COMPLETE STEPS ABOVE TO CONTINUE',
                    style: TextStyle(
                      color: _isReady ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          actionButton,
        ],
      ),
    );
  }

  Widget _buildPermissionButton({
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    if (isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Color(0xFF10B981), size: 14),
            SizedBox(width: 4),
            Text(
              'ACTIVE',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: const Color(0xFF06B6D4).withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'GRANT',
        style: TextStyle(
          color: Color(0xFF06B6D4),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
