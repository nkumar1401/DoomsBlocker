import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class ShortsSettingsScreen extends StatefulWidget {
  const ShortsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ShortsSettingsScreen> createState() => _ShortsSettingsScreenState();
}

class _ShortsSettingsScreenState extends State<ShortsSettingsScreen> {
  int _limitMinutes = 2;
  int _lockDurationMinutes = 30;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await NativeBridge.getDashboardData();
    if (mounted) {
      setState(() {
        _limitMinutes = data.shortsLimitMinutes;
        _lockDurationMinutes = data.shortsLockDurationMinutes;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await NativeBridge.updateShortsConfig(
      limitMinutes: _limitMinutes,
      lockDurationMinutes: _lockDurationMinutes,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shorts rules saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Shorts Doomscrolling Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'When you watch Shorts, DoomsBlocker starts a stopwatch. Once your scroll limit is exhausted, YouTube is forcefully locked for the cooldown duration.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Shorts Scroll Limit Slider
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shorts Scroll Limit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_limitMinutes min',
                              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Maximum allowed active time scrolling Shorts before lockdown.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _limitMinutes.toDouble(),
                        min: 1,
                        max: 15,
                        divisions: 14,
                        activeColor: const Color(0xFFEF4444),
                        inactiveColor: const Color(0xFF334155),
                        label: '$_limitMinutes min',
                        onChanged: (val) {
                          setState(() => _limitMinutes = val.round());
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Lockout Duration Slider
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'YouTube Lockout Duration',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_lockDurationMinutes min',
                              style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'How long YouTube remains strictly blocked once the limit is hit.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _lockDurationMinutes.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 7,
                        activeColor: const Color(0xFF3B82F6),
                        inactiveColor: const Color(0xFF334155),
                        label: '$_lockDurationMinutes min',
                        onChanged: (val) {
                          setState(() => _lockDurationMinutes = val.round());
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Rules',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
    );
  }
}
