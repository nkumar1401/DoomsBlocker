import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../widgets/duration_picker_dialog.dart';

class ShortsSettingsScreen extends StatefulWidget {
  const ShortsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ShortsSettingsScreen> createState() => _ShortsSettingsScreenState();
}

class _ShortsSettingsScreenState extends State<ShortsSettingsScreen> {
  int _limitMinutes = 2;
  int _lockDurationMinutes = 30;
  List<String> _selectedApps = [
    'com.google.android.youtube',
    'com.instagram.android',
  ];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<int> _presetLimits = [1, 2, 3, 5, 10, 15, 30, 45, 60];
  final List<int> _presetLockDurations = [15, 30, 60, 120, 240, 480, 720, 1440];

  final List<Map<String, dynamic>> _supportedPlatforms = [
    {
      'package': 'com.google.android.youtube',
      'name': 'YouTube Shorts',
      'subtitle': 'Shorts feed & shelf • Long-form videos allowed',
      'icon': Icons.play_circle_fill_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'package': 'com.instagram.android',
      'name': 'Instagram Reels',
      'subtitle': 'Reels viewer & explore feed reels',
      'icon': Icons.camera_alt_rounded,
      'color': Color(0xFFE1306C),
    },
    {
      'package': 'com.snapchat.android',
      'name': 'Snapchat Spotlight',
      'subtitle': 'Spotlight feed locked • Chat & Camera stay open',
      'icon': Icons.flash_on_rounded,
      'color': Color(0xFFFFCC00),
    },
    {
      'package': 'in.mohalla.sharechat',
      'name': 'ShareChat',
      'subtitle': 'Pure short-video feed • Full lock on limit',
      'icon': Icons.share_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'package': 'in.mohalla.video',
      'name': 'Moj',
      'subtitle': 'Short-video clips • Full lock on limit',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFFF5722),
    },
    {
      'package': 'com.eterno.shortvideos',
      'name': 'Josh',
      'subtitle': 'Dailyhunt short videos • Full lock on limit',
      'icon': Icons.videocam_rounded,
      'color': Color(0xFF3B82F6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await NativeBridge.getDashboardData();
    final apps = await NativeBridge.getEnabledShortFormApps();
    if (mounted) {
      setState(() {
        _limitMinutes = data.shortsLimitMinutes;
        _lockDurationMinutes = data.shortsLockDurationMinutes;
        _selectedApps = apps.isNotEmpty ? apps : data.enabledShortFormApps;
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
    final List<int> presets = max <= 180
        ? [2, 5, 10, 15, 30, 45, 60, 90, 120]
        : [15, 30, 45, 60, 120, 180, 360, 720, 1440];

    final selected = await DurationPickerDialog.show(
      context,
      title: title,
      description: description,
      initialMinutes: currentValue,
      minMinutes: min,
      maxMinutes: max,
      quickPresets: presets,
    );

    if (selected != null) {
      onSaved(selected);
    }
  }

  Future<void> _save() async {
    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one short-form platform to monitor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok1 = await NativeBridge.updateShortsConfig(
      limitMinutes: _limitMinutes,
      lockDurationMinutes: _lockDurationMinutes,
    );
    final ok2 = await NativeBridge.setEnabledShortFormApps(_selectedApps);

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok1 && ok2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Short-form rules and platforms saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _togglePlatform(String pkg) {
    setState(() {
      if (_selectedApps.contains(pkg)) {
        if (_selectedApps.length > 1) {
          _selectedApps.remove(pkg);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one platform must remain selected.'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _selectedApps.add(pkg);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text('Short-Form Video Rules', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Track active doomscrolling across your chosen platforms into one shared pool. When your limit expires, short feeds lock together for the cooldown period.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Monitored Short-Form Platforms Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monitored Platforms',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_selectedApps.length} Selected',
                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select apps that contribute to your shared scroll-time pool:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      ..._supportedPlatforms.map((p) {
                        final pkg = p['package'] as String;
                        final name = p['name'] as String;
                        final subtitle = p['subtitle'] as String;
                        final icon = p['icon'] as IconData;
                        final color = p['color'] as Color;
                        final isChecked = _selectedApps.contains(pkg);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isChecked ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChecked ? color.withOpacity(0.4) : const Color(0xFF334155),
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            activeColor: color,
                            checkColor: Colors.black,
                            value: isChecked,
                            onChanged: (_) => _togglePlatform(pkg),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              subtitle,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Unified Scroll Limit Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Unified Scroll Limit',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          InkWell(
                            onTap: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Scroll Limit',
                                description: 'Enter maximum active scrolling time across selected platforms before lockdown.',
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
                        'Allowed active time scrolling across monitored apps before lockdown.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._presetLimits.map((mins) {
                            final selected = _limitMinutes == mins;
                            return ChoiceChip(
                              label: Text('${mins}m'),
                              selected: selected,
                              selectedColor: const Color(0xFFEF4444),
                              backgroundColor: const Color(0xFFF8FAFC),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF64748B),
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              onSelected: (_) => setState(() => _limitMinutes = mins),
                            );
                          }).toList(),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14, color: Color(0xFFEF4444)),
                            label: const Text('Custom'),
                            backgroundColor: const Color(0xFFF8FAFC),
                            labelStyle: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onPressed: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Scroll Limit',
                                description: 'Enter maximum active scrolling time across selected apps before lockdown (e.g. 75 min).',
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
                        max: 60,
                        divisions: 59,
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

                const SizedBox(height: 24),

                // 3. Lockout Cooldown Duration Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Lockout Cooldown Duration',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          InkWell(
                            onTap: () {
                              _showCustomMinutesDialog(
                                title: 'Custom Lockout Duration',
                                description: 'Enter how long short feeds remain blocked after limit is hit (up to 24 hours).',
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
                        'How long feeds remain blocked once the limit is reached.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._presetLockDurations.map((mins) {
                            final selected = _lockDurationMinutes == mins;
                            return ChoiceChip(
                              label: Text(_formatDuration(mins)),
                              selected: selected,
                              selectedColor: const Color(0xFF3B82F6),
                              backgroundColor: const Color(0xFFF8FAFC),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF64748B),
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              onSelected: (_) => setState(() => _lockDurationMinutes = mins),
                            );
                          }).toList(),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14, color: Color(0xFF3B82F6)),
                            label: const Text('Custom'),
                            backgroundColor: const Color(0xFFF8FAFC),
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
                        divisions: 287,
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
