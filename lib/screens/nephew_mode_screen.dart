import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/create_pin_dialog.dart';

class NephewModeScreen extends StatefulWidget {
  const NephewModeScreen({Key? key}) : super(key: key);

  @override
  State<NephewModeScreen> createState() => _NephewModeScreenState();
}

class _NephewModeScreenState extends State<NephewModeScreen> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NativeBridge.getDashboardData();
    if (mounted) {
      setState(() {
        _isEnabled = data.isNephewModeEnabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMode(bool value) async {
    if (!value) {
      // Disabling requires PIN
      final pinOk = await PinDialog.show(
        context,
        title: 'Disable Nephew Mode',
        description: 'Enter your 4-digit Parent PIN to disable child protection.',
      );
      if (!pinOk) return;
    }

    await NativeBridge.setNephewMode(enabled: value);
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

    final created = await CreatePinDialog.show(context);
    if (created && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parent PIN updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Nephew & Kids Protection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Big Status Toggle Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isEnabled
                          ? [const Color(0xFF065F46), const Color(0xFF042F2E)]
                          : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isEnabled ? const Color(0xFF10B981) : const Color(0xFF334155),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEnabled ? 'NEPHEW MODE ON' : 'NEPHEW MODE OFF',
                            style: TextStyle(
                              color: _isEnabled ? const Color(0xFF10B981) : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEnabled ? 'Strict 20-min limits active' : 'Normal mode active',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                  'RULES ENFORCED IN NEPHEW MODE',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _buildRuleItem(
                  icon: Icons.video_collection_outlined,
                  color: const Color(0xFFEF4444),
                  title: 'YouTube Max 20 Minutes',
                  description: 'Limits YouTube viewing time so your nephew cannot stay glued to videos.',
                ),
                const SizedBox(height: 10),

                _buildRuleItem(
                  icon: Icons.sports_esports_outlined,
                  color: const Color(0xFF3B82F6),
                  title: 'Selected Games Max 20 Minutes',
                  description: 'Any game checkmarked in "Restricted Games" auto-locks after 20 minutes.',
                ),
                const SizedBox(height: 10),

                _buildRuleItem(
                  icon: Icons.block_outlined,
                  color: const Color(0xFFEC4899),
                  title: 'Blacklisted Channels Blocked',
                  description: 'Restricted YouTube channels cannot be played under any circumstances.',
                ),
                const SizedBox(height: 10),

                _buildRuleItem(
                  icon: Icons.lock_outline,
                  color: const Color(0xFF10B981),
                  title: 'PIN Protected Override',
                  description: 'Kids cannot bypass or turn off these restrictions without your 4-digit PIN.',
                ),

                const SizedBox(height: 28),

                // Change PIN button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parent 4-Digit PIN',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Default PIN: 1234',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: _changePin,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Change PIN', style: TextStyle(color: Color(0xFF10B981))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
