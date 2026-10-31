
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DurationPickerDialog extends StatefulWidget {
  final String title;
  final String description;
  final int initialMinutes;
  final int minMinutes;
  final int maxMinutes;
  final List<int>? quickPresets;

  const DurationPickerDialog({
    Key? key,
    required this.title,
    required this.description,
    required this.initialMinutes,
    this.minMinutes = 1,
    this.maxMinutes = 1440,
    this.quickPresets,
  }) : super(key: key);

  static Future<int?> show(
    BuildContext context, {
    required String title,
    required String description,
    required int initialMinutes,
    int minMinutes = 1,
    int maxMinutes = 1440,
    List<int>? quickPresets,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DurationPickerDialog(
        title: title,
        description: description,
        initialMinutes: initialMinutes,
        minMinutes: minMinutes,
        maxMinutes: maxMinutes,
        quickPresets: quickPresets,
      ),
    );
  }

  @override
  State<DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<DurationPickerDialog> {
  late int _selectedHours;
  late int _selectedMinutes;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final clamped = widget.initialMinutes.clamp(widget.minMinutes, widget.maxMinutes);
    _selectedHours = clamped ~/ 60;
    _selectedMinutes = clamped % 60;

    _hourController = FixedExtentScrollController(initialItem: _selectedHours);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  int get _totalMinutes => (_selectedHours * 60) + _selectedMinutes;

  String _formatPreview(int total) {
    if (total == 0) return '0 min';
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  void _applyPreset(int presetMinutes) {
    setState(() {
      _selectedHours = presetMinutes ~/ 60;
      _selectedMinutes = presetMinutes % 60;
      _hourController.jumpToItem(_selectedHours);
      _minuteController.jumpToItem(_selectedMinutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = widget.maxMinutes ~/ 60;
    final isValid = _totalMinutes >= widget.minMinutes && _totalMinutes <= widget.maxMinutes;

    return Container(
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
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

            // Live Preview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isValid ? const Color(0xFF06B6D4) : const Color(0xFFEF4444),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selected Duration:',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_formatPreview(_totalMinutes)} ($_totalMinutes min)',
                    style: TextStyle(
                      color: isValid ? const Color(0xFF06B6D4) : const Color(0xFFEF4444),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dual Cupertino Scroll Wheels (Hours & Minutes)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Hours Wheel
                  Expanded(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'HOURS',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: _hourController,
                            itemExtent: 44,
                            magnification: 1.2,
                            useMagnifier: true,
                            onSelectedItemChanged: (idx) {
                              setState(() => _selectedHours = idx);
                            },
                            children: List.generate(maxH + 1, (i) {
                              return Center(
                                child: Text(
                                  '$i hr',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(width: 1, height: 100, color: const Color(0xFFE2E8F0)),

                  // Minutes Wheel
                  Expanded(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'MINUTES',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: _minuteController,
                            itemExtent: 44,
                            magnification: 1.2,
                            useMagnifier: true,
                            onSelectedItemChanged: (idx) {
                              setState(() => _selectedMinutes = idx);
                            },
                            children: List.generate(60, (i) {
                              return Center(
                                child: Text(
                                  '$i min',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Presets (if provided)
            if (widget.quickPresets != null && widget.quickPresets!.isNotEmpty) ...[
              const Text(
                'Quick Presets:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.quickPresets!.map((p) {
                    final selected = _totalMinutes == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: selected ? const Color(0xFF06B6D4) : const Color(0xFFF1F5F9),
                        label: Text(
                          _formatPreview(p),
                          style: TextStyle(
                            color: selected ? Colors.white : const Color(0xFF334155),
                            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _applyPreset(p),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? const Color(0xFF06B6D4) : const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: isValid ? 2 : 0,
                ),
                onPressed: isValid
                    ? () => Navigator.pop(context, _totalMinutes)
                    : null,
                child: Text(
                  isValid ? 'Confirm ${_formatPreview(_totalMinutes)}' : 'Select at least ${widget.minMinutes} min',
                  style: TextStyle(
                    color: isValid ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

