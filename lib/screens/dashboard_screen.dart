import 'dart:async';
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
    // Refresh every 2 seconds for live countdown & stats
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
    final pinEntered = await PinDialog.show(
      context,
      title: 'Emergency Unlock',
      description: 'Enter your 4-digit Parent PIN to override the 30-min YouTube lock.',
    );
    if (pinEntered) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('YouTube unlocked successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortsLimitSec = _data.shortsLimitMinutes * 60;
    final shortsProgress =
        (shortsLimitSec > 0) ? (_data.shortsUsedSecondsToday / shortsLimitSec).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DoomsBlocker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: _hasMissingPermissions ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            ),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PermissionsGuideScreen()))
                  .then((_) => _loadData());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              color: const Color(0xFFEF4444),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Missing permissions banner
                  if (_hasMissingPermissions)
                    _buildPermissionWarningBanner(),

                  // Lock Status Card
                  _buildLockStatusCard(),

                  const SizedBox(height: 16),

                  // Shorts Usage Monitor Card (5 min limit)
                  _buildShortsMonitorCard(shortsProgress),

                  const SizedBox(height: 16),

                  // Nephew Mode Quick Card
                  _buildNephewModeCard(),

                  const SizedBox(height: 24),

                  const Text(
                    'CONTROL PANEL',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid / List of settings
                  _buildNavCard(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Shorts Scrolling Rules',
                    subtitle: 'Scroll limit: ${_data.shortsLimitMinutes} min • Lock: ${_data.shortsLockDurationMinutes} min',
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const ShortsSettingsScreen()))
                          .then((_) => _loadData());
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildNavCard(
                    icon: Icons.sports_esports_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Restricted Games & Apps',
                    subtitle: '${_data.restrictedAppsCount} apps restricted • ${_data.gameLimitMinutes} min daily cap',
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const GameLimitsScreen()))
                          .then((_) => _loadData());
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildNavCard(
                    icon: Icons.block_outlined,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Blocked YouTube Channels',
                    subtitle: '${_data.blockedChannelsCount} channels blacklisted',
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const BlockedChannelsScreen()))
                          .then((_) => _loadData());
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildNavCard(
                    icon: Icons.family_restroom_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'Nephew Mode & Parent PIN',
                    subtitle: _data.isNephewModeEnabled ? 'ACTIVE (Protected by PIN)' : 'INACTIVE',
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const NephewModeScreen()))
                          .then((_) => _loadData());
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Required permissions missing. DoomsBlocker cannot monitor Shorts without Accessibility.',
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PermissionsGuideScreen()))
                  .then((_) => _loadData());
            },
            child: const Text('SETUP', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLockStatusCard() {
    final isLocked = _data.isYouTubeLocked;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked
              ? [const Color(0xFF991B1B), const Color(0xFF450A0A)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF334155),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isLocked ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
                    color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isLocked ? 'YOUTUBE IS LOCKED' : 'YOUTUBE UNLOCKED',
                    style: TextStyle(
                      color: isLocked ? Colors.white : const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (isLocked)
                TextButton(
                  onPressed: _handleEmergencyUnlock,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text(
                    'PIN UNLOCK',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLocked) ...[
            Text(
              'Locked for next 30 minutes after reaching 5-min Shorts limit.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Time Remaining: ',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  _formatSeconds(_data.youtubeLockRemainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'YouTube is available. Shorts scrolling is being monitored.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.play_circle_outline, color: Color(0xFFEF4444), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Shorts Screen Time',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Text(
                '${_formatSeconds(usedSec)} / ${_formatSeconds(limitSec)}',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.8 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rule: After 5 minutes of Shorts, YouTube auto-locks for 30 minutes.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.child_care_rounded,
                      color: enabled ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Nephew Mode',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Active: YouTube & marked games strictly locked at 20 min'
                      : 'Disabled: Regular personal limits active',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: const Color(0xFF10B981),
            onChanged: (val) async {
              if (!val) {
                // Disabling requires PIN
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

  Widget _buildNavCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 22),
          ],
        ),
      ),
    );
  }
}
