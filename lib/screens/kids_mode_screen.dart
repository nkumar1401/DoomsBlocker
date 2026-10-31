import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/native_bridge.dart';
import '../services/subscription_service.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/create_pin_dialog.dart';
import '../widgets/duration_picker_dialog.dart';
import '../widgets/kids_mode_paywall_dialog.dart';
import 'game_limits_screen.dart';
import 'blocked_channels_screen.dart';

class KidsModeScreen extends StatefulWidget {
  const KidsModeScreen({Key? key}) : super(key: key);

  @override
  State<KidsModeScreen> createState() => _KidsModeScreenState();
}

class _KidsModeScreenState extends State<KidsModeScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _isEnabled = false;
  bool _isLoading = true;
  int _shortsLimitMinutes = 20;
  int _lockDurationMinutes = 30;
  int _gameLimitMinutes = 20;
  int _restrictedCount = 0;
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NativeBridge.getDashboardData();
    await _subscriptionService.init();
    await _subscriptionService.checkAndTriggerExpiryNotifications();

    if (mounted) {
      setState(() {
        _isEnabled = data.isKidsModeEnabled;
        _shortsLimitMinutes = data.shortsLimitMinutes;
        _lockDurationMinutes = data.shortsLockDurationMinutes;
        _gameLimitMinutes = data.gameLimitMinutes;
        _restrictedCount = data.restrictedAppsCount;
        _blockedCount = data.blockedChannelsCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMode(bool value) async {
    if (value) {
      // 1. Enabling: Check 9-Day Trial or Subscription
      if (!_subscriptionService.canAccessKidsMode) {
        final purchased = await KidsModePaywallDialog.show(context);
        if (purchased != true && !_subscriptionService.canAccessKidsMode) {
          return; // User canceled paywall, leave toggle OFF
        }
      }
    } else {
      // 2. Disabling requires Parent PIN
      final pinOk = await PinDialog.show(
        context,
        title: 'Disable Kids Mode',
        description: 'Enter your 4-digit Parent PIN to disable child protection.',
      );
      if (!pinOk) return;
    }

    await NativeBridge.setKidsMode(enabled: value);
    setState(() => _isEnabled = value);
  }

  Future<void> _changePin() async {
    final pinSet = await NativeBridge.isPinSet();
    if (pinSet) {
      final pinOk = await PinDialog.show(
        context,
        title: 'Verify Current PIN',
        description: 'Enter your current 4-digit PIN before setting a new one.',
      );
      if (!pinOk) return;
    }

    if (!mounted) return;

    final created = await CreatePinDialog.show(context, isUpdating: pinSet);
    if (created && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pinSet
                ? 'New Security PIN set successfully!'
                : 'Security PIN created successfully!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'Parental Controls (Kids Mode)',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Trial / Subscription Status Card
                _buildSubscriptionStatusBanner(),
                const SizedBox(height: 14),

                // 2. Big Status Toggle Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isEnabled ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isEnabled
                            ? const Color(0xFF10B981).withOpacity(0.08)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isEnabled
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.child_care_rounded,
                              color: _isEnabled ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEnabled ? 'PARENTAL CONTROLS ON' : 'PARENTAL CONTROLS OFF',
                                style: TextStyle(
                                  color: _isEnabled ? const Color(0xFF047857) : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isEnabled ? 'Strict parental supervision active' : 'Normal adult mode active',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isEnabled,
                        activeColor: const Color(0xFF10B981),
                        onChanged: _toggleMode,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'RULES ENFORCED IN KIDS MODE',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),

                // Rule 1: YouTube Screen Time (Educational Videos Only)
                _buildInteractiveRuleItem(
                  icon: Icons.video_collection_outlined,
                  color: const Color(0xFFEF4444),
                  title: 'YouTube: $_shortsLimitMinutes min Limit (0s Shorts)',
                  description: 'Shorts & Reels are completely blocked (0s). Long-form educational videos allowed up to $_shortsLimitMinutes min daily.',
                  badge: 'Edit',
                  onTap: () async {
                    final selected = await DurationPickerDialog.show(
                      context,
                      title: 'YouTube Screen Time Limit',
                      description: 'Scroll hours and minutes allowed for YouTube before auto-locking.',
                      initialMinutes: _shortsLimitMinutes,
                      minMinutes: 1,
                      maxMinutes: 180,
                      quickPresets: [5, 10, 15, 20, 30, 45, 60],
                    );
                    if (selected != null) {
                      await NativeBridge.updateShortsConfig(
                        limitMinutes: selected,
                        lockDurationMinutes: _lockDurationMinutes,
                      );
                      _load();
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Rule 2: Selected Games
                _buildInteractiveRuleItem(
                  icon: Icons.sports_esports_outlined,
                  color: const Color(0xFF3B82F6),
                  title: 'Selected Games: $_gameLimitMinutes min Limit',
                  description: '$_restrictedCount games marked. Auto-locks once total session reaches $_gameLimitMinutes minutes.',
                  badge: 'Configure',
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const GameLimitsScreen()))
                        .then((_) => _load());
                  },
                ),
                const SizedBox(height: 10),

                // Rule 3: Restricted Channels
                _buildInteractiveRuleItem(
                  icon: Icons.block_outlined,
                  color: const Color(0xFFEC4899),
                  title: 'Restricted Channels Blocked',
                  description: '$_blockedCount inappropriate channels blocked. Automatically kicks user back to Home screen.',
                  badge: 'Manage',
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const BlockedChannelsScreen()))
                        .then((_) => _load());
                  },
                ),
                const SizedBox(height: 10),

                // Rule 4: Parent PIN Protection (with Change PIN action)
                _buildInteractiveRuleItem(
                  icon: Icons.lock_outline,
                  color: const Color(0xFF10B981),
                  title: 'Parent PIN Protection',
                  description: 'Children cannot bypass limits or disable Kids Mode without your 4-digit Parent PIN. Tap to change PIN.',
                  badge: 'Change PIN',
                  onTap: _changePin,
                ),
              ],
            ),
    );
  }

  Widget _buildSubscriptionStatusBanner() {
    if (_subscriptionService.isKidsSubscribed) {
      final days = _subscriptionService.prepaidDaysRemaining;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⭐ 1-Year Pass Active: $days day(s) remaining (No AutoPay)',
                style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } else if (_subscriptionService.isKidsTrialActive) {
      final days = _subscriptionService.trialDaysRemaining;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFF06B6D4), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎁 Free Trial Active: $days day(s) remaining (₹9 recharge on Day 10)',
                style: const TextStyle(color: Color(0xFF0E7490), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () async {
          final res = await KidsModePaywallDialog.show(context);
          if (res == true) _load();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
          ),
          child: Row(
            children: const [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ 1-Year Pass Expired • Tap to Recharge for ₹9 (No AutoPay)',
                  style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildInteractiveRuleItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  badge,
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, color: color, size: 14),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
