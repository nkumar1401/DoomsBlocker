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

  final List<int> _presetLimits = [1, 2, 3, 5, 10, 15, 30, 45, 60];
  final List<int> _presetLockDurations = [15, 30, 60, 120, 240, 480, 720, 1440];

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

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return '$h hr';
    }
    return '$h hr $m min';
  }

  Future<void> _showCustomMinutesDialog({
    required String title,
    required String description,
    required int currentValue,
    required int min,
    required int max,
    required Function(int) onSaved,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Duration in Minutes',
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                suffixText: 'min',
                suffixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Text('Allowed: $min to $max minutes (${_formatDuration(min)} to ${_formatDuration(max)})',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= min && parsed <= max) {
                onSaved(parsed);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid number between $min and $max.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Set Duration', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                          'When you watch Shorts, DoomsBlocker tracks scroll time. Once your scroll limit is exhausted, YouTube is forcefully locked for the cooldown duration.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Shorts Scroll Limit
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
                          InkWell(
                            onTap: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Shorts Limit',
                                description: 'Enter maximum active Shorts scrolling time allowed before lockdown.',
                                currentValue: _limitMinutes,
                                min: 1,
                                max: 180,
                                onSaved: (val) => setState(() => _limitMinutes = val),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDuration(_limitMinutes),
                                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: Color(0xFFEF4444)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Allowed active time scrolling Shorts before lockdown.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._presetLimits.map((m) {
                            final selected = _limitMinutes == m;
                            return ChoiceChip(
                              label: Text(_formatDuration(m)),
                              selected: selected,
                              selectedColor: const Color(0xFFEF4444),
                              backgroundColor: const Color(0xFF0F172A),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _limitMinutes = m),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14, color: Color(0xFFEF4444)),
                            label: const Text('Custom...'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onPressed: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Shorts Limit',
                                description: 'Enter maximum active Shorts scrolling time allowed.',
                                currentValue: _limitMinutes,
                                min: 1,
                                max: 180,
                                onSaved: (val) => setState(() => _limitMinutes = val),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: _limitMinutes.toDouble().clamp(1.0, 180.0),
                        min: 1,
                        max: 180,
                        divisions: 179,
                        activeColor: const Color(0xFFEF4444),
                        inactiveColor: const Color(0xFF334155),
                        label: _formatDuration(_limitMinutes),
                        onChanged: (val) {
                          setState(() => _limitMinutes = val.round());
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Lockout Duration
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
                            'Lockout Cooldown Duration',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          InkWell(
                            onTap: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Lockout Duration',
                                description: 'Enter how long YouTube or feeds remain blocked after limit is hit (up to 24 hours).',
                                currentValue: _lockDurationMinutes,
                                min: 5,
                                max: 1440,
                                onSaved: (val) => setState(() => _lockDurationMinutes = val),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDuration(_lockDurationMinutes),
                                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: Color(0xFF3B82F6)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'How long distraction remains strictly blocked once your limit is exhausted.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._presetLockDurations.map((m) {
                            final selected = _lockDurationMinutes == m;
                            return ChoiceChip(
                              label: Text(_formatDuration(m)),
                              selected: selected,
                              selectedColor: const Color(0xFF3B82F6),
                              backgroundColor: const Color(0xFF0F172A),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _lockDurationMinutes = m),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14, color: Color(0xFF3B82F6)),
                            label: const Text('Custom...'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onPressed: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Lockout Duration',
                                description: 'Enter how long distraction remains blocked after limit is hit (e.g. 480 min for 8 hours).',
                                currentValue: _lockDurationMinutes,
                                min: 5,
                                max: 1440,
                                onSaved: (val) => setState(() => _lockDurationMinutes = val),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: _lockDurationMinutes.toDouble().clamp(5.0, 1440.0),
                        min: 5,
                        max: 1440,
                        divisions: 287, // ~5 min increments up to 24h
                        activeColor: const Color(0xFF3B82F6),
                        inactiveColor: const Color(0xFF334155),
                        label: _formatDuration(_lockDurationMinutes),
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
