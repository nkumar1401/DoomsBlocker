import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class AccessibilityGuideDialog extends StatefulWidget {
  final String manufacturer;

  const AccessibilityGuideDialog({
    Key? key,
    this.manufacturer = '',
  }) : super(key: key);

  static Future<void> show(BuildContext context, {String manufacturer = ''}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccessibilityGuideDialog(manufacturer: manufacturer),
    );
  }

  @override
  State<AccessibilityGuideDialog> createState() => _AccessibilityGuideDialogState();
}

class _AccessibilityGuideDialogState extends State<AccessibilityGuideDialog> {
  int _selectedBrandIndex = 0;

  @override
  void initState() {
    super.initState();
    final mfg = widget.manufacturer.toLowerCase();
    if (mfg.contains('samsung')) {
      _selectedBrandIndex = 0;
    } else if (mfg.contains('xiaomi') || mfg.contains('redmi') || mfg.contains('poco')) {
      _selectedBrandIndex = 1;
    } else if (mfg.contains('vivo') || mfg.contains('oppo') || mfg.contains('realme') || mfg.contains('oneplus')) {
      _selectedBrandIndex = 2;
    } else {
      _selectedBrandIndex = 3; // Other / Stock Android
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.accessibility_new_rounded, color: Color(0xFF06B6D4), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Enable Accessibility Service',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Required to detect Shorts and block doomscrolling',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Sequence Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepPill('1', 'Settings'),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
                  _buildStepPill('2', 'Downloaded Apps'),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
                  _buildStepPill('3', 'DoomsBlocker'),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
                  _buildStepPill('4', 'Turn ON', isHighlighted: true),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Brand Selector Tabs
            Row(
              children: [
                _buildBrandTab(0, 'Samsung'),
                const SizedBox(width: 6),
                _buildBrandTab(1, 'Xiaomi/Redmi'),
                const SizedBox(width: 6),
                _buildBrandTab(2, 'Vivo/Oppo'),
                const SizedBox(width: 6),
                _buildBrandTab(3, 'Other'),
              ],
            ),
            const SizedBox(height: 10),

            // Brand Specific Instructions Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _getBrandHeader(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getBrandSteps(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '💡 Tip: Leave the "Shortcut" switch OFF to prevent the navigation bar human icon.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sideloaded / Restricted Settings Warning Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_open_rounded, color: Color(0xFFB45309), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Is DoomsBlocker greyed out? (Restricted Setting)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Because this APK was installed manually (sideloaded), Android temporarily restricts accessibility.\n(Play Store downloads never have this restriction).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await NativeBridge.openAppDetailsSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text(
                      'Open App Info (Tap 3 dots → Allow restricted)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Primary CTA: Open Settings
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await NativeBridge.openAccessibilitySettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue to Accessibility Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill(String number, String label, {bool isHighlighted = false}) {
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlighted ? const Color(0xFF06B6D4) : const Color(0xFFCBD5E1),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            color: isHighlighted ? const Color(0xFF0284C7) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandTab(int index, String label) {
    final isSelected = _selectedBrandIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedBrandIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  String _getBrandHeader() {
    switch (_selectedBrandIndex) {
      case 0:
        return 'Samsung Navigation Steps';
      case 1:
        return 'Xiaomi / Redmi / Poco Steps';
      case 2:
        return 'Vivo / Oppo / Realme Steps';
      default:
        return 'Android Navigation Steps';
    }
  }

  String _getBrandSteps() {
    switch (_selectedBrandIndex) {
      case 0:
        return '1. Open Settings → Accessibility\n2. Tap "Installed apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON and tap Allow.';
      case 1:
        return '1. Open Settings → Additional settings → Accessibility\n2. Tap "Downloaded apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON, check the risk prompt, and tap OK.';
      case 2:
        return '1. Open Settings → Accessibility (or System settings)\n2. Tap "Downloaded apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON and confirm.';
      default:
        return '1. Open Settings → Accessibility\n2. Scroll down to find "DoomsBlocker"\n3. Tap "DoomsBlocker" and toggle the switch ON.';
    }
  }
}

