import 'package:flutter/material.dart';
import 'native_bridge.dart';

class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  bool _isChecking = false;
  bool _isUpdateMandatory = false;

  bool get isUpdateMandatory => _isUpdateMandatory;

  /// Check Google Play for immediate force-update on launch or resume
  Future<void> checkForImmediateUpdate(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final info = await NativeBridge.checkInAppUpdate();
      final hasUpdate = info['hasUpdate'] as bool? ?? false;
      final isImmediateAllowed = info['isImmediateAllowed'] as bool? ?? false;

      if (hasUpdate && isImmediateAllowed) {
        _isUpdateMandatory = true;
        // Attempt native Google Play immediate update sheet
        final started = await NativeBridge.startImmediateUpdate();
        if (!started && context.mounted) {
          // If Google Play sheet did not take over, show in-app blocking barrier
          _showBlockingUpdateModal(context);
        }
      } else {
        _isUpdateMandatory = false;
      }
    } catch (e) {
      debugPrint('InAppUpdate check completed with fallback (offline/sideload): $e');
    } finally {
      _isChecking = false;
    }
  }

  void _showBlockingUpdateModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false, // strictly non-dismissible
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF06B6D4), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update Required',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of DoomsBlocker is available on Google Play with critical wellbeing and anti-doomscrolling protections.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Please update your app to continue.',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'UPDATE ON GOOGLE PLAY',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                onPressed: () async {
                  final started = await NativeBridge.startImmediateUpdate();
                  if (!started) {
                    // Fallback to market intent if Play Core flow is blocked
                    // (NativeBridge handles market or Play Store URI)
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

