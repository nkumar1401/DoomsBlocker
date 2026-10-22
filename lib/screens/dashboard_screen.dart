import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/native_bridge.dart';
import '../widgets/pin_dialog.dart';
import 'shorts_settings_screen.dart';
import 'game_limits_screen.dart';
import 'blocked_channels_screen.dart';
import 'nephew_mode_screen.dart';
import 'permissions_guide_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData _data = DashboardData.initial();
  bool _isLoading = true;
  Timer? _refreshTimer;
  Map<String, bool> _permissions = {
    'accessibility': false,
    'overlay': false,
    'usageStats': false,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final data = await NativeBridge.getDashboardData();
    final perms = await NativeBridge.checkPermissions();

    if (mounted) {
      setState(() {
        _data = data;
        _permissions = perms;
        _isLoading = false;
      });
    }
  }

  bool get _hasMissingPermissions =>
      !(_permissions['accessibility'] ?? false) ||
      !(_permissions['overlay'] ?? false) ||
      !(_permissions['usageStats'] ?? false);

  String _formatSeconds(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleEmergencyUnlock() async {
    final pin = await PinDialog.showAndGetPin(
      context,
      title: 'Emergency Unlock',
      description: 'Enter your 4-digit Parent PIN to override the 30-min YouTube lock.',
    );
    if (pin != null) {
      final unlocked = await NativeBridge.emergencyUnlockYouTube(pin);
      if (unlocked) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YouTube unlocked successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to unlock. Incorrect PIN.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortsLimitSec = _data.shortsLimitMinutes * 60;
    final shortsProgress =
        (shortsLimitSec > 0) ? (_data.shortsUsedSecondsToday / shortsLimitSec).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: Stack(
        children: [
          // Ambient blurred glow orbs for glassmorphism
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.12),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildGlassAppBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadData(),
                          color: const Color(0xFF06B6D4),
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            children: [
                              if (_hasMissingPermissions) _buildPermissionWarningBanner(),

                              // Hero Circular Ring Timer Card
                              _buildHeroRingCard(),

                              const SizedBox(height: 18),

                              // Shorts Screen Time Card
                              _buildShortsMonitorCard(shortsProgress),

                              const SizedBox(height: 14),

                              // Nephew Mode Guard Card
                              _buildNephewModeCard(),

                              const SizedBox(height: 22),

                              // Control Panel Header
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'CONTROL PANEL',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Control Grid Tiles
                              _buildControlPanelGrid(),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DoomsBlocker',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Digital Wellbeing',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8).withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _hasMissingPermissions
                    ? const Color(0xFFF59E0B).withOpacity(0.15)
                    : const Color(0xFF10B981).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hasMissingPermissions
                      ? const Color(0xFFF59E0B).withOpacity(0.5)
                      : const Color(0xFF10B981).withOpacity(0.5),
                ),
              ),
              child: Icon(
                _hasMissingPermissions ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: _hasMissingPermissions ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PermissionsGuideScreen()))
                  .then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Permissions missing. Tap setup to grant Accessibility.',
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PermissionsGuideScreen()))
                  .then((_) => _loadData());
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: const Color(0xFFF59E0B).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('SETUP', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRingCard() {
    final isLocked = _data.isYouTubeLocked;
    final totalLockoutSec = _data.shortsLockDurationMinutes * 60;
    final remainingSec = _data.youtubeLockRemainingSeconds;
    final progress = isLocked && totalLockoutSec > 0
        ? (remainingSec / totalLockoutSec).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F).withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.white.withOpacity(0.09),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLocked
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : const Color(0xFF06B6D4).withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isLocked
                  ? const Color(0xFFEF4444).withOpacity(0.18)
                  : const Color(0xFF10B981).withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLocked
                    ? const Color(0xFFEF4444).withOpacity(0.5)
                    : const Color(0xFF10B981).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isLocked ? 'LOCKDOWN ACTIVE' : 'PROTECTION ACTIVE',
                  style: TextStyle(
                    color: isLocked ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Glowing Circular Ring Timer
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: RadialRingPainter(
                    progress: progress,
                    startColor: isLocked ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                    endColor: isLocked ? const Color(0xFFA855F7) : const Color(0xFF8B5CF6),
                    trackColor: Colors.white.withOpacity(0.06),
                    strokeWidth: 9.0,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLocked) ...[
                      Text(
                        _formatSeconds(remainingSec),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Locked for ${_data.shortsLockDurationMinutes} min',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 40),
                      const SizedBox(height: 6),
                      const Text(
                        'UNLOCKED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'YouTube is available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Override / Unlock Capsule Button
          if (isLocked)
            ElevatedButton.icon(
              onPressed: _handleEmergencyUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                foregroundColor: const Color(0xFF6EE7B7),
                elevation: 0,
                side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text(
                'Override with PIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortsMonitorCard(double progress) {
    final usedSec = _data.shortsUsedSecondsToday;
    final limitSec = _data.shortsLimitMinutes * 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFEF4444), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Shorts Screen Time',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '${_formatSeconds(usedSec)} / ${_formatSeconds(limitSec)}',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Gradient Progress Bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * progress;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: barWidth,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Rule: After ${_data.shortsLimitMinutes} min of Shorts, auto-locks for ${_data.shortsLockDurationMinutes} min.',
            style: TextStyle(color: const Color(0xFF94A3B8).withOpacity(0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildNephewModeCard() {
    final enabled = _data.isNephewModeEnabled;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: enabled
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.child_care_rounded,
                    color: enabled ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nephew Guard',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? 'Active: YouTube & games strictly locked'
                            : 'Disabled: Regular personal limits active',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8).withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withOpacity(0.4),
            onChanged: (val) async {
              if (!val) {
                final pinOk = await PinDialog.show(
                  context,
                  title: 'Turn Off Nephew Mode',
                  description: 'Enter your 4-digit Parent PIN to disable nephew restrictions.',
                );
                if (!pinOk) return;
              }
              await NativeBridge.setNephewMode(enabled: val);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanelGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGridTile(
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Shorts Rules',
                subtitle: '${_data.shortsLimitMinutes}m limit',
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ShortsSettingsScreen()))
                      .then((_) => _loadData());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGridTile(
                icon: Icons.block_flipped,
                iconColor: const Color(0xFFF43F5E),
                title: 'Blocked Channels',
                subtitle: '${_data.blockedChannelsCount} restricted',
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const BlockedChannelsScreen()))
                      .then((_) => _loadData());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGridTile(
                icon: Icons.sports_esports_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'App Limits',
                subtitle: '${_data.restrictedAppsCount} games',
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const GameLimitsScreen()))
                      .then((_) => _loadData());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGridTile(
                icon: Icons.lock_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Security PIN',
                subtitle: 'Parent PIN',
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NephewModeScreen()))
                      .then((_) => _loadData());
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF121B2F).withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: const Color(0xFF94A3B8).withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RadialRingPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Color trackColor;
  final double strokeWidth;

  RadialRingPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.trackColor,
    this.strokeWidth = 9.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Glowing arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [startColor, endColor],
    );

    final glowPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawArc(
      rect,
      0,
      sweepAngle,
      false,
      glowPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RadialRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
