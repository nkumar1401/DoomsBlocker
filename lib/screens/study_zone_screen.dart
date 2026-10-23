import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/dashboard_data.dart';
import '../services/native_bridge.dart';
import 'qr_scanner_screen.dart';

class StudyZoneScreen extends StatefulWidget {
  const StudyZoneScreen({Key? key}) : super(key: key);

  @override
  State<StudyZoneScreen> createState() => _StudyZoneScreenState();
}

class _StudyZoneScreenState extends State<StudyZoneScreen>
    with SingleTickerProviderStateMixin {
  DashboardData _data = DashboardData.initial();
  bool _isLoading = true;
  Timer? _ticker;
  int _localRemainingSeconds = 0;

  final GlobalKey _entrancePosterKey = GlobalKey();
  final GlobalKey _exitPosterKey = GlobalKey();

  // Selected duration for check-in
  int _selectedDurationMinutes = 60;
  String _customLibraryName = 'City Central Library';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_data.isStudyZoneActive) {
        if (_localRemainingSeconds > 0) {
          setState(() => _localRemainingSeconds--);
        } else {
          // Timer hit zero -> refresh native data (auto-release check)
          _loadData();
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await NativeBridge.getDashboardData();
    if (mounted) {
      setState(() {
        _data = data;
        _localRemainingSeconds = data.studyZoneRemainingSeconds;
        _isLoading = false;
      });
    }
  }

  String _formatTimer(int totalSec) {
    if (totalSec <= 0) return '00:00:00';
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleScanEntrance() async {
    final result = await Navigator.of(context).push<StudyQrPayload>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Entrance Poster',
          subtitle: 'Scan the printed QR at the library entrance to check in',
          expectedType: StudyScanType.checkIn,
        ),
      ),
    );

    if (result != null && mounted) {
      if (result.type == StudyScanType.checkIn || result.type == StudyScanType.unknown) {
        _showGoalPickerSheet(result.zoneName);
      } else if (result.type == StudyScanType.checkOut) {
        _handleScanExit(result.zoneName);
      }
    }
  }

  Future<void> _handleScanExit([String? zone]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.door_sliding_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('Confirm Early Checkout', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'You are leaving ${zone ?? _data.studyZoneName}. This will release the distraction lock and return your phone to normal mode.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Studying', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Checkout & Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NativeBridge.endStudyZone();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Study session completed! Distraction lock released.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _handleStartStudySession(String zoneName, int minutes) async {
    final success = await NativeBridge.startStudyZone(
      zoneName: zoneName,
      durationMinutes: minutes,
    );

    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📚 Checked into $zoneName for $minutes minutes! Focus locked.'),
            backgroundColor: const Color(0xFF06B6D4),
          ),
        );
      }
    }
  }

  void _showGoalPickerSheet(String zoneName) {
    int duration = _selectedDurationMinutes;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF131B2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF06B6D4), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zoneName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Select your study goal duration',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'DURATION PRESETS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildPresetChip('30 min', 30, duration, (val) => setSheetState(() => duration = val)),
                    _buildPresetChip('45 min', 45, duration, (val) => setSheetState(() => duration = val)),
                    _buildPresetChip('1 Hour', 60, duration, (val) => setSheetState(() => duration = val)),
                    _buildPresetChip('2 Hours', 120, duration, (val) => setSheetState(() => duration = val)),
                    _buildPresetChip('3 Hours', 180, duration, (val) => setSheetState(() => duration = val)),
                    _buildPresetChip('4 Hours', 240, duration, (val) => setSheetState(() => duration = val)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Custom Duration', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      '${duration ~/ 60 > 0 ? '${duration ~/ 60}h ' : ''}${duration % 60}m',
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: duration.toDouble(),
                  min: 15,
                  max: 360,
                  divisions: 23, // 15-min increments
                  activeColor: const Color(0xFF06B6D4),
                  inactiveColor: Colors.white12,
                  onChanged: (val) => setSheetState(() => duration = val.toInt()),
                ),
                const SizedBox(height: 16),
                // Lock notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Personal PIN will be disabled. Shorts & Reels are blocked until the timer hits 00:00 or you scan the Exit QR poster.',
                          style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleStartStudySession(zoneName, duration);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_clock, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Lock Focus & Start Studying',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    int minutes,
    int current,
    Function(int) onSelect,
  ) {
    final isSelected = current == minutes;
    return InkWell(
      onTap: () => onSelect(minutes),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF06B6D4) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080D1A),
        elevation: 0,
        title: const Text(
          'Library Study Zone',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06B6D4),
          indicatorWeight: 3,
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Study Mode'),
            Tab(icon: Icon(Icons.print_outlined, size: 20), text: 'Poster Generator'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudyModeTab(),
                _buildPosterGeneratorTab(),
              ],
            ),
    );
  }

  Widget _buildStudyModeTab() {
    if (_data.isStudyZoneActive) {
      return _buildActiveStudyView();
    } else {
      return _buildCheckInView();
    }
  }

  Widget _buildActiveStudyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Active session glowing badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 8),
                Text(
                  'CHEAT-PROOF FOCUS ACTIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Central circular countdown ring
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF131B2E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
              border: Border.all(
                color: const Color(0xFF06B6D4).withOpacity(0.3),
                width: 4,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFF06B6D4), size: 30),
                const SizedBox(height: 10),
                Text(
                  _formatTimer(_localRemainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFeatures: [],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'REMAINING GOAL',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Zone info card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF06B6D4), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _data.studyZoneName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text('📚 Studying', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white38, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shorts and Reels are completely disabled. Your personal PIN cannot be used to unlock until your timer runs out or you scan the Exit QR poster at the desk.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Scan Exit QR button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: const Text(
                'Scan Exit QR to Release',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final payload = await Navigator.of(context).push<StudyQrPayload>(
                  MaterialPageRoute(
                    builder: (_) => const QrScannerScreen(
                      title: 'Scan Desk Exit QR',
                      subtitle: 'Point camera at the printed Library Checkout QR',
                      expectedType: StudyScanType.checkOut,
                    ),
                  ),
                );
                if (payload != null && mounted) {
                  _handleScanExit(payload.zoneName);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _handleScanExit(),
            child: const Text(
              'Left the library? Emergency Manual Exit',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.15),
                  const Color(0xFF1E293B).withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_library_rounded,
                        color: Color(0xFF06B6D4),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library Check-In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Scan once. Focus 100%. No PIN required.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Arrived at your study hall? Scan the printed QR poster at the desk or entrance. Set how long you want to study, and DoomsBlocker will completely disable doomscrolling until you are done.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Scan Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text(
                'Scan Library Entrance QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _handleScanEntrance,
            ),
          ),
          const SizedBox(height: 24),

          // Feature Highlights
          const Text(
            'HOW IT PROTECTS YOUR STUDY TIME',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _buildFeatureCard(
            icon: Icons.lock_clock,
            color: const Color(0xFF10B981),
            title: 'Auto-Release Timer',
            description: 'Choose your study goal (e.g. 1 hour, 2 hours). Distraction block releases automatically when your time is up.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.no_encryption_gmailerrorred_outlined,
            color: const Color(0xFFF59E0B),
            title: 'Cheat-Proof (PIN Disabled)',
            description: 'Your normal unlock PIN is disabled during study mode so you cannot impulsively bypass your own goal.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.door_front_door_outlined,
            color: const Color(0xFF8B5CF6),
            title: 'Instant Exit QR',
            description: 'Need to leave early? Just scan the printed Exit QR poster located at the library front desk to release.',
          ),
          const SizedBox(height: 20),

          // Direct Demo / Manual Start without QR (useful for testing or home study)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Studying at home or desk?',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Start a self-guided Study Zone session',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showGoalPickerSheet('Personal Study Desk'),
                  child: const Text('Start Now', style: TextStyle(color: Color(0xFF06B6D4))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // POSTER GENERATOR TAB
  Widget _buildPosterGeneratorTab() {
    final entrancePayload = 'DOOMSBLOCKER_STUDY:IN:$_customLibraryName';
    final exitPayload = 'DOOMSBLOCKER_STUDY:OUT:$_customLibraryName';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print, color: Color(0xFF06B6D4), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Printable Library Posters',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Library owners and study halls do not need any app, server, or hardware! Simply print or display these two QR codes on your desk or walls.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Library / Study Hall Name',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  controller: TextEditingController(text: _customLibraryName),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() => _customLibraryName = val.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Poster 1: Entrance Check-In
          _buildPrintablePosterCard(
            repaintKey: _entrancePosterKey,
            title: '1. Entrance Poster (Check-In)',
            badgeText: 'PRINT FOR ENTRANCE & DESKS',
            badgeColor: const Color(0xFF06B6D4),
            qrData: entrancePayload,
            instructions: 'Students scan this QR to choose study duration & lock distraction.',
            footerNote: 'Encodes: $entrancePayload',
            onShare: () => _sharePoster(_entrancePosterKey, 'Entrance_CheckIn'),
          ),
          const SizedBox(height: 28),

          // Poster 2: Exit Checkout
          _buildPrintablePosterCard(
            repaintKey: _exitPosterKey,
            title: '2. Exit Poster (Checkout)',
            badgeText: 'PRINT FOR FRONT DESK EXIT',
            badgeColor: const Color(0xFF10B981),
            qrData: exitPayload,
            instructions: 'Students scan this QR when leaving early to release the lock.',
            footerNote: 'Encodes: $exitPayload',
            onShare: () => _sharePoster(_exitPosterKey, 'Exit_Checkout'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _sharePoster(GlobalKey key, String name) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final file = File('${tempDir.path}/doomsblocker_${sanitized}_poster.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📚 DoomsBlocker $name Poster for $_customLibraryName\nPrint this high-resolution QR poster for your study desk.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share poster: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildPrintablePosterCard({
    required GlobalKey repaintKey,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String qrData,
    required String instructions,
    required String footerNote,
    required VoidCallback onShare,
  }) {
    return Column(
      children: [
        RepaintBoundary(
          key: repaintKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _customLibraryName,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                ),
                const SizedBox(height: 16),

                // White QR container with high contrast
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 190.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  instructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  footerNote,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Share & Print Actions
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: badgeColor.withOpacity(0.4)),
              ),
            ),
            icon: Icon(Icons.share_rounded, size: 18, color: badgeColor),
            label: Text(
              'Share via WhatsApp / Email to Print',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            onPressed: onShare,
          ),
        ),
      ],
    );
  }
}
