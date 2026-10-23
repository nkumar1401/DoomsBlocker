import 'package:flutter/services.dart';
import '../models/dashboard_data.dart';
import '../models/installed_app_model.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.doomsblocker.app/control');

  static Future<DashboardData> getDashboardData() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDashboardData');
      if (res != null) {
        return DashboardData.fromMap(res);
      }
    } catch (e) {
      // ignore
    }
    return DashboardData.initial();
  }

  static Future<bool> updateShortsConfig({
    required int limitMinutes,
    required int lockDurationMinutes,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('updateShortsConfig', {
        'limitMinutes': limitMinutes,
        'lockDurationMinutes': lockDurationMinutes,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> setNephewMode({
    required bool enabled,
    String? pin,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('setNephewMode', {
        'enabled': enabled,
        'pin': pin,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> setGameLimitMinutes(int minutes) async {
    try {
      final res = await _channel.invokeMethod<bool>('setGameLimitMinutes', {
        'minutes': minutes,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<InstalledAppModel>> getInstalledApps() async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getInstalledApps');
      if (res != null) {
        return res
            .map((item) => InstalledAppModel.fromMap(item as Map<dynamic, dynamic>))
            .toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  static Future<bool> toggleRestrictedApp(String packageName) async {
    try {
      final res = await _channel.invokeMethod<bool>('toggleRestrictedApp', {
        'packageName': packageName,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getBlockedChannels() async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getBlockedChannels');
      if (res != null) {
        return res.map((e) => e.toString()).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  static Future<bool> addBlockedChannel(String channel) async {
    try {
      final res = await _channel.invokeMethod<bool>('addBlockedChannel', {
        'channel': channel,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeBlockedChannel(String channel) async {
    try {
      final res = await _channel.invokeMethod<bool>('removeBlockedChannel', {
        'channel': channel,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      final res = await _channel.invokeMethod<bool>('verifyPin', {'pin': pin});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> emergencyUnlockYouTube(String pin) async {
    try {
      final res = await _channel.invokeMethod<bool>('emergencyUnlockYouTube', {
        'pin': pin,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startStudyZone({
    required String zoneName,
    required int durationMinutes,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('startStudyZone', {
        'zoneName': zoneName,
        'durationMinutes': durationMinutes,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> endStudyZone() async {
    try {
      final res = await _channel.invokeMethod<bool>('endStudyZone');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      if (res != null) {
        return {
          'accessibility': res['accessibility'] as bool? ?? false,
          'overlay': res['overlay'] as bool? ?? false,
          'usageStats': res['usageStats'] as bool? ?? false,
        };
      }
    } catch (e) {
      // ignore
    }
    return {
      'accessibility': false,
      'overlay': false,
      'usageStats': false,
    };
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  static Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (_) {}
  }
}
