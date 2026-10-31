import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';

class KidsModePaywallDialog extends StatefulWidget {
  const KidsModePaywallDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const KidsModePaywallDialog(),
    );
  }

  @override
  State<KidsModePaywallDialog> createState() => _KidsModePaywallDialogState();
}

class _KidsModePaywallDialogState extends State<KidsModePaywallDialog> {
  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _handleSubscribe() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing Google Play Billing...';
    });

    try {
      // 1. Ensure parent identity via Google 1-Tap
      if (!_authService.isSignedIn) {
        setState(() => _statusMessage = 'Signing in with Google...');
        final email = await _authService.signInWithGoogle();
        if (email == null) {
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
          return;
        }
      }

      // 2. Launch Google Play Billing Checkout (₹9/year)
      setState(() => _statusMessage = 'Opening Google Pay / Play Store sheet...');
      final success = await _subscriptionService.buyKidsSubscription();

      if (mounted) {
        if (success || _subscriptionService.isKidsSubscribed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Kids Mode Protection Recharged for 1 Year (365 Days)!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Payment error: $e';
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking past Google Play purchases...';
    });

    await _subscriptionService.restorePurchases();

    if (mounted) {
      setState(() => _isLoading = false);
      if (_subscriptionService.isKidsSubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription restored successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscription found on this Google account.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x6606B6D4),
            blurRadius: 30,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Parental Controls',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                          ),
                          child: const Text(
                            'KIDS MODE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: const Text(
                            'TRIAL ENDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Your 9-day free trial has completed',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Feature List
          _buildFeatureItem(
            Icons.block_rounded,
            const Color(0xFFEF4444),
            'Zero-Tolerance Shorts & Reels Block',
            'Completely locks vertical short-form addiction for young minds.',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.school_rounded,
            const Color(0xFF06B6D4),
            'Long-Form Educational YouTube Allowed',
            'Lectures, school tutorials, and cartoons allowed with strict daily timer.',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.lock_clock_rounded,
            const Color(0xFF8B5CF6),
            '24/7 Social Media Lockdown',
            'Instagram, Snapchat, Facebook, and TikTok completely blocked.',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.sports_esports_rounded,
            const Color(0xFF10B981),
            'Games Limit & Channel Blocklist',
            '5-min daily limit for games and automated channel filtering.',
          ),
          const SizedBox(height: 20),

          // Pricing Callout Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.15),
                  const Color(0xFF3B82F6).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: const [
                          Text(
                            '₹9.00',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            ' / 1-Year Pass',
                            style: TextStyle(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '(₹0.75 / mo)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kids Mode 1-Year Pass • One-Time Recharge\nZero Auto-Debit • No AutoPay Mandate\nSupports Google Pay (GPay), PhonePe, Paytm, UPI & Cards',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Text(
                    '90% OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Loading / Status Message
          if (_statusMessage != null) ...[
            Center(
              child: Text(
                _statusMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Subscribe Button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: const Color(0xFF06B6D4).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.payment_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Recharge 1-Year Pass for ₹9',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),

          // Mandatory Google Play Subscriptions Policy Disclosure
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Prepaid Terms: Plan: Kids Mode Annual Pass (₹9.00 / 1 Year). 9-day free trial included for eligible new installs. This is a one-time prepaid recharge with ZERO recurring AutoPay mandates. When the 365-day pass ends, Kids Mode locks peacefully without debiting your account. Extend or top up anytime in your Google Play Account.',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          // Restore Purchases & Adult Mode notice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading ? null : _handleRestore,
                child: const Text(
                  'Restore Purchase',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                ),
              ),
              const Text(
                'Focus & Study Zone remain 100% Free',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

