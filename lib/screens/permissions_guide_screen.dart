import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class PermissionsGuideScreen extends StatefulWidget {
  const PermissionsGuideScreen({Key? key}) : super(key: key);

  @override
  State<PermissionsGuideScreen> createState() => _PermissionsGuideScreenState();
}

class _PermissionsGuideScreenState extends State<PermissionsGuideScreen> with WidgetsBindingObserver {
  Map<String, bool> _permissions = {
    'accessibility': false,
    'overlay': false,
    'usageStats': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    final perms = await NativeBridge.checkPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = (_permissions['accessibility'] ?? false) &&
        (_permissions['overlay'] ?? false) &&
        (_permissions['usageStats'] ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('System Permissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Status Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: allGranted
                        ? const Color(0xFF065F46).withOpacity(0.4)
                        : const Color(0xFF78350F).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: allGranted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allGranted ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: allGranted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allGranted ? 'All Permissions Granted!' : 'Permissions Incomplete',
                              style: TextStyle(
                                color: allGranted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              allGranted
                                  ? 'DoomsBlocker is fully equipped to detect Shorts, games, and lock apps.'
                                  : 'Please grant the missing permissions below to enable screen monitoring.',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Android 13/14 Restricted Settings Guide Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Android 13 / 14 / 15 'Restricted Setting'?",
                            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "If Accessibility is grayed out on your phone:\n"
                        "1. Open Phone Settings → Apps → DoomsBlocker\n"
                        "2. Tap the 3 dots in the top right corner\n"
                        "3. Tap 'Allow restricted settings' and confirm your PIN\n"
                        "4. Return here and tap 'Enable in Settings' below.",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 1. Accessibility Service Permission
                _buildPermissionCard(
                  icon: Icons.accessibility_new_rounded,
                  title: '1. Accessibility Service',
                  description:
                      'Allows DoomsBlocker to detect when YouTube Shorts starts scrolling and inspect channel names to block restricted channels.',
                  isGranted: _permissions['accessibility'] ?? false,
                  actionLabel: 'Enable in Settings',
                  onTap: () => NativeBridge.openAccessibilitySettings(),
                ),

                const SizedBox(height: 14),

                // 2. Display Over Other Apps (Overlay)
                _buildPermissionCard(
                  icon: Icons.layers_outlined,
                  title: '2. Display Over Other Apps',
                  description:
                      'Allows DoomsBlocker to display the fullscreen lock countdown over YouTube and games when limits are reached.',
                  isGranted: _permissions['overlay'] ?? false,
                  actionLabel: 'Allow Overlay',
                  onTap: () => NativeBridge.openOverlaySettings(),
                ),

                const SizedBox(height: 14),

                // 3. Usage Stats Access
                _buildPermissionCard(
                  icon: Icons.bar_chart_rounded,
                  title: '3. Usage Access (Screen Time)',
                  description:
                      'Allows DoomsBlocker to measure exact minutes spent inside marked games and YouTube apps.',
                  isGranted: _permissions['usageStats'] ?? false,
                  actionLabel: 'Grant Access',
                  onTap: () => NativeBridge.openUsageStatsSettings(),
                ),
              ],
            ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFFEF4444).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGranted ? 'GRANTED' : 'MISSING',
                  style: TextStyle(
                    color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
