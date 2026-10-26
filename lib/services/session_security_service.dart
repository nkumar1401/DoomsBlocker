import 'package:flutter/material.dart';
import 'native_bridge.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/create_pin_dialog.dart';

class SessionSecurityService {
  SessionSecurityService._();
  static final SessionSecurityService instance = SessionSecurityService._();

  bool _isUnlocked = false;
  DateTime? _lastBackgroundTime;

  /// Background inactivity threshold matching Google Pay style (1 minute).
  static const Duration backgroundTimeout = Duration(minutes: 1);

  bool get isUnlocked {
    if (!_isUnlocked) return false;
    if (_lastBackgroundTime != null) {
      if (DateTime.now().difference(_lastBackgroundTime!) >= backgroundTimeout) {
        _isUnlocked = false;
        return false;
      }
    }
    return true;
  }

  void handleLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null &&
          DateTime.now().difference(_lastBackgroundTime!) >= backgroundTimeout) {
        _isUnlocked = false;
      }
      _lastBackgroundTime = null;
    }
  }

  void lockSession() {
    _isUnlocked = false;
    _lastBackgroundTime = null;
  }

  /// Authenticates the user for settings access.
  /// If already unlocked within the current session, returns true immediately.
  /// If PIN is not set yet, triggers the 2-step PIN creation dialog.
  /// If PIN is set, triggers the PIN verification dialog.
  Future<bool> authenticate(
    BuildContext context, {
    String reason = 'Enter your 4-digit PIN to access sensitive settings.',
  }) async {
    // 1. If session is still valid in memory, allow immediate access
    if (isUnlocked) {
      return true;
    }

    // 2. Check if a PIN is already configured
    final pinSet = await NativeBridge.isPinSet();
    if (!context.mounted) return false;

    if (!pinSet) {
      // Prompt user to create their initial 4-digit PIN
      final created = await CreatePinDialog.show(context);
      if (created) {
        _isUnlocked = true;
        _lastBackgroundTime = null;
        return true;
      }
      return false;
    }

    // 3. Prompt user to enter their existing 4-digit PIN
    final verified = await PinDialog.show(
      context,
      title: 'Enter Security PIN',
      description: reason,
    );

    if (verified) {
      _isUnlocked = true;
      _lastBackgroundTime = null;
      return true;
    }

    return false;
  }
}
